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

Hash-based identicons are a well-understood solution to this problem (see `identicon`, `jdenticon`, `blockies`, the GitHub default avatar). What is missing on Stacks is a consensus on *which* bytes get hashed and *which* renderer is used, so that the same contract produces the same icon everywhere it is shown.

This SIP proposes that consensus. It does not propose any consensus change to the Stacks blockchain — the specification is an off-chain convention followed by wallets, explorers, and apps.

# Specification

## 1. Canonical source

The canonical form of a contract's source code is the byte-for-byte output of `clarinet format` invoked with default settings, against the contract's `.clar` source file.

- Formatters MUST normalize line endings to `\n` (LF).
- Formatters MUST produce a final trailing `\n`.
- Comments (`;;` and `;;;`) are part of the source and are preserved by `clarinet format`. They are hashed.
- The canonical form is UTF-8 encoded.

Implementations that do not have access to a Clarinet formatter (for example, browser-only apps fetching source from `/v2/contracts/source`) SHOULD hash the source as returned by the node, assuming the contract author deployed `clarinet format`-formatted source. Implementations MAY display a "source not canonicalized" warning next to the identicon when the returned source deviates from a heuristic check (trailing whitespace, mixed line endings, tabs mixed with spaces).

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

Off-chain implementations MUST NOT rely on any on-chain value; the hash is always derived from the deployed source.

## 3. Rendering

The identicon is rendered with the **`minidenticons`** library, used in its default configuration:

- Library: `minidenticons` (https://github.com/laurentpayot/minidenticons), version 4.x or later.
- Function: `minidenticonSvg(seed, saturation, lightness)`.
- Arguments:
  - `seed`: the lowercase hex-encoded identicon hash from §2.
  - `saturation`: default (`50`).
  - `lightness`: default (`50`).
- Output: an SVG string, 5×5 symmetric grid.

Implementations MAY override saturation and lightness to match their theme, but the seed MUST remain the hex-encoded hash so the grid pattern stays constant. A light and a dark theme that agree on the seed will display the same silhouette in different colors, which is the intended behavior.

## 4. Contract ID display

When space permits, implementations SHOULD display the identicon adjacent to the contract principal (`{deployer}.{name}`). The identicon is advisory: it supplements, not replaces, the full principal.

## 5. Network isolation

Identicons are a function of source code only, not of network. A contract deployed on testnet and mainnet from identical formatted source will render the same icon. Implementations SHOULD label the network separately.

# Related Work

- **Ethereum Blockies** (`ethereum-blockies`): hashes the lowercase hex address, not the bytecode. Identical code at different addresses renders differently — the opposite trade-off from this SIP.
- **Jdenticon**: another open-source identicon library. Produces ~874k distinct icons (vs. ~295k for minidenticons). A future revision of this SIP MAY switch renderers; the hash specification is independent of the renderer.
- **Sourcify**: verifies EVM contract source against deployed bytecode. Useful precedent for canonical-source conventions. This SIP intentionally skips the verification step because Stacks deploys source directly, not bytecode.

# Backwards Compatibility

This is a new off-chain convention. There is no on-chain consensus change and no breaking impact on existing contracts, wallets, or explorers. Implementations that do not adopt the SIP continue to display contracts as before.

# Activation

This SIP activates once 10 ecosystem participants who display a set of contracts have implemented this specification.

# Reference Implementations

## TypeScript / browser

TODO

## Clarity (self-declaration)

```clarity
(define-read-only (identicon-hash)
  contract-hash? current-contract)
```

A contract MAY call this off-chain to emit its own hash as an event for indexers that prefer to read the hash rather than recompute it.
