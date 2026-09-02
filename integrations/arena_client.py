"""Small executable MCP client for AI experiments; no third-party dependencies."""
from __future__ import annotations
import json
from pathlib import Path
import subprocess
import sys


class ArenaClient:
    def __init__(self, *server_arguments):
        self.process = subprocess.Popen([sys.executable, str(Path(__file__).with_name("arena_mcp.py")), *server_arguments],
                                        stdin=subprocess.PIPE, stdout=subprocess.PIPE)
        self.sequence = 0
        self.request("initialize", {"protocolVersion": "2025-11-25", "capabilities": {}, "clientInfo": {"name": "arena-example", "version": "1"}})
        self.send({"jsonrpc": "2.0", "method": "notifications/initialized"})

    def send(self, message):
        self.process.stdin.write((json.dumps(message, allow_nan=False) + "\n").encode())
        self.process.stdin.flush()

    def request(self, method, params=None):
        self.sequence += 1
        self.send({"jsonrpc": "2.0", "id": self.sequence, "method": method, "params": params or {}})
        line = self.process.stdout.readline()
        if not line: raise RuntimeError("MCP server exited; inspect stderr and logs/ai-godot-*.log")
        reply = json.loads(line)
        if reply.get("id") != self.sequence: raise RuntimeError("MCP response id mismatch")
        if "error" in reply: raise RuntimeError(reply["error"])
        return reply["result"]

    def call(self, name, **arguments):
        result = self.request("tools/call", {"name": name, "arguments": arguments})
        if result.get("isError"): raise RuntimeError(result["content"])
        return result.get("structuredContent") or json.loads(result["content"][0]["text"])

    def close(self):
        if self.process.stdin: self.process.stdin.close()
        try: self.process.wait(timeout=8)
        except subprocess.TimeoutExpired:
            self.process.terminate(); self.process.wait(timeout=5)

    def __enter__(self): return self
    def __exit__(self, *args): self.close()


def main():
    with ArenaClient(*sys.argv[1:]) as client:
        client.call("arena_mode", mode="stepped")
        for renewal in (0.0, 1.0):
            state = client.call("arena_reset", seed=1337, parameters={"nutrient_renewal": renewal})
            for _ in range(12): state = client.call("arena_step", steps=120)
            result = client.call("arena_export")
            print(json.dumps({"nutrient_renewal": renewal, "time": state["time"], "population": len(state["organisms"]),
                              "births": state["births"], "evidence": result["path"]}, ensure_ascii=False))
        print("Two illustrative seeded trials completed; repeat across seeds before drawing general conclusions.")


if __name__ == "__main__": main()
