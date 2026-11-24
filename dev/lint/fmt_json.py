#!/usr/bin/env python3
"""Formats golden JSON files: two-space indent, one key per line, lists of
scalars on one line. Usage: fmt_json.py [--check] FILE..."""
import json
import sys


def fmt(v, ind=0):
    pad = "  " * (ind + 1)
    if isinstance(v, dict):
        if not v:
            return "{}"
        items = [f"{pad}{json.dumps(k)}: {fmt(x, ind + 1)}" for k, x in v.items()]
        return "{\n" + ",\n".join(items) + "\n" + "  " * ind + "}"
    if isinstance(v, list):
        if all(not isinstance(x, (dict, list)) for x in v):
            return "[" + ", ".join(json.dumps(x) for x in v) + "]"
        items = [pad + fmt(x, ind + 1) for x in v]
        return "[\n" + ",\n".join(items) + "\n" + "  " * ind + "]"
    return json.dumps(v)


def main(args):
    check = args[:1] == ["--check"]
    bad = 0
    for path in args[1:] if check else args:
        with open(path) as f:
            text = f.read()
        want = fmt(json.loads(text)) + "\n"
        if text != want:
            if check:
                print(f"{path}: not formatted (run dev/lint/fmt_json.py {path})")
                bad = 1
            else:
                with open(path, "w") as f:
                    f.write(want)
    return bad


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
