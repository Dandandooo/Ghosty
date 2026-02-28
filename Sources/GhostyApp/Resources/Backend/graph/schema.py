"""GhostyState — the shared state TypedDict for the LangGraph."""

from typing import Annotated, Optional, TypedDict

from langchain_core.messages import BaseMessage
from langgraph.graph.message import add_messages


class GhostyState(TypedDict):
    intent: str
    messages: Annotated[list[BaseMessage], add_messages]
    current_agent: str          # "supervisor"|"web"|"system"|"files"|"gui"|"done"
    agent_task: str
    agent_params: dict
    steps_completed: list[dict]
    step_number: int
    total_steps: int
    user_preferences: dict      # from SuperMemory
    context: dict               # frontmost_app, running_apps
    error: Optional[str]
    retry_count: int
    final_message: str
    should_continue: bool
