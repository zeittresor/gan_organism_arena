"""Runnable standard-library protocol tests: python -m unittest discover -s tests."""
import io
import json
import socket
import sys
import tempfile
import threading
import unittest
from pathlib import Path
from types import SimpleNamespace
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "integrations"))
from arena_mcp import MCPServer, Journal, ArenaError, GodotBackend, VKLPClient, canonical


class FixtureBackend:
    def __init__(self): self.step = 0; self.calls = []; self.controlled = False
    def call(self, action, args):
        self.calls.append((action, args))
        if action == "mode": self.controlled = args['mode'] == 'stepped'
        if action == "capture": return {'model': self.call('describe', {}), 'observation': self.call('observe', {}), 'genomes': [self.call('organism', {'id': 1})]}
        if action == "describe": return {"model": "test-fixture", "assumptions": ["fixture, not biological evidence"]}
        if action == "step": self.step += args["steps"]
        if action == "reset": self.step = 0
        if action == "organism": return {"id": 1, "genome": {"alleles": {"test": [0, 1]}}}
        if action == "events": return {"events": [], "cursor": 0, "gap": False}
        return {"model": "test-fixture", "controlled": self.controlled, "seed": 42, "step": self.step, "time": self.step / 12,
                "organisms": [{"id": 1}], "births": 0, "conceptions": 0, "brood_losses": 0, "parameters": {}}


class ProtocolTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.backend = FixtureBackend()
        self.server = MCPServer(self.backend, Journal(self.temp.name))

    def tearDown(self): self.temp.cleanup()
    def request(self, method, **params):
        return self.server.dispatch({"jsonrpc": "2.0", "id": 1, "method": method, "params": params})
    def initialize(self):
        reply = self.request("initialize", protocolVersion="2025-11-25", capabilities={}, clientInfo={"name": "test", "version": "1"})
        self.server.dispatch({"jsonrpc": "2.0", "method": "notifications/initialized"})
        return reply

    def test_handshake_and_no_implicit_game_launch(self):
        self.assertIn("error", self.request("tools/list"))
        self.assertEqual(self.initialize()["result"]["protocolVersion"], "2025-11-25")
        self.assertEqual(len(self.request("tools/list")["result"]["tools"]), 9)
        self.assertFalse(self.backend.calls)
        self.assertIn("error", self.request("initialize"))

    def test_connecting_and_observing_never_pause_or_reset(self):
        self.initialize()
        state = self.server.call_tool("arena_observe", {})
        self.assertFalse(state['controlled'])
        self.assertEqual(self.backend.calls, [('observe', {})])
        state = self.server.call_tool("arena_mode", {"mode": "stepped"})
        self.assertTrue(state['controlled'])
        state = self.server.call_tool("arena_mode", {"mode": "live"})
        self.assertFalse(state['controlled'])

    def test_tool_schema_blocks_bad_mutations(self):
        self.initialize()
        for args in ({"steps": -1}, {"steps": True}, {"steps": 121}, {"steps": 1, "execute": "code"}, {"steps": "3"}):
            result = self.request("tools/call", name="arena_step", arguments=args)["result"]
            self.assertTrue(result["isError"])
        self.assertFalse(self.backend.calls)

    def test_step_is_real_backend_call_and_structured_result(self):
        self.initialize()
        result = self.request("tools/call", name="arena_step", arguments={"steps": 12})["result"]
        self.assertFalse(result["isError"])
        self.assertEqual(result["structuredContent"]["step"], 12)
        self.assertEqual(self.backend.calls, [("step", {"steps": 12})])

    def test_resources_and_unknown_tool(self):
        self.initialize()
        self.assertEqual(len(self.request("resources/list")["result"]["resources"]), 2)
        resource = self.request("resources/read", uri="arena://model")["result"]
        self.assertIn("assumptions", json.loads(resource["contents"][0]["text"]))
        self.assertIn("error", self.request("tools/call", name="execute_shell", arguments={}))

    def test_draft_is_not_submission_and_hash_matches_bytes(self):
        result = self.server.call_tool("arena_claim_draft", {"claim": "Die Testpopulation enthält ein Individuum."})
        self.assertFalse(result["submitted"])
        self.assertTrue(result["proposal"]["metadata"]["simulation_only"])
        self.assertIn("seed 42", result["proposal"]["claim"])
        import hashlib
        from urllib.parse import urlsplit, unquote
        ev = result["proposal"]["evidence"][0]
        path = Path(unquote(urlsplit(ev["uri"]).path))
        if sys.platform == "win32": path = Path(str(path).lstrip("/"))
        self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), ev["sha256"])
        previous = "0" * 64
        for line in self.server.journal.path.read_bytes().splitlines():
            row = json.loads(line); digest = row.pop("sha256")
            self.assertEqual(row["previous"], previous)
            self.assertEqual(hashlib.sha256(canonical(row)).hexdigest(), digest)
            previous = digest

    def test_transport_recovers_after_invalid_json(self):
        source = io.BytesIO(b'not-json\n{"jsonrpc":"2.0","id":2,"method":"ping"}\n')
        output = io.BytesIO()
        self.server.serve(source, output)
        lines = [json.loads(line) for line in output.getvalue().splitlines()]
        self.assertEqual(lines[0]["error"]["code"], -32700)
        self.assertEqual(lines[1]["id"], 2)

    def test_vklp_optional_and_repeated_submission_blocked(self):
        class FakeVKLP:
            write = True
            def __init__(self): self.calls = []
            def request(self, path, payload):
                self.calls.append((path, payload))
                return {"consensus": {"status": "disputed"}}
        vklp = FakeVKLP()
        server = MCPServer(self.backend, self.server.journal, vklp)
        draft = server.call_tool("arena_claim_draft", {"claim": "test"})
        result = server.call_tool("vklp_submit_draft", {"draft_id": draft["draft_id"]})
        self.assertEqual(result["consensus"]["status"], "disputed")
        with self.assertRaises(ArenaError): server.call_tool("vklp_submit_draft", {"draft_id": draft["draft_id"]})
        self.assertEqual(len(vklp.calls), 1)
        self.assertFalse(any(tool["name"] == "vklp_submit_draft" for tool in self.server.tools))

    def test_external_knowledge_can_inform_a_logged_intervention(self):
        class ClaimVKLP:
            write = False
            def request(self, path):
                return {"claim": {"claim_id": "cl_test"}, "consensus": {"status": "disputed"}}
        server = MCPServer(self.backend, self.server.journal, ClaimVKLP())
        arguments = {"claim_id": "cl_test", "parameters": {"temperature_offset": -2.0}}
        with self.assertRaises(ArenaError): server.call_tool("vklp_apply_claim", arguments)
        self.assertFalse(self.backend.calls)
        arguments["as_hypothesis"] = True
        server.call_tool("vklp_apply_claim", arguments)
        action, values = self.backend.calls[-1]
        self.assertEqual(action, "parameters")
        self.assertEqual(values["parameters"]["temperature_offset"], -2.0)
        self.assertEqual(values["provenance"]["reference"], "cl_test")
        self.assertIn("disputed", values["provenance"]["status"])

    def test_nonlocal_plain_http_and_url_credentials_rejected(self):
        for url in ("http://example.com", "https://user:pass@example.com", "file:///tmp/vklp"):
            with self.assertRaises(ArenaError): VKLPClient(url)

    def test_split_tcp_response_and_token_forwarding(self):
        listener = socket.socket(); listener.bind(("127.0.0.1", 0)); listener.listen()
        captured = []
        def serve():
            with listener:
                connection, _ = listener.accept()
                with connection:
                    with connection.makefile("rb") as stream: request = json.loads(stream.readline())
                    captured.append(request)
                    reply = canonical({"id": request["id"], "result": {"step": 17}}) + b"\n"
                    for byte in reply: connection.sendall(bytes([byte]))
        thread = threading.Thread(target=serve); thread.start()
        args = SimpleNamespace(port=listener.getsockname()[1], attach=False)
        backend = GodotBackend(args)
        self.assertEqual(backend._exchange("observe", {}), {"step": 17})
        thread.join(timeout=3)
        self.assertEqual(captured[0]["token"], backend.token)
        self.assertEqual(captured[0]["action"], "observe")


if __name__ == "__main__": unittest.main()
