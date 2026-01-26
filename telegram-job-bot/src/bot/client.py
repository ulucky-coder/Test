"""
Telegram client using Pyrogram for MTProto API access.
Handles both user account (for reading groups) and bot (for publishing).
"""

import asyncio
from pathlib import Path
from typing import Optional, AsyncGenerator, List

import structlog
from pyrogram import Client
from pyrogram.types import Message, Chat
from pyrogram.errors import (
    FloodWait,
    ChannelPrivate,
    ChannelInvalid,
    ChatAdminRequired,
    UserNotParticipant
)
from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type

from ..config import get_settings

logger = structlog.get_logger(__name__)


class TelegramClient:
    """
    Telegram client wrapper for Pyrogram.
    Uses user account for reading groups, bot for publishing.
    """

    def __init__(self):
        self.settings = get_settings()
        self._user_client: Optional[Client] = None
        self._bot_client: Optional[Client] = None
        self._is_connected = False

    async def connect(self) -> None:
        """Connect both user and bot clients."""
        if self._is_connected:
            return

        session_path = Path(self.settings.bot.session_path)
        session_path.mkdir(parents=True, exist_ok=True)

        # User client for reading groups (MTProto)
        self._user_client = Client(
            name=str(session_path / self.settings.bot.session_name),
            api_id=self.settings.telegram.api_id,
            api_hash=self.settings.telegram.api_hash,
            phone_number=self.settings.telegram.phone
        )

        # Bot client for publishing
        self._bot_client = Client(
            name=str(session_path / f"{self.settings.bot.session_name}_bot"),
            api_id=self.settings.telegram.api_id,
            api_hash=self.settings.telegram.api_hash,
            bot_token=self.settings.telegram.bot_token
        )

        try:
            await self._user_client.start()
            logger.info("User client connected")

            await self._bot_client.start()
            logger.info("Bot client connected")

            self._is_connected = True
        except Exception as e:
            logger.error("Failed to connect Telegram clients", error=str(e))
            raise

    async def disconnect(self) -> None:
        """Disconnect both clients."""
        if self._user_client and self._user_client.is_connected:
            await self._user_client.stop()
            logger.info("User client disconnected")

        if self._bot_client and self._bot_client.is_connected:
            await self._bot_client.stop()
            logger.info("Bot client disconnected")

        self._is_connected = False

    @property
    def user(self) -> Client:
        """Get user client for reading groups."""
        if not self._user_client:
            raise RuntimeError("User client not initialized. Call connect() first.")
        return self._user_client

    @property
    def bot(self) -> Client:
        """Get bot client for publishing."""
        if not self._bot_client:
            raise RuntimeError("Bot client not initialized. Call connect() first.")
        return self._bot_client

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(min=2, max=30),
        retry=retry_if_exception_type(FloodWait)
    )
    async def get_chat(self, chat_id: int) -> Optional[Chat]:
        """Get chat information."""
        try:
            return await self.user.get_chat(chat_id)
        except (ChannelPrivate, ChannelInvalid) as e:
            logger.warning("Cannot access chat", chat_id=chat_id, error=str(e))
            return None
        except FloodWait as e:
            logger.warning("Flood wait", seconds=e.value)
            await asyncio.sleep(e.value)
            raise
        except Exception as e:
            logger.error("Error getting chat", chat_id=chat_id, error=str(e))
            return None

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(min=2, max=30),
        retry=retry_if_exception_type(FloodWait)
    )
    async def get_chat_history(
        self,
        chat_id: int,
        limit: int = 100,
        offset_id: int = 0
    ) -> AsyncGenerator[Message, None]:
        """
        Get chat history messages.

        Args:
            chat_id: Telegram chat ID
            limit: Maximum messages to fetch
            offset_id: Start from this message ID (0 = latest)

        Yields:
            Message objects
        """
        try:
            async for message in self.user.get_chat_history(
                chat_id=chat_id,
                limit=limit,
                offset_id=offset_id
            ):
                yield message
                # Rate limiting
                await asyncio.sleep(self.settings.bot.api_delay_seconds / 10)
        except (ChannelPrivate, ChannelInvalid, UserNotParticipant) as e:
            logger.warning("Cannot access chat history", chat_id=chat_id, error=str(e))
            return
        except FloodWait as e:
            logger.warning("Flood wait", seconds=e.value)
            await asyncio.sleep(e.value)
            raise
        except Exception as e:
            logger.error("Error getting chat history", chat_id=chat_id, error=str(e))
            return

    async def get_new_messages(
        self,
        chat_id: int,
        after_message_id: int,
        limit: int = 100
    ) -> List[Message]:
        """
        Get messages newer than specified message ID.

        Args:
            chat_id: Telegram chat ID
            after_message_id: Get messages after this ID
            limit: Maximum messages to fetch

        Returns:
            List of new messages
        """
        messages = []
        try:
            async for message in self.get_chat_history(chat_id, limit=limit):
                if message.id <= after_message_id:
                    break
                messages.append(message)

            # Reverse to get chronological order
            messages.reverse()
            return messages
        except Exception as e:
            logger.error(
                "Error getting new messages",
                chat_id=chat_id,
                after_id=after_message_id,
                error=str(e)
            )
            return []

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(min=2, max=30),
        retry=retry_if_exception_type(FloodWait)
    )
    async def send_message(
        self,
        chat_id: int,
        text: str,
        parse_mode: str = "html",
        disable_preview: bool = True
    ) -> Optional[Message]:
        """
        Send message using bot client.

        Args:
            chat_id: Target chat ID
            text: Message text
            parse_mode: Parse mode (html, markdown)
            disable_preview: Disable link preview

        Returns:
            Sent message or None on error
        """
        try:
            message = await self.bot.send_message(
                chat_id=chat_id,
                text=text,
                parse_mode=parse_mode,
                disable_web_page_preview=disable_preview
            )
            logger.info("Message sent", chat_id=chat_id, message_id=message.id)
            return message
        except ChatAdminRequired:
            logger.error("Bot is not admin in chat", chat_id=chat_id)
            return None
        except FloodWait as e:
            logger.warning("Flood wait on send", seconds=e.value)
            await asyncio.sleep(e.value)
            raise
        except Exception as e:
            logger.error("Error sending message", chat_id=chat_id, error=str(e))
            return None

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(min=2, max=30),
        retry=retry_if_exception_type(FloodWait)
    )
    async def forward_message(
        self,
        to_chat_id: int,
        from_chat_id: int,
        message_id: int
    ) -> Optional[Message]:
        """
        Forward message (not used in this bot, but available).

        Args:
            to_chat_id: Target chat ID
            from_chat_id: Source chat ID
            message_id: Message ID to forward

        Returns:
            Forwarded message or None on error
        """
        try:
            return await self.bot.forward_messages(
                chat_id=to_chat_id,
                from_chat_id=from_chat_id,
                message_ids=message_id
            )
        except FloodWait as e:
            logger.warning("Flood wait on forward", seconds=e.value)
            await asyncio.sleep(e.value)
            raise
        except Exception as e:
            logger.error(
                "Error forwarding message",
                to_chat=to_chat_id,
                from_chat=from_chat_id,
                error=str(e)
            )
            return None

    async def join_chat(self, chat_link: str) -> Optional[Chat]:
        """
        Join a chat by invite link or username.

        Args:
            chat_link: Invite link or @username

        Returns:
            Chat object or None on error
        """
        try:
            chat = await self.user.join_chat(chat_link)
            logger.info("Joined chat", chat_id=chat.id, title=chat.title)
            return chat
        except Exception as e:
            logger.error("Error joining chat", link=chat_link, error=str(e))
            return None

    async def get_me(self) -> dict:
        """Get info about user and bot accounts."""
        user_me = await self.user.get_me()
        bot_me = await self.bot.get_me()
        return {
            "user": {
                "id": user_me.id,
                "username": user_me.username,
                "phone": user_me.phone_number
            },
            "bot": {
                "id": bot_me.id,
                "username": bot_me.username
            }
        }


# Global instance
_telegram_client: Optional[TelegramClient] = None


def get_telegram_client() -> TelegramClient:
    """Get or create Telegram client instance."""
    global _telegram_client
    if _telegram_client is None:
        _telegram_client = TelegramClient()
    return _telegram_client
