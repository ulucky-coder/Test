"""
FastAPI webhook server for n8n integration.
Provides API endpoints for controlling the bot.
"""

from typing import Optional, List, Dict, Any
from datetime import datetime

import structlog
from fastapi import FastAPI, HTTPException, Header, BackgroundTasks, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from ..config import get_settings
from ..database import get_db, SourceGroup, TargetChannel
from ..bot.scheduler import get_scheduler, JobScheduler
from ..bot.publisher import JobPublisher
from ..bot.collector import JobCollector
from ..parsers import get_parser

logger = structlog.get_logger(__name__)

# Pydantic models for API
class JobPostRequest(BaseModel):
    """Request to publish a job."""
    text: str = Field(..., description="Raw job text to parse and publish")
    contact_link: Optional[str] = Field(None, description="Custom contact link")
    priority: int = Field(5, ge=1, le=10, description="Job priority")


class SourceGroupRequest(BaseModel):
    """Request to add/update source group."""
    telegram_id: int
    username: Optional[str] = None
    title: Optional[str] = None
    group_type: str = "public"
    invite_link: Optional[str] = None
    priority: int = Field(1, ge=1, le=10)


class TargetChannelRequest(BaseModel):
    """Request to add/update target channel."""
    telegram_id: int
    username: Optional[str] = None
    title: Optional[str] = None
    channel_type: str = "group"


class SettingRequest(BaseModel):
    """Request to update setting."""
    key: str
    value: Any


class ParseRequest(BaseModel):
    """Request to parse job text (without publishing)."""
    text: str


class TriggerResponse(BaseModel):
    """Response for trigger operations."""
    status: str
    message: Optional[str] = None
    result: Optional[Dict[str, Any]] = None


def get_settings_instance():
    """Dependency for settings."""
    return get_settings()


def verify_api_key(
    x_api_key: str = Header(..., alias="X-API-Key"),
    settings = Depends(get_settings_instance)
) -> bool:
    """Verify API key from header."""
    if x_api_key != settings.webhook.secret:
        raise HTTPException(status_code=401, detail="Invalid API key")
    return True


