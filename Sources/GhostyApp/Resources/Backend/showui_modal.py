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

app = modal.App("showui-service")

@app.cls(gpu="any", image=image, timeout=600)
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
        print(f"Loading model {self.model_id} with 4-bit quantization...")
        
        # Official Recommended Quantization
        nf4_config = BitsAndBytesConfig(
           load_in_4bit=True,
           bnb_4bit_quant_type="nf4",
           bnb_4bit_use_double_quant=True,
           bnb_4bit_compute_dtype=torch.bfloat16
        )
        
        self.model = Qwen2VLForConditionalGeneration.from_pretrained(
            self.model_id,
            torch_dtype=torch.bfloat16,
            device_map="auto",
            quantization_config=nf4_config
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
        messages = []
        if system_prompt:
            messages.append({"role": "system", "content": [{"type": "text", "text": system_prompt}]})
            
        messages.append({
            "role": "user",
            "content": [
                {"type": "image", "image": img, "min_pixels": self.min_pixels, "max_pixels": self.max_pixels},
                {"type": "text", "text": prompt},
            ],
        })

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
            max_new_tokens=128,
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
