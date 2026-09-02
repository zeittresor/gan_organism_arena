"""Native Godot + MCP end-to-end check. Run explicitly after installation.
Enable MCP in the F10 options before running this explicit scenario.
python tests/live_arena_check.py [--godot PATH] [--headless]
"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'integrations'))
from arena_client import ArenaClient

with ArenaClient(*sys.argv[1:]) as client:
    client.call("arena_mode", mode="stepped")
    params = {'initial_organisms': 2, 'organism_cap': 12, 'nutrient_count': 32}
    first = client.call('arena_reset', seed=42, parameters=params)
    assert first['step'] == 0 and len(first['organisms']) == 2
    first = client.call('arena_step', steps=12)
    assert first['step'] == 12 and abs(first['time'] - 1) < 1e-6
    client.call('arena_reset', seed=42, parameters=params)
    second = client.call('arena_step', steps=12)
    assert first['organisms'] == second['organisms'], 'seeded reset was not reproducible'
    assert first['broods'] == second['broods']
    detail = client.call('arena_organism', id=1)
    assert len(detail['genome']['alleles']) == 88
    assert detail['dna']['ploidy'] == 2
    assert detail['cell_cycle']['gamete_ploidy'] == 1
    client.call('arena_parameters', parameters={'nutrient_renewal': 0.0})
    events = client.call('arena_events', after=0)
    assert any(e['kind'] == 'intervention' for e in events['events'])
    evidence = client.call('arena_export')
    assert Path(evidence['path']).is_file()
    print('NATIVE GODOT + MCP E2E OK:', evidence['path'])
