"""Anchor trace hashes on Solana DevNet."""
import base64
import json
from dataclasses import dataclass
from typing import Optional

from solders.keypair import Keypair
from solders.pubkey import Pubkey
from solders.rpc.client import Client
from solders.rpc.requests import RpcRequest
from solders.rpc.config import Commitment


@dataclass
class AnchorResult:
    trace_id: str
    tx_signature: str
    slot: int


class SolanaAnchor:
    def __init__(self, endpoint: str = "https://api.devnet.solana.com"):
        self.client = Client(endpoint)

    def fund_wallet(self, wallet: Keypair, lamports: int = 100_000_000) -> Optional[str]:
        response = self.client.request_airdrop(wallet.pubkey(), lamports, commitment=Commitment.CONFIRMED)
        return response.value if response.is_ok() else None

    def anchor_hash(self, wallet: Keypair, trace_hash: str) -> Optional[AnchorResult]:
        message = b"TRACE:" + trace_hash.encode("utf-8")
        tx = wallet.transfer(wallet.pubkey(), 0, message=message)
        serialized = tx.serialize()
        response = self.client.send_transaction(serialized, [wallet])
        if response.is_ok():
            return AnchorResult(trace_id=trace_hash, tx_signature=response.value, slot=response.value.slot)
        return None


if __name__ == "__main__":
    anchor = SolanaAnchor()
    wallet = Keypair.random()
    trace_hash = "example-trace-hash"
    print("Requesting airdrop…")
    airdrop = anchor.fund_wallet(wallet)
    print("Airdrop result:", airdrop)
    print("Anchoring trace…")
    result = anchor.anchor_hash(wallet, trace_hash)
    print("Anchor result:", result)
