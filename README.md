# lindy

Onchain security score based on objective survivorship heuristics.
Every input is deterministic and verifiable onchain. No trust required.

**[lindy.wei.is](https://lindy.wei.is)** | **[github](https://github.com/z-fi/lindy)**

## How it works

The lindy score answers one question: **how battle-tested is this contract?**

It combines two core signals — **time survived** and **value at stake** — then adjusts for code complexity, upgradeability, and source verification. All data comes directly from onchain state and public APIs.

### Signals

**Time (T)** — Days since contract deployment. Found by binary-searching for the first block with code at the address. Log-scaled and capped at ~7 years.

**Value (V)** — How much is on the line.
- *Escrow contracts*: ETH + stablecoin balances (USDC, USDT, DAI, WETH). Uses the **minimum** balance across three checkpoints (now, 7d ago, 30d ago) to resist flash deposits.
- *Router contracts*: Daily ETH volume from internal transactions over a 30-day window.

Log-scaled so the difference between 0 and 100 ETH matters more than between 100k and 200k ETH.

**Complexity (C)** — Lines of verified source code (or estimated from bytecode at ~7 bytes/LOC). Simpler code scores higher — fewer lines means less attack surface.

**Proxy (P)** — Whether the contract is upgradeable (EIP-1967, UUPS, Beacon, etc). Upgradeable contracts receive a 15% penalty because the code you see today might not be the code running tomorrow.

**Unverified (U)** — Whether source code is published on Etherscan or Sourcify. Unverified contracts receive a 30% penalty.

### Formula

```
T = min(1, ln(1 + days) / ln(1 + 2555))
V = min(1, ln(1 + eth)  / ln(1 + vCap))

base  = sqrt(T * V) * 100
score = min(99, base * C * P * U)
```

The geometric mean of T and V means both signals must be strong — a new contract holding a lot of ETH scores low, and an old empty contract scores low. Only contracts that have held real value for real time score well.

### Grades

| Score | Grade |
|-------|-------|
| 85-99 | BATTLE-HARDENED |
| 65-84 | ESTABLISHED |
| 40-64 | MATURING |
| 20-39 | EARLY |
| 0-19  | UNPROVEN |

### Why this works

The Lindy effect says the longer something has survived, the longer it's likely to survive. A contract holding 50k ETH for 3 years without being drained is strong evidence of security — stronger than any audit report. This score quantifies that intuition with fully verifiable onchain data.

## Lindy Audit NFT

Onchain audit registry as a soulbound ERC721. Each audited contract address receives a non-transferable NFT whose token ID is the `uint256` of the address itself. The metadata URI points to the published audit.

**Contract:** [`0x0000000000aa87b596256B79Cf2262b00b0cDb46`](https://etherscan.io/address/0x0000000000aa87b596256B79Cf2262b00b0cDb46)

### How it works

zFi authorizes auditors who can publish, update, and manage audit entries onchain. Each audit is an NFT minted to the audited contract's address with a metadata URI linking to the full report.

- **Owner (zFi)** — Authorizes and revokes auditors. Can also mint, update, and burn entries directly.
- **Auditors** — Authorized addresses that can mint new audit NFTs and update existing metadata.
- **Token ID** — `uint256(uint160(address))` — the numeric value of the audited address. One NFT per address.
- **Soulbound** — Audit NFTs cannot be transferred, only minted and burned.
- **Provenance** — Every mint emits an `Audited(auditor, auditedAddress, uri)` event recording who published it.

### Lookup

To check if a contract has been audited, query `tokenURI(uint256(uint160(contractAddress)))`. If the token exists, the URI points to the audit report. If not, the call reverts.

### Authorized Auditors

| Address | Name |
|---------|------|
| `0x...` | TBD |

Want to audit onchain with Lindy? Open a PR adding your `0x` address to this table with a brief statement of your credentials and audit experience.
