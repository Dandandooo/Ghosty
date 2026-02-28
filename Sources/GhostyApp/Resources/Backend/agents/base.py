"""BaseAgent — shared error handling and state update logic for all agents."""

import sys
import time
import traceback

import state_bridge
from graph.schema import GhostyState


def agent_wrapper(agent_name: str, execute_fn):
    """Wrap an agent execution function with error handling and state updates.

    Args:
        agent_name: Name of the agent (for logging).
        execute_fn: Function(state) -> str that executes the task and returns a summary.

    Returns:
        A node function compatible with LangGraph.
    """
    def node(state: GhostyState) -> dict:
        task = state.get("agent_task", "")
        step_num = state.get("step_number", 0) + 1

        state_bridge.set_working(
            f"[{agent_name}] {task}",
            step=step_num,
            total_steps=state.get("total_steps", 0),
        )

        try:
            summary = execute_fn(state)
            print(f"[{agent_name}] Done: {summary}")

            completed = list(state.get("steps_completed", []))
            completed.append({
                "agent": agent_name,
                "task": task,
                "summary": summary,
            })

            return {
                "steps_completed": completed,
                "step_number": step_num,
                "error": None,
            }

        except Exception as e:
            error_msg = f"{agent_name} failed: {e}"
            print(f"[{agent_name}] Error: {error_msg}", file=sys.stderr)
            traceback.print_exc(file=sys.stderr)

            return {
                "error": error_msg,
                "step_number": step_num,
            }

    return node
