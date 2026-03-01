import modal
# if you run ./Sources/GhostyApp/Resources/Backend/.venv/bin/python3 Sources/GhostyApp/Resources/Backend/template_backend.py "Click the Login button"
# it will run the showui on modal. Did not test integration yet bc I am on Sonoma 14.5

# Define the image with all necessary dependencies
# ShowUI-2B is based on Qwen2-VL, so it needs qwen-vl-utils and transformers
image = (
    modal.Image.debian_slim(python_version="3.11")
    .pip_install(
        "torch",
        "torchvision",
        "transformers>=4.45.0",
        "qwen-vl-utils",
        "accelerate",
        "pillow",
        "numpy",
        "bitsandbytes>=0.46.1",
    )
)

# Create a persistent volume for the Hugging Face cache
volume = modal.Volume.from_name("showui-model-cache", create_if_missing=True)

app = modal.App("showui-service")

@app.cls(gpu="L4", image=image, volumes={"/root/.cache/huggingface": volume}, timeout=600, min_containers=1)
class ShowUI:
    @modal.enter()
    def load_model(self):
        import os
        # Disable telemetry and symlinks to reduce background threads and file issues
        os.environ["HF_HUB_DISABLE_TELEMETRY"] = "1"
        os.environ["HF_HUB_OFFLINE"] = "0"
        
        from transformers import Qwen2VLForConditionalGeneration, AutoProcessor, BitsAndBytesConfig
        import torch

        self.model_id = "showlab/ShowUI-2B"
        print(f"Loading model {self.model_id} in native bfloat16 (no quantization for faster startup)...")
        
        self.model = Qwen2VLForConditionalGeneration.from_pretrained(
            self.model_id,
            torch_dtype=torch.bfloat16,
            device_map="auto"
        )
        
        # Official pixel constraints
        self.min_pixels = 256*28*28
        self.max_pixels = 1344*28*28
        
        self.processor = AutoProcessor.from_pretrained(
            self.model_id, 
            min_pixels=self.min_pixels, 
            max_pixels=self.max_pixels
        )
        print("Model loaded successfully.")

    @modal.method()
    def run_inference(self, image_url: str = None, image_bytes: bytes = None, prompt: str = "", system_prompt: str = ""):
        print("[DEBUG] Inference request received")
        from PIL import Image
        from io import BytesIO
        from qwen_vl_utils import process_vision_info
        import requests
        import torch
        
        # 1. Fetch/Load Image
        if image_bytes:
            print(f"[DEBUG] Loading image from bytes ({len(image_bytes)} bytes)")
            img = Image.open(BytesIO(image_bytes))
        elif image_url:
            print(f"[DEBUG] Fetching image from URL: {image_url}")
            headers = {'User-Agent': 'Mozilla/5.0'}
            response = requests.get(image_url, headers=headers)
            response.raise_for_status()
            img = Image.open(BytesIO(response.content))
        else:
            raise ValueError("Either image_url or image_bytes must be provided.")
        
        print(f"[DEBUG] Image loaded. Size: {img.size}")

        # 2. Prepare Messages
        # Integrate official ShowUI _NAV_SYSTEM and action_map
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
        
        full_system_prompt = _NAV_SYSTEM + _NAV_FORMAT
        
        messages = [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": full_system_prompt},
                    {"type": "text", "text": f'Task: {prompt}'},
                    {"type": "image", "image": img, "min_pixels": self.min_pixels, "max_pixels": self.max_pixels},
                ]
            }
        ]

        # 3. Process and Generate

        print("[DEBUG] Applying chat template...")
        text = self.processor.apply_chat_template(
            messages, tokenize=False, add_generation_prompt=True
        )
        image_inputs, video_inputs = process_vision_info(messages)
        inputs = self.processor(
            text=[text],
            images=image_inputs,
            videos=video_inputs,
            padding=True,
            return_tensors="pt",
        )
        inputs = inputs.to(self.model.device)

        print("[DEBUG] Generating tokens...")
        generated_ids = self.model.generate(
            **inputs, 
            max_new_tokens=512,
            do_sample=False,
            num_beams=1,
        )

        # 4. Decode Result
        print("[DEBUG] Decoding output...")
        generated_ids_trimmed = [
            out_ids[len(in_ids) :] for in_ids, out_ids in zip(inputs.input_ids, generated_ids)
        ]
        output_text = self.processor.batch_decode(
            generated_ids_trimmed, skip_special_tokens=True, clean_up_tokenization_spaces=False
        )
        
        print(f"[DEBUG] Result: {output_text[0]}")
        return output_text[0]

@app.local_entrypoint()
def main():
    import os
    # Use a standard screenshot for action testing
    test_image = "https://huggingface.co/showlab/ShowUI-2B/resolve/main/examples/web_dbd7514b-9ca3-40cd-b09a-990f7b955da1.png"
    
    showui = ShowUI()
    
    # ShowUI-2B action prediction prompts
    # We want to see if it returns a dictionary string or just coordinates
    action_prompts = [
        "Click the search icon.",
        "Type 'Modal' in the search bar.",
        "Scroll down the page."
    ]
    
    # System prompt for action prediction
    sys_prompt = "You are a GUI agent. Respond with the action to take in JSON format: {'action': '...', 'value': '...', 'position': [x, y]}"

    for i, p in enumerate(action_prompts):
        print(f"\n=== ACTION TEST {i+1}: {p} ===")
        res = showui.run_inference.remote(image_url=test_image, prompt=p, system_prompt=sys_prompt)
        print(f"Result {i+1}: {res}")
    
    print("\nForcing exit to prevent shutdown delay...")
    os._exit(0)
