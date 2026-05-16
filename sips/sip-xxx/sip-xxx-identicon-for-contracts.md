# Preamble

SIP Number: XXX

Title: Identicons for Contracts

Author(s):

- Friedger Müffke <mail@friedger.de>

Status: Draft

Consideration: Technical

Type: Standard

Layer: Traits

Created: 2026-04-14

License: CC0-1.0

Sign-off:

Discussions-To:

- https://forum.stacks.org/t/identicon-for-contracts/18637

# Abstract

This SIP specifies a deterministic way to derive a visual identifier (an "identicon") for any Clarity smart contract deployed to the Stacks blockchain. The identicon is a pure function of the contract's source code after canonicalization: two deployments of the same source — on any address, at any height, on any network — render the same icon. Wallets, explorers, and apps that implement the specification allow users to recognize known code at a glance and to notice when contracts that share a name or author address do not share code.

The specification pins three things: the canonical form of the source (the output of `clarinet format` with default settings), the hash function (`SHA-512/256` over the UTF-8 bytes of the canonical form), and the rendering library and configuration (`minidenticons`, default options, seeded with the lowercase hex-encoded hash). The output is an SVG suitable for inline rendering.

# Copyright

This SIP is made available under the terms of the Creative Commons CC0 1.0 Universal license, available at https://creativecommons.org/publicdomain/zero/1.0/.

# Introduction

Clarity contracts are addressed by `{deployer}.{name}`. That pair is useful for on-chain references but is a poor user-facing identifier: a user reading `SP2J….transfer-helper` cannot tell from the name alone whether this is the audited, widely-deployed helper they have used before, a fork with a subtle change, or a phishing lookalike deployed to a confusable address.

Hash-based identicons are a well-understood solution to this problem (see `identicon`, `jdenticon`, `blockies`, the GitHub default avatar). What is missing on Stacks is a convention on *which* bytes get hashed and *which* renderer is used, so that the same contract produces the same icon everywhere it is shown.

This SIP proposes adoption of this convention as a standard across the Stacks ecosystem. It does not propose any consensus change to the Stacks blockchain — the specification is an off-chain convention followed by wallets, explorers, and apps.

# Specification

## 1. Canonical source

The canonical form of a contract's source code is the byte-for-byte output of `clarinet format` invoked with default settings, against the contract's `.clar` source file.

- Formatters MUST normalize line endings to `\n` (LF).
- Formatters MUST produce a final trailing `\n`.
- Comments (`;;` and `;;;`) are part of the source and are preserved by `clarinet format`. They are hashed.
- The canonical form is UTF-8 encoded.

Implementations without access to a local Clarinet formatter SHOULD attempt to retrieve pre-formatted source and SHOULD emit a warning if the source deviates from the canonical heuristic (trailing whitespace, line-ending consistency, tab usage).

Contract authors who wish to participate in the identicon convention MUST run `clarinet format` before deploying. Two authors deploying identical logic with different whitespace will produce different identicons.

## 2. Hash

The identicon hash is:

```
identicon_hash = SHA-512/256(utf8_bytes(canonical_source))
```

- `SHA-512/256` is the SHA-512 algorithm with the 512/256 initialization vector, truncated to 256 bits (FIPS 180-4 §5.3.6).
- The output is a 32-byte buffer.
- When passed to the renderer, the hash is lowercase hex-encoded without a `0x` prefix (64 characters).

This is the same hash exposed in Clarity as the `sha512/256` function, so a contract MAY compute and expose its own identicon hash on-chain:

```clarity
(define-read-only (get-identicon-hash (source (buff 65535)))
  (sha512/256 source))
```

Off-chain implementations MUST compute the identicon hash directly from the canonical source code fetched via /v2/contracts/source, 
not from any contract copy or on-chain-published or cached hash value. The source, once deployed, is immutable and authoritative.

## 3. Rendering

The identicon is rendered with the **`minidenticons`** library, used in its default configuration:

- Library: `minidenticons` (https://github.com/laurentpayot/minidenticons), version 4.x or later.
- Function: `minidenticonSvg(seed, saturation, lightness)`.
- Arguments:
  - `seed`: the lowercase hex-encoded identicon hash from §2.
  - `saturation`: default (`50`).
  - `lightness`: default (`50`).
- Output: an SVG element (default viewBox) rendering a 5×5 symmetric pixel grid.

Implementations MAY override saturation and lightness to match their theme, but the seed MUST remain the hex-encoded hash so the grid pattern stays constant. A light and a dark theme that agree on the seed will display the same silhouette in different colors, which is the intended behavior.

## 4. Contract identifier display

When space permits, implementations SHOULD display the identicon adjacent to the qualified contract identifier (contract principal, `{deployer}.{name}`). The identicon is advisory: it supplements, not replaces, the identifier.

To prevent visual conflation of code identity with contract principal, implementations:

* SHOULD display the contract identicon adjacent to the contract identifier ({deployer}.{name}) with a clear visual hierarchy or label indicating it represents source code, not contract address.

* MAY display a separate visual representation of the contract identifier to make address divergence visually apparent. The visual representation MAY be derived from the BNS name owned by the contract principal (e.g. profile image), a minidenticon derived from SHA-256(contract principal) or SHA-256(deployer), or a similar representation. Two deployments of identical code to different principals would then show: identical code icons, distinct contract identifier icons.


## 5. Network isolation

Identicons are a function of source code only, not of network. A contract deployed on testnet and mainnet from identical formatted source will render the same icon. Implementations SHOULD label the network separately.

# Related Work

- **Ethereum Blockies** (`ethereum-blockies`): hashes the lowercase hex address, not the bytecode. Identical code at different addresses renders differently — the opposite trade-off from this SIP.
- **Jdenticon**: another open-source identicon library. Produces ~874k distinct icons (vs. ~295k for minidenticons). A future revision of this SIP MAY switch renderers; the hash specification is independent of the renderer.
- **Sourcify**: verifies EVM contract source against deployed bytecode. Useful precedent for canonical-source conventions. This SIP intentionally skips the verification step because Stacks deploys source directly, not bytecode.

# Backwards Compatibility

This is a new off-chain convention. There is no on-chain consensus change and no breaking impact on existing contracts, wallets, or explorers. Implementations that do not adopt the SIP continue to display contracts as before.

# Activation

This SIP activates once 10 ecosystem participants (wallets, explorers, developer tools or dApps) have publicly implemented and deployed this specification in production.

# Reference Implementations

## TypeScript / browser

JavaScript/TypeScript: Forthcoming (target: May 2026).

## Clarity (self-declaration)

```clarity
(define-read-only (identicon-hash)
  contract-hash? current-contract)
```

A contract MAY call this off-chain to emit its own hash as an event for indexers that prefer to read the hash rather than recompute it.
