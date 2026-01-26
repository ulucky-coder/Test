#!/usr/bin/env python3
"""
Interactive script to setup Pyrogram session.
Run this before starting the bot for the first time.
"""

import asyncio
import os
import sys
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from dotenv import load_dotenv
from pyrogram import Client

load_dotenv()


async def setup_session():
    """Setup Pyrogram session interactively."""
    print("=" * 50)
    print("Telegram Job Repost Bot - Session Setup")
    print("=" * 50)
    print()

    api_id = os.getenv("TELEGRAM_API_ID")
    api_hash = os.getenv("TELEGRAM_API_HASH")
    phone = os.getenv("TELEGRAM_PHONE")
    bot_token = os.getenv("TELEGRAM_BOT_TOKEN")

    if not all([api_id, api_hash, phone, bot_token]):
        print("ERROR: Missing environment variables!")
        print("Please set the following in .env file:")
        print("  - TELEGRAM_API_ID")
        print("  - TELEGRAM_API_HASH")
        print("  - TELEGRAM_PHONE")
        print("  - TELEGRAM_BOT_TOKEN")
        return

    session_path = Path(os.getenv("SESSION_PATH", "./sessions"))
    session_path.mkdir(parents=True, exist_ok=True)

    session_name = os.getenv("SESSION_NAME", "job_repost_bot")

    print(f"API ID: {api_id}")
    print(f"Phone: {phone}")
    print(f"Session path: {session_path}")
    print()

    # Setup user client
    print("Setting up USER account session...")
    print("You will receive a code on Telegram.")
    print()

    user_client = Client(
        name=str(session_path / session_name),
        api_id=int(api_id),
        api_hash=api_hash,
        phone_number=phone
    )

    async with user_client:
        me = await user_client.get_me()
        print(f"✓ User session created for: {me.first_name} (@{me.username})")
        print(f"  User ID: {me.id}")
        print()

    # Setup bot client
    print("Setting up BOT session...")
    bot_client = Client(
        name=str(session_path / f"{session_name}_bot"),
        api_id=int(api_id),
        api_hash=api_hash,
        bot_token=bot_token
    )

    async with bot_client:
        me = await bot_client.get_me()
        print(f"✓ Bot session created for: {me.first_name} (@{me.username})")
        print(f"  Bot ID: {me.id}")
        print()

    print("=" * 50)
    print("Session setup completed!")
    print("You can now start the bot with: python -m src.main")
    print("=" * 50)


if __name__ == "__main__":
    asyncio.run(setup_session())
