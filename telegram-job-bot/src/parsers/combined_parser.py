"""
Combined parser that uses both AI and regex for best results.
"""

from typing import Optional
import structlog

from ..config import get_settings
from ..database.models import ParsedJobData
from .regex_parser import RegexJobParser, get_regex_parser
from .ai_parser import AIJobParser, get_ai_parser

logger = structlog.get_logger(__name__)


class CombinedParser:
    """
    Combines AI and regex parsing for optimal results.

    Strategy:
    1. If AI is enabled and available, use AI first
    2. Use regex to fill in any missing fields
    3. If AI fails, fall back to regex only
    """

    def __init__(
        self,
        regex_parser: Optional[RegexJobParser] = None,
        ai_parser: Optional[AIJobParser] = None
    ):
        self.settings = get_settings()
        self.regex_parser = regex_parser or get_regex_parser()
        self.ai_parser = ai_parser or get_ai_parser()

    async def parse(self, text: str) -> ParsedJobData:
        """
        Parse job posting using combined approach.

        Args:
            text: Raw job posting text

        Returns:
            ParsedJobData with best available data
        """
        ai_result = None
        regex_result = None

        # Try AI parsing first if enabled
        if self.settings.bot.ai_parser_enabled and self.ai_parser.is_available:
            try:
                ai_result = await self.ai_parser.parse(text)
                logger.debug("AI parsing successful", confidence=ai_result.confidence_score if ai_result else 0)
            except Exception as e:
                logger.warning("AI parsing failed, falling back to regex", error=str(e))

        # Always run regex for comparison/fallback
        if self.settings.bot.regex_parser_enabled:
            regex_result = self.regex_parser.parse(text)
            logger.debug("Regex parsing completed", confidence=regex_result.confidence_score)

        # Combine results
        if ai_result and regex_result:
            return self._merge_results(ai_result, regex_result)
        elif ai_result:
            return ai_result
        elif regex_result:
            return regex_result
        else:
            # Return empty result with raw text
            return ParsedJobData(raw_text=text, confidence_score=0.0)

    def _merge_results(
        self,
        ai_result: ParsedJobData,
        regex_result: ParsedJobData
    ) -> ParsedJobData:
        """
        Merge AI and regex results, preferring AI but filling gaps with regex.

        Args:
            ai_result: Result from AI parser
            regex_result: Result from regex parser

        Returns:
            Merged ParsedJobData
        """
        merged = ParsedJobData(
            # Prefer AI for most fields (usually more accurate)
            title=ai_result.title or regex_result.title,
            company_type=ai_result.company_type or regex_result.company_type,
            location=ai_result.location or regex_result.location,
            metro=ai_result.metro or regex_result.metro,
            metro_distance=ai_result.metro_distance or regex_result.metro_distance,
            salary=ai_result.salary or regex_result.salary,
            payment_terms=ai_result.payment_terms or regex_result.payment_terms,
            requirements=ai_result.requirements or regex_result.requirements,
            experience=ai_result.experience or regex_result.experience,

            # For contact, prefer regex (more reliable pattern matching)
            contact_link=regex_result.contact_link or ai_result.contact_link,
            contact_username=regex_result.contact_username or ai_result.contact_username,

            # Merge bonuses (combine both lists, remove duplicates)
            bonuses=self._merge_bonuses(
                ai_result.bonuses or [],
                regex_result.bonuses or []
            ),

            # Keep raw text
            raw_text=ai_result.raw_text,

            # Average confidence
            confidence_score=(ai_result.confidence_score + regex_result.confidence_score) / 2
        )

        logger.debug(
            "Results merged",
            ai_confidence=ai_result.confidence_score,
            regex_confidence=regex_result.confidence_score,
            merged_confidence=merged.confidence_score
        )

        return merged

    def _merge_bonuses(self, ai_bonuses: list, regex_bonuses: list) -> list:
        """Merge bonus lists, removing duplicates."""
        seen = set()
        merged = []

        for bonus in ai_bonuses + regex_bonuses:
            # Normalize for comparison
            normalized = bonus.lower().replace('(', '').replace(')', '').strip()

            # Check if we've seen something similar
            is_duplicate = False
            for seen_item in seen:
                if normalized in seen_item or seen_item in normalized:
                    is_duplicate = True
                    break

            if not is_duplicate:
                merged.append(bonus)
                seen.add(normalized)

        return merged


# Global instance
_combined_parser: Optional[CombinedParser] = None


def get_parser() -> CombinedParser:
    """Get or create combined parser instance."""
    global _combined_parser
    if _combined_parser is None:
        _combined_parser = CombinedParser()
    return _combined_parser
