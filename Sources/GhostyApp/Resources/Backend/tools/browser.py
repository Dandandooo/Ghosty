"""Browser control — interact with the user's browser via AppleScript.

Auto-detects whichever browser is active (Chrome, Safari, Arc, Brave, Edge,
Firefox). Supports a preferred browser override from SuperMemory preferences.
"""

import sys
import time
import urllib.parse

from config import BROWSER_ORDER, CHROME_LIKE
from tools import applescript, screen


_active_browser = None
_preferred_browser = None


def set_preferred_browser(name: str):
    """Set the preferred browser (from user preferences/SuperMemory)."""
    global _preferred_browser, _active_browser
    _preferred_browser = name
    _active_browser = None  # reset detection so preferred takes effect


def _run_osascript(script: str, timeout: float = 10) -> str:
    """Execute an AppleScript and return stdout."""
    return applescript.run_applescript(script)


def _detect_browser() -> str:
    """Return the name of the browser to control."""
    global _active_browser
    if _active_browser is not None:
        return _active_browser

    # 0. User preference from SuperMemory
    if _preferred_browser:
        _active_browser = _preferred_browser
        print(f"[browser] Using preferred browser: {_active_browser}")
        return _active_browser

    known = set(BROWSER_ORDER)

    # 1. Frontmost app
    try:
        frontmost = applescript.get_frontmost_app()
        if frontmost in known:
            _active_browser = frontmost
            print(f"[browser] Using frontmost browser: {_active_browser}")
            return _active_browser
    except Exception:
        pass

    # 2. First running browser
    try:
        running = set(applescript.list_running_apps())
        for browser in BROWSER_ORDER:
            if browser in running:
                _active_browser = browser
                print(f"[browser] Using running browser: {_active_browser}")
                return _active_browser
    except Exception:
        pass

    # 3. Fallback
    _active_browser = "Safari"
    print("[browser] Defaulting to Safari")
    return _active_browser


def _ensure_browser():
    """Activate the detected browser and bring it to the front."""
    browser = _detect_browser()
    applescript.switch_to_app(browser)
    time.sleep(0.5)


def _do_javascript(js: str):
    """Run JavaScript in the active tab of the detected browser."""
    browser = _detect_browser()
    escaped = js.replace("\\", "\\\\").replace('"', '\\"')

    if browser in CHROME_LIKE:
        return applescript.run_applescript(
            f'tell application "{browser}" to '
            f'execute active tab of front window javascript "{escaped}"'
        )

    if browser == "Safari":
        return applescript.run_applescript(
            f'tell application "Safari" to do JavaScript "{escaped}" '
            f"in current tab of front window"
        )

    raise RuntimeError(f"{browser} does not support AppleScript JavaScript")


# ── public API ────────────────────────────────────────────────────────


def navigate(url: str):
    """Open a URL in the detected browser, reusing the front tab."""
    browser = _detect_browser()
    safe_url = url.replace('"', "")

    if browser in CHROME_LIKE:
        script = (
            f'tell application "{browser}"\n'
            f"  activate\n"
            f"  if (count of windows) = 0 then\n"
            f"    make new window\n"
            f'    set URL of active tab of front window to "{safe_url}"\n'
            f"  else\n"
            f'    set URL of active tab of front window to "{safe_url}"\n'
            f"  end if\n"
            f"end tell"
        )
    elif browser == "Safari":
        script = (
            f'tell application "Safari"\n'
            f"  activate\n"
            f"  if (count of windows) = 0 then\n"
            f'    make new document with properties {{URL:"{safe_url}"}}\n'
            f"  else\n"
            f'    set URL of current tab of front window to "{safe_url}"\n'
            f"  end if\n"
            f"end tell"
        )
    else:
        script = (
            f'tell application "{browser}"\n'
            f"  activate\n"
            f'  open location "{safe_url}"\n'
            f"end tell"
        )

    applescript.run_applescript(script)
    print(f"[browser] Navigated to {url} in {browser}")


def new_tab():
    """Open a new browser tab."""
    _ensure_browser()
    screen.hotkey("command", "t")
    time.sleep(0.3)
    print("[browser] Opened new tab")


def focus_url_bar():
    """Focus the URL/search bar."""
    _ensure_browser()
    screen.hotkey("command", "l")
    time.sleep(0.3)
    print("[browser] Focused URL bar")


def search(query: str):
    """Search via direct URL navigation (reliable from any context)."""
    encoded = urllib.parse.quote_plus(query)
    url = f"https://www.google.com/search?q={encoded}"
    navigate(url)
    print(f"[browser] Searched for: {query}")


def type_in_page(selector: str, text: str):
    """Type text into a browser element."""
    _ensure_browser()

    focused = False
    try:
        _do_javascript(f"document.querySelector('{selector}').focus()")
        time.sleep(0.2)
        focused = True
    except Exception:
        pass

    if not focused:
        if any(
            hint in selector.lower()
            for hint in ["search", "name='q'", 'name="q"', "query"]
        ):
            screen.hotkey("command", "l")
            time.sleep(0.3)

    screen.type_text(text)
    print(f"[browser] Typed into '{selector}'")


def click_element(selector: str):
    """Click a browser element via JavaScript."""
    _ensure_browser()
    try:
        _do_javascript(f"document.querySelector('{selector}').click()")
    except Exception as e:
        print(f"[browser] JS click failed for '{selector}': {e}", file=sys.stderr)
    print(f"[browser] Clicked '{selector}'")


def press_key(key: str):
    """Press a key in the browser."""
    _ensure_browser()
    screen.key_press(key.lower())
    print(f"[browser] Pressed '{key}'")


def scroll_page(direction: str = "down", amount: int = 500):
    """Scroll the browser page."""
    _ensure_browser()
    try:
        delta = amount if direction == "down" else -amount
        _do_javascript(f"window.scrollBy(0, {delta})")
    except Exception:
        clicks = 5 if direction == "up" else -5
        screen.scroll(clicks)
    print(f"[browser] Scrolled {direction} {amount}px")
