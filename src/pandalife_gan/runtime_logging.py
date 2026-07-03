from __future__ import annotations

import faulthandler
import logging
import os
import sys
import time
import traceback
from pathlib import Path


class TeeStream:
    """Small stream wrapper that mirrors stdout/stderr into a log file."""

    def __init__(self, original, log_file):
        self.original = original
        self.log_file = log_file

    def write(self, data: str) -> int:
        try:
            self.original.write(data)
            self.original.flush()
        except Exception:
            pass
        try:
            self.log_file.write(data)
            self.log_file.flush()
        except Exception:
            pass
        return len(data)

    def flush(self) -> None:
        try:
            self.original.flush()
        except Exception:
            pass
        try:
            self.log_file.flush()
        except Exception:
            pass

    def isatty(self) -> bool:
        return False


_runtime_log_handle = None


def make_log_dir(path: str | os.PathLike[str] = "logs") -> Path:
    log_dir = Path(path).resolve()
    log_dir.mkdir(parents=True, exist_ok=True)
    return log_dir


def setup_runtime_logging(log_dir: str | os.PathLike[str] = "logs", *, console_tee: bool = True) -> Path:
    """Initialise runtime logging early and return the active log path.

    This catches normal Python exceptions, Panda3D notify output configured by the caller,
    stdout/stderr, and faulthandler dumps for hard crashes where Python still gets a chance
    to flush a traceback.
    """
    global _runtime_log_handle
    log_root = make_log_dir(log_dir)
    stamp = time.strftime("%Y%m%d_%H%M%S")
    log_path = log_root / f"runtime_{stamp}.log"
    latest_path = log_root / "latest_runtime.log"
    try:
        latest_path.write_text("", encoding="utf-8")
    except Exception:
        pass

    _runtime_log_handle = open(log_path, "a", encoding="utf-8", buffering=1)
    _latest_log_handle = logging.FileHandler(latest_path, encoding="utf-8", mode="a")

    logging.basicConfig(
        level=logging.DEBUG,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        handlers=[
            logging.FileHandler(log_path, encoding="utf-8"),
            _latest_log_handle,
            logging.StreamHandler(sys.__stdout__),
        ],
        force=True,
    )

    if console_tee:
        sys.stdout = TeeStream(sys.__stdout__, _runtime_log_handle)  # type: ignore[assignment]
        sys.stderr = TeeStream(sys.__stderr__, _runtime_log_handle)  # type: ignore[assignment]

    try:
        faulthandler.enable(_runtime_log_handle)
    except Exception:
        logging.getLogger(__name__).exception("Could not enable faulthandler")

    def _excepthook(exc_type, exc, tb):
        logging.critical("Uncaught exception", exc_info=(exc_type, exc, tb))
        traceback.print_exception(exc_type, exc, tb, file=_runtime_log_handle)
        _runtime_log_handle.flush()
        sys.__excepthook__(exc_type, exc, tb)

    sys.excepthook = _excepthook

    logging.info("Runtime log initialised: %s", log_path)
    logging.info("Latest runtime log mirror: %s", latest_path)
    logging.info("Python: %s", sys.version.replace("\n", " "))
    logging.info("Executable: %s", sys.executable)
    logging.info("Working directory: %s", Path.cwd())
    return log_path


def flush_runtime_logging() -> None:
    logging.shutdown()
    if _runtime_log_handle is not None:
        try:
            _runtime_log_handle.flush()
        except Exception:
            pass
