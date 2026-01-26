"""
Telegram Job Repost Bot - Main Entry Point

Runs both the scheduler and the webhook server.
"""

import asyncio
import signal
import sys
from typing import Optional

import structlog
import uvicorn
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

from .config import get_settings
from .bot.scheduler import get_scheduler
from .api.webhook import app

# Configure structured logging
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.UnicodeDecoder(),
        structlog.processors.JSONRenderer()
    ],
    wrapper_class=structlog.stdlib.BoundLogger,
    context_class=dict,
    logger_factory=structlog.stdlib.LoggerFactory(),
    cache_logger_on_first_use=True,
)

logger = structlog.get_logger(__name__)


class BotApplication:
    """Main application class that manages all components."""

    def __init__(self):
        self.settings = get_settings()
        self.scheduler = get_scheduler()
        self._shutdown_event = asyncio.Event()
        self._server: Optional[uvicorn.Server] = None

    async def start_webhook_server(self) -> None:
        """Start the FastAPI webhook server."""
        config = uvicorn.Config(
            app=app,
            host=self.settings.webhook.host,
            port=self.settings.webhook.port,
            log_level="info",
            access_log=True
        )
        self._server = uvicorn.Server(config)

        logger.info(
            "Starting webhook server",
            host=self.settings.webhook.host,
            port=self.settings.webhook.port
        )

        await self._server.serve()

    async def start_scheduler(self) -> None:
        """Start the job scheduler."""
        logger.info("Starting scheduler")
        await self.scheduler.start()

        # Wait for shutdown signal
        await self._shutdown_event.wait()

    async def run(self) -> None:
        """Run the application."""
        logger.info("Starting Telegram Job Repost Bot")

        # Setup signal handlers
        loop = asyncio.get_event_loop()
        for sig in (signal.SIGTERM, signal.SIGINT):
            loop.add_signal_handler(
                sig,
                lambda s=sig: asyncio.create_task(self.shutdown(s))
            )

        try:
            # Run both scheduler and webhook server concurrently
            await asyncio.gather(
                self.start_scheduler(),
                self.start_webhook_server()
            )
        except asyncio.CancelledError:
            logger.info("Application cancelled")
        except Exception as e:
            logger.error("Application error", error=str(e))
            raise
        finally:
            await self.cleanup()

    async def shutdown(self, sig: signal.Signals) -> None:
        """Handle shutdown signal."""
        logger.info(f"Received signal {sig.name}, shutting down...")
        self._shutdown_event.set()

        if self._server:
            self._server.should_exit = True

    async def cleanup(self) -> None:
        """Cleanup resources."""
        logger.info("Cleaning up...")
        await self.scheduler.stop()
        logger.info("Cleanup completed")


async def main() -> None:
    """Main entry point."""
    app = BotApplication()
    await app.run()


def run_bot() -> None:
    """Run the bot (synchronous entry point)."""
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("Bot stopped by user")
    except Exception as e:
        logger.error("Fatal error", error=str(e))
        sys.exit(1)


def run_scheduler_only() -> None:
    """Run only the scheduler (without webhook server)."""
    async def _run():
        scheduler = get_scheduler()
        try:
            await scheduler.start()
            # Keep running
            while True:
                await asyncio.sleep(3600)
        except asyncio.CancelledError:
            pass
        finally:
            await scheduler.stop()

    try:
        asyncio.run(_run())
    except KeyboardInterrupt:
        logger.info("Scheduler stopped by user")


def run_webhook_only() -> None:
    """Run only the webhook server (without scheduler)."""
    settings = get_settings()
    uvicorn.run(
        "src.api.webhook:app",
        host=settings.webhook.host,
        port=settings.webhook.port,
        reload=False
    )


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Telegram Job Repost Bot")
    parser.add_argument(
        "--mode",
        choices=["full", "scheduler", "webhook"],
        default="full",
        help="Run mode: full (both), scheduler only, or webhook only"
    )
    args = parser.parse_args()

    if args.mode == "full":
        run_bot()
    elif args.mode == "scheduler":
        run_scheduler_only()
    elif args.mode == "webhook":
        run_webhook_only()
