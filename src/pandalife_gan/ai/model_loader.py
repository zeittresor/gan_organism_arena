from __future__ import annotations

from pathlib import Path


class OptionalModelLoader:
    """Placeholder for future ONNX generator/critic integration.

    The app is intentionally usable without neural model files. This loader only
    reports availability and does not import onnxruntime unless a model exists.
    """

    def __init__(self, model_dir: Path):
        self.model_dir = model_dir
        self.generator_path = model_dir / "gan_generator.onnx"
        self.critic_path = model_dir / "gan_critic.onnx"

    @property
    def has_generator(self) -> bool:
        return self.generator_path.exists()

    @property
    def has_critic(self) -> bool:
        return self.critic_path.exists()

    def status_text(self) -> str:
        gen = "available" if self.has_generator else "not installed"
        cri = "available" if self.has_critic else "not installed"
        return f"ONNX generator: {gen}; ONNX critic: {cri}"
