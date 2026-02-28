"""Files Agent — handles file operations: open, create, move, search."""

import os

from agents.base import agent_wrapper
from graph.schema import GhostyState
from tools import applescript, shell


def _execute(state: GhostyState) -> str:
    task = state.get("agent_task", "")
    params = state.get("agent_params", {})

    path = params.get("path", "")
    destination = params.get("destination", "")
    content = params.get("content", "")
    query = params.get("query", "")
    action = params.get("action", "")

    if action == "open" or (path and not content and not destination):
        if path:
            applescript.open_file(path)
            return f"Opened {path}"

    if action == "create" or (path and content):
        if path:
            expanded = os.path.expanduser(path)
            parent = os.path.dirname(expanded)
            if parent:
                os.makedirs(parent, exist_ok=True)
            with open(expanded, "w") as f:
                f.write(content)
            return f"Created {path}"

    if action == "move" or (path and destination):
        if path and destination:
            shell.run_command(f"mv {path} {destination}")
            return f"Moved {path} to {destination}"

    if action == "copy":
        if path and destination:
            shell.run_command(f"cp {path} {destination}")
            return f"Copied {path} to {destination}"

    if action == "search" or query:
        search_term = query or path
        if search_term:
            output = shell.run_command(f"mdfind {search_term}")
            results = output.strip().split("\n")[:10] if output else []
            return f"Found {len(results)} files matching '{search_term}'"

    if action == "list" or action == "ls":
        target = path or "."
        output = shell.run_command(f"ls {target}")
        return f"Directory listing of {target}:\n{output}"

    if action == "mkdir":
        if path:
            os.makedirs(os.path.expanduser(path), exist_ok=True)
            return f"Created directory {path}"

    # Infer from task
    task_lower = task.lower()

    if "search" in task_lower or "find" in task_lower:
        words = task.split()
        # Use the last meaningful word as query
        search_term = words[-1] if words else task
        output = shell.run_command(f"mdfind {search_term}")
        results = output.strip().split("\n")[:10] if output else []
        return f"Found {len(results)} files matching '{search_term}'"

    if "open" in task_lower and path:
        applescript.open_file(path)
        return f"Opened {path}"

    return f"Files task handled: {task}"


files_agent_node = agent_wrapper("files", _execute)
