#!/usr/bin/env python3
"""Keep the developer connection token outside Xcode's removable build outputs."""
import uuid
from pathlib import Path


def prepare_token(root: Path) -> None:
    token = root / '.local/bridge-token.txt'
    token.parent.mkdir(parents=True, exist_ok=True)
    if not token.exists():
        token.write_text(str(uuid.uuid4()) + '\n')
    if not token.read_text().strip():
        raise ValueError('Existing local connection token is empty')
    token.chmod(0o600)


if __name__ == '__main__':
    prepare_token(Path(__file__).resolve().parents[1])
