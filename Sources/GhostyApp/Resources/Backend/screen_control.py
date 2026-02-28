"""Screen interaction via PyAutoGUI — screenshot, click, type, hotkey, scroll."""

import subprocess
import pyautogui

pyautogui.FAILSAFE = True
pyautogui.PAUSE = 0.05


def _retina_scale() -> int:
    """Return the Retina scale factor for the main display (1 or 2)."""
    try:
        out = subprocess.check_output(
            ["system_profiler", "SPDisplaysDataType"],
            text=True, timeout=5,
        )
        if "Retina" in out:
            return 2
    except Exception:
        pass
    return 1


SCALE = _retina_scale()


def screenshot():
    """Capture the current screen and return a PIL.Image."""
    return pyautogui.screenshot()


def click(x: int, y: int, button: str = "left"):
    """Click at absolute coordinates (in PyAutoGUI space)."""
    pyautogui.click(x, y, button=button)


def double_click(x: int, y: int):
    """Double-click at absolute coordinates."""
    pyautogui.doubleClick(x, y)


def right_click(x: int, y: int):
    """Right-click at absolute coordinates."""
    pyautogui.rightClick(x, y)


def type_text(text: str, interval: float = 0.02):
    """Type a string character by character."""
    pyautogui.write(text, interval=interval)


def hotkey(*keys: str):
    """Press a key combination, e.g. hotkey('command', 't')."""
    pyautogui.hotkey(*keys)


def key_press(key: str):
    """Press and release a single key."""
    pyautogui.press(key)


def scroll(clicks, x=None, y=None):
    """Scroll vertically. Positive = up, negative = down."""
    pyautogui.scroll(clicks, x=x, y=y)


def mouse_move(x: int, y: int, duration: float = 0.25):
    """Move the cursor to absolute coordinates."""
    pyautogui.moveTo(x, y, duration=duration)


def screen_size():
    """Return (width, height) of the screen in PyAutoGUI coordinates."""
    return pyautogui.size()


def pixel_to_pyautogui(px, py):
    """Convert raw pixel coordinates to PyAutoGUI coordinates (Retina-aware)."""
    return px // SCALE, py // SCALE


def normalized_to_absolute(nx, ny):
    """Convert 0-1 normalized coords to absolute PyAutoGUI coordinates."""
    w, h = screen_size()
    return int(nx * w), int(ny * h)


if __name__ == "__main__":
    print(f"Screen size: {screen_size()}")
    print(f"Retina scale: {SCALE}")
    img = screenshot()
    img.save("/tmp/ghosty_screenshot.png")
    print("Screenshot saved to /tmp/ghosty_screenshot.png")
