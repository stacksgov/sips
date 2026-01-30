# SIP-XXX: Standard Trait Definition for Commitment-Based Private Metadata (Encrypted NFTs)

## Preamble

- **SIP**: SIP-XXX
- **Title**: Standard Trait Definition for Commitment-Based Private Metadata (Encrypted NFTs)
- **Authors**: Xenitron nortinex@gmail.com
- **Status**: Draft
- **Consideration**: Technical
- **Type**: Standard
- **Created**: 2026-01-10
- **License**: CC0-1.0
- **Sign-off**: 
- **Discussions-To**: https://forum.stacks.org/t/encrypted-nfts-on-stacks-a-standard-trait-for-commitment-based-private-layers-enft/18560

# Abstract

This SIP proposes a minimal, composable trait interface for “Encrypted NFTs” (eNFTs): NFTs that commit on-chain to a private off-chain payload (“private metadata”) while keeping the payload itself off-chain. The standard defines:

1) a public commitment interface,  
2) an optional owner-gated envelope descriptor for wallet User Experience, and  
3) indexer-friendly event conventions.

This enables interoperable private-metadata NFT patterns across contracts, wallets, marketplaces, and indexers without requiring consensus changes.


# Copyright

This SIP is made available under the terms of the CC0-1.0 license.
This SIP’s copyright is waived to the extent possible under law.


## Introduction

“Encrypted metadata / private metadata” NFTs on Stacks are currently implemented as project-specific patterns. This fragmentation makes it difficult for wallets, marketplaces, and indexers to support such NFTs uniformly.

This SIP standardizes a minimal interface for commitment-based private metadata on SIP-009 NFTs:

- A **public commitment** (hash) to the payload (or ciphertext), enabling anyone to verify integrity after reveal.
- An optional **owner-gated envelope descriptor** to guide wallet User Experience (e.g., show “Reveal” only to the owner).
- A recommended **event format** so indexers can detect updates efficiently.

### Relationship to SIP-009

This trait is designed to be implemented **alongside** SIP-009-compliant NFT contracts, not as a replacement. An eNFT contract implements SIP-009 for ownership and transfer, and additionally implements this trait to expose commitment-based private metadata.

## Goals

- Define a reusable trait for commitment-based private metadata for eNFTs.
- Make private-layer patterns discoverable and composable for wallets/indexers.
- Keep the standard minimal, additive, and backward-compatible.

## Non-Goals

- Full on-chain confidentiality (not achievable in a public read-only model).
- Mandating a specific storage network, encryption scheme, or reveal flow.
- Defining a full game/puzzle “answer verification” protocol (out of scope).

# Specification

## 1. Terminology

- **Payload**: The private off-chain data (JSON, image, encrypted blob, etc.).
- **Ciphertext**: An encrypted payload (still considered “payload bytes” for commitment purposes).
- **Commitment**: A hash over the payload bytes (often ciphertext bytes) recorded on-chain.
- **Envelope**: A small off-chain descriptor used for UX/access (e.g., retrieval URI, encrypted key blob, signed URL descriptor).
- **Reveal**: Off-chain delivery of payload/envelope to the user; the client verifies integrity by comparing hash(payload_bytes) to the on-chain commitment.
- **Algo ID**: An integer identifier that indicates how the commitment hash is computed.
- **Scheme Version**: A monotonically increasing version number for commitment/envelope encoding.

### 2. Commitment Semantics

Implementations **MUST** expose a commitment for a given token-id.

- The commitment **MUST** be computed exactly according to the declared algorithm id.
- The commitment **MUST** be stable: the same payload bytes must produce the same commitment.
- This SIP does not mandate a single algorithm, but **RECOMMENDS**:
- `algo = u0` => SHA-256 over raw payload bytes

### Algorithm Registry (Informative)

| Algo ID | Algorithm | Notes |
|---------|-----------|-------|
| u0 | SHA-256 | Recommended default |
| u1-u99 | Reserved | For future standardization |
| u100+ | Application-defined | Projects may define custom algorithms |

**Notes**
- If the payload is JSON, implementers should treat the committed object as raw bytes of a canonical encoding chosen by the application (this SIP does not standardize canonicalization). Consumers must verify against the exact bytes they receive on reveal.

---

### 3. Trait Interface (Clarity)

To make “optional” functionality actually optional in Clarity, this SIP defines **two traits**:

- A **required** commitment trait (baseline interoperability).
- An **optional** owner-envelope trait (wallet UX extension).

Contracts may implement the baseline trait alone, or both traits.

#### 3.1 Required Trait: Commitment

```clarity
(define-trait enft-commitment-trait
  (
    ;; Public: returns the commitment to the private payload (often ciphertext bytes)
    (get-private-commitment (uint)
      (response
        (tuple
          (commitment (buff 32))                 ;; hash of payload bytes
          (algo uint)                            ;; algorithm id (e.g., u0 = sha256)
          (mime (optional (string-ascii 64)))    ;; e.g. "application/json", "image/png"
          (size (optional uint))                 ;; payload size in bytes (optional)
          (commitment-version uint)              ;; commitment scheme version
        )
        uint
      )
    )
  )
)
```

