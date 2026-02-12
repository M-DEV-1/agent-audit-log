"""Simple AgentTrace logger with hash chaining + light PoW."""
import hashlib
import json
import os
from datetime import datetime
from pathlib import Path
from typing import Any, Dict

TRACES_DIR = Path("traces")
TRACES_DIR.mkdir(exist_ok=True)


def canonical_json(obj: Dict[str, Any]) -> str:
    return json.dumps(obj, sort_keys=True, separators=(',', ':'), ensure_ascii=False)


def compute_hash(data: str) -> str:
    return hashlib.sha256(data.encode("utf-8")).hexdigest()


def pow_nonce(content_hash: str, difficulty: int = 4) -> Dict[str, Any]:
    target = "0" * difficulty
    nonce = 0
    while True:
        candidate = f"{content_hash}{nonce}"
        digest = hashlib.sha256(candidate.encode("utf-8")).hexdigest()
        if digest.startswith(target):
            return {"nonce": nonce, "difficulty": difficulty, "digest": digest}
        nonce += 1


def write_trace(trace: Dict[str, Any]) -> Path:
    payload = trace.copy()
    payload["timestamp"] = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
    canonical_fields = {k: payload[k] for k in sorted(payload) if k not in {"hash", "pow"}}
    canonical = canonical_json(canonical_fields)
    payload["hash"] = compute_hash(canonical)
    pow_record = pow_nonce(payload["hash"], difficulty=trace.get("pow", {}).get("difficulty", 4))
    payload["pow"] = pow_record
    filename = TRACES_DIR / f"{payload['timestamp'].replace(':', '-')}.json"
    with open(filename, "w", encoding="utf-8") as fp:
        json.dump(payload, fp, indent=2, sort_keys=True)
    return filename


def main():
    trace = {
        "trace_id": os.environ.get("TRACE_ID", "manual-test-trace"),
        "type": "ACTION",
        "model_name": os.environ.get("MODEL_NAME", "custom-logger/1.0"),
        "instruction": "logger self-check",
        "input": {},
        "output": {"status": "ok"},
        "parent_trace_id": os.environ.get("PARENT_TRACE", ""),
        "pow": {"difficulty": int(os.environ.get("POW", "4"))},
    }
    path = write_trace(trace)
    print(f"wrote trace: {path}")


if __name__ == "__main__":
    main()
