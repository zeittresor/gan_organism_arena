from __future__ import annotations

import json
import logging
from pathlib import Path
from typing import Any

LOG = logging.getLogger(__name__)

SUPPORTED_LANGUAGES: list[tuple[str, str]] = [
    ("en", "English"),
    ("de", "Deutsch"),
    ("fr", "Francais"),
]


def normalize_language(code: str | None) -> str:
    value = (code or "en").strip().lower().replace("_", "-")
    if value.startswith("de"):
        return "de"
    if value.startswith("fr"):
        return "fr"
    return "en"


class Localizer:
    """Small JSON-backed UI localizer.

    Language files live in the project-level ``language`` folder so users can add
    or edit translations without touching Python code. Missing keys fall back to
    English and finally to the key name itself.
    """

    def __init__(self, language_dir: Path | str = "language", language: str = "en"):
        self.language_dir = Path(language_dir)
        self.language = normalize_language(language)
        self._english = self._load_file("en")
        self._data = self._english if self.language == "en" else self._load_file(self.language)

    def set_language(self, language: str) -> None:
        self.language = normalize_language(language)
        self._data = self._english if self.language == "en" else self._load_file(self.language)

    def _load_file(self, code: str) -> dict[str, Any]:
        path = self.language_dir / f"{normalize_language(code)}.json"
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            return data if isinstance(data, dict) else {}
        except Exception:
            LOG.warning("Could not load language file: %s", path, exc_info=True)
            return {}

    def _lookup(self, data: dict[str, Any], key: str) -> Any:
        current: Any = data
        for part in key.split("."):
            if not isinstance(current, dict) or part not in current:
                return None
            current = current[part]
        return current

    def text(self, key: str, **kwargs: Any) -> str:
        value = self._lookup(self._data, key)
        if value is None:
            value = self._lookup(self._english, key)
        if value is None:
            value = key
        if isinstance(value, list):
            value = "\n".join(str(item) for item in value)
        else:
            value = str(value)
        if kwargs:
            try:
                return value.format(**kwargs)
            except Exception:
                LOG.debug("Could not format translation key %s with %s", key, kwargs, exc_info=True)
        return value

    def lines(self, key: str) -> list[str]:
        value = self._lookup(self._data, key)
        if value is None:
            value = self._lookup(self._english, key)
        if isinstance(value, list):
            return [str(item) for item in value]
        if isinstance(value, str):
            return value.splitlines()
        return [key]
