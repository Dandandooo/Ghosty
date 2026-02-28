"""Ghosty configuration — all tunables in one place."""

import os
from pathlib import Path

from dotenv import load_dotenv

load_dotenv(Path(__file__).parent / ".env")

# ── LLM ──────────────────────────────────────────────────────────────
GHOSTY_LLM_PROVIDER = os.getenv("GHOSTY_LLM_PROVIDER", "ollama")
GHOSTY_LLM_MODEL = os.getenv("GHOSTY_LLM_MODEL", "llama3.1:8b")
OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY", "")

# ── SuperMemory ──────────────────────────────────────────────────────
SUPERMEMORY_API_KEY = os.getenv("SUPERMEMORY_API_KEY", "")

# ── Safety limits ────────────────────────────────────────────────────
MAX_STEPS = 20
MAX_TIMEOUT = 60          # seconds
MAX_RETRIES = 2
SHELL_TIMEOUT = 15        # seconds per CLI command

# ── State bridge ─────────────────────────────────────────────────────
STATE_DIR = os.path.expanduser("~/ghosty")

# ── Shell allowlist ──────────────────────────────────────────────────
SHELL_ALLOWLIST = {
    "open", "mdfind", "defaults", "pmset", "mv", "cp", "mkdir", "ls",
    "cat", "head", "tail", "wc", "sort", "find", "which", "whoami",
    "date", "cal", "df", "du", "file", "mdls", "xattr", "stat",
    "say", "afplay", "screencapture", "osascript", "system_profiler",
    "networksetup", "scutil", "sw_vers", "uname",
}

# ── Browser order ────────────────────────────────────────────────────
BROWSER_ORDER = [
    "Google Chrome", "Safari", "Arc", "Brave Browser",
    "Microsoft Edge", "Firefox",
]
CHROME_LIKE = {"Google Chrome", "Brave Browser", "Microsoft Edge", "Arc", "Chromium"}
