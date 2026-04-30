"""Strip Claude Code JSONL transcripts down to dialog substance.

Drops tool calls and tool results — keeps only user messages, assistant text,
and assistant thinking. Reduces 10 MB session bundles to ~700 KB so a sonnet
extraction agent can read them within budget.

Usage::

    python scripts/filter_transcript.py <out_path> <jsonl1> [<jsonl2> ...]

Writes UTF-8 to ``out_path``. ``out_path`` can be ``-`` to write to stdout.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path


def extract(jsonl_path: Path) -> str:
    out = [f"=== TRANSCRIPT: {jsonl_path.name} ==="]
    for line in jsonl_path.read_text(encoding="utf-8", errors="replace").splitlines():
        if not line.strip():
            continue
        try:
            d = json.loads(line)
        except json.JSONDecodeError:
            continue
        msg = d.get("message")
        if not isinstance(msg, dict):
            continue
        role = msg.get("role")
        content = msg.get("content")
        if role == "user":
            if isinstance(content, str):
                if content.strip() and not content.startswith("<command-name>"):
                    out.append(f"\n[USER]\n{content.strip()}")
            elif isinstance(content, list):
                for block in content:
                    if isinstance(block, dict) and block.get("type") == "text":
                        text = block.get("text", "").strip()
                        if text and not text.startswith("<system-reminder>"):
                            out.append(f"\n[USER]\n{text}")
        elif role == "assistant":
            if isinstance(content, list):
                for block in content:
                    if not isinstance(block, dict):
                        continue
                    if block.get("type") == "text":
                        text = block.get("text", "").strip()
                        if text:
                            out.append(f"\n[ASSISTANT]\n{text}")
                    elif block.get("type") == "thinking":
                        text = block.get("thinking", "").strip()
                        if text:
                            out.append(f"\n[ASSISTANT THINKING]\n{text}")
    return "\n".join(out)


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print(__doc__, file=sys.stderr)
        return 2
    out_arg = argv[1]
    inputs = [Path(p) for p in argv[2:]]
    parts = [extract(p) for p in inputs if p.is_file()]
    payload = "\n\n".join(parts)
    if out_arg == "-":
        sys.stdout.write(payload)
    else:
        Path(out_arg).write_text(payload, encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
