"""Web Agent — handles browser tasks: navigate, search, type, click."""

import re
import time

from agents.base import agent_wrapper
from graph.schema import GhostyState
from tools import browser


def _extract_search_query(task: str, intent: str) -> str:
    """Try hard to extract a search query from the task or original intent."""
    # 1. From task: "search for X", "search X", "look up X", "google X"
    for pattern in [
        r'(?:search\s+for|search|look\s+up|google|find)\s+["\']?(.+?)["\']?\s*$',
        r'(?:search\s+for|search|look\s+up|google|find)\s+(.+)',
    ]:
        match = re.search(pattern, task, re.IGNORECASE)
        if match:
            return match.group(1).strip().strip('"\'')

    # 2. From original intent
    for pattern in [
        r'(?:search\s+for|search|look\s+up|google|find)\s+["\']?(.+?)["\']?\s*$',
        r'(?:search\s+for|search|look\s+up|google|find)\s+(.+)',
    ]:
        match = re.search(pattern, intent, re.IGNORECASE)
        if match:
            return match.group(1).strip().strip('"\'')

    return ""


def _execute(state: GhostyState) -> str:
    task = state.get("agent_task", "")
    params = state.get("agent_params", {})
    intent = state.get("intent", "")

    # Apply preferred browser from user preferences
    prefs = state.get("user_preferences", {})
    if prefs.get("preferred_browser"):
        browser.set_preferred_browser(prefs["preferred_browser"])

    # Determine action from params or infer from task
    url = params.get("url", "")
    query = params.get("query", "")
    selector = params.get("selector", "")
    text = params.get("text", "")
    action = params.get("action", "")

    # If no query in params, try to extract from task/intent
    if not query:
        task_lower = task.lower()
        if "search" in task_lower or "look up" in task_lower or "google" in task_lower:
            query = _extract_search_query(task, intent)

    if url:
        browser.navigate(url)
        time.sleep(2)
        if query:
            browser.search(query)
            time.sleep(0.5)
        elif text and selector:
            browser.type_in_page(selector, text)
        return f"Navigated to {url}" + (f" and searched for '{query}'" if query else "")

    if query:
        browser.search(query)
        return f"Searched for '{query}'"

    if action == "new_tab":
        browser.new_tab()
        return "Opened new tab"

    if action == "focus_url_bar":
        browser.focus_url_bar()
        return "Focused URL bar"

    if selector and text:
        browser.type_in_page(selector, text)
        return f"Typed '{text}' into '{selector}'"

    if selector:
        browser.click_element(selector)
        return f"Clicked '{selector}'"

    if text:
        browser.search(text)
        return f"Searched for '{text}'"

    # Last resort: try to extract from intent directly
    fallback_query = _extract_search_query(task, intent)
    if fallback_query:
        browser.search(fallback_query)
        return f"Searched for '{fallback_query}'"

    if "navigate" in task.lower() or "open" in task.lower() or "go to" in task.lower():
        for word in task.split():
            if "." in word and "/" not in word[:4]:
                target = word if word.startswith("http") else f"https://{word}"
                browser.navigate(target)
                return f"Navigated to {target}"

    return f"Web task handled: {task}"


web_agent_node = agent_wrapper("web", _execute)
