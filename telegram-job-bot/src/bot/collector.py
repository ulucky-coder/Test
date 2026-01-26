"""
Job collector module.
Collects job postings from source groups and filters them.
"""

import asyncio
from datetime import datetime, timedelta
from typing import List, Optional, Dict, Any

import structlog
from pyrogram.types import Message

from ..config import get_settings
from ..database import get_db, SourceGroup, JobQueue
from ..database.supabase_client import SupabaseClient
from .client import TelegramClient, get_telegram_client

logger = structlog.get_logger(__name__)


class JobCollector:
    """
    Collects job postings from Telegram groups.
    Filters by keywords and checks for duplicates.
    """

    def __init__(
        self,
        telegram_client: Optional[TelegramClient] = None,
        db_client: Optional[SupabaseClient] = None
    ):
        self.telegram = telegram_client or get_telegram_client()
        self.db = db_client or get_db()
        self.settings = get_settings()

        # Cache for keywords
        self._include_keywords: Optional[List[str]] = None
        self._exclude_keywords: Optional[List[str]] = None

    async def _load_keywords(self) -> None:
        """Load keywords from database."""
        self._include_keywords = await self.db.get_include_keywords()
        self._exclude_keywords = await self.db.get_exclude_keywords()
        logger.debug(
            "Loaded keywords",
            include=len(self._include_keywords),
            exclude=len(self._exclude_keywords)
        )

    def _matches_keywords(self, text: str) -> bool:
        """
        Check if text matches keyword filters.

        Args:
            text: Message text to check

        Returns:
            True if message should be processed
        """
        if not text:
            return False

        text_lower = text.lower()

        # Check exclude keywords first
        if self._exclude_keywords:
            for keyword in self._exclude_keywords:
                if keyword in text_lower:
                    logger.debug("Message excluded by keyword", keyword=keyword)
                    return False

        # Check include keywords
        if self._include_keywords:
            for keyword in self._include_keywords:
                if keyword in text_lower:
                    return True
            return False

        # If no include keywords defined, accept all
        return True

    def _is_valid_message(self, message: Message) -> bool:
        """
        Check if message is valid for processing.

        Args:
            message: Telegram message

        Returns:
            True if message should be processed
        """
        # Skip non-text messages
        if not message.text and not message.caption:
            return False

        text = message.text or message.caption

        # Check length
        min_length = self.settings.bot.bot.get("min_message_length", 50) if hasattr(self.settings.bot, 'get') else 50
        max_length = self.settings.bot.bot.get("max_message_length", 4000) if hasattr(self.settings.bot, 'get') else 4000

        if len(text) < min_length or len(text) > max_length:
            return False

        # Skip service messages
        if message.service:
            return False

        # Skip forwarded messages from channels (usually ads)
        # But allow forwarded messages from other groups
        if message.forward_from_chat and message.forward_from_chat.type == "channel":
            return False

        return True

    async def collect_from_group(
        self,
        group: SourceGroup,
        limit: int = 50
    ) -> List[Dict[str, Any]]:
        """
        Collect new job postings from a single group.

        Args:
            group: Source group to collect from
            limit: Maximum messages to fetch

        Returns:
            List of collected jobs (raw data)
        """
        collected_jobs = []

        try:
            # Get new messages since last check
            messages = await self.telegram.get_new_messages(
                chat_id=group.telegram_id,
                after_message_id=group.last_message_id,
                limit=limit
            )

            if not messages:
                logger.debug("No new messages", group_id=group.telegram_id)
                return []

            logger.info(
                "Found new messages",
                group_id=group.telegram_id,
                count=len(messages)
            )

            last_message_id = group.last_message_id

            for message in messages:
                # Update last message ID
                if message.id > last_message_id:
                    last_message_id = message.id

                # Validate message
                if not self._is_valid_message(message):
                    continue

                text = message.text or message.caption

                # Check keywords
                if not self._matches_keywords(text):
                    continue

                # Generate content hash for deduplication
                content_hash = self.db.generate_content_hash(text)

                # Check if already processed
                if await self.db.is_duplicate(content_hash):
                    logger.debug("Duplicate job skipped", hash=content_hash[:16])
                    continue

                # Collect job data
                job_data = {
                    "content_hash": content_hash,
                    "original_text": text,
                    "source_telegram_id": group.telegram_id,
                    "source_group_title": group.title,
                    "original_message_id": message.id,
                    "message_date": message.date.isoformat() if message.date else None,
                    "has_media": bool(message.media),
                    "priority": group.priority
                }

                collected_jobs.append(job_data)
                logger.info(
                    "Job collected",
                    group=group.title,
                    message_id=message.id
                )

            # Update last checked info
            await self.db.update_group_last_checked(
                telegram_id=group.telegram_id,
                last_message_id=last_message_id
            )

            return collected_jobs

        except Exception as e:
            logger.error(
                "Error collecting from group",
                group_id=group.telegram_id,
                error=str(e)
            )
            await self.db.log_activity(
                event_type="collection_error",
                event_data={
                    "group_id": group.telegram_id,
                    "error": str(e)
                },
                severity="error"
            )
            return []

    async def collect_all(self) -> List[Dict[str, Any]]:
        """
        Collect jobs from all active source groups.

        Returns:
            List of all collected jobs
        """
        # Load keywords
        await self._load_keywords()

        # Get active groups
        groups = await self.db.get_active_source_groups()

        if not groups:
            logger.warning("No active source groups found")
            return []

        logger.info("Starting collection", groups_count=len(groups))

        all_jobs = []

        for group in groups:
            try:
                jobs = await self.collect_from_group(group)
                all_jobs.extend(jobs)

                # Rate limiting between groups
                await asyncio.sleep(self.settings.bot.api_delay_seconds)

            except Exception as e:
                logger.error(
                    "Error processing group",
                    group_id=group.telegram_id,
                    error=str(e)
                )
                continue

        # Log activity
        await self.db.log_activity(
            event_type="collection_completed",
            event_data={
                "groups_processed": len(groups),
                "jobs_collected": len(all_jobs)
            },
            severity="info"
        )

        logger.info(
            "Collection completed",
            groups=len(groups),
            jobs=len(all_jobs)
        )

        return all_jobs

    async def add_jobs_to_queue(self, jobs: List[Dict[str, Any]]) -> int:
        """
        Add collected jobs to the processing queue.

        Args:
            jobs: List of job data dictionaries

        Returns:
            Number of jobs added to queue
        """
        added = 0

        for job in jobs:
            try:
                await self.db.add_to_queue(
                    content_hash=job["content_hash"],
                    original_text=job["original_text"],
                    source_telegram_id=job["source_telegram_id"],
                    original_message_id=job["original_message_id"],
                    priority=job.get("priority", 5)
                )
                added += 1
            except Exception as e:
                logger.error(
                    "Error adding job to queue",
                    hash=job["content_hash"][:16],
                    error=str(e)
                )

        logger.info("Jobs added to queue", count=added)
        return added

    async def run_collection_cycle(self) -> Dict[str, Any]:
        """
        Run a complete collection cycle.

        Returns:
            Summary of collection results
        """
        start_time = datetime.utcnow()

        # Collect jobs
        jobs = await self.collect_all()

        # Add to queue
        queued = await self.add_jobs_to_queue(jobs)

        end_time = datetime.utcnow()
        duration = (end_time - start_time).total_seconds()

        result = {
            "collected": len(jobs),
            "queued": queued,
            "duration_seconds": duration,
            "timestamp": start_time.isoformat()
        }

        logger.info("Collection cycle completed", **result)

        return result
