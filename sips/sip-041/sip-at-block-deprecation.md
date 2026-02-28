# Preamble

SIP Number: 041

Title: Deprecation of `at-block`

Author(s):

- Francesco Leacche [francesco@stackslabs.com](mailto:francesco@stackslabs.com)

Status: Draft

Consideration: Technical

Type: Consensus

Layer: Consensus (hard fork)

Created: 2026-02-20

License: BSD-2-Clause

Sign-off:

Discussions-To:

- https://forum.stacks.org/t/chain-state-pruning-and-at-block-proposed-change/18685

# Abstract

This SIP deprecates the at-block built-in in Clarity, effective from Epoch 3.4. After activation, new contracts that reference at-block will fail during static analysis, and existing contracts that invoke it will fail at runtime. This removes the only mechanism that requires nodes to retain the full historical MARF, enabling future chainstate pruning.

# Copyright

This SIP is made available under the terms of the BSD-2-Clause license, available at [https://opensource.org/licenses/BSD-2-Clause](https://opensource.org/licenses/BSD-2-Clause). This SIP's copyright is held by the Stacks Open Internet Foundation.

# Introduction

The `at-block` function in Clarity (originally defined in SIP-002) allows contracts to evaluate read-only expressions against the chain state as it existed at a specific historical block. Its signature is:

```
(at-block id-block-hash expr)
```

Where `id-block-hash` is a 32-byte buffer identifying a Stacks block, and `expr` is a read-only expression to evaluate in the context of that block's state.

Currently, `at-block` can reference any block in the chain's history, all the way back to the genesis block. This unbounded lookback forces every Stacks node to maintain the full historical MARF, tracking the value of every key at every point in history.

On mainnet, the chainstate has grown to approximately 1 TB, of which roughly 95% is consumed by the MARF's historical data. This growth has accelerated significantly since the activation of Nakamoto, making chainstate storage an increasingly urgent concern for node operators. As of 02/20/26, the chain grows by ~2.73 GB/day.

Deprecating `at-block` entirely removes the only mechanism that requires nodes to retain this history and is a prerequisite for future MARF pruning.

## Design Goals

1. Remove the ability for contracts to query arbitrary historical chain state via `at-block`.
2. Enable future MARF pruning by eliminating the only built-in that requires retention of the full historical state.

# Specification

Starting from Epoch 3.4, `at-block` is disabled across all Clarity versions. The enforcement mechanism differs depending on the Clarity version and execution phase.

## Static Analysis (New Deployments)

In Epoch 3.4+, any contract that references `at-block` will be rejected during analysis:

- **Clarity 1–4:** The type checker rejects `at-block` with `StaticCheckErrorKind::AtBlockUnavailable`. The keyword remains syntactically present in the language surface, but is gated by epoch.
- **Clarity 5+:** `at-block` is removed from the set of registered native functions entirely, so the analyzer rejects it as `UnknownFunction("at-block")`.

In both cases, the deployment transaction is included in the block, it fails, and the miner collects the fee.

## Runtime (Existing Contracts)

When an already-deployed Clarity 1–4 contract invokes `at-block` during Epoch 3.4 or later, the VM immediately aborts with a `RuntimeCheckError` of kind `AtBlockUnavailable`, without evaluating the block hash argument or the closure. The enclosing transaction is included in the block, it fails, and the miner collects the fee.

This only applies to Clarity 1–4, since Clarity 5+ contracts cannot contain `at-block` references (they would have been rejected at deploy time).

## Epoch Gating

The `AtBlockUnavailable` behavior is enforced exclusively in Epoch 3.4 and later. Blocks produced before the activation height are validated using the prior rules, regardless of when they are replayed. No previously valid block is invalidated by this change.

## Impact on Existing Contracts

Any deployed contract that calls `at-block` will begin receiving runtime errors after Epoch 3.4 activates. The practical usage of `at-block` on mainnet is limited, and affected contracts can be redeployed without `at-block` calls prior to activation.

# Related Work

- [SIP-002](https://github.com/stacksgov/sips/blob/main/sips/sip-002/sip-002-smart-contract-language.md) defines the Clarity smart contract language, including the original unbounded `at-block` built-in function.
- This SIP will activate in Epoch 3.4 together with SIP-039 and SIP-040.

# Backwards Compatibility

This SIP introduces a breaking change: after Epoch 3.4 activates, `at-block` cannot be used successfully in any Clarity version. This is an intentional and necessary trade-off to enable future chainstate pruning.

# Activation

This SIP will be a rider on SIP-039. It will be considered activated if and only if SIP-039 is activated and, as such, should be considered in the vote specified therein.

# Reference Implementation

Implementation of this SIP is in [at-block deprecation](https://github.com/stacks-network/stacks-core/pull/6937).
