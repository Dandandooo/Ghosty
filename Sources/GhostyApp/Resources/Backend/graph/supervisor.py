"""Supervisor node — calls the LLM to decide which agent handles the next step."""

import json
import re
import sys

from langchain_core.messages import HumanMessage, SystemMessage

from graph.schema import GhostyState
from llm.provider import get_llm
from llm.prompts import SUPERVISOR_PROMPT
from config import MAX_RETRIES
import state_bridge


def supervisor_node(state: GhostyState) -> dict:
    """LLM-based routing: returns the next agent and task."""
    llm = get_llm()

    # Build the user message with context
    parts = [f"User request: {state['intent']}"]

    ctx = state.get("context", {})
    if ctx.get("frontmost_app"):
        parts.append(f"Currently focused app: {ctx['frontmost_app']}")
    if ctx.get("running_apps"):
        apps = ", ".join(ctx["running_apps"][:15])
        parts.append(f"Running apps: {apps}")

    prefs = state.get("user_preferences", {})
    if prefs:
        parts.append(f"User preferences: {json.dumps(prefs)}")

    completed = state.get("steps_completed", [])
    if completed:
        summaries = [s.get("summary", s.get("agent", "?")) for s in completed]
        parts.append(f"Steps completed so far: {', '.join(summaries)}")

    error = state.get("error")
    if error:
        parts.append(f"Previous step failed with error: {error}")

    user_msg = "\n".join(parts)

    state_bridge.set_working(
        "Deciding next step...",
        step=state.get("step_number", 0),
        total_steps=state.get("total_steps", 0),
    )

    messages = [
        SystemMessage(content=SUPERVISOR_PROMPT),
        HumanMessage(content=user_msg),
    ]

    try:
        response = llm.invoke(messages)
        raw = response.content.strip()
        parsed = _parse_routing(raw)
    except Exception as e:
        print(f"[supervisor] LLM call failed: {e}", file=sys.stderr)
        retry = state.get("retry_count", 0)
        if retry < MAX_RETRIES:
            return {
                "error": str(e),
                "retry_count": retry + 1,
                "current_agent": "supervisor",
            }
        return {
            "current_agent": "done",
            "agent_task": "",
            "agent_params": {"message": f"Failed after {MAX_RETRIES} retries: {e}"},
            "final_message": f"Sorry, I couldn't complete the task: {e}",
        }

    agent = parsed.get("agent", "done")
    task = parsed.get("task", "")
    params = parsed.get("params", {})

    print(f"[supervisor] Routing to: {agent} | Task: {task}")

    return {
        "current_agent": agent,
        "agent_task": task,
        "agent_params": params,
        "error": None,
        "retry_count": 0,
        "messages": [response],
    }


def _parse_routing(raw: str) -> dict:
    """Parse the LLM's JSON routing response."""
    # Try direct JSON parse
    try:
        parsed = json.loads(raw)
        if isinstance(parsed, dict) and "agent" in parsed:
            return parsed
    except json.JSONDecodeError:
        pass

    # Try extracting JSON from text
    match = re.search(r"\{.*\}", raw, re.DOTALL)
    if match:
        try:
            parsed = json.loads(match.group())
            if isinstance(parsed, dict) and "agent" in parsed:
                return parsed
        except json.JSONDecodeError:
            pass

    # Fallback: try to guess agent from keywords
    raw_lower = raw.lower()
    for agent in ("web", "system", "files", "gui", "done"):
        if agent in raw_lower:
            return {"agent": agent, "task": raw, "params": {}}

    return {"agent": "done", "task": "", "params": {"message": f"Could not parse: {raw[:200]}"}}
