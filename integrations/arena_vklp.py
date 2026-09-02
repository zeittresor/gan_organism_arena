"""Direct VKLP client: works with VKLP enabled and MCP disabled in F10."""
import argparse
import json
import sys
from arena_mcp import (ArenaError, GodotBackend, Journal, MCPServer, ROOT,
                       VKLPClient, finite_json, require_permission)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["search", "get", "verify", "observe", "export", "apply", "claim"])
    parser.add_argument("value", nargs="?", default="")
    parser.add_argument("--parameters", default="{}", help="JSON parameter mapping for apply")
    parser.add_argument("--as-hypothesis", action="store_true")
    parser.add_argument("--submit", action="store_true", help="Explicitly submit the generated claim draft")
    parser.add_argument("--godot")
    parser.add_argument("--port", type=int, default=8766)
    args = parser.parse_args()
    config = require_permission("vklp", write=args.submit)
    args.protocol, args.headless, args.attach = "vklp", False, False
    backend = GodotBackend(args)
    server = MCPServer(backend, Journal(ROOT / "logs/experiments"),
                       VKLPClient(config.get("vklp_url", "http://127.0.0.1:8000"), True),
                       permissions=require_permission, transport="vklp")
    try:
        if args.command == "search": result = server.call_tool("vklp_search", {"query": args.value})
        elif args.command == "get": result = server.call_tool("vklp_get_claim", {"claim_id": args.value})
        elif args.command == "verify": result = server.call_tool("vklp_verify_ledger", {})
        elif args.command == "observe": result = server.call_tool("arena_observe", {})
        elif args.command == "export": result = server.call_tool("arena_export", {})
        elif args.command == "apply":
            result = server.call_tool("vklp_apply_claim", {"claim_id": args.value, "parameters": finite_json(args.parameters), "as_hypothesis": args.as_hypothesis})
        else:
            result = server.call_tool("arena_claim_draft", {"claim": args.value})
            if args.submit: result = server.call_tool("vklp_submit_draft", {"draft_id": result["draft_id"]})
        print(json.dumps(result, ensure_ascii=False, indent=2))
    finally:
        backend.close()


if __name__ == "__main__":
    try: main()
    except (ArenaError, OSError, ValueError, KeyboardInterrupt) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
