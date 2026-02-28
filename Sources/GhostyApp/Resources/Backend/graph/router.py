"""Conditional edge function — routes from supervisor to the correct agent node."""

from graph.schema import GhostyState

VALID_AGENTS = {"web", "system", "files", "gui", "done", "supervisor"}


def route_agent(state: GhostyState) -> str:
    """Return the next node name based on current_agent."""
    agent = state.get("current_agent", "done")
    if agent not in VALID_AGENTS:
        return "done"
    return agent
