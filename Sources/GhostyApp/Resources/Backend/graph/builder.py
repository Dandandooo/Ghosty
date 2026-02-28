"""Assembles and compiles the Ghosty StateGraph."""

from langgraph.graph import StateGraph, START, END

from graph.schema import GhostyState
from graph.supervisor import supervisor_node
from graph.router import route_agent
from agents.web_agent import web_agent_node
from agents.system_agent import system_agent_node
from agents.files_agent import files_agent_node
from agents.gui_agent import gui_agent_node
from memory.client import memory_load_node, memory_save_node


def _done_node(state: GhostyState) -> dict:
    """Terminal node — sets the final message."""
    params = state.get("agent_params", {})
    message = params.get("message", "Task complete.")
    return {
        "final_message": message,
        "should_continue": False,
    }


def build_graph() -> StateGraph:
    """Build and compile the Ghosty agent graph."""
    graph = StateGraph(GhostyState)

    # Add nodes
    graph.add_node("memory_load", memory_load_node)
    graph.add_node("supervisor", supervisor_node)
    graph.add_node("web", web_agent_node)
    graph.add_node("system", system_agent_node)
    graph.add_node("files", files_agent_node)
    graph.add_node("gui", gui_agent_node)
    graph.add_node("done", _done_node)
    graph.add_node("memory_save", memory_save_node)

    # Entry: START → memory_load → supervisor
    graph.add_edge(START, "memory_load")
    graph.add_edge("memory_load", "supervisor")

    # Supervisor routes to agents via conditional edge
    graph.add_conditional_edges(
        "supervisor",
        route_agent,
        {
            "web": "web",
            "system": "system",
            "files": "files",
            "gui": "gui",
            "done": "done",
            "supervisor": "supervisor",  # retry on error
        },
    )

    # Each agent loops back to supervisor
    for agent in ("web", "system", "files", "gui"):
        graph.add_edge(agent, "supervisor")

    # Done → memory_save → END
    graph.add_edge("done", "memory_save")
    graph.add_edge("memory_save", END)

    return graph.compile()
