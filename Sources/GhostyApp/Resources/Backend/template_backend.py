#!/usr/bin/env python3
import sys


def generate_response(text: str) -> str:
    normalized = (text or "").strip()
    if not normalized:
        return "Template response: I received an empty input.\n[[image:skibidi.png]]"
    return '\n'.join([
        f'Template response: I received "{normalized}" from Swift.',
        "[[image:skibidi.png]]"
    ])


def main() -> int:
    text = " ".join(sys.argv[1:]).strip()
    print(generate_response(text))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
