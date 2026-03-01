import modal

# Shared volume for Hugging Face cache
volume = modal.Volume.from_name("showui-model-cache", create_if_missing=True)

# Image with required dependencies for running Qwen2.5-VL and LangChain
image = (
    modal.Image.debian_slim(python_version="3.11")
    .pip_install(
        "torch",
        "torchvision",
        "transformers>=4.49.0", # Bumped for Qwen2.5
        "qwen-vl-utils",
        "accelerate",
        "pillow",
        "numpy",
        "langchain>=0.3.0",
        "langchain-huggingface>=0.1.0",
    )
)

app = modal.App("ghosty-orchestrator")

# Define tools
def execute_gui_action(instruction: str, image_bytes: bytes) -> str:
    """Invokes the ShowUI remote Modal app to click, type, or navigate the UI."""
    print(f"[Orchestrator] Calling ShowUI tool for: '{instruction}'")
    
    # Short-circuit: ShowUI is a vision model and can't handle keyboard actions.
    # Detect "press enter/return" instructions and return the action directly.
    lower_instr = instruction.lower().strip()
    if any(phrase in lower_instr for phrase in ["press enter", "press return", "hit enter", "hit return", "send the message"]):
        print("[Orchestrator] Keyboard action detected, bypassing ShowUI.")
        return "GUI Action executed. Result from vision model: {'action': 'ENTER', 'position': None}"
    
    # Short-circuit: For "type X" instructions, compose CLICK + INPUT directly.
    # ShowUI is unreliable at separating instructions from typed content.
    import re
    type_match = re.search(r"(?:type|input|enter|write|send)\s+['\"](.+?)['\"]", instruction, re.IGNORECASE)
    if type_match:
        text_to_type = type_match.group(1)
        print(f"[Orchestrator] INPUT short-circuit: will type '{text_to_type}' — using ShowUI only for click position.")
        # Still call ShowUI to find WHERE the input field is
        try:
            showui = modal.Cls.from_name("showui-service", "ShowUI")()
            click_prompt = (
                f"Click on the text input field or chat box where a message can be typed. "
                f"IGNORE the black box at the top center. The input field is at the BOTTOM (y > 0.8). "
                f"Respond with JSON: {{\"action\": \"CLICK\", \"position\": [x, y]}}"
            )
            click_result = showui.run_inference.remote(image_bytes=image_bytes, prompt=click_prompt)
            # Extract position from click result
            pos_match = re.search(r"\[(\d+\.?\d*),\s*(\d+\.?\d*)\]", click_result)
            if pos_match:
                x, y = float(pos_match.group(1)), float(pos_match.group(2))
                return (
                    f"GUI Action executed. Result from vision model: "
                    f"{{'action': 'CLICK', 'position': [{x}, {y}]}},"
                    f"{{'action': 'INPUT', 'value': '{text_to_type}', 'position': [{x}, {y}]}}"
                )
        except Exception as e:
            print(f"[Orchestrator] ShowUI click-for-INPUT failed: {e}")
        # Fallback: type at bottom-center
        return (
            f"GUI Action executed. Result from vision model: "
            f"{{'action': 'CLICK', 'position': [0.49, 0.94]}},"
            f"{{'action': 'INPUT', 'value': '{text_to_type}', 'position': [0.49, 0.94]}}"
        )

    # Dynamically lookup the ShowUI app we already built
    try:
        showui = modal.Cls.from_name("showui-service", "ShowUI")()
        # Minimal prompt — only ask for the action, keep instructions separate
        gui_prompt = (
            f"Based on this instruction: '{instruction}'\n"
            f"IGNORE any black box at the top center of the screen.\n"
            f"Chat input fields are at the BOTTOM (y > 0.8).\n"
            f"Respond with JSON. Allowed actions: CLICK, INPUT, ENTER.\n"
            f"CLICK: {{\"action\": \"CLICK\", \"position\": [x, y]}}\n"
            f"INPUT: {{\"action\": \"INPUT\", \"value\": \"text\", \"position\": [x, y]}}\n"
            f"ENTER: {{\"action\": \"ENTER\", \"position\": null}}"
        )
        
        result = showui.run_inference.remote(
            image_bytes=image_bytes, 
            prompt=gui_prompt
        )
        return f"GUI Action executed. Result from vision model: {result}"
    except Exception as e:
        return f"Error executing GUI action: {e}"

