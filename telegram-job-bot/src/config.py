"""
Configuration module for Telegram Job Repost Bot.
Uses pydantic-settings for type-safe configuration management.
"""

from typing import Optional, Literal
from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict
from pathlib import Path


class TelegramSettings(BaseSettings):
    """Telegram API configuration."""

    model_config = SettingsConfigDict(env_prefix="TELEGRAM_")

    api_id: int = Field(..., description="Telegram API ID from my.telegram.org")
    api_hash: str = Field(..., description="Telegram API Hash from my.telegram.org")
    phone: str = Field(..., description="Phone number for user account")
    bot_token: str = Field(..., description="Bot token from @BotFather")

    @field_validator("phone")
    @classmethod
    def validate_phone(cls, v: str) -> str:
        if not v.startswith("+"):
            v = f"+{v}"
        return v


class SupabaseSettings(BaseSettings):
    """Supabase configuration."""

    model_config = SettingsConfigDict(env_prefix="SUPABASE_")

    url: str = Field(..., description="Supabase project URL")
    anon_key: str = Field(..., description="Supabase anonymous key")
    service_key: str = Field(..., description="Supabase service role key")


class AISettings(BaseSettings):
    """AI Parser configuration."""

    model_config = SettingsConfigDict(env_prefix="")

    openai_api_key: Optional[str] = Field(None, description="OpenAI API key")
    openai_model: str = Field("gpt-4-turbo-preview", description="OpenAI model")

    anthropic_api_key: Optional[str] = Field(None, description="Anthropic API key")
    anthropic_model: str = Field("claude-3-sonnet-20240229", description="Anthropic model")

    ai_provider: Literal["openai", "anthropic", "none"] = Field(
        "openai", description="Which AI provider to use"
    )


class N8NSettings(BaseSettings):
    """n8n integration configuration."""

    model_config = SettingsConfigDict(env_prefix="N8N_")

    webhook_url: Optional[str] = Field(None, description="n8n webhook URL")
    api_key: Optional[str] = Field(None, description="n8n API key")


class WebhookSettings(BaseSettings):
    """Webhook server configuration."""

    model_config = SettingsConfigDict(env_prefix="WEBHOOK_")

    host: str = Field("0.0.0.0", description="Webhook server host")
    port: int = Field(8080, description="Webhook server port")
    secret: str = Field(..., description="Webhook secret for authentication")


class BotSettings(BaseSettings):
    """Bot operation settings."""

    model_config = SettingsConfigDict(env_prefix="")

    check_interval_minutes: int = Field(60, description="Group check interval")
    max_posts_per_hour: int = Field(24, description="Maximum posts per hour")
    target_group_id: int = Field(..., description="Target group Telegram ID")
    target_channel_id: Optional[int] = Field(None, description="Target channel Telegram ID")

    regex_parser_enabled: bool = Field(True, description="Enable regex parser")
    ai_parser_enabled: bool = Field(True, description="Enable AI parser")
    ai_fallback_to_regex: bool = Field(True, description="Fallback to regex if AI fails")

    log_level: str = Field("INFO", description="Logging level")
    log_format: Literal["json", "text"] = Field("json", description="Log format")

    session_path: Path = Field(Path("./sessions"), description="Session storage path")
    session_name: str = Field("job_repost_bot", description="Session name")

    api_delay_seconds: float = Field(2.0, description="Delay between API calls")
    post_delay_seconds: float = Field(150.0, description="Delay between posts")

    max_retries: int = Field(3, description="Maximum retry attempts")
    retry_delay_seconds: float = Field(5.0, description="Delay between retries")


class Settings(BaseSettings):
    """Main settings class combining all configurations."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore"
    )

    telegram: TelegramSettings = Field(default_factory=TelegramSettings)
    supabase: SupabaseSettings = Field(default_factory=SupabaseSettings)
    ai: AISettings = Field(default_factory=AISettings)
    n8n: N8NSettings = Field(default_factory=N8NSettings)
    webhook: WebhookSettings = Field(default_factory=WebhookSettings)
    bot: BotSettings = Field(default_factory=BotSettings)

    @classmethod
    def load(cls) -> "Settings":
        """Load settings from environment."""
        return cls(
            telegram=TelegramSettings(),
            supabase=SupabaseSettings(),
            ai=AISettings(),
            n8n=N8NSettings(),
            webhook=WebhookSettings(),
            bot=BotSettings()
        )


# Global settings instance
_settings: Optional[Settings] = None


def get_settings() -> Settings:
    """Get or create settings instance."""
    global _settings
    if _settings is None:
        _settings = Settings.load()
    return _settings


def reload_settings() -> Settings:
    """Force reload settings."""
    global _settings
    _settings = Settings.load()
    return _settings
