"""
Job scheduler module.
Manages periodic tasks for collection and publishing.
"""

import asyncio
from datetime import datetime
from typing import Optional, Callable, Dict, Any

import structlog
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.interval import IntervalTrigger
from apscheduler.triggers.cron import CronTrigger

from ..config import get_settings
from ..database import get_db
from .collector import JobCollector
from .publisher import JobPublisher
from .client import get_telegram_client

logger = structlog.get_logger(__name__)


class JobScheduler:
    """
    Manages scheduled tasks for the bot.
    - Collection: Every hour (configurable)
    - Publishing: Continuously from queue
    - Cleanup: Daily at 3 AM
    """

    def __init__(
        self,
        collector: Optional[JobCollector] = None,
        publisher: Optional[JobPublisher] = None
    ):
        self.settings = get_settings()
        self.db = get_db()
        self.telegram = get_telegram_client()

        self.collector = collector or JobCollector(self.telegram, self.db)
        self.publisher = publisher or JobPublisher(self.telegram, self.db)

        self.scheduler = AsyncIOScheduler()
        self._is_running = False
        self._collection_in_progress = False
        self._publishing_in_progress = False

    async def _run_collection(self) -> None:
        """Run collection job."""
        if self._collection_in_progress:
            logger.warning("Collection already in progress, skipping")
            return

        self._collection_in_progress = True
        try:
            logger.info("Starting scheduled collection")
            result = await self.collector.run_collection_cycle()
            logger.info("Scheduled collection completed", **result)
        except Exception as e:
            logger.error("Scheduled collection failed", error=str(e))
            await self.db.log_activity(
                event_type="scheduled_collection_error",
                event_data={"error": str(e)},
                severity="error"
            )
        finally:
            self._collection_in_progress = False

    async def _run_publishing(self) -> None:
        """Run publishing job."""
        if self._publishing_in_progress:
            logger.debug("Publishing already in progress, skipping")
            return

        self._publishing_in_progress = True
        try:
            result = await self.publisher.publish_batch(limit=5)
            if result["published"] > 0:
                logger.info("Scheduled publishing completed", **{
                    k: v for k, v in result.items() if k != "jobs"
                })
        except Exception as e:
            logger.error("Scheduled publishing failed", error=str(e))
            await self.db.log_activity(
                event_type="scheduled_publishing_error",
                event_data={"error": str(e)},
                severity="error"
            )
        finally:
            self._publishing_in_progress = False

    async def _run_cleanup(self) -> None:
        """Run cleanup job."""
        try:
            logger.info("Starting scheduled cleanup")
            deleted = await self.db.cleanup_old_jobs()
            logger.info("Scheduled cleanup completed", deleted_count=deleted)
        except Exception as e:
            logger.error("Scheduled cleanup failed", error=str(e))

    async def _run_health_check(self) -> None:
        """Run periodic health check."""
        try:
            # Check Telegram connection
            me = await self.telegram.get_me()
            logger.debug("Health check passed", user=me["user"]["username"])

            # Log stats
            stats = await self.publisher.get_queue_stats()
            await self.db.log_activity(
                event_type="health_check",
                event_data=stats,
                severity="debug"
            )
        except Exception as e:
            logger.error("Health check failed", error=str(e))
            await self.db.log_activity(
                event_type="health_check_failed",
                event_data={"error": str(e)},
                severity="warning"
            )

    def setup_jobs(self) -> None:
        """Setup all scheduled jobs."""
        # Collection job - every hour (configurable)
        check_interval = self.settings.bot.check_interval_minutes
        self.scheduler.add_job(
            self._run_collection,
            IntervalTrigger(minutes=check_interval),
            id="collection",
            name="Job Collection",
            replace_existing=True,
            max_instances=1
        )
        logger.info(f"Collection job scheduled every {check_interval} minutes")

        # Publishing job - every 3 minutes
        self.scheduler.add_job(
            self._run_publishing,
            IntervalTrigger(minutes=3),
            id="publishing",
            name="Job Publishing",
            replace_existing=True,
            max_instances=1
        )
        logger.info("Publishing job scheduled every 3 minutes")

        # Cleanup job - daily at 3 AM
        self.scheduler.add_job(
            self._run_cleanup,
            CronTrigger(hour=3, minute=0),
            id="cleanup",
            name="Database Cleanup",
            replace_existing=True
        )
        logger.info("Cleanup job scheduled daily at 3 AM")

        # Health check - every 10 minutes
        self.scheduler.add_job(
            self._run_health_check,
            IntervalTrigger(minutes=10),
            id="health_check",
            name="Health Check",
            replace_existing=True
        )
        logger.info("Health check scheduled every 10 minutes")

    async def start(self) -> None:
        """Start the scheduler."""
        if self._is_running:
            logger.warning("Scheduler already running")
            return

        # Connect Telegram clients
        await self.telegram.connect()

        # Setup and start scheduler
        self.setup_jobs()
        self.scheduler.start()
        self._is_running = True

        logger.info("Scheduler started")

        # Run initial collection
        await self._run_collection()

    async def stop(self) -> None:
        """Stop the scheduler."""
        if not self._is_running:
            return

        self.scheduler.shutdown(wait=True)
        await self.telegram.disconnect()
        self._is_running = False

        logger.info("Scheduler stopped")

    async def trigger_collection(self) -> Dict[str, Any]:
        """Manually trigger collection."""
        if self._collection_in_progress:
            return {"status": "skipped", "reason": "Collection already in progress"}

        result = await self.collector.run_collection_cycle()
        return {"status": "completed", "result": result}

    async def trigger_publishing(self, limit: int = 5) -> Dict[str, Any]:
        """Manually trigger publishing."""
        if self._publishing_in_progress:
            return {"status": "skipped", "reason": "Publishing already in progress"}

        result = await self.publisher.publish_batch(limit=limit)
        return {"status": "completed", "result": result}

    def get_job_status(self) -> Dict[str, Any]:
        """Get status of all scheduled jobs."""
        jobs = {}
        for job in self.scheduler.get_jobs():
            jobs[job.id] = {
                "name": job.name,
                "next_run": job.next_run_time.isoformat() if job.next_run_time else None,
                "pending": job.pending
            }

        return {
            "is_running": self._is_running,
            "collection_in_progress": self._collection_in_progress,
            "publishing_in_progress": self._publishing_in_progress,
            "jobs": jobs
        }


# Global instance
_scheduler: Optional[JobScheduler] = None


def get_scheduler() -> JobScheduler:
    """Get or create scheduler instance."""
    global _scheduler
    if _scheduler is None:
        _scheduler = JobScheduler()
    return _scheduler
