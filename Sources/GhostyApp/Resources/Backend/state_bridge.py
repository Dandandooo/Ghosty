"""State bridge — writes ~/ghosty/state.json for the Swift frontend."""

import json
import os

from config import STATE_DIR

STATE_FILE = os.path.join(STATE_DIR, "state.json")


def _ensure_dir():
    os.makedirs(STATE_DIR, exist_ok=True)


def update_state(state, message=None, step=None, total_steps=None):
    """Write a state update to ~/ghosty/state.json.

    Args:
        state: One of "idle", "working", "complete", "listening".
        message: Optional human-readable description of current activity.
        step: Current step number (1-indexed).
        total_steps: Total number of planned steps.
    """
    _ensure_dir()
    payload = {"state": state}
    if message is not None:
        payload["message"] = message
    if step is not None:
        payload["step"] = step
    if total_steps is not None:
        payload["total_steps"] = total_steps

    tmp = STATE_FILE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(payload, f)
    os.replace(tmp, STATE_FILE)


def set_working(message, step=None, total_steps=None):
    """Convenience: set state to working with a message."""
    update_state("working", message=message, step=step, total_steps=total_steps)


def set_complete(message=None):
    """Convenience: set state to complete."""
    update_state("complete", message=message)


def set_idle():
    """Convenience: set state to idle."""
    update_state("idle")


def read_state() -> dict:
    """Read the current state file, returning {} if missing or invalid."""
    try:
        with open(STATE_FILE, "r") as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {}
