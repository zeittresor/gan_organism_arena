"""Optional Arena MCP stdio server. Python 3.10+, standard library only.
The game backend is the actual Godot simulation, never a Python replacement.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import secrets
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

ROOT = Path(__file__).resolve().parents[1]
VERSION = "1.0.0-alpha18"
PROTOCOLS = ("2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05")
MAX_MESSAGE = 16 * 1024 * 1024


def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False).encode("utf-8")


def finite_json(raw):
    return json.loads(raw, parse_constant=lambda value: (_ for _ in ()).throw(ValueError("non-finite JSON")))


class ArenaError(Exception):
    pass


def user_settings():
    path = ROOT / "settings/config.json"
    if not path.is_file(): return {}
    try:
        value = finite_json(path.read_bytes())
    except (ValueError, OSError) as error:
        raise ArenaError("Cannot read Arena settings; access denied until configuration is readable") from error
    if not isinstance(value, dict): raise ArenaError("Invalid Arena settings")
    return value


def require_permission(protocol, write=False):
    config = user_settings()
    if config.get(protocol + "_enabled") is not True:
        raise ArenaError(protocol.upper() + " is disabled. Enable it in the Arena F10 options first.")
    if write and config.get("vklp_write_enabled") is not True:
        raise ArenaError("VKLP submissions are disabled in the Arena F10 options.")
    return config


class Journal:
    def __init__(self, directory):
        self.directory = Path(directory)
        self.directory.mkdir(parents=True, exist_ok=True)
        self.path = self.directory / ("run-" + uuid.uuid4().hex + ".jsonl")
        self.previous = "0" * 64
        self.sequence = 0
        digest = hashlib.sha256()
        for path in sorted((ROOT / "game").glob("*.gd")):
            digest.update(path.name.encode()); digest.update(path.read_bytes())
        self.source_sha256 = digest.hexdigest()
        self.append("manifest", {"arena_version": VERSION, "source_sha256": self.source_sha256,
                                 "scope": "fictional simulation; not empirical biology"})

    def append(self, kind, data):
        entry = {"sequence": self.sequence, "previous": self.previous, "kind": kind, "data": data}
        digest = hashlib.sha256(canonical(entry)).hexdigest()
        entry["sha256"] = digest
        with self.path.open("ab") as stream:
            stream.write(canonical(entry) + b"\n")
        self.sequence += 1
        self.previous = digest
        return digest


class GodotBackend:
    def __init__(self, args):
        self.args = args
        self.protocol = getattr(args, "protocol", "mcp")
        self.port = args.port
        self.token = os.environ.get("ARENA_API_TOKEN", "") if args.attach else secrets.token_hex(32)
        self.process = None
        self.started = False
        self.log = None
        self.request_id = 0
        self.requested_stepping = False
        self.session_path = ROOT / "runtime" / ("arena-session-" + str(self.port) + ".json")

    def _exchange(self, action, arguments):
        self.request_id += 1
        request = {"id": self.request_id, "token": self.token, "action": action, "arguments": arguments, "protocol": self.protocol}
        with socket.create_connection(("127.0.0.1", self.port), timeout=3) as connection:
            connection.settimeout(35)
            connection.sendall(canonical(request) + b"\n")
            with connection.makefile("rb") as reader:
                raw = reader.readline(MAX_MESSAGE + 1)
        if not raw.endswith(b"\n") or len(raw) > MAX_MESSAGE:
            raise ArenaError("Incomplete or oversized Godot response; request outcome may be unknown. Do not retry a mutation blindly.")
        reply = finite_json(raw)
        if not isinstance(reply, dict) or reply.get("id") != self.request_id:
            raise ArenaError("Godot response id mismatch")
        if "error" in reply: raise ArenaError(str(reply["error"]))
        result = reply.get("result")
        if not isinstance(result, dict): raise ArenaError("Malformed Godot result")
        if "error" in result: raise ArenaError(str(result["error"]))
        return result

    def start(self):
        require_permission(self.protocol)
        if self.started: return
        if self.args.attach:
            if len(self.token) < 32: raise ArenaError("--attach requires ARENA_API_TOKEN (at least 32 characters)")
            self._exchange("describe", {})
            self.started = True
            return
        if self.session_path.is_file() and not self.args.headless:
            saved = finite_json(self.session_path.read_bytes())
            if isinstance(saved, dict) and saved.get("port") == self.port and isinstance(saved.get("token"), str):
                self.token = saved["token"]
                try:
                    self._exchange("describe", {})
                    self.started = True
                    return
                except ConnectionRefusedError:
                    self.token = secrets.token_hex(32)
        path = Path(self.args.godot) if self.args.godot else ROOT / "runtime/godot/Godot_v4.7.2-stable_win64.exe"
        if not path.is_file():
            raise ArenaError("Godot runtime missing. Run install_windows.bat, or supply --godot with its executable path.")
        # Refuse to launch onto an occupied port; never adopt a different arena.
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", self.port))
        env = os.environ.copy()
        env.update(ARENA_API_PORT=str(self.port), ARENA_API_TOKEN=self.token)
        (ROOT / "logs").mkdir(exist_ok=True)
        self.log = (ROOT / "logs" / ("ai-godot-" + uuid.uuid4().hex + ".log")).open("wb")
        command = [str(path.resolve()), "--path", str(ROOT)]
        if self.args.headless: command += ["--headless"]
        command += ["--", "--arena-api"]
        self.process = subprocess.Popen(command, env=env, stdin=subprocess.DEVNULL, stdout=self.log, stderr=subprocess.STDOUT)
        deadline = time.monotonic() + 25
        while time.monotonic() < deadline:
            if self.process.poll() is not None:
                raise ArenaError("Godot exited during startup; inspect logs/ai-godot-*.log")
            try:
                self._exchange("describe", {})
                self.started = True
                if not self.args.headless:
                    self.session_path.parent.mkdir(parents=True, exist_ok=True)
                    with self.session_path.open("w", encoding="utf-8") as stream:
                        stream.write(canonical({"port": self.port, "token": self.token}).decode())
                    self.session_path.chmod(0o600)
                return
            except (ConnectionRefusedError, TimeoutError):
                time.sleep(0.1)
        raise ArenaError("Godot API startup timed out; inspect logs/ai-godot-*.log")

    def call(self, action, arguments):
        self.start()
        result = self._exchange(action, arguments)
        if action == "mode": self.requested_stepping = arguments.get("mode") == "stepped"
        return result

    def close(self):
        if self.started and self.requested_stepping:
            try: self._exchange("mode", {"mode": "live"})
            except (ArenaError, OSError, ValueError): pass
        if self.process is not None and self.process.poll() is None and (self.args.headless or not self.started):
            self.process.terminate()
            try: self.process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.process.kill(); self.process.wait(timeout=5)
        if self.log: self.log.close()


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ArenaError("VKLP redirect rejected; configure the final service URL explicitly")


class VKLPClient:
    """Matches the user's VKLP Research Prototype 0.1 service.py/ProposeRequest."""
    def __init__(self, url, write=False):
        self.url = url.rstrip("/")
        parts = urllib.parse.urlsplit(self.url)
        if parts.username or parts.password or parts.query or parts.fragment or not parts.hostname:
            raise ArenaError("VKLP URL must be a service base URL without credentials/query/fragment")
        if parts.scheme != "https" and not (parts.scheme == "http" and parts.hostname in ("127.0.0.1", "localhost", "::1")):
            raise ArenaError("Remote VKLP requires HTTPS; HTTP is allowed only on loopback")
        self.write = write
        self.key = os.environ.get("VKLP_API_KEY", "")
        self.opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())

    def request(self, path, payload=None):
        headers = {"Accept": "application/json"}
        if self.key: headers["Authorization"] = "Bearer " + self.key
        body = canonical(payload) if payload is not None else None
        if body is not None: headers["Content-Type"] = "application/json"
        req = urllib.request.Request(self.url + path, data=body, headers=headers)
        try:
            with self.opener.open(req, timeout=300) as response:
                raw = response.read(MAX_MESSAGE + 1)
        except urllib.error.HTTPError as exc:
            raise ArenaError(f"VKLP HTTP {exc.code}; proposal outcome can be unknown after server errors. Check ledger before retrying.") from None
        except (urllib.error.URLError, TimeoutError) as exc:
            raise ArenaError("VKLP unavailable/timeout; check ledger before retrying a proposal") from None
        if len(raw) > MAX_MESSAGE: raise ArenaError("VKLP response too large")
        return finite_json(raw)


