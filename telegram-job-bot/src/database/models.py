"""
Data models for Telegram Job Repost Bot.
Pydantic models for type-safe data handling.
"""

from datetime import datetime
from typing import Optional, List, Dict, Any, Literal
from pydantic import BaseModel, Field
from uuid import UUID


class SourceGroup(BaseModel):
    """Source group model for monitoring."""

    id: Optional[UUID] = None
    telegram_id: int
    username: Optional[str] = None
    title: Optional[str] = None
    group_type: Literal["public", "private"] = "public"
    invite_link: Optional[str] = None
    is_active: bool = True
    priority: int = Field(default=1, ge=1, le=10)
    last_checked_at: Optional[datetime] = None
    last_message_id: int = 0
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class TargetChannel(BaseModel):
    """Target channel/group model for publishing."""

    id: Optional[UUID] = None
    telegram_id: int
    username: Optional[str] = None
    title: Optional[str] = None
    channel_type: Literal["group", "channel"] = "group"
    is_active: bool = True
    bot_is_admin: bool = False
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class JobTemplate(BaseModel):
    """Job post template model."""

    id: Optional[UUID] = None
    name: str
    template_text: str
    is_default: bool = False
    is_active: bool = True
    variables: List[str] = Field(default_factory=list)
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class PostedJob(BaseModel):
    """Posted job record for deduplication."""

    id: Optional[UUID] = None
    content_hash: str
    original_message_id: Optional[int] = None
    source_group_id: Optional[UUID] = None
    source_telegram_id: Optional[int] = None
    target_channel_id: Optional[UUID] = None
    posted_message_id: Optional[int] = None
    original_text: Optional[str] = None
    formatted_text: Optional[str] = None
    parsed_data: Dict[str, Any] = Field(default_factory=dict)
    status: Literal["pending", "posted", "failed", "skipped"] = "posted"
    error_message: Optional[str] = None
    created_at: Optional[datetime] = None
    posted_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class JobQueue(BaseModel):
    """Job queue model for pending publications."""

    id: Optional[UUID] = None
    content_hash: str
    source_group_id: Optional[UUID] = None
    source_telegram_id: Optional[int] = None
    original_message_id: Optional[int] = None
    original_text: str
    parsed_data: Optional[Dict[str, Any]] = None
    formatted_text: Optional[str] = None
    priority: int = Field(default=5, ge=1, le=10)
    status: Literal["pending", "processing", "ready", "published", "failed"] = "pending"
    attempts: int = 0
    max_attempts: int = 3
    error_message: Optional[str] = None
    scheduled_at: Optional[datetime] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class BotSetting(BaseModel):
    """Bot settings model."""

    id: Optional[UUID] = None
    key: str
    value: Any
    description: Optional[str] = None
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class Keyword(BaseModel):
    """Keyword model for filtering."""

    id: Optional[UUID] = None
    word: str
    keyword_type: Literal["include", "exclude"] = "include"
    is_active: bool = True
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class Contact(BaseModel):
    """Contact model for recruiter links."""

    id: Optional[UUID] = None
    name: str
    telegram_username: Optional[str] = None
    telegram_id: Optional[int] = None
    bot_link: Optional[str] = None
    is_default: bool = False
    is_active: bool = True
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class ActivityLog(BaseModel):
    """Activity log model."""

    id: Optional[UUID] = None
    event_type: str
    event_data: Dict[str, Any] = Field(default_factory=dict)
    source_group_id: Optional[UUID] = None
    job_id: Optional[UUID] = None
    severity: Literal["debug", "info", "warning", "error", "critical"] = "info"
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class ParsedJobData(BaseModel):
    """Structured data extracted from job post."""

    title: Optional[str] = None
    company_type: Optional[str] = None
    location: Optional[str] = None
    metro: Optional[str] = None
    metro_distance: Optional[str] = None
    salary: Optional[str] = None
    payment_terms: Optional[str] = None
    bonuses: Optional[List[str]] = Field(default_factory=list)
    requirements: Optional[str] = None
    experience: Optional[str] = None
    contact_link: Optional[str] = None
    contact_username: Optional[str] = None
    raw_text: Optional[str] = None
    confidence_score: float = 0.0

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for template formatting."""
        return {
            "title": self.title or "Вакансия",
            "company_type": self.company_type or "Компания",
            "location": self.location or "Центр",
            "metro": self.metro or "Не указано",
            "metro_distance": self.metro_distance or "5 мин",
            "salary": self.salary or "По договорённости",
            "payment_terms": self.payment_terms or "Ежедневно",
            "bonuses": self._format_bonuses(),
            "requirements": self.requirements or "Аккуратность и желание работать",
            "experience": self.experience or "Не важен",
            "contact_link": self.contact_link or self.contact_username or "Уточняйте",
        }

    def _format_bonuses(self) -> str:
        """Format bonuses list for template."""
        if not self.bonuses:
            return "• 🍲 Питание (Бесплатно).\n• 👗 Форма (Бесплатно).\n• 🤝 Дружный коллектив."

        formatted = []
        for bonus in self.bonuses:
            formatted.append(f"• {bonus}")
        return "\n".join(formatted)
