#!/usr/bin/env python3
"""Smoke client for gamepilot_daemon (contracts/v1).

hello -> backend.load_state -> subscribe a core.color_stats@1 box -> submit Start ->
watch frames -> submit B -> watch frames, printing mean/stddev per phase.

    python3 daemon/tools/smoke_client.py --state PATH [--port 47900]
"""

import argparse
import json
import socket
import sys

BOX = {"x": 0.7, "y": 0.02, "w": 0.28, "h": 0.5}


class Client:
    def __init__(self, port):
        self.sock = socket.create_connection(("127.0.0.1", port))
        self.file = self.sock.makefile("rw", encoding="utf-8", newline="\n")
        self.next_id = 1
        self.frames = []
        self.held = {}  # latest result per probe id: a frame sends only changed ones
        self.done = {}

    def _read(self):
        line = self.file.readline()
        if not line:
            sys.exit("daemon closed the connection")
        msg = json.loads(line)
        if msg.get("method") == "frame":
            self.held.update(msg["params"]["probes"])
            self.frames.append({**msg["params"], "probes": dict(self.held)})
        elif msg.get("method") == "batch_done":
            self.done[msg["params"]["batch_id"]] = msg["params"]
        return msg

    def call(self, method, params):
        rid = self.next_id
        self.next_id += 1
        self.file.write(json.dumps({"jsonrpc": "2.0", "id": rid, "method": method,
                                    "params": params}) + "\n")
        self.file.flush()
        while True:
            msg = self._read()
            if msg.get("id") == rid:
                if "error" in msg:
                    sys.exit(f"{method}: {msg['error']}")
                return msg["result"]

    def watch(self, count):
        start = len(self.frames)
        while len(self.frames) - start < count:
            self._read()
        return self.frames[start:]


def fmt(values):
    return "[" + ", ".join(f"{v:6.1f}" for v in values) + "]"


def summarize(name, frames):
    stats = [f["probes"]["menu_panel"] for f in frames]
    seqs = [f["seq"] for f in frames]
    gaps = sum(1 for a, b in zip(seqs, seqs[1:]) if b != a + 1)
    span_ms = frames[-1]["t_ms"] - frames[0]["t_ms"]
    fps = (len(frames) - 1) * 1000.0 / span_ms if span_ms > 0 else float("inf")
    print(f"{name}: seq {seqs[0]}..{seqs[-1]} ({len(frames)} frames, {gaps} gaps, "
          f"{fps:.2f} frames/s)")
    for label, s in (("first", stats[0]), ("last", stats[-1])):
        print(f"  {label:5} mean {fmt(s['mean'])} stddev {fmt(s['stddev'])}")
    return stats[-1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=47900)
    parser.add_argument("--state", required=True, help="save state file for backend.load_state")
    parser.add_argument("--frames", type=int, default=60)
    args = parser.parse_args()

    c = Client(args.port)
    hello = c.call("hello", {"protocol": 1, "client": "smoke_client/0.1"})
    print("hello:", json.dumps(hello["backend"]), hello["probe_kinds"])
    seq = c.call("backend.load_state", {"path": args.state})["seq"]
    print("load_state: seq", seq)
    c.call("subscribe", {"probes": [{"id": "menu_panel", "kind": "core.color_stats@1",
                                     "box": BOX, "delivery": "every"}]})
    before = summarize("closed (before Start)", c.watch(20))

    r = c.call("submit", {"batch_id": "start", "commands": [
        {"press": ["Start"], "hold_ms": 100, "cooldown_ms": 100}]})
    print("submit Start: start_seq", r["start_seq"])
    opened = summarize("after Start", c.watch(args.frames))
    print("  batch_done:", c.done.get("start"))

    r = c.call("submit", {"batch_id": "close", "commands": [
        {"press": ["B"], "hold_ms": 100, "cooldown_ms": 100}]})
    print("submit B: start_seq", r["start_seq"])
    closed = summarize("after B", c.watch(args.frames))
    print("  batch_done:", c.done.get("close"))

    seqs = [f["seq"] for f in c.frames]
    gaps = sum(1 for a, b in zip(seqs, seqs[1:]) if b != a + 1)
    print(f"total: {len(c.frames)} frames, {gaps} seq gaps")
    print(f"menu open  mean {fmt(opened['mean'])} stddev {fmt(opened['stddev'])}")
    print(f"menu closed mean {fmt(closed['mean'])} stddev {fmt(closed['stddev'])} "
          f"(before Start: mean {fmt(before['mean'])})")
    c.file.close()
    c.sock.close()


if __name__ == "__main__":
    main()
