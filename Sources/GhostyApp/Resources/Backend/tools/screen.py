"""Screen interaction — PyAutoGUI for mouse/screenshots, Quartz CGEvents for keyboard."""

import subprocess
import time

import pyautogui
import Quartz

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


# ── Keyboard via Quartz CGEvents ─────────────────────────────────────

def _cg_event_source():
    """Create a reusable CGEvent source."""
    return Quartz.CGEventSourceCreate(Quartz.kCGEventSourceStateHIDSystemState)


# macOS virtual key-codes for named keys.
_KEY_CODES = {
    "return": 36, "enter": 76, "tab": 48, "escape": 53,
    "delete": 51, "backspace": 51, "forwarddelete": 117,
    "space": 49, "up": 126, "down": 125, "left": 123, "right": 124,
    "home": 115, "end": 119, "pageup": 116, "pagedown": 121,
    "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97,
    "f7": 98, "f8": 100, "f9": 101, "f10": 109, "f11": 103, "f12": 111,
}

# Single-character to virtual key-code mapping (US keyboard layout).
_CHAR_CODES = {
    "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5, "h": 4,
    "i": 34, "j": 38, "k": 40, "l": 37, "m": 46, "n": 45, "o": 31,
    "p": 35, "q": 12, "r": 15, "s": 1, "t": 17, "u": 32, "v": 9,
    "w": 13, "x": 7, "y": 16, "z": 6,
    "0": 29, "1": 18, "2": 19, "3": 20, "4": 21, "5": 23,
    "6": 22, "7": 26, "8": 28, "9": 25,
    " ": 49, "-": 27, "=": 24, "[": 33, "]": 30, "\\": 42,
    ";": 41, "'": 39, ",": 43, ".": 47, "/": 44, "`": 50,
}

# Modifier name → CGEvent flag mask.
_MODIFIER_FLAGS = {
    "command": Quartz.kCGEventFlagMaskCommand,
    "cmd": Quartz.kCGEventFlagMaskCommand,
    "shift": Quartz.kCGEventFlagMaskShift,
    "option": Quartz.kCGEventFlagMaskAlternate,
    "alt": Quartz.kCGEventFlagMaskAlternate,
    "control": Quartz.kCGEventFlagMaskControl,
    "ctrl": Quartz.kCGEventFlagMaskControl,
}


def _post_key(keycode: int, flags: int = 0):
    """Post a single key-down + key-up event via CGEvent."""
    src = _cg_event_source()
    for key_down in (True, False):
        evt = Quartz.CGEventCreateKeyboardEvent(src, keycode, key_down)
        if flags:
            Quartz.CGEventSetFlags(evt, flags)
        Quartz.CGEventPost(Quartz.kCGHIDEventTap, evt)
    time.sleep(0.02)


def _post_unicode_char(char: str, flags: int = 0):
    """Post a single Unicode character using CGEventKeyboardSetUnicodeString."""
    src = _cg_event_source()
    for key_down in (True, False):
        evt = Quartz.CGEventCreateKeyboardEvent(src, 0, key_down)
        if flags:
            Quartz.CGEventSetFlags(evt, flags)
        Quartz.CGEventKeyboardSetUnicodeString(evt, len(char), char)
        Quartz.CGEventPost(Quartz.kCGHIDEventTap, evt)
    time.sleep(0.02)


def type_text(text: str, interval: float = 0.03):
    """Type a string by posting CGEvent keyboard events for each character."""
    for char in text:
        low = char.lower()
        if low in _CHAR_CODES:
            flags = Quartz.kCGEventFlagMaskShift if char != low and char.isalpha() else 0
            _post_key(_CHAR_CODES[low], flags)
        elif char in _KEY_CODES:
            _post_key(_KEY_CODES[char])
        else:
            _post_unicode_char(char)
        time.sleep(interval)


def hotkey(*keys: str):
    """Press a key combination, e.g. hotkey('command', 'l')."""
    flags = 0
    target_key = None

    for k in keys:
        low = k.lower().strip()
        if low in _MODIFIER_FLAGS:
            flags |= _MODIFIER_FLAGS[low]
        else:
            target_key = low

    if target_key is None:
        return

    if target_key in _KEY_CODES:
        keycode = _KEY_CODES[target_key]
    elif target_key in _CHAR_CODES:
        keycode = _CHAR_CODES[target_key]
    else:
        _post_unicode_char(target_key, flags)
        return

    _post_key(keycode, flags)


def key_press(key: str):
    """Press and release a single key."""
    low = key.lower().strip()
    if low in _KEY_CODES:
        _post_key(_KEY_CODES[low])
    elif low in _CHAR_CODES:
        _post_key(_CHAR_CODES[low])
    else:
        _post_unicode_char(low)


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