#### 3.2 Optional Trait: Owner-Gated Envelope (Wallet UX Extension)

```clarity
(define-trait enft-owner-envelope-trait
  (
    ;; User Experience oriented: returns an owner-gated envelope descriptor.
    ;; Implementations SHOULD check ownership for consistent wallet UX.
    (get-owner-envelope (uint)
      (response
        (tuple
          (envelope-uri (string-ascii 256))      ;; retrieval location (NOT a secrecy guarantee)
          (envelope-hash (buff 32))              ;; integrity check for envelope blob/response
          (algo uint)                            ;; algorithm id for envelope-hash
          (envelope-version uint)                ;; envelope scheme version
        )
        uint
      )
    )
  )
)
```

**Normative guidance**
- Contracts that claim eNFT support **MUST** implement `enft-commitment-trait`.
- Contracts **MAY** implement `enft-owner-envelope-trait` to provide a standardized “Reveal” UX path.
- Wallets/indexers should treat the presence of `enft-owner-envelope-trait` as an optional capability.

---

### 3.3 Error Codes (Recommended)

Implementations **MAY** choose their own error codes. This SIP **RECOMMENDS**:

- `err u404` => token-id not found / no commitment set
- `err u100` => not authorized for `get-owner-envelope` (only relevant if `enft-owner-envelope-trait` is implemented)


### 4. Events (Indexer Conventions)

When a private-metadata commitment is set or updated, contracts **SHOULD** emit a `print` event with a predictable structure:

```clarity
(print {
  notification: "enft-update",
  token-id: token-id,
  commitment: commitment,
  algo: algo,
  commitment-version: commitment-version
})
```

If an envelope descriptor is set/updated, contracts **MAY** emit:

```clarity
(print {
  notification: "enft-envelope-update",
  token-id: token-id,
  envelope-hash: envelope-hash,
  algo: algo,
  envelope-version: envelope-version
})
```

**Notes**
- Events are intended for indexers/wallets discovery and user interface updates.
- `envelope-uri` is intentionally excluded from the event for safety; wallets should fetch it via the read-only function if needed.
- Indexers should treat these events as hints and verify by reading the latest on-chain state as required.

---

## Backwards Compatibility

This SIP is additive and does not break existing SIP-009 NFT contracts. Projects can implement these traits alongside existing token URI / metadata patterns. Wallets and indexers can support eNFTs incrementally.

---

## Security Considerations

### Read-only visibility and “owner gating”
`get-owner-envelope` ownership checks are primarily for **wallet UX consistency**, not cryptographic secrecy. Read-only calls can be simulated by any party running a node; therefore, **confidentiality MUST NOT rely solely on on-chain gating**.

If the envelope or payload must remain private, it **SHOULD** be protected off-chain via:
- encryption (e.g., encrypt payload/key per owner), and/or
- access control (signed challenges, bearer tokens, short-TTL URLs).

### Integrity and server non-equivocation
The on-chain commitment ensures the content provider cannot swap the underlying payload after minting (or after a commitment update) without being detected. Clients **MUST** verify `hash(payload_bytes) == commitment` after reveal.

### Phishing / malicious URIs
Wallets should treat envelope URIs as untrusted input and apply standard URL safety practices (origin warnings, link previews sandboxing, and user confirmation flows where appropriate).

---

## Reference Implementation (Informative)

A reference contract can implement:
- a mapping `token-id -> commitment tuple`
- optionally a mapping `token-id -> envelope tuple`
- setters restricted to contract-defined roles (e.g., token owner or authorized operator)
- `print` events as specified above

---

## Related Work (Informative)

Commitments and commit–reveal schemes are widely used across blockchains to prevent equivocation. Some NFT ecosystems support “encrypted metadata” patterns, but these are often application-specific and lack a shared interface for wallets/indexers.

To the best of our knowledge, Stacks lacks a minimal, interoperable trait and event convention for commitment-anchored private metadata on SIP-009 NFTs; this SIP defines such a standard in a composable, non-consensus, and implementation-agnostic manner.

---

## Activation

This SIP defines a voluntary standard trait and does not require a consensus upgrade.

The SIP is considered **“Active”** when:

1) A reference implementation is deployed on Stacks mainnet (maintained by the SIP authors or any party), and  
2) At least one independent integration demonstrates interoperability (e.g., an indexer parses the events, or a wallet/marketplace displays the commitment and/or envelope capability).

Until then, the SIP remains **“Draft”**, and implementers may ship experimental contracts under the proposed interface.

## References

[1] [SIP-009 ](https://github.com/stacksgov/sips/blob/main/sips/sip-009/sip-009-nft-standard.md)

[2] [Forum discussion thread](https://forum.stacks.org/t/encrypted-nfts-on-stacks-a-standard-trait-for-commitment-based-private-layers-enft/18560)
