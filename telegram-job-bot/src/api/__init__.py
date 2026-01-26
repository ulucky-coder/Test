"""API module for n8n integration."""

from .webhook import app, create_app

__all__ = ["app", "create_app"]
