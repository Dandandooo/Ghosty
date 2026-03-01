#!/usr/bin/env python3
import sys
import os
import modal

# Setup Modal Orchestrator client
def get_orchestrator_client():
    try:
        # Look up the newly deployed Orchestrator class
        return modal.Cls.from_name("ghosty-orchestrator", "OrchestratorAgent")()
    except Exception as e:
        print(f"DEBUG: Failed to lookup Orchestrator service: {e}", file=sys.stderr)
        return None

def get_screenshot():
    import tempfile
    from datetime import datetime
    
    # 1. Ensure screenshot directory exists
    screenshot_dir = os.path.expanduser("~/Ghosty/screenshots")
    if not os.path.exists(screenshot_dir):
        os.makedirs(screenshot_dir, exist_ok=True)
    
    # 2. Generate timestamped filename
    timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    permanent_path = os.path.join(screenshot_dir, f"ghosty_{timestamp}.png")
    
    # 3. Capture screen using macOS screencapture utility
    # -x: disable sound
    os.system(f"screencapture -x {permanent_path}")
    print(f"DEBUG: Screenshot saved to {permanent_path}", file=sys.stderr, flush=True)
    
    # 4. Mask the "Ghosty Zone" (top center) using Pillow
    from PIL import Image, ImageDraw
    try:
        with Image.open(permanent_path) as img:
            width, height = img.size
            draw = ImageDraw.Draw(img)
            
            # Define Ghosty Zone: [0.3 to 0.7, 0.0 to 0.6]
            # We use a black rectangle to "cut out" the Ghosty UI
            left = int(0.3 * width)
            top = 0
            right = int(0.7 * width)
            bottom = int(0.6 * height)
            
            draw.rectangle([left, top, right, bottom], fill="black")
            
            # Save the masked image back to a buffer or the file
            img.save(permanent_path)
            print(f"DEBUG: Masked Ghosty Zone in {permanent_path}", file=sys.stderr, flush=True)
            
            import io
            img_byte_arr = io.BytesIO()
            img.save(img_byte_arr, format='PNG')
            return img_byte_arr.getvalue()
    except Exception as e:
        print(f"DEBUG: Masking failed: {e}", file=sys.stderr)
        with open(permanent_path, "rb") as f:
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

    # 2. Call Modal Orchestrator
    try:
        print("DEBUG: Connecting to Modal Orchestrator...", file=sys.stderr, flush=True)
        orch = get_orchestrator_client()
        if not orch:
            return "Error: Could not connect to Modal Orchestrator service."
        
        print(f"DEBUG: Calling Orchestrator remote inference with prompt: {normalized}", file=sys.stderr, flush=True)
        result = orch.invoke.remote(
            user_prompt=normalized,
            image_bytes=image_bytes
        )
        print(f"DEBUG: Received result from Orchestrator: {result}", file=sys.stderr, flush=True)
        return result
    except Exception as e:
        return f"Error calling Orchestrator: {str(e)}"

def main() -> int:
    text = " ".join(sys.argv[1:]).strip()
    # GhostyApp expects the response on stdout
    print(generate_response(text))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
