"""
AI-based parser for extracting job data from text.
Uses OpenAI or Anthropic for intelligent extraction.
"""

import json
from typing import Optional, Dict, Any
import structlog
from tenacity import retry, stop_after_attempt, wait_exponential

from ..config import get_settings
from ..database.models import ParsedJobData

logger = structlog.get_logger(__name__)

# System prompt for job parsing
SYSTEM_PROMPT = """Ты - эксперт по парсингу вакансий на русском языке. Твоя задача - извлечь структурированные данные из текста объявления о работе.

Извлеки следующие поля (если информация есть в тексте):
- title: название вакансии/должности
- company_type: тип заведения (отель, ресторан, офис и т.д.)
- location: район/локация
- metro: ближайшая станция метро
- metro_distance: расстояние до метро (например "5 мин")
- salary: зарплата (только число или диапазон, без "руб")
- payment_terms: условия выплаты (ежедневно, еженедельно и т.д.)
- bonuses: список бонусов (питание, форма, проезд и т.д.)
- requirements: требования к кандидату
- experience: требуемый опыт (не нужен/от 1 года и т.д.)
- contact_username: telegram username без @
- contact_link: ссылка на контакт (t.me/... или телефон)

Верни ТОЛЬКО валидный JSON без markdown форматирования. Если поле не найдено, используй null.
Bonuses должен быть массивом строк."""


class AIJobParser:
    """
    AI-powered job parser using OpenAI or Anthropic.
    Falls back gracefully on errors.
    """

    def __init__(self):
        self.settings = get_settings()
        self._openai_client = None
        self._anthropic_client = None
        self._initialize_client()

    def _initialize_client(self) -> None:
        """Initialize the appropriate AI client."""
        provider = self.settings.ai.ai_provider

        if provider == "openai" and self.settings.ai.openai_api_key:
            try:
                from openai import OpenAI
                self._openai_client = OpenAI(api_key=self.settings.ai.openai_api_key)
                logger.info("OpenAI client initialized")
            except ImportError:
                logger.warning("OpenAI package not installed")

        elif provider == "anthropic" and self.settings.ai.anthropic_api_key:
            try:
                import anthropic
                self._anthropic_client = anthropic.Anthropic(
                    api_key=self.settings.ai.anthropic_api_key
                )
                logger.info("Anthropic client initialized")
            except ImportError:
                logger.warning("Anthropic package not installed")

    @property
    def is_available(self) -> bool:
        """Check if AI parsing is available."""
        return self._openai_client is not None or self._anthropic_client is not None

    @retry(stop=stop_after_attempt(2), wait=wait_exponential(min=1, max=5))
    async def _parse_with_openai(self, text: str) -> Dict[str, Any]:
        """Parse using OpenAI."""
        response = self._openai_client.chat.completions.create(
            model=self.settings.ai.openai_model,
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": f"Распарси эту вакансию:\n\n{text}"}
            ],
            temperature=0.1,
            max_tokens=1000,
            response_format={"type": "json_object"}
        )

        content = response.choices[0].message.content
        return json.loads(content)

    @retry(stop=stop_after_attempt(2), wait=wait_exponential(min=1, max=5))
    async def _parse_with_anthropic(self, text: str) -> Dict[str, Any]:
        """Parse using Anthropic Claude."""
        message = self._anthropic_client.messages.create(
            model=self.settings.ai.anthropic_model,
            max_tokens=1000,
            system=SYSTEM_PROMPT,
            messages=[
                {"role": "user", "content": f"Распарси эту вакансию:\n\n{text}"}
            ]
        )

        content = message.content[0].text

        # Extract JSON from response
        try:
            # Try direct parse
            return json.loads(content)
        except json.JSONDecodeError:
            # Try to find JSON in response
            import re
            json_match = re.search(r'\{[\s\S]*\}', content)
            if json_match:
                return json.loads(json_match.group())
            raise ValueError("Could not extract JSON from response")

    async def parse(self, text: str) -> Optional[ParsedJobData]:
        """
        Parse job posting using AI.

        Args:
            text: Raw job posting text

        Returns:
            ParsedJobData or None on error
        """
        if not self.is_available:
            logger.warning("AI parser not available")
            return None

        try:
            # Choose provider
            if self._openai_client:
                data = await self._parse_with_openai(text)
            elif self._anthropic_client:
                data = await self._parse_with_anthropic(text)
            else:
                return None

            # Convert to ParsedJobData
            bonuses = data.get("bonuses", [])
            if isinstance(bonuses, str):
                bonuses = [bonuses]

            parsed = ParsedJobData(
                title=data.get("title"),
                company_type=data.get("company_type"),
                location=data.get("location"),
                metro=data.get("metro"),
                metro_distance=data.get("metro_distance"),
                salary=data.get("salary"),
                payment_terms=data.get("payment_terms"),
                bonuses=bonuses,
                requirements=data.get("requirements"),
                experience=data.get("experience"),
                contact_link=data.get("contact_link"),
                contact_username=data.get("contact_username"),
                raw_text=text,
                confidence_score=0.9  # AI usually has high confidence
            )

            logger.info("AI parsing completed successfully")
            return parsed

        except json.JSONDecodeError as e:
            logger.error("Failed to parse AI response as JSON", error=str(e))
            return None
        except Exception as e:
            logger.error("AI parsing failed", error=str(e))
            return None


# Global instance
_ai_parser: Optional[AIJobParser] = None


def get_ai_parser() -> AIJobParser:
    """Get or create AI parser instance."""
    global _ai_parser
    if _ai_parser is None:
        _ai_parser = AIJobParser()
    return _ai_parser
