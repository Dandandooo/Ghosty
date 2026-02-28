"""Regex-based preference extraction from user intents."""

import re

# Patterns: (regex, preference_key, group_index)
_PATTERNS = [
    (r"(?:use|prefer|switch to|set)\s+(\w[\w\s]*?)\s+(?:as|for|instead of)\s+(?:my\s+)?browser",
     "preferred_browser", 1),
    (r"(?:use|prefer|switch to)\s+(chrome|safari|arc|brave|firefox|edge)",
     "preferred_browser", 1),
    (r"(?:always|default)\s+(?:use|open with)\s+(\w[\w\s]*?)(?:\s|$)",
     "default_app", 1),
]

# Normalize browser names
_BROWSER_NAMES = {
    "chrome": "Google Chrome",
    "safari": "Safari",
    "arc": "Arc",
    "brave": "Brave Browser",
    "firefox": "Firefox",
    "edge": "Microsoft Edge",
}


def extract_preferences(intent: str) -> dict:
    """Extract user preferences from an intent string.

    Returns:
        Dict of preference_key → value. Empty if no preferences found.
    """
    prefs = {}
    intent_lower = intent.lower()

    for pattern, key, group in _PATTERNS:
        match = re.search(pattern, intent_lower)
        if match:
            value = match.group(group).strip()
            if key == "preferred_browser":
                value = _BROWSER_NAMES.get(value.lower(), value.title())
            prefs[key] = value

    return prefs
