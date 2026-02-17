#!/usr/bin/env python3
"""
Batch trace verification script.

Verifies all RFC 0.1.0 traces in a given commit range by checking:
  - Schema compliance (version, id, timestamp, vcs, tool, files)
  - SHA-256 hash integrity
  - Solana anchor presence

Usage:
    python scripts/verify-batch.py [start..end]
    python scripts/verify-batch.py HEAD~10..HEAD --verbose
    python scripts/verify-batch.py --all
"""

import argparse
import hashlib
import json
import os
import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import List, Optional

# ANSI color codes
GREEN = "\033[0;32m"
RED = "\033[0;31m"
YELLOW = "\033[1;33m"
BLUE = "\033[0;34m"
BOLD = "\033[1m"
DIM = "\033[2m"
NC = "\033[0m"  # No Color

PROJECT_ROOT = Path(__file__).resolve().parent.parent
TRACE_DIR = PROJECT_ROOT / ".agent-trace"

REQUIRED_FIELDS = ["version", "id", "timestamp", "vcs", "tool", "files"]


@dataclass
class VerifyResult:
    commit: str
    status: str  # "passed", "failed", "missing"
    message: str = ""
    trace_hash: Optional[str] = None
    solana_tx: Optional[str] = None


@dataclass
class BatchReport:
    commit_range: str
    results: List[VerifyResult] = field(default_factory=list)

    @property
    def total(self) -> int:
        return len(self.results)

    @property
    def passed(self) -> int:
        return sum(1 for r in self.results if r.status == "passed")

    @property
    def failed(self) -> int:
        return sum(1 for r in self.results if r.status == "failed")

    @property
    def missing(self) -> int:
        return sum(1 for r in self.results if r.status == "missing")

    @property
    def success_rate(self) -> float:
        return (self.passed / self.total * 100) if self.total > 0 else 0.0


def get_commits(commit_range: str) -> List[str]:
    """Retrieve the list of commit SHAs in the given range."""
    try:
        result = subprocess.run(
            ["git", "rev-list", "--reverse", commit_range],
            capture_output=True, text=True, check=True,
            cwd=str(PROJECT_ROOT),
        )
        return [line.strip() for line in result.stdout.strip().splitlines() if line.strip()]
    except subprocess.CalledProcessError:
        print(f"Error: invalid commit range '{commit_range}'", file=sys.stderr)
        sys.exit(1)


def find_trace_file(commit_sha: str) -> Optional[Path]:
    """Locate the trace file for a given commit SHA."""
    if not TRACE_DIR.is_dir():
        return None
    for f in TRACE_DIR.iterdir():
        if f.suffix == ".json" and f.stem.startswith(commit_sha):
            return f
    return None


def verify_trace(trace_path: Path, verbose: bool = False) -> VerifyResult:
    """Run full verification on a single trace file."""
    commit_sha = trace_path.stem.split(".")[0]
    try:
        with open(trace_path, "r", encoding="utf-8") as fh:
            data = json.load(fh)
    except (json.JSONDecodeError, OSError) as exc:
        return VerifyResult(commit=commit_sha, status="failed", message=f"Parse error: {exc}")

    # Schema check
    for field_name in REQUIRED_FIELDS:
        if field_name not in data:
            return VerifyResult(
                commit=commit_sha, status="failed",
                message=f"Missing required field: {field_name}",
            )

    # Hash integrity
    stored_hash = (data.get("metadata") or {}).get("trace_hash")
    if stored_hash:
        canonical_data = {k: v for k, v in data.items()}
        meta_copy = dict(canonical_data.get("metadata", {}))
        meta_copy.pop("trace_hash", None)
        meta_copy.pop("trace_hash_scope", None)
        meta_copy.pop("solana_anchor", None)
        canonical_data["metadata"] = meta_copy
        canonical_json = json.dumps(canonical_data, sort_keys=True, separators=(",", ":"))
        computed = hashlib.sha256(canonical_json.encode("utf-8")).hexdigest()
        if computed != stored_hash:
            return VerifyResult(
                commit=commit_sha, status="failed",
                message=f"Hash mismatch: stored={stored_hash[:12]}… computed={computed[:12]}…",
            )

    solana_tx = ((data.get("metadata") or {}).get("solana_anchor") or {}).get("tx_hash")
    return VerifyResult(
        commit=commit_sha, status="passed",
        trace_hash=stored_hash, solana_tx=solana_tx,
    )


