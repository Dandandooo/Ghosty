"""macOS automation via AppleScript and CLI commands."""

import subprocess


def _run_osascript(script: str, timeout: float = 10) -> str:
    """Execute an AppleScript and return stdout."""
    result = subprocess.run(
        ["osascript", "-e", script],
        capture_output=True, text=True, timeout=timeout,
    )
    if result.returncode != 0:
        raise RuntimeError(f"AppleScript failed: {result.stderr.strip()}")
    return result.stdout.strip()


def open_app(name: str):
    """Open (or activate) an application by name."""
    subprocess.run(["open", "-a", name], check=True, timeout=10)


def switch_to_app(name: str):
    """Bring an application to the foreground."""
    _run_osascript(f'tell application "{name}" to activate')


def list_running_apps() -> list[str]:
    """Return names of all running applications."""
    script = (
        'tell application "System Events" to get name of '
        "every application process whose background only is false"
    )
    raw = _run_osascript(script)
    if not raw:
        return []
    return [a.strip() for a in raw.split(",")]


def get_frontmost_app() -> str:
    """Return the name of the frontmost application."""
    script = (
        'tell application "System Events" to get name of '
        "first application process whose frontmost is true"
    )
    return _run_osascript(script)


def run_applescript(script: str) -> str:
    """Execute an arbitrary AppleScript string."""
    return _run_osascript(script)


def open_url(url: str):
    """Open a URL in the default browser."""
    subprocess.run(["open", url], check=True, timeout=10)


def open_file(path: str):
    """Open a file with its default application."""
    subprocess.run(["open", path], check=True, timeout=10)


def set_volume(level: int):
    """Set system volume (0-100)."""
    clamped = max(0, min(100, level))
    _run_osascript(f"set volume output volume {clamped}")


def toggle_dark_mode():
    """Toggle macOS dark mode."""
    script = (
        'tell application "System Events" to tell appearance preferences '
        "to set dark mode to not dark mode"
    )
    _run_osascript(script)
