#!/usr/bin/env python3
import sys
import os
import modal

# Setup Modal ShowUI client
def get_showui_client():
    try:
        # Look up the deployed class (Modal 1.3.4+ syntax)
        return modal.Cls.from_name("showui-service", "ShowUI")()
    except Exception as e:
        print(f"DEBUG: Failed to lookup Modal service: {e}", file=sys.stderr)
        return None

def get_screenshot():
    import tempfile
    tmp_dir = tempfile.gettempdir()
    screenshot_path = os.path.join(tmp_dir, "ghosty_screen.png")
    # Using macOS screencapture utility
    os.system(f"screencapture -x {screenshot_path}")
    
    with open(screenshot_path, "rb") as f:
        return f.read()

def generate_response(text: str) -> str:
    normalized = (text or "").strip()
    if not normalized:
        return "Ghosty: I didn't catch that. What should I do on the screen?"
    
    print(f"DEBUG: Processing intent: {normalized}", file=sys.stderr)
    
    # 1. Capture screen
    try:
        print("DEBUG: Capturing screenshot...", file=sys.stderr, flush=True)
        image_bytes = get_screenshot()
        print(f"DEBUG: Captured {len(image_bytes)} bytes", file=sys.stderr, flush=True)
    except Exception as e:
        return f"Error capturing screen: {str(e)}"

    # 2. Call Modal Service
    try:
        print("DEBUG: Connecting to Modal...", file=sys.stderr, flush=True)
        showui = get_showui_client()
        if not showui:
            return "Error: Could not connect to Modal ShowUI service."
        
        # --- Official Propts from ShowUI Docs ---
        _NAV_SYSTEM = """You are an assistant trained to navigate the web screen. 
Given a task instruction, a screen observation, and an action history sequence, 
output the next action and wait for the next observation. 
Here is the action space:
1. `CLICK`: Click on an element, value is not applicable and the position [x,y] is required. 
2. `INPUT`: Type a string into an element, value is a string to type and the position [x,y] is required. 
3. `SELECT`: Select a value for an element, value is not applicable and the position [x,y] is required. 
4. `HOVER`: Hover on an element, value is not applicable and the position [x,y] is required.
5. `ANSWER`: Answer the question, value is the answer and the position is not applicable.
6. `ENTER`: Enter operation, value and position are not applicable.
7. `SCROLL`: Scroll the screen, value is the direction to scroll and the position is not applicable.
8. `SELECT_TEXT`: Select some text content, value is not applicable and position [[x1,y1], [x2,y2]] is the start and end position of the select operation.
9. `COPY`: Copy the text, value is the text to copy and the position is not applicable.
"""

        _NAV_FORMAT = """
Format the action as a dictionary with the following keys:
{'action': 'ACTION_TYPE', 'value': 'element', 'position': [x,y]}

If value or position is not applicable, set it as `None`.
Position might be [[x1,y1], [x2,y2]] if the action requires a start and end position.
Position represents the relative coordinates on the screenshot and should be scaled to a range of 0-1.
"""
        sys_prompt = _NAV_SYSTEM + _NAV_FORMAT
        
        # Official prompt format: Task: {query}
        full_prompt = f"Task: {normalized}"
        
        print(f"DEBUG: Calling Modal remote inference with prompt: {full_prompt}", file=sys.stderr, flush=True)
        result = showui.run_inference.remote(
            image_bytes=image_bytes, 
            prompt=full_prompt, 
            system_prompt=sys_prompt
        )
        print("DEBUG: Received result from Modal", file=sys.stderr, flush=True)
        
        return result
    except Exception as e:
        return f"Error calling ShowUI: {str(e)}"

def main() -> int:
    text = " ".join(sys.argv[1:]).strip()
    # GhostyApp expects the response on stdout
    print(generate_response(text))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
