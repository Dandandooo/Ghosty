#!/usr/bin/env python3
"""Ghosty Agent — main entry point for the virtual assistant backend.

Usage: python3 agent.py "open Safari and search for cats"

Flow:
  1. Parse user intent from argv
  2. Set state to working
  3. Gather context (frontmost app, running apps)
  4. Plan via Ollama
  5. Execute each step (AppleScript for direct actions, ShowUI for visual)
  6. Set state to complete
"""

import os
import sys
import time
import traceback

# Ensure sibling modules are importable regardless of working directory
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import applescript_engine
import orchestrator
import screen_control
import state

# Safety limits
MAX_STEPS = 20
MAX_TIMEOUT = 60  # seconds

# ShowUI backend: "local", "gradio", or "modal"
SHOWUI_BACKEND = "local"

_showui = None


def _get_showui():
    """Lazy-load ShowUI client."""
    global _showui
    if _showui is None:
        try:
            import showui_client
            _showui = showui_client.get_client(SHOWUI_BACKEND)
        except Exception as e:
            print(f"[agent] ShowUI unavailable: {e}", file=sys.stderr)
            _showui = None
    return _showui


def gather_context() -> dict:
    """Gather current macOS context for the planner."""
    ctx = {}
    try:
        ctx["frontmost_app"] = applescript_engine.get_frontmost_app()
    except Exception:
        ctx["frontmost_app"] = "Unknown"
    try:
        ctx["running_apps"] = applescript_engine.list_running_apps()
    except Exception:
        ctx["running_apps"] = []
    return ctx


def execute_step(step: dict) -> bool:
    """Execute a single action step. Returns True on success."""
    action = step.get("action", "")
    params = step.get("params", {})

    if action == "open_app":
        applescript_engine.open_app(params["name"])

    elif action == "switch_to_app":
        applescript_engine.switch_to_app(params["name"])

    elif action == "click_element":
        description = params.get("description", "")
        client = _get_showui()
        if client is None:
            print(f"[agent] ShowUI unavailable, skipping click_element: {description}",
                  file=sys.stderr)
            return True  # Non-fatal: continue with remaining steps

        img = screen_control.screenshot()
        result = client.grounding(img, description)
        abs_x, abs_y = result.absolute_coords
        print(f"[agent] ShowUI grounding: {description} → ({abs_x}, {abs_y})")
        screen_control.click(abs_x, abs_y)

    elif action == "type_text":
        screen_control.type_text(params["text"])

    elif action == "hotkey":
        keys = params.get("keys", "")
        if isinstance(keys, str):
            keys = [k.strip() for k in keys.split("+")]
        screen_control.hotkey(*keys)

    elif action == "key_press":
        screen_control.key_press(params["key"])

    elif action == "scroll":
        direction = params.get("direction", "down")
        amount = int(params.get("amount", 3))
        clicks = amount if direction == "up" else -amount
        screen_control.scroll(clicks)

    elif action == "open_url":
        applescript_engine.open_url(params["url"])

    elif action == "open_file":
        applescript_engine.open_file(params["path"])

    elif action == "applescript":
        applescript_engine.run_applescript(params["script"])

    elif action == "wait":
        time.sleep(float(params.get("seconds", 1)))

    elif action == "done":
        msg = params.get("message", "Task complete.")
        print(f"[agent] Done: {msg}")

    else:
        print(f"[agent] Unknown action: {action}", file=sys.stderr)

    return True


def run_agent(intent: str) -> str:
    """Main agent loop.

    Args:
        intent: User's natural language request.

    Returns:
        Final status message.
    """
    start_time = time.time()

    # 1. Set working state
    state.set_working(f"Understanding: {intent}")

    # 2. Gather context
    context = gather_context()

    # 3. Plan via Ollama
    try:
        state.set_working("Planning steps...")
        steps = orchestrator.plan(intent, context=context)
    except Exception as e:
        error_msg = f"Planning failed: {e}"
        print(f"[agent] {error_msg}", file=sys.stderr)
        state.set_complete(error_msg)
        return error_msg

    if not steps:
        state.set_complete("No steps planned.")
        return "No steps planned."

    total = len(steps)
    completed_steps = []
    final_message = "Task complete."

    # 4. Execute each step
    for i, step in enumerate(steps):
        # Safety: timeout
        elapsed = time.time() - start_time
        if elapsed > MAX_TIMEOUT:
            state.set_complete("Timed out.")
            return "Timed out after 60 seconds."

        # Safety: max steps
        if i >= MAX_STEPS:
            state.set_complete("Too many steps.")
            return "Stopped after 20 steps."

        action = step.get("action", "unknown")
        params = step.get("params", {})

        # Update state for UI
        if action == "done":
            final_message = params.get("message", "Task complete.")
            continue

        description = _step_description(step)
        state.set_working(description, step=i + 1, total_steps=total)

        try:
            execute_step(step)
            completed_steps.append(step)
        except Exception as e:
            error = str(e)
            print(f"[agent] Step {i+1} failed: {error}", file=sys.stderr)
            traceback.print_exc(file=sys.stderr)

            # Try to re-plan
            try:
                state.set_working("Re-planning after error...")
                new_context = gather_context()
                remaining = orchestrator.replan(
                    intent, completed_steps, error, context=new_context,
                )
                # Replace remaining steps
                steps = steps[:i+1] + remaining
                total = len(steps)
            except Exception as replan_err:
                print(f"[agent] Re-plan failed: {replan_err}", file=sys.stderr)
                state.set_complete(f"Failed: {error}")
                return f"Failed at step {i+1}: {error}"

        # Brief pause between steps
        if action not in ("wait", "done"):
            time.sleep(0.3)

    # 5. Complete
    state.set_complete(final_message)
    return final_message


def _step_description(step: dict) -> str:
    """Human-readable description of a step for the UI."""
    action = step.get("action", "")
    params = step.get("params", {})

    descriptions = {
        "open_app": f"Opening {params.get('name', 'app')}...",
        "switch_to_app": f"Switching to {params.get('name', 'app')}...",
        "click_element": f"Clicking {params.get('description', 'element')}...",
        "type_text": f"Typing text...",
        "hotkey": f"Pressing {params.get('keys', 'keys')}...",
        "key_press": f"Pressing {params.get('key', 'key')}...",
        "scroll": f"Scrolling {params.get('direction', 'down')}...",
        "open_url": f"Opening URL...",
        "open_file": f"Opening file...",
        "applescript": "Running AppleScript...",
        "wait": "Waiting...",
    }
    return descriptions.get(action, f"Executing {action}...")


def main() -> int:
    intent = " ".join(sys.argv[1:]).strip()
    if not intent:
        print("Usage: python3 agent.py \"your intent here\"", file=sys.stderr)
        return 1

    print(f"[agent] Intent: {intent}")
    result = run_agent(intent)
    print(result)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
