"""System Agent — handles volume, dark mode, CLI commands, system settings."""

from agents.base import agent_wrapper
from graph.schema import GhostyState
from tools import applescript, shell


def _execute(state: GhostyState) -> str:
    task = state.get("agent_task", "")
    params = state.get("agent_params", {})

    # Direct parameter-driven actions
    if "volume" in params:
        level = int(params["volume"])
        applescript.set_volume(level)
        return f"Volume set to {level}"

    if params.get("setting") == "dark_mode" or params.get("action") == "toggle_dark_mode":
        applescript.toggle_dark_mode()
        return "Toggled dark mode"

    if "command" in params:
        output = shell.run_command(params["command"])
        return f"Ran command: {params['command']}" + (f"\n{output}" if output else "")

    if "script" in params:
        output = applescript.run_applescript(params["script"])
        return f"Ran AppleScript" + (f": {output}" if output else "")

    # Infer from task description
    task_lower = task.lower()

    if "volume" in task_lower:
        # Extract number from task
        import re
        nums = re.findall(r"\d+", task)
        if nums:
            level = int(nums[0])
            applescript.set_volume(level)
            return f"Volume set to {level}"
        if "mute" in task_lower or "off" in task_lower:
            applescript.set_volume(0)
            return "Volume muted"
        if "max" in task_lower or "full" in task_lower:
            applescript.set_volume(100)
            return "Volume set to max"

    if "dark mode" in task_lower:
        applescript.toggle_dark_mode()
        return "Toggled dark mode"

    if "open system" in task_lower or "system settings" in task_lower or "system preferences" in task_lower:
        applescript.open_app("System Settings")
        return "Opened System Settings"

    return f"System task handled: {task}"


system_agent_node = agent_wrapper("system", _execute)
