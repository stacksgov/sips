# Preamble

SIP Number: 035

Title: Clarification of Clarity's `secp256r1-verify` Behavior

Author(s):

- Brice Dobry <brice@stackslabs.com>

Status: Draft

Consideration: Technical

Type: Informational

Layer: Consensus

Created: 2025-12-15

License: BSD-2-Clause

Sign-off:

Discussions-To:

- https://github.com/stacksgov/sips/pull/247

# Abstract

A discrepancy has been identified between the behavior described in SIP-033 for
the `secp256r1-verify` function added in Clarity 4 and the actual behavior
implemented and activated in Epoch 3.3.

# Copyright

This SIP is made available under the terms of the BSD-2-Clause license,
available at https://opensource.org/licenses/BSD-2-Clause. This SIP’s copyright
is held by the Stacks Open Internet Foundation.

# Introduction

In SIP-033, `secp256r1-verify` was described as:

> The `secp256r1-verify` function verifies that the provided `signature` of the
> `message-hash` was produced by the private key corresponding to `public-key`.
> The `message-hash` is the SHA-256 hash of the message. The `signature` must be
> 64 bytes (compact signature). Returns `true` if the signature is valid for the
> given `public-key` and message hash, otherwise returns `false`.

The implementation that activated with Clarity 4 in epoch 3.3 however introduces
a double-hash -- the `message-hash` that is passed in is again SHA256 hashed,
and the resulting hash is used to verify the signature. Changing the behavior is
a consensus-change, requiring a hard fork, so the intention of this SIP is
simply informational, to clarify and document this discrepancy in behavior, and
to prepare the ecosystem for a future SIP that will define a new version of
Clarity (activated in a new epoch) which will implement the originally intended
behavior.

# Specification

The `secp256r1-verify` documentation will be updated from the existing:

> The `secp256r1-verify` function verifies that the provided signature of the
> message-hash was signed with the private key that generated the public key.
> `message-hash` is typically the `sha256` of a message and `signature` is the
> raw 64-byte signature. High-S signatures are allowed. Note that this is NOT
> the Bitcoin (or default Stacks) signature scheme, secp256k1, but rather the
> NIST P-256 curve (also known as secp256r1).

to:

> The `secp256r1-verify` function verifies that the provided signature of the
> message-hash was signed with the private key that generated the public key.
> **In Clarity 4, the `message-hash` is SHA256 hashed again internally before
> verification (i.e. double SHA256)**. `message-hash` is typically the `sha256`
> of a message and `signature` is the raw 64-byte signature. High-S signatures
> are allowed. Note that this is NOT the Bitcoin (or default Stacks) signature
> scheme, secp256k1, but rather the NIST P-256 curve (also known as secp256r1).

Developers wishing to verify signatures using this function in Clarity 4 must
ensure that the signature was generated over the double-hash of the original
message, specifically (pseudo-code):

```
Signature = ECDSA_Sign(SHA256(SHA256(original_message)), private-key)
```

# Related Work

[SIP-033](../sip-033/sip-033-clarity4.md) describes the originally intended
behavior of `secp256r1-verify`.

# Backwards Compatibility

No technical changes will be made based on this SIP, other than documentation
changes.

# Activation

This SIP should be activated upon receiving sign off from the Technical CAB,
ensuring that the details described herein are correct.

# Reference Implementation

N/A