def create_app() -> FastAPI:
    """Create and configure FastAPI application."""
    app = FastAPI(
        title="Telegram Job Repost Bot API",
        description="API for n8n integration with the job repost bot",
        version="1.0.0"
    )

    # CORS middleware
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # ==========================================
    # Health endpoints
    # ==========================================

    @app.get("/health")
    async def health_check():
        """Health check endpoint."""
        return {
            "status": "healthy",
            "timestamp": datetime.utcnow().isoformat()
        }

    @app.get("/status", dependencies=[Depends(verify_api_key)])
    async def get_status():
        """Get bot status and statistics."""
        scheduler = get_scheduler()
        db = get_db()

        job_status = scheduler.get_job_status()

        # Get queue stats
        pending_jobs = await db.get_pending_jobs(limit=1000)

        return {
            "scheduler": job_status,
            "queue": {
                "pending_count": len(pending_jobs)
            },
            "timestamp": datetime.utcnow().isoformat()
        }

    # ==========================================
    # Collection endpoints
    # ==========================================

    @app.post("/collect", response_model=TriggerResponse, dependencies=[Depends(verify_api_key)])
    async def trigger_collection(background_tasks: BackgroundTasks):
        """Trigger job collection from source groups."""
        scheduler = get_scheduler()
        result = await scheduler.trigger_collection()
        return TriggerResponse(
            status=result["status"],
            result=result.get("result")
        )

    # ==========================================
    # Publishing endpoints
    # ==========================================

    @app.post("/publish", response_model=TriggerResponse, dependencies=[Depends(verify_api_key)])
    async def trigger_publishing(limit: int = 5):
        """Trigger publishing from queue."""
        scheduler = get_scheduler()
        result = await scheduler.trigger_publishing(limit=limit)
        return TriggerResponse(
            status=result["status"],
            result=result.get("result")
        )

    @app.post("/publish/single", response_model=TriggerResponse, dependencies=[Depends(verify_api_key)])
    async def publish_single_job(request: JobPostRequest):
        """Parse and publish a single job immediately."""
        from ..bot.client import get_telegram_client

        publisher = JobPublisher(
            telegram_client=get_telegram_client(),
            db_client=get_db()
        )

        result = await publisher.publish_single(
            text=request.text,
            custom_contact=request.contact_link
        )

        return TriggerResponse(
            status=result["status"],
            message=result.get("error"),
            result={
                "message_id": result.get("message_id"),
                "formatted_text": result.get("formatted_text")
            }
        )

    # ==========================================
    # Parse endpoint (for preview)
    # ==========================================

    @app.post("/parse", dependencies=[Depends(verify_api_key)])
    async def parse_job(request: ParseRequest):
        """Parse job text without publishing (for preview)."""
        parser = get_parser()
        parsed = await parser.parse(request.text)

        # Format for preview
        from ..templates import get_formatter
        formatter = get_formatter()
        formatted = await formatter.format(parsed)

        return {
            "parsed_data": parsed.model_dump(),
            "formatted_text": formatted,
            "confidence_score": parsed.confidence_score
        }

    # ==========================================
    # Source groups management
    # ==========================================

    @app.get("/groups", dependencies=[Depends(verify_api_key)])
    async def list_source_groups():
        """List all source groups."""
        db = get_db()
        groups = await db.get_active_source_groups()
        return {
            "groups": [g.model_dump() for g in groups],
            "count": len(groups)
        }

    @app.post("/groups", dependencies=[Depends(verify_api_key)])
    async def add_source_group(request: SourceGroupRequest):
        """Add or update a source group."""
        db = get_db()
        group = SourceGroup(
            telegram_id=request.telegram_id,
            username=request.username,
            title=request.title,
            group_type=request.group_type,
            invite_link=request.invite_link,
            priority=request.priority
        )
        result = await db.upsert_source_group(group)
        return {"status": "success", "group": result.model_dump()}

    @app.delete("/groups/{telegram_id}", dependencies=[Depends(verify_api_key)])
    async def deactivate_source_group(telegram_id: int):
        """Deactivate a source group."""
        db = get_db()
        group = await db.get_source_group_by_telegram_id(telegram_id)
        if not group:
            raise HTTPException(status_code=404, detail="Group not found")

        group.is_active = False
        await db.upsert_source_group(group)
        return {"status": "success", "message": "Group deactivated"}

    # ==========================================
    # Target channels management
    # ==========================================

    @app.get("/channels", dependencies=[Depends(verify_api_key)])
    async def list_target_channels():
        """List all target channels."""
        db = get_db()
        channels = await db.get_active_target_channels()
        return {
            "channels": [c.model_dump() for c in channels],
            "count": len(channels)
        }

    @app.post("/channels", dependencies=[Depends(verify_api_key)])
    async def add_target_channel(request: TargetChannelRequest):
        """Add or update a target channel."""
        db = get_db()
        channel = TargetChannel(
            telegram_id=request.telegram_id,
            username=request.username,
            title=request.title,
            channel_type=request.channel_type
        )
        result = await db.upsert_target_channel(channel)
        return {"status": "success", "channel": result.model_dump()}

    # ==========================================
    # Queue management
    # ==========================================

    @app.get("/queue", dependencies=[Depends(verify_api_key)])
    async def get_queue():
        """Get pending jobs in queue."""
        db = get_db()
        jobs = await db.get_pending_jobs(limit=50)
        return {
            "jobs": [j.model_dump() for j in jobs],
            "count": len(jobs)
        }

    @app.delete("/queue/{job_id}", dependencies=[Depends(verify_api_key)])
    async def remove_from_queue(job_id: str):
        """Remove a job from queue."""
        from uuid import UUID
        db = get_db()
        try:
            await db.remove_from_queue(UUID(job_id))
            return {"status": "success", "message": "Job removed from queue"}
        except Exception as e:
            raise HTTPException(status_code=400, detail=str(e))

    # ==========================================
    # Settings management
    # ==========================================

    @app.get("/settings", dependencies=[Depends(verify_api_key)])
    async def get_all_settings():
        """Get all bot settings."""
        db = get_db()
        settings = await db.get_all_settings()
        return {"settings": settings}

    @app.post("/settings", dependencies=[Depends(verify_api_key)])
    async def update_setting(request: SettingRequest):
        """Update a bot setting."""
        db = get_db()
        await db.set_setting(request.key, request.value)
        return {"status": "success", "key": request.key, "value": request.value}

    # ==========================================
    # Activity log
    # ==========================================

    @app.get("/logs", dependencies=[Depends(verify_api_key)])
    async def get_recent_logs(limit: int = 50, severity: Optional[str] = None):
        """Get recent activity logs."""
        db = get_db()
        logs = await db.get_recent_logs(limit=limit, severity=severity)
        return {
            "logs": [l.model_dump() for l in logs],
            "count": len(logs)
        }

    # ==========================================
    # Keywords management
    # ==========================================

    @app.get("/keywords", dependencies=[Depends(verify_api_key)])
    async def list_keywords():
        """List all keywords."""
        db = get_db()
        keywords = await db.get_keywords()
        return {
            "keywords": [k.model_dump() for k in keywords],
            "count": len(keywords)
        }

    # ==========================================
    # Cache management
    # ==========================================

    @app.post("/cache/clear", dependencies=[Depends(verify_api_key)])
    async def clear_caches():
        """Clear all caches."""
        db = get_db()
        db.clear_cache()

        from ..templates import get_formatter
        formatter = get_formatter()
        formatter.invalidate_cache()

        return {"status": "success", "message": "All caches cleared"}

    return app


# Create default app instance
app = create_app()
