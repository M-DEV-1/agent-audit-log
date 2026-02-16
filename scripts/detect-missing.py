#!/usr/bin/env python3
"""
Missing trace detector.

Scans a commit range and identifies commits that lack a corresponding
RFC 0.1.0 trace file in .agent-trace/.  Optionally emits a machine-
readable JSON report.

Usage:
    python scripts/detect-missing.py
    python scripts/detect-missing.py --range HEAD~100..HEAD
    python scripts/detect-missing.py --json missing-report.json
"""

import argparse
import json
import subprocess
import sys
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import List, Optional

PROJECT_ROOT = Path(__file__).resolve().parent.parent
TRACE_DIR = PROJECT_ROOT / ".agent-trace"


@dataclass
class MissingCommit:
    sha: str
    short_sha: str
    subject: str
    author: str
    date: str


@dataclass
class DetectionReport:
    commit_range: str
    total_commits: int = 0
    missing: List[MissingCommit] = field(default_factory=list)
    covered: int = 0

    @property
    def missing_count(self) -> int:
        return len(self.missing)

    @property
    def coverage_pct(self) -> float:
        if self.total_commits == 0:
            return 0.0
        return (self.covered / self.total_commits) * 100


def git_rev_list(commit_range: str) -> List[str]:
    """Get list of commits in range."""
    try:
        result = subprocess.run(
            ["git", "rev-list", "--reverse", commit_range],
            capture_output=True, text=True, check=True,
            cwd=str(PROJECT_ROOT),
        )
        return [l.strip() for l in result.stdout.strip().splitlines() if l.strip()]
    except subprocess.CalledProcessError:
        print(f"Error: invalid commit range '{commit_range}'", file=sys.stderr)
        sys.exit(1)


def git_log_field(sha: str, fmt: str) -> str:
    """Retrieve a single git log field for a commit."""
    result = subprocess.run(
        ["git", "log", "-1", f"--format={fmt}", sha],
        capture_output=True, text=True, check=True,
        cwd=str(PROJECT_ROOT),
    )
    return result.stdout.strip()


def has_trace(sha: str) -> bool:
    """Check whether a trace file exists for the given commit SHA."""
    if not TRACE_DIR.is_dir():
        return False
    for f in TRACE_DIR.iterdir():
        if f.suffix == ".json" and f.stem.startswith(sha):
            return True
    return False


def detect(commit_range: str) -> DetectionReport:
    """Scan the range and build a detection report."""
    commits = git_rev_list(commit_range)
    report = DetectionReport(commit_range=commit_range, total_commits=len(commits))

    for sha in commits:
        if has_trace(sha):
            report.covered += 1
        else:
            report.missing.append(MissingCommit(
                sha=sha,
                short_sha=sha[:7],
                subject=git_log_field(sha, "%s"),
                author=git_log_field(sha, "%an"),
                date=git_log_field(sha, "%ai"),
            ))
    return report


def print_report(report: DetectionReport) -> None:
    """Pretty-print detection results."""
    print()
    print("═" * 42)
    print("  Missing Trace Detector")
    print("═" * 42)
    print(f"  Range:    {report.commit_range}")
    print(f"  Total:    {report.total_commits}")
    print(f"  Covered:  {report.covered}")
    print(f"  Missing:  {report.missing_count}")
    print(f"  Coverage: {report.coverage_pct:.1f}%")
    print("═" * 42)
    print()

    if report.missing:
        print("Missing traces:")
        for mc in report.missing:
            print(f"  ⚠ {mc.short_sha} — {mc.subject}")
            print(f"    Author: {mc.author}  Date: {mc.date}")
    else:
        print("  ✓ All commits have traces!")
    print()


def export_json(report: DetectionReport, output_path: str) -> None:
    """Write detection report as JSON."""
    data = {
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "commit_range": report.commit_range,
        "total_commits": report.total_commits,
        "covered": report.covered,
        "missing_count": report.missing_count,
        "coverage_pct": round(report.coverage_pct, 2),
        "missing": [
            {"sha": m.sha, "subject": m.subject, "author": m.author, "date": m.date}
            for m in report.missing
        ],
    }
    Path(output_path).write_text(json.dumps(data, indent=2), encoding="utf-8")
    print(f"  Report saved to {output_path}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Detect commits without traces")
    parser.add_argument("--range", default="HEAD~50..HEAD", help="Commit range")
    parser.add_argument("--json", dest="json_out", help="Export JSON report")
    args = parser.parse_args()

    report = detect(args.range)
    print_report(report)

    if args.json_out:
        export_json(report, args.json_out)

    sys.exit(1 if report.missing_count > 0 else 0)


if __name__ == "__main__":
    main()
