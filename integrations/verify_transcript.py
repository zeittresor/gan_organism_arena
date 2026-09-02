"""Verify a locally exported experiment transcript's hash chain.
Usage: python integrations/verify_transcript.py logs/experiments/run-ID.jsonl
A valid hash chain establishes byte consistency, not factual/scientific validity.
"""
import hashlib
import json
from pathlib import Path
import sys
from arena_mcp import canonical

def verify(path):
    previous = '0' * 64
    count = 0
    with Path(path).open('rb') as stream:
        for line in stream:
            entry = json.loads(line)
            expected = entry.pop('sha256')
            if entry['sequence'] != count or entry['previous'] != previous:
                raise ValueError('Broken sequence or predecessor at entry ' + str(count))
            if hashlib.sha256(canonical(entry)).hexdigest() != expected:
                raise ValueError('Hash mismatch at entry ' + str(count))
            previous = expected; count += 1
    if not count: raise ValueError('Empty transcript')
    return {'entries': count, 'head': previous, 'valid': True}

if __name__ == '__main__': print(json.dumps(verify(sys.argv[1])))
