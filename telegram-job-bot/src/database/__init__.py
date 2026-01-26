"""Database module for Telegram Job Repost Bot."""

from .supabase_client import SupabaseClient, get_db
from .models import (
    SourceGroup,
    TargetChannel,
    JobTemplate,
    PostedJob,
    JobQueue,
    BotSetting,
    Keyword,
    Contact,
    ActivityLog
)

__all__ = [
    "SupabaseClient",
    "get_db",
    "SourceGroup",
    "TargetChannel",
    "JobTemplate",
    "PostedJob",
    "JobQueue",
    "BotSetting",
    "Keyword",
    "Contact",
    "ActivityLog"
]
