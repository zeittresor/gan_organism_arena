"""Check release metadata before packaging, without requiring Windows."""
from pathlib import Path
import re


def check(root: Path) -> None:
    verifier = (root / "tools/verify_package.ps1").read_text(encoding="utf-8-sig")
    version = re.search(r"\$ExpectedVersion = '([^']+)'", verifier)[1]
    date = re.search(r"\$ExpectedDate = '([^']+)'", verifier)[1]
    project = (root / "project.godot").read_text(encoding="utf-8-sig")
    actual = re.search(r'^config/version="([^"]+)"', project, re.MULTILINE)
    if actual is None or actual[1] != version:
        raise ValueError(f"project.godot version mismatch: expected {version}, found {actual[1] if actual else 'missing'}")
    for name in ("VERSION.txt", "install_windows.bat", "tools/install_godot.ps1", "tools/launch.ps1", "README.md"):
        if version not in (root / name).read_text(encoding="utf-8-sig"):
            raise ValueError(f"Current version {version} missing from {name}")
    if date not in (root / "VERSION.txt").read_text(encoding="utf-8-sig"):
        raise ValueError(f"Release date {date} missing from VERSION.txt")
    print(f"Release metadata OK: {version} ({date})")


if __name__ == "__main__":
    check(Path(__file__).resolve().parents[1])