def obj(properties=None, required=()):
    return {"type": "object", "properties": properties or {}, "required": list(required), "additionalProperties": False}


NUM = lambda lo, hi: {"type": "number", "minimum": lo, "maximum": hi}
INT = lambda lo, hi: {"type": "integer", "minimum": lo, "maximum": hi}
STRING = {"type": "string", "minLength": 1, "maxLength": 2000}
PROVENANCE = obj({"source": STRING, "reference": STRING, "status": STRING})
PARAMETERS = obj({
    "mutation_strength": NUM(0, .5), "macro_mutation_rate": NUM(0, .2), "nutrient_renewal": NUM(0, 4),
    "temperature_offset": NUM(-12, 12), "predation_strength": NUM(0, 1), "group_strength": NUM(0, 1),
    "initial_organisms": INT(2, 60), "organism_cap": INT(2, 80), "nutrient_count": INT(16, 1000),
    "auto_reproduce": {"type": "boolean"}, "auto_reseed": {"type": "boolean"}})


def validate(value, schema, name="arguments"):
    kind = schema["type"]
    valid = {"object": isinstance(value, dict), "string": isinstance(value, str),
             "number": type(value) in (int, float), "integer": type(value) is int,
             "boolean": type(value) is bool, "array": isinstance(value, list)}[kind]
    if not valid: raise ArenaError(name + " must be " + kind)
    if "enum" in schema and value not in schema["enum"]: raise ArenaError(name + " is not an allowed choice")
    if kind == "object":
        if set(schema.get("required", [])) - set(value): raise ArenaError(name + " missing required field")
        for key, item in value.items():
            if key not in schema["properties"]: raise ArenaError("Unknown field: " + str(key))
            validate(item, schema["properties"][key], name + "." + key)
    elif kind in ("number", "integer"):
        if not math.isfinite(value) or value < schema.get("minimum", -math.inf) or value > schema.get("maximum", math.inf):
            raise ArenaError(name + " outside allowed range")
    elif kind == "string":
        if len(value) < schema.get("minLength", 0) or len(value) > schema.get("maxLength", 10000): raise ArenaError(name + " invalid length")
    elif kind == "array":
        if len(value) > schema.get("maxItems", 32): raise ArenaError(name + " too many items")
        for item in value: validate(item, schema["items"], name)


