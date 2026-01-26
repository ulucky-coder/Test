"""
Supabase client for Telegram Job Repost Bot.
Handles all database operations with retry logic and error handling.
"""

import hashlib
from datetime import datetime, timedelta
from typing import Optional, List, Dict, Any
from uuid import UUID

import structlog
from supabase import create_client, Client
from tenacity import retry, stop_after_attempt, wait_exponential

from ..config import get_settings
from .models import (
    SourceGroup,
    TargetChannel,
    JobTemplate,
    PostedJob,
    JobQueue,
    BotSetting,
    Keyword,
    Contact,
    ActivityLog,
    ParsedJobData
)

logger = structlog.get_logger(__name__)


class SupabaseClient:
    """Supabase database client with all CRUD operations."""

    def __init__(self):
        settings = get_settings()
        self.client: Client = create_client(
            settings.supabase.url,
            settings.supabase.service_key
        )
        self._settings_cache: Dict[str, Any] = {}
        self._keywords_cache: Optional[List[Keyword]] = None
        self._template_cache: Optional[JobTemplate] = None

    # =========================================
    # Source Groups
    # =========================================

    @retry(stop=stop_after_attempt(3), wait=wait_exponential(min=1, max=10))
    async def get_active_source_groups(self) -> List[SourceGroup]:
        """Get all active source groups ordered by priority."""
        response = self.client.table("source_groups").select("*").eq(
            "is_active", True
        ).order("priority", desc=True).execute()

        return [SourceGroup(**row) for row in response.data]

    @retry(stop=stop_after_attempt(3), wait=wait_exponential(min=1, max=10))
    async def get_source_group_by_telegram_id(self, telegram_id: int) -> Optional[SourceGroup]:
        """Get source group by Telegram ID."""
        response = self.client.table("source_groups").select("*").eq(
            "telegram_id", telegram_id
        ).limit(1).execute()

        if response.data:
            return SourceGroup(**response.data[0])
        return None

    @retry(stop=stop_after_attempt(3), wait=wait_exponential(min=1, max=10))
    async def upsert_source_group(self, group: SourceGroup) -> SourceGroup:
        """Insert or update source group."""
        data = group.model_dump(exclude={"id", "created_at"}, exclude_none=True)
        data["updated_at"] = datetime.utcnow().isoformat()

        response = self.client.table("source_groups").upsert(
            data, on_conflict="telegram_id"
        ).execute()

        return SourceGroup(**response.data[0])

    @retry(stop=stop_after_attempt(3), wait=wait_exponential(min=1, max=10))
    async def update_group_last_checked(
        self, telegram_id: int, last_message_id: int
    ) -> None:
        """Update last checked timestamp and message ID."""
        self.client.table("source_groups").update({
            "last_checked_at": datetime.utcnow().isoformat(),
            "last_message_id": last_message_id
        }).eq("telegram_id", telegram_id).execute()

    # =========================================
    # Target Channels
    # =========================================

    @retry(stop=stop_after_attempt(3), wait=wait_exponential(min=1, max=10))
    async def get_active_target_channels(self) -> List[TargetChannel]:
        """Get all active target channels."""
        response = self.client.table("target_channels").select("*").eq(
            "is_active", True
        ).execute()

        return [TargetChannel(**row) for row in response.data]

    @retry(stop=stop_after_attempt(3), wait=wait_exponential(min=1, max=10))
    async def upsert_target_channel(self, channel: TargetChannel) -> TargetChannel:
        """Insert or update target channel."""
        data = channel.model_dump(exclude={"id", "created_at"}, exclude_none=True)
        data["updated_at"] = datetime.utcnow().isoformat()

        response = self.client.table("target_channels").upsert(
            data, on_conflict="telegram_id"
        ).execute()

        return TargetChannel(**response.data[0])

    # =========================================
    # Job Templates
    # =========================================

    @retry(stop=stop_after_attempt(3), wait=wait_exponential(min=1, max=10))
    async def get_default_template(self) -> Optional[JobTemplate]:
        """Get the default job template."""
        if self._template_cache:
            return self._template_cache

        response = self.client.table("job_templates").select("*").eq(
            "is_default", True
        ).eq("is_active", True).limit(1).execute()

        if response.data:
            self._template_cache = JobTemplate(**response.data[0])
            return self._template_cache
        return None

    @retry(stop=stop_after_attempt(3), wait=wait_exponential(min=1, max=10))
    async def get_template_by_name(self, name: str) -> Optional[JobTemplate]:
        """Get template by name."""
        response = self.client.table("job_templates").select("*").eq(
            "name", name
        ).limit(1).execute()

        if response.data:
            return JobTemplate(**response.data[0])
        return None

    # =========================================
    # Posted Jobs (Deduplication)
    # =========================================

    @staticmethod
    def generate_content_hash(text: str) -> str:
        """Generate hash for content deduplication."""
        normalized = " ".join(text.lower().split())
        return hashlib.sha256(normalized.encode()).hexdigest()[:64]

    @retry(stop=stop_after_attempt(3), wait=wait_exponential(min=1, max=10))
    async def is_duplicate(self, content_hash: str) -> bool:
        """Check if job with this hash was already posted."""
        cutoff_date = (datetime.utcnow() - timedelta(days=14)).isoformat()

        response = self.client.table("posted_jobs").select("id").eq(
            "content_hash", content_hash
        ).gte("created_at", cutoff_date).limit(1).execute()

        return len(response.data) > 0

    @retry(stop=stop_after_attempt(3), wait=wait_exponential(min=1, max=10))
    async def record_posted_job(
        self,
        content_hash: str,
        original_text: str,
        formatted_text: str,
        parsed_data: Dict[str, Any],
        source_telegram_id: int,
        original_message_id: int,
        posted_message_id: Optional[int] = None,
        target_channel_id: Optional[UUID] = None,
        status: str = "posted"
    ) -> PostedJob:
        """Record a posted job for deduplication."""
        data = {
            "content_hash": content_hash,
            "original_text": original_text,
            "formatted_text": formatted_text,
            "parsed_data": parsed_data,
            "source_telegram_id": source_telegram_id,
            "original_message_id": original_message_id,
            "posted_message_id": posted_message_id,
            "status": status,
            "posted_at": datetime.utcnow().isoformat() if status == "posted" else None
        }

        if target_channel_id:
            data["target_channel_id"] = str(target_channel_id)

        response = self.client.table("posted_jobs").insert(data).execute()
        return PostedJob(**response.data[0])

    @retry(stop=stop_after_attempt(3), wait=wait_exponential(min=1, max=10))
    async def cleanup_old_jobs(self) -> int:
        """Delete jobs older than 14 days. Returns count of deleted records."""
        cutoff_date = (datetime.utcnow() - timedelta(days=14)).isoformat()

        response = self.client.table("posted_jobs").delete().lt(
            "created_at", cutoff_date
        ).execute()

        deleted_count = len(response.data) if response.data else 0

        await self.log_activity(
            event_type="cleanup",
            event_data={"deleted_count": deleted_count},
            severity="info"
        )

        return deleted_count

    # =========================================
    # Job Queue
    # =========================================

    @retry(stop=stop_after_attempt(3), wait=wait_exponential(min=1, max=10))
    async def add_to_queue(
        self,
        content_hash: str,
        original_text: str,
        source_telegram_id: int,
        original_message_id: int,
        parsed_data: Optional[Dict[str, Any]] = None,
        formatted_text: Optional[str] = None,
        priority: int = 5
    ) -> JobQueue:
        """Add job to publishing queue."""
        data = {
            "content_hash": content_hash,
            "original_text": original_text,
            "source_telegram_id": source_telegram_id,
            "original_message_id": original_message_id,
            "parsed_data": parsed_data,
            "formatted_text": formatted_text,
            "priority": priority,
            "status": "pending"
        }

        response = self.client.table("job_queue").insert(data).execute()
        return JobQueue(**response.data[0])

    @retry(stop=stop_after_attempt(3), wait=wait_exponential(min=1, max=10))
    async def get_pending_jobs(self, limit: int = 10) -> List[JobQueue]:
        """Get pending jobs from queue ordered by priority."""
        response = self.client.table("job_queue").select("*").in_(
            "status", ["pending", "ready"]
        ).order("priority", desc=True).order("created_at").limit(limit).execute()

        return [JobQueue(**row) for row in response.data]

    @retry(stop=stop_after_attempt(3), wait=wait_exponential(min=1, max=10))
    async def update_job_status(
        self,
        job_id: UUID,
        status: str,
        error_message: Optional[str] = None,
        formatted_text: Optional[str] = None,
        parsed_data: Optional[Dict[str, Any]] = None
    ) -> None:
        """Update job queue status."""
        data = {"status": status, "updated_at": datetime.utcnow().isoformat()}

        if error_message:
            data["error_message"] = error_message

        if formatted_text:
            data["formatted_text"] = formatted_text

        if parsed_data:
            data["parsed_data"] = parsed_data

        if status == "failed":
            self.client.table("job_queue").update({
                **data,
                "attempts": self.client.table("job_queue").select("attempts").eq(
                    "id", str(job_id)
                ).execute().data[0]["attempts"] + 1
            }).eq("id", str(job_id)).execute()
        else:
            self.client.table("job_queue").update(data).eq("id", str(job_id)).execute()

    @retry(stop=stop_after_attempt(3), wait=wait_exponential(min=1, max=10))
    async def remove_from_queue(self, job_id: UUID) -> None:
        """Remove job from queue."""
        self.client.table("job_queue").delete().eq("id", str(job_id)).execute()

    # =========================================
    # Keywords
    # =========================================

    @retry(stop=stop_after_attempt(3), wait=wait_exponential(min=1, max=10))
    async def get_keywords(self, keyword_type: Optional[str] = None) -> List[Keyword]:
        """Get active keywords, optionally filtered by type."""
        if self._keywords_cache and not keyword_type:
            return self._keywords_cache

        query = self.client.table("keywords").select("*").eq("is_active", True)

        if keyword_type:
            query = query.eq("keyword_type", keyword_type)

        response = query.execute()
        keywords = [Keyword(**row) for row in response.data]

        if not keyword_type:
            self._keywords_cache = keywords

        return keywords

    async def get_include_keywords(self) -> List[str]:
        """Get list of include keywords."""
        keywords = await self.get_keywords("include")
        return [k.word.lower() for k in keywords]

    async def get_exclude_keywords(self) -> List[str]:
        """Get list of exclude keywords."""
        keywords = await self.get_keywords("exclude")
        return [k.word.lower() for k in keywords]

    # =========================================
    # Contacts
    # =========================================

    @retry(stop=stop_after_attempt(3), wait=wait_exponential(min=1, max=10))
    async def get_default_contact(self) -> Optional[Contact]:
        """Get default contact for job posts."""
        response = self.client.table("contacts").select("*").eq(
            "is_default", True
        ).eq("is_active", True).limit(1).execute()

        if response.data:
            return Contact(**response.data[0])
        return None

    @retry(stop=stop_after_attempt(3), wait=wait_exponential(min=1, max=10))
    async def get_contact_link(self) -> str:
        """Get contact link for template."""
        contact = await self.get_default_contact()
        if contact:
            if contact.bot_link:
                return contact.bot_link
            if contact.telegram_username:
                return f"https://t.me/{contact.telegram_username}"
        return "Уточняйте у администратора"

    # =========================================
    # Bot Settings
    # =========================================

    @retry(stop=stop_after_attempt(3), wait=wait_exponential(min=1, max=10))
    async def get_setting(self, key: str, default: Any = None) -> Any:
        """Get bot setting by key."""
        if key in self._settings_cache:
            return self._settings_cache[key]

        response = self.client.table("bot_settings").select("value").eq(
            "key", key
        ).limit(1).execute()

        if response.data:
            value = response.data[0]["value"]
            self._settings_cache[key] = value
            return value

        return default

    @retry(stop=stop_after_attempt(3), wait=wait_exponential(min=1, max=10))
    async def set_setting(self, key: str, value: Any, description: Optional[str] = None) -> None:
        """Set bot setting."""
        data = {
            "key": key,
            "value": value,
            "updated_at": datetime.utcnow().isoformat()
        }

        if description:
            data["description"] = description

        self.client.table("bot_settings").upsert(data, on_conflict="key").execute()
        self._settings_cache[key] = value

    async def get_all_settings(self) -> Dict[str, Any]:
        """Get all bot settings as dictionary."""
        response = self.client.table("bot_settings").select("*").execute()

        settings = {}
        for row in response.data:
            settings[row["key"]] = row["value"]
            self._settings_cache[row["key"]] = row["value"]

        return settings

    # =========================================
    # Activity Log
    # =========================================

    @retry(stop=stop_after_attempt(3), wait=wait_exponential(min=1, max=10))
    async def log_activity(
        self,
        event_type: str,
        event_data: Optional[Dict[str, Any]] = None,
        source_group_id: Optional[UUID] = None,
        job_id: Optional[UUID] = None,
        severity: str = "info"
    ) -> None:
        """Log bot activity."""
        data = {
            "event_type": event_type,
            "event_data": event_data or {},
            "severity": severity
        }

        if source_group_id:
            data["source_group_id"] = str(source_group_id)

        if job_id:
            data["job_id"] = str(job_id)

        try:
            self.client.table("activity_log").insert(data).execute()
        except Exception as e:
            logger.error("Failed to log activity", error=str(e))

    @retry(stop=stop_after_attempt(3), wait=wait_exponential(min=1, max=10))
    async def get_recent_logs(
        self,
        limit: int = 100,
        severity: Optional[str] = None
    ) -> List[ActivityLog]:
        """Get recent activity logs."""
        query = self.client.table("activity_log").select("*").order(
            "created_at", desc=True
        ).limit(limit)

        if severity:
            query = query.eq("severity", severity)

        response = query.execute()
        return [ActivityLog(**row) for row in response.data]

    # =========================================
    # Cache Management
    # =========================================

    def clear_cache(self) -> None:
        """Clear all caches."""
        self._settings_cache.clear()
        self._keywords_cache = None
        self._template_cache = None

    def invalidate_settings_cache(self) -> None:
        """Invalidate settings cache."""
        self._settings_cache.clear()

    def invalidate_keywords_cache(self) -> None:
        """Invalidate keywords cache."""
        self._keywords_cache = None

    def invalidate_template_cache(self) -> None:
        """Invalidate template cache."""
        self._template_cache = None


# Global instance
_db_client: Optional[SupabaseClient] = None


def get_db() -> SupabaseClient:
    """Get or create database client instance."""
    global _db_client
    if _db_client is None:
        _db_client = SupabaseClient()
    return _db_client