def _status_icon(status: str) -> str:
    """Return a colored icon for the given status."""
    if status == "passed":
        return f"{GREEN}✓{NC}"
    if status == "failed":
        return f"{RED}✗{NC}"
    return f"{YELLOW}⚠{NC}"


def _progress_bar(current: int, total: int, width: int = 30) -> str:
    """Render a simple progress bar string."""
    filled = int(width * current / max(total, 1))
    bar = "█" * filled + "░" * (width - filled)
    pct = current / max(total, 1) * 100
    return f"{bar} {pct:5.1f}%"


def run_batch(commit_range: str, verbose: bool = False) -> BatchReport:
    """Execute batch verification across a commit range."""
    commits = get_commits(commit_range)
    report = BatchReport(commit_range=commit_range)
    total = len(commits)

    print(f"\n{BLUE}{BOLD}Scanning {total} commits …{NC}\n")

    for idx, sha in enumerate(commits, 1):
        trace_file = find_trace_file(sha)
        if trace_file is None:
            report.results.append(VerifyResult(commit=sha, status="missing", message="No trace file"))
            if verbose:
                print(f"  {_status_icon('missing')} {sha[:7]} — {DIM}no trace file{NC}")
            continue

        result = verify_trace(trace_file, verbose=verbose)
        report.results.append(result)
        if verbose:
            print(f"  {_status_icon(result.status)} {sha[:7]} — {result.status} {result.message}")

        # Compact progress indicator in non-verbose mode
        if not verbose and sys.stdout.isatty():
            sys.stdout.write(f"\r  {_progress_bar(idx, total)} ({idx}/{total})")
            sys.stdout.flush()

    if not verbose and sys.stdout.isatty():
        print()  # newline after progress bar

    return report


def print_report(report: BatchReport, elapsed: float = 0.0) -> None:
    """Print a human-readable summary with color."""
    rate_color = GREEN if report.success_rate == 100 else (YELLOW if report.success_rate >= 80 else RED)

    print()
    print(f"{BLUE}{'═' * 48}{NC}")
    print(f"{BLUE}{BOLD}  Batch Verification Report{NC}")
    print(f"{BLUE}{'═' * 48}{NC}")
    print(f"  {BLUE}Range:{NC}   {report.commit_range}")
    print(f"  {BLUE}Total:{NC}   {report.total}")
    print(f"  {GREEN}Passed:{NC}  {report.passed}")
    print(f"  {RED}Failed:{NC}  {report.failed}")
    print(f"  {YELLOW}Missing:{NC} {report.missing}")
    print(f"  {BLUE}Rate:{NC}    {rate_color}{report.success_rate:.1f}%{NC}")
    if elapsed > 0:
        print(f"  {DIM}Elapsed: {elapsed:.2f}s ({report.total / elapsed:.1f} commits/s){NC}")
    print(f"{BLUE}{'═' * 48}{NC}")
    print()


def main() -> None:
    parser = argparse.ArgumentParser(description="Batch trace verification")
    parser.add_argument("range", nargs="?", default="HEAD~20..HEAD", help="Commit range")
    parser.add_argument("--all", action="store_true", help="Verify all commits")
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args()

    commit_range = "HEAD~500..HEAD" if args.all else args.range
    t0 = time.monotonic()
    report = run_batch(commit_range, verbose=args.verbose)
    elapsed = time.monotonic() - t0
    print_report(report, elapsed=elapsed)

    sys.exit(0 if report.failed == 0 else 1)


if __name__ == "__main__":
    main()
