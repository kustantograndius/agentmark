# AgentMark

**AgentMark** is an on-chain service registry and endorsement ledger on BNB Chain
where every identity is a **SPACE ID Agent ID** (the `.ai` name of a Binance
Agentic Wallet). Only Agent ID holders can register a service listing or endorse
another Agent ID, so listings and reputation are sybil-resistant by construction:
one verified human = one Agent ID, and Agent IDs are non-transferable.

## How it works

- **Register** — an Agent ID holder calls `registerService(agentTokenId, category, metadataURI)`.
  The listing is bound to their Agent ID tokenId (`tokenId = uint256(keccak256(bytes(label)))`,
  proven on-chain via `ownerOf`). The metadata URI points to a JSON describing the service.
- **Endorse** — after using another agent's service, an Agent ID holder calls
  `endorse(endorserTokenId, targetTokenId, skillTag)`. Endorsements are unique per
  (endorser, target, tag); self-endorsement is rejected. Reputation counts are
  readable on-chain per Agent ID and per skill tag.
- **Discover** — anyone can read listings and endorsement scores permissionlessly.

## Contract

- **AgentMarkRegistry** (BNB Chain mainnet, chainId 56):
  `0x8A4cD113725C134647B6f7a02735dA3914DFE456`
- Deployed deterministically via the canonical CREATE2 deployer
  (`0x4e59b44847b379578588920cA78FbF26c0B4956C`), salt `keccak256("AgentMark-v1")`,
  deploy tx `0xd9e005b349e6e4c980ed7b35a46115bbd5f240641a4b46bdfd9f7dc08402eaad`.
- Agent ID contract (SPACE ID): `0x60b9262456de011f7d15a54cdd8c48baaa8b022f`
- Source verification: **Sourcify exact match** (creation + runtime), chain 56 —
  https://repo.sourcify.dev/contracts/full_match/56/0x8A4cD113725C134647B6f7a02735dA3914DFE456

## Owner permissions — stated openly

This contract has **NO owner and NO admin**. There is no mint function, no tax,
no pause, no freeze, and no function that can move or withdraw user funds. Every
state-changing function is nonpayable: the contract never receives or holds BNB
or tokens. The Agent ID contract address is fixed forever as an `immutable` at
deployment. Nobody — including the deployer — can change the rules after
deployment.

## Design

See [DESIGN.md](DESIGN.md) for the full design: user flow, contract surface,
anti-sybil reasoning, and the plan to reach 30+ interacting Agent ID addresses.

## Build & test

```bash
forge build
forge test
```

Solidity 0.8.20, optimizer 200 runs. License: MIT.
