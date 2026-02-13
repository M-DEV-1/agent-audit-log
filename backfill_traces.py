#!/usr/bin/env python3
import json, hashlib, uuid, subprocess, re
from datetime import datetime

commits_to_backfill = [
    '2d7b4c0f5fb40784071aeaa5d52a8d9ef4339b0a',
    '9e6626f',
    'b9bf2df',
    '89f37d0',
    '9fd60e3',
    'c876ed7',
    '4917d0d',
    '6dc6052',
    '7ae4744'
]

for commit_short in commits_to_backfill:
    full_sha = subprocess.check_output(['git', 'rev-parse', commit_short]).decode().strip()
    message = subprocess.check_output(['git', 'log', '-1', '--format=%s', full_sha]).decode().strip()
    parent = subprocess.check_output(['git', 'log', '-1', '--format=%P', full_sha]).decode().strip().split()[0]
    timestamp = subprocess.check_output(['git', 'log', '-1', '--format=%cI', full_sha]).decode().strip()
    
    # Get numstat
    numstat = subprocess.check_output(['git', 'show', full_sha, '--numstat', '--format='], text=True).strip()
    
    file_records = []
    for line in numstat.split('\n'):
        if not line.strip():
            continue
        parts = line.split('\t')
        if len(parts) < 3:
            continue
        added, removed, filepath = parts[0], parts[1], parts[2]
        
        # Skip trace files and binary files
        if '.agent-trace' in filepath or added == '-':
            continue
        
        # Get actual diff to extract line ranges
        try:
            diff_output = subprocess.check_output(['git', 'diff', f'{parent}..{full_sha}', '--', filepath], text=True)
            
            ranges = []
            for match in re.finditer(r'@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@', diff_output):
                start_line = int(match.group(1))
                count = int(match.group(2)) if match.group(2) else 1
                if count > 0:
                    ranges.append({'start_line': start_line, 'end_line': start_line + count - 1})
            
            if ranges:
                file_records.append({
                    'path': filepath,
                    'conversations': [{
                        'contributor': {'type': 'ai', 'model_id': 'github-copilot/claude-sonnet-4.5'},
                        'ranges': ranges[:5]  # Top 5 ranges
                    }]
                })
        except Exception as e:
            print(f"  Warning: Could not parse diff for {filepath}: {e}")
    
    if not file_records:
        print(f"⊘ {full_sha[:7]} - No parseable code changes")
        continue
    
    trace_record = {
        'version': '1.0',
        'id': str(uuid.uuid4()),
        'timestamp': timestamp,
        'vcs': {'type': 'git', 'revision': full_sha},
        'tool': {'name': 'github-copilot', 'version': 'claude-sonnet-4.5'},
        'files': file_records,
        'metadata': {
            'commit_message': message,
            'parent_commit': parent
        }
    }
    
    canonical = json.dumps(trace_record, sort_keys=True, separators=(',', ':'))
    trace_hash = hashlib.sha256(canonical.encode('utf-8')).hexdigest()
    
    trace_record['metadata']['trace_hash'] = trace_hash
    trace_record['metadata']['trace_hash_scope'] = 'sha256(canonical(record_without_trace_hash))'
    trace_record['metadata']['solana_anchor'] = {'status': 'pending', 'note': 'Backfilled - will anchor in batch'}
    
    with open(f'.agent-trace/{full_sha}.json', 'w') as f:
        json.dump(trace_record, f, indent=2)
    
    print(f"✓ {full_sha[:7]} - {message[:50]}")
    print(f"  Files: {len(file_records)} | Hash: {trace_hash[:16]}...")

print("\n✅ Backfill complete!")
