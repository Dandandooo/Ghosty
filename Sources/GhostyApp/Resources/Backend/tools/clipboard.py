"""Clipboard wrappers — pbcopy/pbpaste."""

import subprocess


def get_clipboard() -> str:
    """Return current clipboard text."""
    result = subprocess.run(
        ["pbpaste"], capture_output=True, text=True, timeout=5,
    )
    return result.stdout


def set_clipboard(text: str):
    """Set clipboard text."""
    process = subprocess.Popen(["pbcopy"], stdin=subprocess.PIPE)
    process.communicate(input=text.encode(), timeout=5)
