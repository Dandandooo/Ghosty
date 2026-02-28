"""ShowUI visual grounding — maps (screenshot, instruction) → (action, x, y).

Supports multiple backends:
  - LocalShowUIClient: runs ShowUI-2B locally via transformers
  - GradioShowUIClient: calls HuggingFace Spaces API (free fallback)
  - ModalShowUIClient: calls ShowUI deployed on Modal (stub for later)
"""

import io
import base64
from abc import ABC, abstractmethod

import screen_control


class ShowUIResult:
    """Result of a ShowUI grounding call."""

    def __init__(self, action: str, x: float, y: float, value: str = ""):
        self.action = action  # "click", "type", "scroll", etc.
        self.x = x            # normalized 0-1
        self.y = y            # normalized 0-1
        self.value = value    # optional text for "type" actions

    @property
    def absolute_coords(self):
        """Convert normalized coords to absolute PyAutoGUI coordinates."""
        return screen_control.normalized_to_absolute(self.x, self.y)

    def __repr__(self):
        return f"ShowUIResult(action={self.action!r}, x={self.x:.3f}, y={self.y:.3f}, value={self.value!r})"


class ShowUIClient(ABC):
    """Abstract base for ShowUI inference."""

    @abstractmethod
    def grounding(self, screenshot, instruction: str) -> ShowUIResult:
        """Given a screenshot (PIL.Image) and instruction, return grounding result."""
        ...


class LocalShowUIClient(ShowUIClient):
    """Runs ShowUI-2B locally via transformers + torch."""

    def __init__(self, model_name: str = "showlab/ShowUI-2B"):
        self._model_name = model_name
        self._model = None
        self._processor = None

    def _load(self):
        if self._model is not None:
            return
        import torch
        from transformers import Qwen2VLForConditionalGeneration, AutoProcessor

        self._model = Qwen2VLForConditionalGeneration.from_pretrained(
            self._model_name,
            torch_dtype=torch.bfloat16,
            device_map="auto",
        )
        self._processor = AutoProcessor.from_pretrained(self._model_name)

    def grounding(self, screenshot, instruction: str) -> ShowUIResult:
        self._load()
        import torch
        from qwen_vl_utils import process_vision_info

        messages = [
            {
                "role": "user",
                "content": [
                    {"type": "image", "image": screenshot},
                    {"type": "text", "text": instruction},
                ],
            }
        ]

        text_prompt = self._processor.apply_chat_template(
            messages, tokenize=False, add_generation_prompt=True,
        )
        image_inputs, video_inputs = process_vision_info(messages)
        inputs = self._processor(
            text=[text_prompt],
            images=image_inputs,
            videos=video_inputs,
            padding=True,
            return_tensors="pt",
        ).to(self._model.device)

        with torch.no_grad():
            output_ids = self._model.generate(**inputs, max_new_tokens=128)

        input_len = inputs.input_ids.shape[1]
        output_text = self._processor.decode(
            output_ids[0][input_len:], skip_special_tokens=True,
        ).strip()

        return self._parse_output(output_text)

    @staticmethod
    def _parse_output(text: str) -> ShowUIResult:
        """Parse ShowUI output like '[0.52, 0.34]' into a result."""
        import re
        coords = re.findall(r"[\d.]+", text)
        if len(coords) >= 2:
            x, y = float(coords[0]), float(coords[1])
            return ShowUIResult(action="click", x=x, y=y)
        return ShowUIResult(action="click", x=0.5, y=0.5)


class GradioShowUIClient(ShowUIClient):
    """Calls ShowUI via HuggingFace Spaces Gradio API (free fallback)."""

    def __init__(self, space_id: str = "showlab/ShowUI"):
        self._space_id = space_id

    def grounding(self, screenshot, instruction: str) -> ShowUIResult:
        from gradio_client import Client

        buf = io.BytesIO()
        screenshot.save(buf, format="PNG")
        buf.seek(0)

        import tempfile
        with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp:
            tmp.write(buf.getvalue())
            tmp_path = tmp.name

        client = Client(self._space_id)
        result = client.predict(
            tmp_path,
            instruction,
            api_name="/predict",
        )

        import os
        os.unlink(tmp_path)

        return self._parse_result(result)

    @staticmethod
    def _parse_result(result) -> ShowUIResult:
        """Parse Gradio result into ShowUIResult."""
        import re
        if isinstance(result, str):
            coords = re.findall(r"[\d.]+", result)
            if len(coords) >= 2:
                return ShowUIResult(
                    action="click",
                    x=float(coords[0]),
                    y=float(coords[1]),
                )
        return ShowUIResult(action="click", x=0.5, y=0.5)


class ModalShowUIClient(ShowUIClient):
    """Calls ShowUI deployed on Modal. Stub for future implementation."""

    def __init__(self, endpoint: str = ""):
        self._endpoint = endpoint

    def grounding(self, screenshot, instruction: str) -> ShowUIResult:
        if not self._endpoint:
            raise NotImplementedError(
                "ModalShowUIClient requires a deployed Modal endpoint. "
                "Set the endpoint URL when initializing."
            )

        import requests

        buf = io.BytesIO()
        screenshot.save(buf, format="PNG")
        img_b64 = base64.b64encode(buf.getvalue()).decode()

        resp = requests.post(
            self._endpoint,
            json={"image": img_b64, "instruction": instruction},
            timeout=30,
        )
        resp.raise_for_status()
        data = resp.json()

        return ShowUIResult(
            action=data.get("action", "click"),
            x=data.get("x", 0.5),
            y=data.get("y", 0.5),
            value=data.get("value", ""),
        )


def get_client(backend: str = "local", **kwargs) -> ShowUIClient:
    """Factory: create a ShowUI client by backend name."""
    if backend == "local":
        return LocalShowUIClient(**kwargs)
    elif backend == "gradio":
        return GradioShowUIClient(**kwargs)
    elif backend == "modal":
        return ModalShowUIClient(**kwargs)
    else:
        raise ValueError(f"Unknown ShowUI backend: {backend}")


if __name__ == "__main__":
    print("ShowUI client module loaded.")
    print("Available backends: local, gradio, modal")
    print("Use get_client('local') to create a local ShowUI client.")
