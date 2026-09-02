"""Exercise live option changes without contacting external services."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from types import SimpleNamespace
import arena_mcp as mcp
from test_mcp import FixtureBackend


class PermissionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        (self.root / 'settings').mkdir()
        self.patch = patch.object(mcp, 'ROOT', self.root)
        self.patch.start()
        self.backend = FixtureBackend()
        self.config = {}
        self.write()

    def tearDown(self):
        self.patch.stop()
        self.temp.cleanup()

    def write(self, **values):
        self.config.update(values)
        (self.root / 'settings/config.json').write_text(json.dumps(self.config))

    def server(self, transport='mcp'):
        return mcp.MCPServer(self.backend, mcp.Journal(self.root / 'logs'),
                             mcp.VKLPClient('http://127.0.0.1:8000', True),
                             permissions=mcp.require_permission, transport=transport)

    def test_four_permission_combinations_and_live_revocation(self):
        server = self.server()
        for a, b in [(False, False), (True, False), (False, True), (True, True)]:
            self.write(mcp_enabled=a, vklp_enabled=b)
            if a:
                self.assertFalse(server.call_tool('arena_observe', {})['controlled'])
            else:
                with self.assertRaises(mcp.ArenaError): server.call_tool('arena_observe', {})
            direct = self.server('vklp')
            if b:
                self.assertFalse(direct.call_tool('arena_observe', {})['controlled'])
            else:
                with self.assertRaises(mcp.ArenaError): direct.call_tool('arena_observe', {})
        self.write(mcp_enabled=False)
        calls = len(self.backend.calls)
        with self.assertRaises(mcp.ArenaError): server.call_tool('arena_observe', {})
        self.assertEqual(calls, len(self.backend.calls))

    def test_vklp_network_and_submission_permissions_checked_per_request(self):
        server = self.server()
        with patch.object(mcp.VKLPClient, 'request', return_value={'ok': True}) as network:
            self.write(mcp_enabled=True, vklp_enabled=False)
            with self.assertRaises(mcp.ArenaError): server.call_tool('vklp_verify_ledger', {})
            network.assert_not_called()
            self.write(vklp_enabled=True)
            self.assertEqual(server.call_tool('vklp_verify_ledger', {}), {'ok': True})
            self.write(vklp_enabled=False)
            with self.assertRaises(mcp.ArenaError): server.call_tool('vklp_verify_ledger', {})
            self.assertEqual(network.call_count, 1)
            self.write(vklp_enabled=True, vklp_write_enabled=False)
            draft = server.call_tool('arena_claim_draft', {'claim': 'test observation'})
            with self.assertRaises(mcp.ArenaError): server.call_tool('vklp_submit_draft', {'draft_id': draft['draft_id']})
            self.assertEqual(server.drafts[draft['draft_id']]['state'], 'draft')
            self.write(vklp_write_enabled=True)
            self.assertEqual(server.call_tool('vklp_submit_draft', {'draft_id': draft['draft_id']}), {'ok': True})

    def test_disabled_handshake_and_corrupt_configuration_fail_closed(self):
        server = self.server()
        request = {'jsonrpc': '2.0', 'id': 1, 'method': 'initialize', 'params': {
            'protocolVersion': '2025-11-25', 'capabilities': {}, 'clientInfo': {'name': 'test', 'version': '1'}}}
        self.assertIn('error', server.dispatch(request))
        self.assertFalse(server.initialized)
        self.write(mcp_enabled=True)
        self.assertIn('result', server.dispatch(request))
        (self.root / 'settings/config.json').write_text('{broken')
        with self.assertRaises(mcp.ArenaError): server.call_tool('arena_observe', {})

    def test_cli_cannot_start_runtime_when_disabled(self):
        args = SimpleNamespace(port=8766, attach=False, headless=False, godot=None)
        backend = mcp.GodotBackend(args)
        with patch.object(mcp.subprocess, 'Popen') as process:
            with self.assertRaises(mcp.ArenaError): backend.call('observe', {})
            process.assert_not_called()
