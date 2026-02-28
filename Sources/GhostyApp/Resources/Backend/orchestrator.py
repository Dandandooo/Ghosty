"""Ollama-powered task planner — decomposes user intent into executable steps."""

import json
import requests

OLLAMA_URL = "http://localhost:11434/api/generate"
DEFAULT_MODEL = "llama3.1:8b"

SYSTEM_PROMPT = """\
You are Ghosty, a macOS virtual assistant. You plan step-by-step actions as a JSON array.

Available actions:
- open_app(name): Launch a macOS application. Use real app names: "Safari", "Notes", "Finder", "Terminal", "System Settings". Google, YouTube, etc. are NOT apps — use open_url for websites.
- switch_to_app(name): Bring an already-running app to the foreground.
- open_url(url): Open a URL in the default browser. Use this for ANY website: google.com, youtube.com, etc.
- click_element(description): Click a UI element described visually (uses screen vision).
- type_text(text): Type text at the current cursor position.
- hotkey(keys): Press a keyboard shortcut, e.g. "command+t", "command+l", "command+space".
- key_press(key): Press a single key: "return", "tab", "escape", "delete".
- scroll(direction, amount): Scroll "up" or "down", amount 1-10.
- open_file(path): Open a file with its default application.
- applescript(script): Run an AppleScript command.
- wait(seconds): Pause for a duration (0.5-2 seconds). Use after opening apps or pages.
- done(message): Signal task completion. ALWAYS end with this.

IMPORTANT rules:
1. Google, YouTube, Twitter, Reddit, etc. are WEBSITES, not apps. Use open_url to visit them.
2. To search Google: open_url("https://www.google.com"), wait, click the search box, type the query, press return.
3. To search in Safari's URL bar: open Safari, use hotkey("command+l") to focus the URL bar, then type.
4. Always add wait(0.5-1) after open_app or open_url before interacting.
5. Always end with done(message).
6. Output ONLY a JSON array. No other text.

Example — "search for news on google":
[{"action":"open_url","params":{"url":"https://www.google.com"}},{"action":"wait","params":{"seconds":1.5}},{"action":"click_element","params":{"description":"the Google search box in the center of the page"}},{"action":"type_text","params":{"text":"news"}},{"action":"key_press","params":{"key":"return"}},{"action":"wait","params":{"seconds":1}},{"action":"done","params":{"message":"Searched for news on Google"}}]

Example — "open Safari and search for cats":
[{"action":"open_app","params":{"name":"Safari"}},{"action":"wait","params":{"seconds":1}},{"action":"hotkey","params":{"keys":"command+l"}},{"action":"wait","params":{"seconds":0.3}},{"action":"type_text","params":{"text":"cats"}},{"action":"key_press","params":{"key":"return"}},{"action":"wait","params":{"seconds":1}},{"action":"done","params":{"message":"Opened Safari and searched for cats"}}]

Example — "open Notes and type hello":
[{"action":"open_app","params":{"name":"Notes"}},{"action":"wait","params":{"seconds":1}},{"action":"hotkey","params":{"keys":"command+n"}},{"action":"wait","params":{"seconds":0.5}},{"action":"type_text","params":{"text":"hello"}},{"action":"done","params":{"message":"Opened Notes and typed hello"}}]
"""


def plan(intent, context=None, model=DEFAULT_MODEL):
    """Send user intent to Ollama and get back a list of action steps.

    Args:
        intent: The user's request in natural language.
        context: Optional dict with current system context
                 (frontmost_app, running_apps, etc.)
        model: Ollama model to use.

    Returns:
        List of action step dicts, each with "action" and "params".
    """
    user_message = f"User request: {intent}\n\nRespond with ONLY the complete JSON array including the done step at the end. No explanation."

    if context:
        ctx_parts = []
        if "frontmost_app" in context:
            ctx_parts.append(f"Currently focused app: {context['frontmost_app']}")
        if "running_apps" in context:
            ctx_parts.append(f"Running apps: {', '.join(context['running_apps'][:15])}")
        if ctx_parts:
            user_message = "\n".join(ctx_parts) + "\n\n" + user_message

    resp = requests.post(
        OLLAMA_URL,
        json={
            "model": model,
            "system": SYSTEM_PROMPT,
            "prompt": user_message,
            "stream": False,
            "options": {
                "temperature": 0.1,
                "num_predict": 1024,
            },
        },
        timeout=60,
    )
    resp.raise_for_status()

    raw = resp.json().get("response", "")
    return _parse_steps(raw)


def replan(
    intent,
    completed_steps,
    error,
    context=None,
    model=DEFAULT_MODEL,
):
    """Re-plan after a step failure.

    Args:
        intent: Original user intent.
        completed_steps: Steps already executed successfully.
        error: Error message from the failed step.
        context: Current system context.
        model: Ollama model to use.

    Returns:
        New list of remaining action steps.
    """
    user_message = (
        f"Original request: {intent}\n\n"
        f"Steps completed so far:\n{json.dumps(completed_steps, indent=2)}\n\n"
        f"The next step failed with error: {error}\n\n"
        "Please provide the remaining steps to complete the task, "
        "adjusting for the error. Output ONLY the JSON array."
    )

    if context:
        ctx_parts = []
        if "frontmost_app" in context:
            ctx_parts.append(f"Currently focused app: {context['frontmost_app']}")
        if ctx_parts:
            user_message = "\n".join(ctx_parts) + "\n\n" + user_message

    resp = requests.post(
        OLLAMA_URL,
        json={
            "model": model,
            "system": SYSTEM_PROMPT,
            "prompt": user_message,
            "stream": False,
            "options": {
                "temperature": 0.2,
                "num_predict": 1024,
            },
        },
        timeout=60,
    )
    resp.raise_for_status()

    raw = resp.json().get("response", "")
    return _parse_steps(raw)


def _parse_steps(raw):
    """Parse Ollama response into a list of step dicts."""
    raw = raw.strip()

    # Try parsing as a direct JSON array
    try:
        parsed = json.loads(raw)
        if isinstance(parsed, list):
            return parsed
        # Ollama "format": "json" sometimes wraps in an object
        if isinstance(parsed, dict):
            for key in ("steps", "actions", "plan"):
                if key in parsed and isinstance(parsed[key], list):
                    return parsed[key]
            # If it's a single step wrapped in an object
            if "action" in parsed:
                return [parsed]
    except json.JSONDecodeError:
        pass

    # Try to extract JSON array from the response text
    import re
    match = re.search(r"\[.*\]", raw, re.DOTALL)
    if match:
        try:
            return json.loads(match.group())
        except json.JSONDecodeError:
            pass

    # Fallback: return a done step with the raw response
    return [{"action": "done", "params": {"message": f"Could not plan: {raw[:200]}"}}]


if __name__ == "__main__":
    import sys

    intent = " ".join(sys.argv[1:]) or "open Safari"
    print(f"Planning for: {intent}")

    try:
        steps = plan(intent)
        print(json.dumps(steps, indent=2))
    except requests.ConnectionError:
        print("Error: Ollama is not running. Start it with: ollama serve")
    except Exception as e:
        print(f"Error: {e}")
