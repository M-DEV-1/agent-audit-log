# Security Notes

- **Never store or log personal information** (phone numbers, claim URLs, API keys) inside any trace file. If a trace accidentally contains sensitive data, treat it as retrospective; do not publish new traces with similar fields.
- **AgentWallet credentials** (API tokens, wallet addresses) live in `~/.agentwallet/config.json` and are ignored by git via `.gitignore`. Never commit or share this file publicly.
- **On-chain proofs only include hashes and metadata.** The Solana anchor transaction publishes the trace hash (via the Memo field) but not any personal identifiers.
- **Every commit is GPG-signed** and references the relevant `trace-id/parent-trace-id` so auditors can verify the chain without needing sensitive context.
- **System reminders:** Keep `AGENTWALLET_API_TOKEN`, claim codes, and phone numbers out of trace JSONs. When in doubt, omit the field and summarize the action using generic metadata.
