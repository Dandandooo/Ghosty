"""SuperMemory SDK integration — load/save user preferences.

Requires SUPERMEMORY_API_KEY to be set in .env.
"""

import json
import sys

from supermemory import Supermemory

from config import SUPERMEMORY_API_KEY
from graph.schema import GhostyState
from memory.preferences import extract_preferences


def _get_client() -> Supermemory:
    """Create a SuperMemory client. Raises if API key is missing."""
    if not SUPERMEMORY_API_KEY:
        raise RuntimeError(
            "SUPERMEMORY_API_KEY is not set. Add it to Backend/.env"
        )
    return Supermemory(api_key=SUPERMEMORY_API_KEY)


def load_preferences(intent: str) -> dict:
    """Query SuperMemory for preferences matching the intent."""
    client = _get_client()
    result = client.search.execute(q=intent, limit=5)
    prefs = {}
    for chunk in getattr(result, "chunks", []):
        content = getattr(chunk, "content", "")
        try:
            data = json.loads(content)
            if isinstance(data, dict):
                prefs.update(data)
        except (json.JSONDecodeError, TypeError):
            pass
    return prefs


def save_preferences(prefs: dict):
    """Save preferences to SuperMemory."""
    if not prefs:
        return
    client = _get_client()
    client.add(content=json.dumps(prefs), metadata={"type": "preference"})
    print(f"[memory] Saved preferences: {prefs}")


# ── LangGraph node functions ────────────────────────────────────────


def memory_load_node(state: GhostyState) -> dict:
    """Load user preferences from SuperMemory."""
    prefs = load_preferences(state["intent"])
    if prefs:
        print(f"[memory] Loaded preferences: {prefs}")
    return {"user_preferences": prefs}


def memory_save_node(state: GhostyState) -> dict:
    """Extract and save new preferences from the intent."""
    new_prefs = extract_preferences(state["intent"])
    if new_prefs:
        existing = state.get("user_preferences", {})
        merged = {**existing, **new_prefs}
        save_preferences(merged)
    return {}
