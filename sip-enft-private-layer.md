# SIP-XXX: Encrypted NFTs - Standard Trait for Commitment-Based Private Layers (eNFT)

## Preamble

- **SIP**: SIP-XXX
- **Title**: Encrypted NFTs - Standard Trait for Commitment-Based Private Layers (eNFT)
- **Authors**: Xenitron nortinex@gmail.com
- **Status**: Draft
- **Consideration**: Technical
- **Type**: Standard
- **Layer**: Traits
- **Created**: 2026-01-10
- **License**: CC0-1.0
- **Sign-off**: 
- **Discussions-To**: https://forum.stacks.org/t/encrypted-nfts-on-stacks-a-standard-trait-for-commitment-based-private-layers-enft/18560

# Abstract

This SIP proposes a simple, composable trait for “Encrypted NFTs” (eNFTs): NFTs that commit on-chain to a private off-chain payload (a “private layer”) while keeping the payload itself off-chain. The standard defines (1) a public commitment interface, (2) an optional owner-gated envelope descriptor for wallet UX, and (3) indexer-friendly event conventions. This enables interoperable private-layer NFT patterns across contracts, wallets, marketplaces, and indexers without requiring consensus changes.

# Copyright

This SIP is made available under the terms of the CC0-1.0 license.
This SIP’s copyright is waived to the extent possible under law.

# Introduction

Today, “private layer / encrypted metadata” NFTs on Stacks are implemented as bespoke, project-specific patterns. That fragmentation makes it hard for wallets, marketplaces, and indexers to support them generically.

This SIP standardizes a minimal interface for eNFT private layers:
- A **public commitment** (hash) to the private payload, enabling anyone to verify integrity after reveal.
- An optional **owner-gated envelope descriptor** to guide wallet UX (e.g., show “Reveal” only to the owner).
- A recommended **event format** so indexers can discover updates efficiently.

## Goals

- Define a reusable trait for commitment-based private layers for NFTs.
- Make private-layer patterns discoverable and composable for wallets/indexers.
- Keep the standard minimal and non-consensus.

## Non-Goals

- Full on-chain confidentiality (not achievable in a public read-only model).
- Mandating a specific storage network, encryption scheme, or reveal flow.
- Defining a full game/puzzle “answer verification” protocol (out of scope).

# Specification

## 1. Terminology

- **Payload**: The private off-chain data (JSON, image, encrypted blob, etc.).
- **Commitment**: A hash over the payload (or ciphertext) recorded on-chain.
- **Envelope**: A small off-chain descriptor used for UX/access, e.g., a retrieval URI, encrypted key, or signed URL.
- **Reveal**: Off-chain delivery of payload/envelope to the user; verification is done by comparing hash(payload) to on-chain commitment.

## 2. Commitment Semantics

Implementations MUST expose a 32-byte commitment for a given token-id.  
The commitment MUST be computed using the declared algorithm identifier.

This SIP does not mandate a single algorithm, but RECOMMENDS:
- `algo = u0` => SHA-256 over raw payload bytes

## 3. Trait Interface (Clarity)

The trait defines two read-only methods: one public (commitment) and one optional/UX-oriented (owner envelope).

### 3.1 Clarity trait definition

```clarity
(define-trait enft-private-layer-trait
  (
    ;; Public: returns the commitment to the private payload (or ciphertext)
    (get-private-commitment (uint)
      (response
        (tuple
          (commitment (buff 32))                 ;; hash of payload or ciphertext
          (algo uint)                            ;; algorithm id (e.g., u0 = sha256)
          (mime (optional (string-ascii 64)))    ;; e.g. "application/json", "image/png"
          (size (optional uint))                 ;; bytes (optional)
          (commitment-version uint)              ;; scheme versioning
        )
        uint
      )
    )

    ;; UX-oriented: returns an owner-gated envelope descriptor.
    ;; Implementations SHOULD check ownership for consistent wallet UX.
    (get-owner-envelope (uint)
      (response
        (tuple
          (envelope-uri (string-ascii 256))      ;; retrieval location (NOT a secrecy guarantee)
          (envelope-hash (buff 32))              ;; integrity check for envelope blob/response
          (algo uint)                            ;; algorithm id for envelope-hash
          (envelope-version uint)                ;; scheme versioning
        )
        uint
      )
    )
  )
)
```

## 3.2 Error Codes (Recommended)
Implementations MAY choose their own error codes. This SIP RECOMMENDS:

`err u404` => token-id not found / no private layer set

`err u100` => not authorized (e.g., tx-sender not owner) for get-owner-envelope

## 4. Events (Indexer Conventions)
When a private-layer commitment is set or updated, contracts SHOULD emit a print event with a predictable structure:

```clarity

(print {
  notification: "enft-update",
  token-id: token-id,
  commitment: commitment,
  algo: algo,
  commitment-version: commitment-version
})
```

If an envelope descriptor is set/updated, contracts MAY emit:

```clarity

(print {
  notification: "enft-envelope-update",
  token-id: token-id,
  envelope-hash: envelope-hash,
  algo: algo,
  envelope-version: envelope-version
})
```

Notes:

- Events are intended for indexers/wallets discovery and UI updates.

- `envelope-uri` SHOULD NOT be treated as confidential by default.

## Backwards Compatibility
This SIP is additive and does not break existing SIP-009 NFT contracts. Projects can implement this trait alongside existing token URI metadata patterns. Wallets/indexers can support eNFTs incrementally.

## Security Considerations
**Read-only visibility and “owner gating”**

`get-owner-envelope` ownership checks are primarily for **wallet UX consistency**, not cryptographic secrecy. Read-only calls can be simulated by node operators; therefore, **confidentiality MUST NOT rely solely on on-chain gating**.

If the envelope or payload must remain private, it SHOULD be protected off-chain via:

- encryption (e.g., encrypt payload/key per owner), and/or

- access control (signed messages, bearer tokens, short TTL URLs).

**Integrity and server non-equivocation**

The on-chain commitment ensures the server cannot swap the underlying private payload after minting without being detected. Clients MUST verify `hash(payload)==commitment` after reveal.

**Phishing / malicious URIs**

Wallets SHOULD treat envelope URIs as untrusted input and apply standard URL safety practices.

## Reference Implementation

A reference contract (informative) can implement:

- storage mapping token-id => commitment tuple

- storage mapping token-id => envelope tuple

- setters restricted to contract-defined roles (e.g., token owner or game operator)

- `print` events as specified above

## Related Work

Cryptographic commitments (hash commitments) and commit–reveal mechanics are widely used across blockchains and in on-chain games to prevent equivocation. Separately, some NFT ecosystems support “encrypted metadata” or off-chain private content patterns, but these are typically application-specific and lack a shared interface for wallets/indexers.
To the best of our knowledge, Stacks currently has no minimal, interoperable trait + event convention that standardizes a commitment-anchored private layer for SIP-009 NFTs. This SIP fills that gap by defining a composable trait and predictable indexer events, while remaining non-consensus and implementation-agnostic.

## Activation

No consensus changes are required. Adoption is voluntary:

- NFT contracts implement the trait

- wallets/indexers add UI for commitments and optional reveal flows

- marketplaces may display “private layer present” and verified reveal status

## References

[1] SIP-009 (NFT trait standard on Stacks)

[2] Forum discussion thread linked in Preamble
