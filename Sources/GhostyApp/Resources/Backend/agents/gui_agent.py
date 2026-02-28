"""GUI Agent — handles direct GUI interaction: click, type, hotkey, switch apps."""

import time

from agents.base import agent_wrapper
from graph.schema import GhostyState
from tools import applescript, screen


def _execute(state: GhostyState) -> str:
    task = state.get("agent_task", "")
    params = state.get("agent_params", {})

    app = params.get("app", "")
    text = params.get("text", "")
    keys = params.get("keys", "")
    key = params.get("key", "")
    description = params.get("description", "")
    x = params.get("x")
    y = params.get("y")
    action = params.get("action", "")

    # Switch to / open app
    if app:
        try:
            applescript.switch_to_app(app)
        except Exception:
            applescript.open_app(app)
        time.sleep(0.5)

    # Click at coordinates
    if x is not None and y is not None:
        screen.click(int(x), int(y))
        time.sleep(0.2)
        summary = f"Clicked at ({x}, {y})"
        if text:
            time.sleep(0.15)
            screen.type_text(text)
            summary += f" and typed '{text}'"
        return summary

    # Hotkey
    if keys:
        key_list = [k.strip() for k in keys.split("+")]
        screen.hotkey(*key_list)
        time.sleep(0.2)
        summary = f"Pressed {keys}"
        if text:
            time.sleep(0.15)
            screen.type_text(text)
            summary += f" and typed '{text}'"
        return summary

    # Single key press
    if key:
        screen.key_press(key)
        return f"Pressed {key}"

    # Type text
    if text:
        time.sleep(0.15)
        screen.type_text(text)
        return f"Typed '{text}'" + (f" in {app}" if app else "")

    # Accessibility click by description (future: integrate with vision)
    if description:
        # For now, just report — could integrate with a vision model later
        return f"GUI interaction: {description}" + (f" in {app}" if app else "")

    # Infer from task
    task_lower = task.lower()

    if app and not text and not keys:
        return f"Switched to {app}"

    if "type" in task_lower and not text:
        # Try to extract text from task
        for prefix in ("type ", "type: "):
            if prefix in task_lower:
                extracted = task[task_lower.index(prefix) + len(prefix):].strip().strip('"\'')
                if extracted:
                    screen.type_text(extracted)
                    return f"Typed '{extracted}'"

    return f"GUI task handled: {task}"


gui_agent_node = agent_wrapper("gui", _execute)