def hide_ghosty() -> str:
    """Outputs a specific command to tell the Ghosty app to retreat into the menu bar."""
    print("[Orchestrator] Calling Hide Tool")
    return "COMMAND_HIDE_GHOSTY"


@app.cls(gpu="L4", image=image, volumes={"/root/.cache/huggingface": volume}, timeout=600, min_containers=1)
class OrchestratorAgent:
    @modal.enter()
    def setup(self):
        import os
        from transformers import Qwen2_5_VLForConditionalGeneration, AutoProcessor
        import torch

        # Use the newer 2.5 7B model for stronger reasoning capabilities
        self.model_id = "Qwen/Qwen2.5-VL-7B-Instruct"
        print(f"Loading Orchestrator Model {self.model_id} in bfloat16...")
        
        self.model = Qwen2_5_VLForConditionalGeneration.from_pretrained(
            self.model_id,
            torch_dtype=torch.bfloat16,
            device_map="auto"
        )
        self.min_pixels = 256*28*28
        self.max_pixels = 1344*28*28
        self.processor = AutoProcessor.from_pretrained(
            self.model_id, 
            min_pixels=self.min_pixels, 
            max_pixels=self.max_pixels
        )
        print("Orchestrator loaded successfully.")

    @modal.method()
    def invoke(self, user_prompt: str, image_bytes: bytes = None) -> str:
        """
        Takes the user's raw prompt and the screenshot, uses the Qwen2-VL model directly 
        to reason about which tool to call, and returns the result.
        
        Note: True LangChain ReAct loops inside Modal with Vision models require complex 
        custom LLM wrappers parsing image interleaving. For the MVP, we use the model's 
        native JSON output capabilities as a lightweight functional orchestrator.
        """
        from PIL import Image
        from io import BytesIO
        from qwen_vl_utils import process_vision_info
        import json
        import torch

        user_content = []

        system_instructions = """You are Ghosty, a helpful MacOS assistant. 
Analyze the user's screen and request. 

CRITICAL SPATIAL AWARENESS:
1. **Ghosty Zone**: The top-center area `[x: 0.3 to 0.7, y: 0.0 to 0.6]` is your own UI. It has been BLACKED OUT in the screenshot. NEVER interact with anything in this black area.
2. **Chat Inputs**: In almost all Mac applications (Discord, iMessage, Slack), the text input field is at the BOTTOM of the window, typically at `y` coordinates greater than `0.8`.
3. **Sidebars**: Navigation lists are usually on the LEFT, typically at `x` coordinates less than `0.2`.

Your goal is to find the REAL application UI behind or around the black "Ghosty Zone".

Your prompt may contain an "ACTION HISTORY" section. Use this to:
1. Avoid repeating the same failed clicks or inputs.
2. Realize when a task is progressing or stalled.
3. If you see "Action refused", it means your target coordinate was inside the Ghosty panel. You MUST find the correct target in the background application instead (e.g., look lower on the screen for chat boxes).

Available Tools:
1. "gui_action": Use this to interact with the UI. 
   - Provide an instruction for the NEXT IMMEDIATE STEP only.
   - Do NOT use "SEND". In messenging apps, follow "Type '...' in the chat box" with "Press enter" in the NEXT turn.
2. "hide": Dismiss yourself.
3. "chat": Response to the user or summarize a completed task.

Rule: If you just typed text into a chat box in the previous turn (check ACTION HISTORY), and the intention is to send a message, your NEXT action should almost always be a "Press enter" gui_action.

You MUST respond in strict JSON format:
{
    "thought": "Explain your reasoning for this step, referencing previous actions or why you are avoiding the Ghosty Zone if applicable.",
    "tool": "gui_action" | "hide" | "chat",
    "tool_input": ["<specific instruction for this turn>"],
    "task_status": "working" | "completed"
}

Rule: Set `task_status` to "completed" ONLY when the user's request is fully finished. Otherwise, use "working".

Rule: `tool_input` MUST ALWAYS be a JSON array of strings, even if there is only one instruction.

Example 1:
User: "Tell my DIBZS group chat 67"
Response: {"thought": "The user wants to send a message. I can see the blacked out area in the center, so I will ignore it and look for the DIBZS chat in the sidebar on the left.", "tool": "gui_action", "tool_input": ["Click the DIBZS chat on the left side"], "task_status": "working"}

Example 2:
User: "Thanks, I'm done"
Response: {"tool": "hide", "tool_input": ["Listening..."], "task_status": "completed"}

Example 3:
User: "What does that error mean?"
Response: {"tool": "chat", "tool_input": ["That error means the network is disconnected..."], "task_status": "completed"}

Example 4 (Multi-turn):
Action History: ["- Turn: INPUT at Optional((0.5, 0.9)) with value '67'"]
User: "Tell my DIBZS group chat 67"
Response: {"thought": "I have already typed '67' into the chat box at the bottom. Now I need to press enter to send the message.", "tool": "gui_action", "tool_input": ["Press enter"], "task_status": "completed"}
"""
        
        if image_bytes:
            print(f"[Orchestrator] Loading image context ({len(image_bytes)} bytes)")
            img = Image.open(BytesIO(image_bytes))
            user_content.append({"type": "image", "image": img, "min_pixels": self.min_pixels, "max_pixels": self.max_pixels})
        
        user_content.append({"type": "text", "text": user_prompt})

        messages = [
            {"role": "system", "content": [{"type": "text", "text": system_instructions}]},
            {"role": "user", "content": user_content}
        ]

        text = self.processor.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)
        image_inputs, video_inputs = process_vision_info(messages)
        inputs = self.processor(
            text=[text], images=image_inputs, videos=video_inputs, padding=True, return_tensors="pt",
        ).to(self.model.device)

        print("[Orchestrator] Reasoning...")
        generated_ids = self.model.generate(**inputs, max_new_tokens=256, do_sample=False)
        generated_ids_trimmed = [out_ids[len(in_ids) :] for in_ids, out_ids in zip(inputs.input_ids, generated_ids)]
        output_text = self.processor.batch_decode(generated_ids_trimmed, skip_special_tokens=True)[0]
        print(f"[Orchestrator] Model Output: {output_text}")

        # Parse the JSON and route
        try:
            clean_json = output_text.strip()
            if clean_json.startswith("```json"):
                clean_json = clean_json[7:-3]
            elif clean_json.startswith("```"):
                clean_json = clean_json[3:-3]
                
            decision = json.loads(clean_json)
            status = decision.get("task_status", "working")
            thought = decision.get("thought", "")
            print(f"[Orchestrator] Thought: {thought} | Status: {status}")
            
            tool = decision.get("tool")
            tool_input = decision.get("tool_input", [])
            
            prefix = f"TASK_STATUS: {status}\nTHOUGHT: {thought}\n"
            
            if tool == "gui_action":
                results = []
                for step_instruction in tool_input:
                    step_result = execute_gui_action(step_instruction, image_bytes)
                    results.append(step_result)
                return prefix + "\n".join(results)
            elif tool == "hide":
                return prefix + hide_ghosty()
            elif tool == "chat":
                return prefix + "\n".join(tool_input)
            else:
                return prefix + f"I thought about doing '{tool}', but I don't know how to do that yet."
                
        except json.JSONDecodeError:
            print(f"[Orchestrator] Failed to parse JSON. Raw output: {output_text}")
            return f"TASK_STATUS: working\nTHOUGHT: Failed to parse model output.\n{output_text}"

@app.local_entrypoint()
def main():
    import os
    print("Testing Orchestrator routing...")
    orch = OrchestratorAgent()
    
    # Test a simple chat (no image)
    res = orch.invoke.remote("Hi Ghosty, are you there?")
    print(f"Test Result: {res}")
    os._exit(0)