class MCPServer:
    def __init__(self, backend, journal, vklp=None, permissions=None, transport="mcp"):
        self.permissions = permissions
        self.transport = transport
        self.backend, self.journal, self.vklp = backend, journal, vklp
        self.initialized = False
        self.ready = False
        self.drafts = {}
        self.tools = []
        self.add("arena_observe", "Observe current live simulation state and biological budgets.", obj(), True)
        self.add("arena_organism", "Inspect an organism's alleles, expression, parents and physiology.", obj({"id": INT(1, 2147483647)}, ["id"]), True)
        self.add("arena_events", "Read births, conceptions, losses and interventions after a cursor; gap reports truncation.", obj({"after": INT(0, 2147483647)}), True)
        self.add("arena_step", "Advance a controlled experiment by 1..120 fixed 1/12-second steps.", obj({"steps": INT(1, 120)}, ["steps"]))
        self.add("arena_mode", "Explicitly choose live playback or fixed stepping. Connecting alone leaves gameplay unchanged; all UI controls remain available.", obj({"mode": {"type": "string", "enum": ["live", "stepped"]}}, ["mode"]))
        self.add("arena_reset", "Explicitly replace the current simulated population with a seeded experiment; keeps disk logs and the current playback mode.", obj({"seed": INT(0, 2147483647), "parameters": PARAMETERS}, ["seed"]))
        self.add("arena_parameters", "Change allowed environmental/selection parameters; records an intervention.", obj({"parameters": PARAMETERS, "provenance": PROVENANCE}, ["parameters"]))
        self.add("arena_export", "Save the current observation, model assumptions and transcript hash as evidence JSON.", obj())
        self.add("arena_claim_draft", "Create a local VKLP 0.1 proposal scoped to this simulation and backed by an exported observation; does not submit it.", obj({"claim": STRING, "supersedes": {"type": "array", "items": STRING, "maxItems": 16}}, ["claim"]))
        if vklp:
            self.add("vklp_search", "Search the configured VKLP service; preserve disputed/provisional statuses.", obj({"query": STRING, "top_k": INT(1, 30), "include_disputed": {"type": "boolean"}}, ["query"]), True)
            self.add("vklp_get_claim", "Get full VKLP evidence, validator votes and claim status.", obj({"claim_id": STRING}, ["claim_id"]), True)
            self.add("vklp_verify_ledger", "Ask VKLP to verify its ledger and signed votes; not a truth guarantee.", obj(), True)
            self.add("vklp_apply_claim", "Use a retrieved VKLP claim as the documented basis for an explicit Arena parameter intervention. Non-accepted claims require as_hypothesis=true; no text is executed as code.", obj({"claim_id": STRING, "parameters": PARAMETERS, "as_hypothesis": {"type": "boolean"}}, ["claim_id", "parameters"]), external=True)
            if vklp.write:
                self.add("vklp_submit_draft", "Submit a previously created local draft to VKLP validators. External persistent write; never auto-retried.", obj({"draft_id": STRING}, ["draft_id"]), external=True)

    def add(self, name, description, schema, readonly=False, external=False):
        self.tools.append({"name": name, "description": description, "inputSchema": schema,
                           "annotations": {"readOnlyHint": readonly, "destructiveHint": name == "arena_reset",
                                           "idempotentHint": readonly, "openWorldHint": external or name.startswith("vklp_")}})

    def game(self, action, arguments):
        if self.permissions: self.permissions(self.transport)
        self.journal.append("request", {"action": action, "arguments": arguments})
        try: result = self.backend.call(action, arguments)
        except Exception:
            self.journal.append("failure", {"action": action, "outcome": "unknown; inspect state before retry"})
            raise
        self.journal.append("response", {"action": action, "result": result})
        return result

    def export(self):
        capture = self.game("capture", {})
        model = capture["model"]
        snapshot = capture["observation"]
        genomes = capture["genomes"]
        document = {"schema": "arena.evidence/1", "model": model, "observation": snapshot,
                    "genomes": genomes, "source_sha256": self.journal.source_sha256,
                    "transcript": {"path": str(self.journal.path), "head": self.journal.previous}}
        data = canonical(document)
        digest = hashlib.sha256(data).hexdigest()
        path = self.journal.directory / ("evidence-" + digest + ".json")
        if not path.exists(): path.write_bytes(data)
        return {"path": str(path), "sha256": digest, "evidence_uri": path.as_uri(), "document": document}

    def call_tool(self, name, arguments):
        tool = next((tool for tool in self.tools if tool["name"] == name), None)
        if not tool: raise ArenaError("Unknown or disabled tool: " + name)
        validate(arguments, tool["inputSchema"])
        if self.permissions:
            self.permissions(self.transport)
            if name.startswith("vklp_"):
                config = self.permissions("vklp", write=name == "vklp_submit_draft")
                if self.vklp:
                    self.vklp = VKLPClient(config.get("vklp_url") or self.vklp.url, self.vklp.write)
        if name in ("arena_observe", "arena_organism", "arena_events", "arena_step", "arena_reset", "arena_parameters", "arena_mode"):
            return self.game(name.removeprefix("arena_"), arguments)
        if name == "arena_export": return self.export()
        if name == "arena_claim_draft":
            evidence = self.export()
            state = evidence["document"]["observation"]
            # Self-contained numeric summary is usable even by remote validators;
            # full local files can be shared separately, never uploaded implicitly.
            summary = {key: state.get(key) for key in ("schema", "model", "seed", "revision", "step", "time", "parameters", "habitat", "births", "conceptions", "brood_losses", "nutrient_energy", "external_nutrient_input")}
            summary["population"] = len(state["organisms"])
            summary["scope"] = "fictional model observation; no empirical species claim"
            proposal = {"claim": f"In GAN Organism Arena {VERSION}, model {state['model']}, seed {state['seed']}, step {state['step']}: {arguments['claim']}",
                        "language": "de", "domain": "artificial-life/simulation", "proposer": "gan-organism-arena",
                        "evidence": [{"uri": evidence["evidence_uri"], "title": "Arena experiment observation", "sha256": evidence["sha256"],
                                      "media_type": "application/json", "excerpt": canonical(summary).decode()}],
                        "supersedes": arguments.get("supersedes", []),
                        "metadata": {"arena_model": state["model"], "source_sha256": self.journal.source_sha256,
                                     "simulation_only": True, "full_evidence_local_only": True,
                                     "model_assumptions": evidence["document"]["model"]["assumptions"],
                                     "transcript_head": evidence["document"]["transcript"]["head"]}}
            draft_id = "draft_" + hashlib.sha256(canonical(proposal)).hexdigest()
            self.drafts[draft_id] = {"proposal": proposal, "state": "draft"}
            self.journal.append("claim_draft", {"draft_id": draft_id, "proposal": proposal})
            path = self.journal.directory / (draft_id + ".json")
            path.write_bytes(canonical(proposal))
            return {"draft_id": draft_id, "path": str(path), "submitted": False, "proposal": proposal}
        if name == "vklp_search":
            return self.vklp.request("/knowledge/search", {"query": arguments["query"], "top_k": arguments.get("top_k", 6), "include_disputed": arguments.get("include_disputed", False)})
        if name == "vklp_get_claim": return self.vklp.request("/knowledge/" + urllib.parse.quote(arguments["claim_id"], safe=""))
        if name == "vklp_verify_ledger": return self.vklp.request("/ledger/verify")
        if name == "vklp_apply_claim":
            claim_id = arguments["claim_id"]
            record = self.vklp.request("/knowledge/" + urllib.parse.quote(claim_id, safe=""))
            if not isinstance(record, dict) or record.get("claim", {}).get("claim_id") != claim_id:
                raise ArenaError("VKLP claim identity mismatch")
            status = record.get("consensus", {}).get("status", "unknown")
            hypothesis = arguments.get("as_hypothesis", False)
            if status != "accepted" and not hypothesis:
                raise ArenaError("Claim is not accepted; use as_hypothesis=true for a transparently labelled exploratory trial")
            provenance = {"source": "VKLP/0.1", "reference": claim_id,
                          "status": status + ("; experimental hypothesis" if hypothesis else "; client-derived parameter mapping")}
            self.journal.append("knowledge_basis", {"claim_id": claim_id, "record": record, "parameters": arguments["parameters"], "as_hypothesis": hypothesis})
            return self.game("parameters", {"parameters": arguments["parameters"], "provenance": provenance})
        if name == "vklp_submit_draft":
            draft = self.drafts.get(arguments["draft_id"])
            if draft is None: raise ArenaError("Unknown draft in this session; create a draft first")
            if draft["state"] != "draft": raise ArenaError("Draft was already submitted or has unknown outcome; inspect VKLP ledger before any new proposal")
            draft["state"] = "submission_unknown"
            self.journal.append("vklp_submission", {"draft_id": arguments["draft_id"]})
            result = self.vklp.request("/claims/propose", draft["proposal"])
            draft["state"] = "submitted"
            self.journal.append("vklp_result", {"draft_id": arguments["draft_id"], "record": result})
            return result
        raise ArenaError("Unsupported tool")

    def dispatch(self, request):
        request_id = request.get("id") if isinstance(request, dict) else None
        def error(code, message): return {"jsonrpc": "2.0", "id": request_id, "error": {"code": code, "message": message}}
        if not isinstance(request, dict) or request.get("jsonrpc") != "2.0" or not isinstance(request.get("method"), str):
            return error(-32600, "Invalid Request")
        if "id" in request and type(request_id) not in (str, int): return error(-32600, "Invalid id")
        method = request["method"]
        if "id" not in request:
            if method == "notifications/initialized" and self.initialized: self.ready = True
            return None
        params = request.get("params", {})
        if not isinstance(params, dict): return error(-32602, "params must be an object")
        try:
            if self.permissions: self.permissions(self.transport)
            if method == "initialize":
                if self.initialized: return error(-32600, "Already initialized")
                if not isinstance(params.get("protocolVersion"), str) or not isinstance(params.get("clientInfo"), dict) or not isinstance(params.get("capabilities"), dict):
                    return error(-32602, "initialize requires protocolVersion, clientInfo, capabilities")
                version = params["protocolVersion"]
                self.initialized = True
                result = {"protocolVersion": version if version in PROTOCOLS else PROTOCOLS[0],
                          "capabilities": {"tools": {"listChanged": False}, "resources": {"subscribe": False, "listChanged": False}},
                          "serverInfo": {"name": "GAN Organism Arena", "version": VERSION},
                          "instructions": "Use arena://model first. Connecting preserves live gameplay. Observations concern a fictional model. Explicitly choose stepped mode for controlled trials, reset with a seed, step, inspect genomes/events, export evidence. VKLP status is returned unchanged."}
            elif method == "ping": result = {}
            elif not self.ready: return error(-32002, "Initialization and notifications/initialized required")
            elif method == "tools/list": result = {"tools": self.tools}
            elif method == "resources/list":
                result = {"resources": [{"uri": "arena://model", "name": "Arena biological model and units", "mimeType": "application/json"},
                                        {"uri": "arena://observation", "name": "Current simulation observation", "mimeType": "application/json"}]}
            elif method == "resources/read":
                uri = params.get("uri")
                if not isinstance(uri, str): return error(-32602, "Resource URI must be a string")
                action = {"arena://model": "describe", "arena://observation": "observe"}.get(uri)
                if action is None: return error(-32002, "Resource not found")
                result = {"contents": [{"uri": uri, "mimeType": "application/json", "text": canonical(self.game(action, {})).decode()}]}
            elif method == "tools/call":
                name = params.get("name")
                if not isinstance(name, str): return error(-32602, "Tool name required")
                if not any(tool["name"] == name for tool in self.tools): return error(-32602, "Unknown or disabled tool")
                try:
                    payload = self.call_tool(name, params.get("arguments", {}))
                    result = {"content": [{"type": "text", "text": canonical(payload).decode()}], "isError": False}
                    if isinstance(payload, dict): result["structuredContent"] = payload
                except (ArenaError, OSError, ValueError) as exc:
                    result = {"content": [{"type": "text", "text": str(exc)}], "isError": True}
            else: return error(-32601, "Method not found")
            return {"jsonrpc": "2.0", "id": request_id, "result": result}
        except (ArenaError, OSError, ValueError) as exc:
            return error(-32603, str(exc))

    def serve(self, source, sink):
        while True:
            raw = source.readline(1024 * 1024 + 1)
            if not raw: return
            if len(raw) > 1024 * 1024:
                # Drain exactly this line, retaining synchronization.
                while raw and not raw.endswith(b"\n"): raw = source.readline(1024 * 1024)
                reply = {"jsonrpc": "2.0", "id": None, "error": {"code": -32700, "message": "Message exceeds 1 MiB"}}
            else:
                try: reply = self.dispatch(finite_json(raw))
                except (ValueError, UnicodeError): reply = {"jsonrpc": "2.0", "id": None, "error": {"code": -32700, "message": "Parse error"}}
            if reply is not None:
                sink.write(canonical(reply) + b"\n"); sink.flush()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", help="Godot executable; defaults to project's portable Windows runtime")
    parser.add_argument("--headless", action="store_true")
    parser.add_argument("--attach", action="store_true", help="Attach to explicitly started arena using ARENA_API_TOKEN")
    parser.add_argument("--port", type=int, default=8766)
    parser.add_argument("--vklp-url", default="", help="Legacy fallback VKLP URL; saved F10 service address takes precedence; key in VKLP_API_KEY")
    parser.add_argument("--vklp-write", action="store_true", help="Compatibility flag; actual submission permission is controlled in F10")
    args = parser.parse_args()
    if not 1024 <= args.port <= 65535: parser.error("port must be 1024..65535")
    config = user_settings()
    if not args.vklp_url: args.vklp_url = config.get("vklp_url", "http://127.0.0.1:8000")
    # The menu permissions remain authoritative even for explicit CLI flags.
    args.vklp_write = True
    backend = GodotBackend(args)
    try:
        server = MCPServer(backend, Journal(ROOT / "logs/experiments"), VKLPClient(args.vklp_url, args.vklp_write) if args.vklp_url else None, permissions=require_permission)
        server.serve(sys.stdin.buffer, sys.stdout.buffer)
    finally: backend.close()


if __name__ == "__main__":
    try: main()
    except (ArenaError, OSError, KeyboardInterrupt) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
