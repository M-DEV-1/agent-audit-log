"""Anchor trace hashes via AgentWallet on Solana DevNet."""
import json
import sys
from pathlib import Path
from typing import Any, Dict, Optional

import requests

CONFIG_PATH = Path.home() / ".agentwallet" / "config.json"
API_BASE = "https://agentwallet.mcpay.tech/api"


class AgentWalletError(Exception):
    pass


def load_config() -> Dict[str, Any]:
    if not CONFIG_PATH.exists():
        raise AgentWalletError(f"AgentWallet config not found at {CONFIG_PATH}")
    config = json.loads(CONFIG_PATH.read_text())
    required = {"username", "apiToken", "solanaAddress"}
    missing = required - set(config)
    if missing:
        raise AgentWalletError(f"AgentWallet config is missing: {missing}")
    return config


def call_action(username: str, token: str, action: str, payload: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }
    url = f"{API_BASE}/wallets/{username}/actions/{action}"
    payload = payload or {}
    resp = requests.post(url, headers=headers, json=payload, timeout=30)
    if resp.status_code != 200:
        raise AgentWalletError(f"AgentWallet {action} failed ({resp.status_code}): {resp.text}")
    data = resp.json()
    if not data.get("success", True):
        raise AgentWalletError(f"AgentWallet {action} returned error: {data}")
    return data


def fund_wallet(config: Dict[str, Any]) -> Dict[str, Any]:
    print("Requesting AgentWallet faucet-spl...", flush=True)
    return call_action(config["username"], config["apiToken"], "faucet-sol", {"network": "devnet"})


def anchor_trace(config: Dict[str, Any], trace_hash: str) -> Dict[str, Any]:
    payload = {
        "to": config["solanaAddress"],
        "amount": "1",
        "asset": "sol",
        "network": "devnet",
        "memo": f"TRACE:{trace_hash}",
    }
    print("Submitting AgentWallet transfer-solana for trace…", flush=True)
    return call_action(config["username"], config["apiToken"], "transfer-solana", payload)


def main():
    if len(sys.argv) != 2:
        print("Usage: python solana_anchor.py <trace_hash>")
        sys.exit(1)
    trace_hash = sys.argv[1]
    config = load_config()
    faucet = fund_wallet(config)
    transfer = anchor_trace(config, trace_hash)
    print(json.dumps({"faucet": faucet, "anchor": transfer}, indent=2))


if __name__ == "__main__":
    main()
