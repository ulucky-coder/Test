"""
Job template formatter.
Formats parsed job data into the target template.
"""

import re
from typing import Optional, Dict, Any
import structlog

from ..config import get_settings
from ..database import get_db
from ..database.models import ParsedJobData, JobTemplate

logger = structlog.get_logger(__name__)

# Default template matching user's specification
DEFAULT_TEMPLATE = """🔥 СРОЧНО. {location}. {company_type}. Девочки, открыт набор в смену!

🏢 Вакансия: {title}
📍 Метро: {metro} ({metro_distance}).

💰 ДЕНЬГИ:
• {salary} руб/смена.
• Выплаты: {payment_terms}.

🎁 БОНУСЫ:
{bonuses}

Требования: {requirements}
Опыт: {experience}.

👇 ЖМИ НА ССЫЛКУ И ЗАПИСЫВАЙСЯ:
{contact_link}"""


class JobTemplateFormatter:
    """
    Formats parsed job data using templates.
    Supports dynamic templates from database.
    """

    def __init__(self):
        self.settings = get_settings()
        self.db = get_db()
        self._template_cache: Optional[str] = None
        self._default_contact: Optional[str] = None

    async def _get_template(self) -> str:
        """Get template from database or use default."""
        if self._template_cache:
            return self._template_cache

        try:
            template = await self.db.get_default_template()
            if template:
                self._template_cache = template.template_text
                return self._template_cache
        except Exception as e:
            logger.warning("Could not load template from DB", error=str(e))

        self._template_cache = DEFAULT_TEMPLATE
        return self._template_cache

    async def _get_default_contact(self) -> str:
        """Get default contact link."""
        if self._default_contact:
            return self._default_contact

        try:
            self._default_contact = await self.db.get_contact_link()
            return self._default_contact
        except Exception as e:
            logger.warning("Could not load default contact", error=str(e))
            return "Уточняйте у администратора"

    def _format_bonuses(self, bonuses: list) -> str:
        """Format bonuses list for template."""
        if not bonuses:
            return """• 🍲 Питание (Бесплатно).
• 👗 Форма (Бесплатно).
• 🤝 Дружный коллектив."""

        formatted_lines = []
        for bonus in bonuses:
            # Ensure bonus has emoji
            if not any(c in bonus for c in ['🍲', '👗', '🤝', '📅', '📚', '🚇', '💵', '🎁', '📈']):
                bonus = f"• {bonus}"
            else:
                bonus = f"• {bonus}"
            formatted_lines.append(bonus)

        return "\n".join(formatted_lines)

    def _sanitize_text(self, text: Optional[str]) -> str:
        """Sanitize text for Telegram HTML."""
        if not text:
            return ""
        # Escape HTML special characters
        text = text.replace('&', '&amp;')
        text = text.replace('<', '&lt;')
        text = text.replace('>', '&gt;')
        return text

    async def format(
        self,
        parsed_data: ParsedJobData,
        custom_contact: Optional[str] = None
    ) -> str:
        """
        Format parsed job data into template.

        Args:
            parsed_data: Parsed job data
            custom_contact: Optional custom contact link to use

        Returns:
            Formatted job post text
        """
        template = await self._get_template()

        # Get contact link (priority: custom > parsed > default)
        if custom_contact:
            contact_link = custom_contact
        elif parsed_data.contact_link:
            contact_link = parsed_data.contact_link
        else:
            contact_link = await self._get_default_contact()

        # Prepare data with defaults
        data = {
            "title": self._sanitize_text(parsed_data.title) or "Вакансия",
            "company_type": self._sanitize_text(parsed_data.company_type) or "Компания",
            "location": self._sanitize_text(parsed_data.location) or "ЦЕНТР",
            "metro": self._sanitize_text(parsed_data.metro) or "Уточняйте",
            "metro_distance": self._sanitize_text(parsed_data.metro_distance) or "5 мин",
            "salary": self._sanitize_text(parsed_data.salary) or "По договорённости",
            "payment_terms": self._sanitize_text(parsed_data.payment_terms) or "Ежедневно",
            "bonuses": self._format_bonuses(parsed_data.bonuses),
            "requirements": self._sanitize_text(parsed_data.requirements) or "Аккуратность и желание работать",
            "experience": self._sanitize_text(parsed_data.experience) or "Не важен",
            "contact_link": contact_link,
        }

        # Format template
        try:
            formatted = template.format(**data)
        except KeyError as e:
            logger.warning("Missing template variable", variable=str(e))
            # Try to format with available data
            for key in re.findall(r'\{(\w+)\}', template):
                if key not in data:
                    data[key] = "Не указано"
            formatted = template.format(**data)

        logger.debug("Job formatted successfully", length=len(formatted))
        return formatted

    async def format_from_dict(
        self,
        data: Dict[str, Any],
        custom_contact: Optional[str] = None
    ) -> str:
        """
        Format job from dictionary data.

        Args:
            data: Dictionary with job data
            custom_contact: Optional custom contact link

        Returns:
            Formatted job post text
        """
        parsed = ParsedJobData(
            title=data.get("title"),
            company_type=data.get("company_type"),
            location=data.get("location"),
            metro=data.get("metro"),
            metro_distance=data.get("metro_distance"),
            salary=data.get("salary"),
            payment_terms=data.get("payment_terms"),
            bonuses=data.get("bonuses", []),
            requirements=data.get("requirements"),
            experience=data.get("experience"),
            contact_link=data.get("contact_link"),
            contact_username=data.get("contact_username"),
        )
        return await self.format(parsed, custom_contact)

    def invalidate_cache(self) -> None:
        """Invalidate template cache."""
        self._template_cache = None
        self._default_contact = None


# Global instance
_formatter: Optional[JobTemplateFormatter] = None


def get_formatter() -> JobTemplateFormatter:
    """Get or create formatter instance."""
    global _formatter
    if _formatter is None:
        _formatter = JobTemplateFormatter()
    return _formatter
