"""
Job publisher module.
Publishes formatted jobs to target groups/channels.
"""

import asyncio
from datetime import datetime
from typing import Optional, List, Dict, Any
from uuid import UUID

import structlog

from ..config import get_settings
from ..database import get_db, JobQueue, PostedJob
from ..database.supabase_client import SupabaseClient
from ..parsers import get_parser, CombinedParser
from ..templates import get_formatter, JobTemplateFormatter
from .client import TelegramClient, get_telegram_client

logger = structlog.get_logger(__name__)


class JobPublisher:
    """
    Publishes jobs from queue to target channels.
    Handles parsing, formatting, and rate limiting.
    """

    def __init__(
        self,
        telegram_client: Optional[TelegramClient] = None,
        db_client: Optional[SupabaseClient] = None,
        parser: Optional[CombinedParser] = None,
        formatter: Optional[JobTemplateFormatter] = None
    ):
        self.telegram = telegram_client or get_telegram_client()
        self.db = db_client or get_db()
        self.parser = parser or get_parser()
        self.formatter = formatter or get_formatter()
        self.settings = get_settings()

        self._posts_this_hour = 0
        self._hour_start = datetime.utcnow().replace(minute=0, second=0, microsecond=0)

    def _check_rate_limit(self) -> bool:
        """Check if we can post (within rate limits)."""
        now = datetime.utcnow()
        current_hour = now.replace(minute=0, second=0, microsecond=0)

        # Reset counter if new hour
        if current_hour > self._hour_start:
            self._posts_this_hour = 0
            self._hour_start = current_hour

        max_posts = self.settings.bot.max_posts_per_hour
        if self._posts_this_hour >= max_posts:
            logger.warning(
                "Rate limit reached",
                posts_this_hour=self._posts_this_hour,
                max=max_posts
            )
            return False

        return True

    async def process_job(self, job: JobQueue) -> Dict[str, Any]:
        """
        Process a single job from queue.

        Args:
            job: Job queue item

        Returns:
            Result dictionary with status and details
        """
        result = {
            "job_id": str(job.id),
            "status": "unknown",
            "error": None,
            "message_id": None
        }

        try:
            # Update status to processing
            await self.db.update_job_status(job.id, "processing")

            # Parse job text
            parsed_data = await self.parser.parse(job.original_text)

            # Check confidence
            if parsed_data.confidence_score < 0.3:
                logger.warning(
                    "Low confidence score, skipping job",
                    confidence=parsed_data.confidence_score
                )
                await self.db.update_job_status(
                    job.id,
                    "failed",
                    error_message="Low parsing confidence"
                )
                result["status"] = "skipped"
                result["error"] = "Low parsing confidence"
                return result

            # Format job
            formatted_text = await self.formatter.format(parsed_data)

            # Update job with parsed data
            await self.db.update_job_status(
                job.id,
                "ready",
                formatted_text=formatted_text,
                parsed_data=parsed_data.model_dump()
            )

            # Publish to target group
            target_group_id = self.settings.bot.target_group_id
            message = await self.telegram.send_message(
                chat_id=target_group_id,
                text=formatted_text,
                parse_mode="html"
            )

            if message:
                # Also publish to channel if configured
                if self.settings.bot.target_channel_id:
                    await self.telegram.send_message(
                        chat_id=self.settings.bot.target_channel_id,
                        text=formatted_text,
                        parse_mode="html"
                    )

                # Record success
                await self.db.record_posted_job(
                    content_hash=job.content_hash,
                    original_text=job.original_text,
                    formatted_text=formatted_text,
                    parsed_data=parsed_data.model_dump(),
                    source_telegram_id=job.source_telegram_id,
                    original_message_id=job.original_message_id,
                    posted_message_id=message.id,
                    status="posted"
                )

                # Remove from queue
                await self.db.remove_from_queue(job.id)

                # Update counter
                self._posts_this_hour += 1

                result["status"] = "published"
                result["message_id"] = message.id

                logger.info(
                    "Job published successfully",
                    job_id=str(job.id),
                    message_id=message.id
                )

            else:
                raise Exception("Failed to send message")

        except Exception as e:
            logger.error(
                "Error processing job",
                job_id=str(job.id),
                error=str(e)
            )

            # Update job status
            await self.db.update_job_status(
                job.id,
                "failed",
                error_message=str(e)
            )

            # Log activity
            await self.db.log_activity(
                event_type="publish_error",
                event_data={
                    "job_id": str(job.id),
                    "error": str(e)
                },
                severity="error"
            )

            result["status"] = "failed"
            result["error"] = str(e)

        return result

    async def publish_batch(self, limit: int = 5) -> Dict[str, Any]:
        """
        Publish a batch of jobs from queue.

        Args:
            limit: Maximum jobs to publish in this batch

        Returns:
            Summary of publishing results
        """
        results = {
            "processed": 0,
            "published": 0,
            "failed": 0,
            "skipped": 0,
            "rate_limited": False,
            "jobs": []
        }

        # Get pending jobs
        jobs = await self.db.get_pending_jobs(limit=limit)

        if not jobs:
            logger.debug("No pending jobs in queue")
            return results

        logger.info("Processing job batch", count=len(jobs))

        for job in jobs:
            # Check rate limit
            if not self._check_rate_limit():
                results["rate_limited"] = True
                break

            # Process job
            result = await self.process_job(job)
            results["jobs"].append(result)
            results["processed"] += 1

            if result["status"] == "published":
                results["published"] += 1
            elif result["status"] == "failed":
                results["failed"] += 1
            elif result["status"] == "skipped":
                results["skipped"] += 1

            # Delay between posts
            await asyncio.sleep(self.settings.bot.post_delay_seconds)

        # Log activity
        await self.db.log_activity(
            event_type="batch_published",
            event_data={
                "processed": results["processed"],
                "published": results["published"],
                "failed": results["failed"]
            },
            severity="info"
        )

        logger.info(
            "Batch processing completed",
            **{k: v for k, v in results.items() if k != "jobs"}
        )

        return results

    async def publish_single(
        self,
        text: str,
        custom_contact: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Parse and publish a single job immediately (bypass queue).

        Args:
            text: Raw job text
            custom_contact: Optional custom contact link

        Returns:
            Result dictionary
        """
        result = {
            "status": "unknown",
            "error": None,
            "message_id": None,
            "formatted_text": None
        }

        try:
            # Check rate limit
            if not self._check_rate_limit():
                result["status"] = "rate_limited"
                result["error"] = "Rate limit exceeded"
                return result

            # Parse
            parsed_data = await self.parser.parse(text)

            # Format
            formatted_text = await self.formatter.format(parsed_data, custom_contact)
            result["formatted_text"] = formatted_text

            # Publish
            target_group_id = self.settings.bot.target_group_id
            message = await self.telegram.send_message(
                chat_id=target_group_id,
                text=formatted_text,
                parse_mode="html"
            )

            if message:
                # Also to channel
                if self.settings.bot.target_channel_id:
                    await self.telegram.send_message(
                        chat_id=self.settings.bot.target_channel_id,
                        text=formatted_text,
                        parse_mode="html"
                    )

                content_hash = self.db.generate_content_hash(text)
                await self.db.record_posted_job(
                    content_hash=content_hash,
                    original_text=text,
                    formatted_text=formatted_text,
                    parsed_data=parsed_data.model_dump(),
                    source_telegram_id=0,
                    original_message_id=0,
                    posted_message_id=message.id,
                    status="posted"
                )

                self._posts_this_hour += 1
                result["status"] = "published"
                result["message_id"] = message.id

                logger.info("Single job published", message_id=message.id)
            else:
                raise Exception("Failed to send message")

        except Exception as e:
            logger.error("Error publishing single job", error=str(e))
            result["status"] = "failed"
            result["error"] = str(e)

        return result

    async def get_queue_stats(self) -> Dict[str, Any]:
        """Get current queue statistics."""
        pending = await self.db.get_pending_jobs(limit=1000)

        return {
            "queue_size": len(pending),
            "posts_this_hour": self._posts_this_hour,
            "max_posts_per_hour": self.settings.bot.max_posts_per_hour,
            "rate_limited": not self._check_rate_limit()
        }
