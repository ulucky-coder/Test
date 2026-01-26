"""
Regex-based parser for extracting job data from text.
Fast and reliable for structured posts.
"""

import re
from typing import Optional, List, Dict, Any
import structlog

from ..database.models import ParsedJobData

logger = structlog.get_logger(__name__)


class RegexJobParser:
    """
    Extracts structured job data using regex patterns.
    Optimized for Russian job postings.
    """

    # Salary patterns
    SALARY_PATTERNS = [
        r'(?:от\s*)?(\d[\d\s]*\d|\d+)\s*(?:₽|руб|р\.?|rub)\s*(?:/\s*(?:смена|смену|день|час))?',
        r'(?:зарплата|оплата|ставка|доход)[:\s]*(\d[\d\s]*\d|\d+)',
        r'(\d{1,3}(?:\s?\d{3})*)\s*(?:в день|за смену|/смена)',
        r'(?:до|от)\s*(\d{1,3}(?:\s?\d{3})*)\s*(?:₽|руб|р)',
    ]

    # Metro/Location patterns
    METRO_PATTERNS = [
        r'(?:м\.|метро|ст\.?\s*м\.?)[:\s]*([А-Яа-яЁё\s\-]+?)(?:\s*\(|\s*,|\s*\d|\n|$)',
        r'(?:станция)[:\s]*([А-Яа-яЁё\s\-]+?)(?:\s*\(|\s*,|\n|$)',
        r'(?:рядом с м\.|у м\.)[:\s]*([А-Яа-яЁё\s\-]+)',
    ]

    # Distance patterns
    DISTANCE_PATTERNS = [
        r'(\d+)\s*(?:мин|минут|минуты)\s*(?:пешком|от метро|от м\.)?',
        r'(?:в\s*)?(\d+)\s*(?:мин|минут)',
    ]

    # Location/Area patterns
    LOCATION_PATTERNS = [
        r'(?:район|р-н|локация|адрес)[:\s]*([А-Яа-яЁё\s\-,]+?)(?:\n|$|\.)',
        r'(?:ЦЕНТР|ЦАО|САО|ВАО|ЗАО|СВАО|СЗАО|ЮАО|ЮВАО|ЮЗАО)',
        r'(?:центр|юг|север|восток|запад)\s*(?:москвы|города)?',
    ]

    # Title/Position patterns
    TITLE_PATTERNS = [
        r'(?:вакансия|должность|позиция)[:\s]*([^\n]+)',
        r'(?:требуется|ищем|нужен|нужна|нужны)[:\s]*([^\n]+?)(?:\n|$|!)',
        r'(?:🏢|💼)\s*(?:вакансия)?[:\s]*([^\n]+)',
    ]

    # Company type patterns
    COMPANY_TYPE_PATTERNS = [
        r'(отель|гостиница|ресторан|кафе|бар|клуб|салон|spa|спа|офис|магазин|склад)',
        r'(?:тип\s*(?:компании|заведения))[:\s]*([^\n]+)',
    ]

    # Experience patterns
    EXPERIENCE_PATTERNS = [
        r'(?:опыт)[:\s]*(не\s*(?:нужен|требуется|обязателен|важен)|без\s*опыта|от\s*\d+\s*(?:года?|лет)|обязателен|желателен)',
        r'(без\s*опыта|с\s*опытом)',
    ]

    # Payment terms patterns
    PAYMENT_PATTERNS = [
        r'(?:выплаты|оплата|зп)[:\s]*(ежедневно|еженедельно|ежемесячно|2\s*раза\s*в\s*(?:неделю|месяц)|раз\s*в\s*неделю)',
        r'(ежедневная\s*оплата|оплата\s*каждый\s*день)',
    ]

    # Contact patterns
    CONTACT_PATTERNS = [
        r'(?:контакт|связь|писать|звонить)[:\s]*@([A-Za-z0-9_]+)',
        r't\.me/([A-Za-z0-9_]+)',
        r'@([A-Za-z0-9_]+)',
        r'(?:тел|телефон|номер)[:\s]*(\+?\d[\d\s\-\(\)]+)',
    ]

    # Bonus patterns
    BONUS_KEYWORDS = [
        ('питание', '🍲 Питание'),
        ('обед', '🍲 Питание'),
        ('еда', '🍲 Питание'),
        ('форма', '👗 Форма'),
        ('одежда', '👗 Форма'),
        ('униформа', '👗 Форма'),
        ('коллектив', '🤝 Дружный коллектив'),
        ('команда', '🤝 Дружный коллектив'),
        ('график', '📅 Гибкий график'),
        ('гибкий', '📅 Гибкий график'),
        ('обучение', '📚 Обучение'),
        ('стажировка', '📚 Обучение'),
        ('проезд', '🚇 Оплата проезда'),
        ('транспорт', '🚇 Оплата проезда'),
        ('чаевые', '💵 Чаевые'),
        ('премия', '🎁 Премии'),
        ('бонус', '🎁 Бонусы'),
        ('карьера', '📈 Карьерный рост'),
        ('рост', '📈 Карьерный рост'),
    ]

    def __init__(self):
        # Compile patterns for performance
        self._compiled_patterns: Dict[str, List[re.Pattern]] = {}
        self._compile_patterns()

    def _compile_patterns(self) -> None:
        """Compile all regex patterns."""
        pattern_groups = {
            'salary': self.SALARY_PATTERNS,
            'metro': self.METRO_PATTERNS,
            'distance': self.DISTANCE_PATTERNS,
            'location': self.LOCATION_PATTERNS,
            'title': self.TITLE_PATTERNS,
            'company': self.COMPANY_TYPE_PATTERNS,
            'experience': self.EXPERIENCE_PATTERNS,
            'payment': self.PAYMENT_PATTERNS,
            'contact': self.CONTACT_PATTERNS,
        }

        for name, patterns in pattern_groups.items():
            self._compiled_patterns[name] = [
                re.compile(p, re.IGNORECASE | re.UNICODE)
                for p in patterns
            ]

    def _find_first_match(self, text: str, pattern_name: str) -> Optional[str]:
        """Find first match for a pattern group."""
        for pattern in self._compiled_patterns.get(pattern_name, []):
            match = pattern.search(text)
            if match:
                return match.group(1).strip() if match.groups() else match.group(0).strip()
        return None

    def _find_all_matches(self, text: str, pattern_name: str) -> List[str]:
        """Find all matches for a pattern group."""
        matches = []
        for pattern in self._compiled_patterns.get(pattern_name, []):
            for match in pattern.finditer(text):
                value = match.group(1).strip() if match.groups() else match.group(0).strip()
                if value and value not in matches:
                    matches.append(value)
        return matches

    def _extract_salary(self, text: str) -> Optional[str]:
        """Extract and normalize salary."""
        salary = self._find_first_match(text, 'salary')
        if salary:
            # Clean up whitespace in numbers
            salary = re.sub(r'\s+', '', salary)
            # Format with spaces for readability
            try:
                num = int(salary)
                return f"{num:,}".replace(',', ' ')
            except ValueError:
                return salary
        return None

    def _extract_bonuses(self, text: str) -> List[str]:
        """Extract bonuses from text."""
        text_lower = text.lower()
        bonuses = []
        seen = set()

        for keyword, formatted in self.BONUS_KEYWORDS:
            if keyword in text_lower and formatted not in seen:
                # Check if it's mentioned as free/included
                if any(w in text_lower for w in ['бесплатн', 'включен', 'предоставля', 'есть']):
                    bonuses.append(f"{formatted} (Бесплатно)")
                else:
                    bonuses.append(formatted)
                seen.add(formatted)

        return bonuses

    def _extract_requirements(self, text: str) -> Optional[str]:
        """Extract requirements from text."""
        # Common requirement patterns
        req_patterns = [
            r'(?:требования|что\s*нужно)[:\s]*([^\n]+(?:\n[^\n]+)*?)(?:\n\n|\n[А-Я]|$)',
            r'(?:нужно|необходимо)[:\s]*([^\n]+)',
        ]

        for pattern in req_patterns:
            match = re.search(pattern, text, re.IGNORECASE)
            if match:
                req = match.group(1).strip()
                # Clean up
                req = re.sub(r'\s*[-•]\s*', ', ', req)
                req = re.sub(r'\s+', ' ', req)
                return req[:200]  # Limit length

        return None

    def _extract_contact(self, text: str) -> tuple[Optional[str], Optional[str]]:
        """Extract contact info (username and link)."""
        # Try to find Telegram username
        username_match = re.search(r'@([A-Za-z0-9_]{5,})', text)
        if username_match:
            username = username_match.group(1)
            return username, f"https://t.me/{username}"

        # Try to find t.me link
        link_match = re.search(r't\.me/([A-Za-z0-9_]+)', text)
        if link_match:
            username = link_match.group(1)
            return username, f"https://t.me/{username}"

        return None, None

    def parse(self, text: str) -> ParsedJobData:
        """
        Parse job posting text and extract structured data.

        Args:
            text: Raw job posting text

        Returns:
            ParsedJobData with extracted fields
        """
        # Extract all fields
        title = self._find_first_match(text, 'title')
        company_type = self._find_first_match(text, 'company')
        location = self._find_first_match(text, 'location')
        metro = self._find_first_match(text, 'metro')
        distance = self._find_first_match(text, 'distance')
        salary = self._extract_salary(text)
        payment_terms = self._find_first_match(text, 'payment')
        experience = self._find_first_match(text, 'experience')
        bonuses = self._extract_bonuses(text)
        requirements = self._extract_requirements(text)
        contact_username, contact_link = self._extract_contact(text)

        # Calculate confidence score
        filled_fields = sum([
            bool(title), bool(salary), bool(metro or location),
            bool(experience), bool(contact_link)
        ])
        confidence = filled_fields / 5.0

        parsed = ParsedJobData(
            title=title,
            company_type=company_type,
            location=location,
            metro=metro,
            metro_distance=f"{distance} мин" if distance else None,
            salary=salary,
            payment_terms=payment_terms,
            bonuses=bonuses,
            requirements=requirements,
            experience=experience,
            contact_link=contact_link,
            contact_username=contact_username,
            raw_text=text,
            confidence_score=confidence
        )

        logger.debug(
            "Regex parsing completed",
            confidence=confidence,
            fields_found=filled_fields
        )

        return parsed


# Global instance
_parser: Optional[RegexJobParser] = None


def get_regex_parser() -> RegexJobParser:
    """Get or create regex parser instance."""
    global _parser
    if _parser is None:
        _parser = RegexJobParser()
    return _parser
