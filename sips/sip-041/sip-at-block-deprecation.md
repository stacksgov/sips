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

This SIP deprecates the `at-block` built-in in Clarity. Starting from Epoch 3.4, all invocations of `at-block` will fail unconditionally, regardless of which block is referenced or which Clarity version the contract was deployed with. New contracts that use `at-block` will fail static analysis and cannot be deployed. Existing contracts that invoke `at-block` will receive a runtime error.

# Copyright

This SIP is made available under the terms of the BSD-2-Clause license, available at [https://opensource.org/licenses/BSD-2-Clause](https://opensource.org/licenses/BSD-2-Clause). This SIP's copyright is held by the Stacks Open Internet Foundation.

# Introduction

The `at-block` function in Clarity (originally defined in SIP-002) allows contracts to evaluate read-only expressions against the chain state as it existed at a specific historical block. Its signature is:

```
(at-block id-block-hash expr)
```

Where `id-block-hash` is a 32-byte buffer identifying a Stacks block, and `expr` is a read-only expression to evaluate in the context of that block's state.

Currently, `at-block` can reference any block in the chain's history, all the way back to the genesis block. This unbounded lookback forces every Stacks node to maintain the full historical MARF, tracking the value of every key at every point in history.

On mainnet, the chainstate has grown to approximately 1 TB, of which roughly 95% is consumed by the MARF's historical data. This growth has accelerated significantly since the activation of Nakamoto, making chainstate storage an increasingly urgent concern for node operators. As of 02/20/26, the chain grows by \~2.73GB/day.

Deprecating `at-block` entirely removes the only mechanism that requires nodes to retain the full MARF history. This is a prerequisite for future MARF pruning and will enable aggressive chainstate reduction.

## Design Goals

1. Remove the ability for contracts to query arbitrary historical chain state via `at-block`.
2. Enable future MARF pruning by eliminating the only built-in that requires retention of the full historical state.

# Specification

Starting from Epoch 3.4, the `at-block` built-in is **disabled entirely**. This is enforced at two levels:

**Static analysis (new deployments):** When a contract is deployed in Epoch 3.4 or later, the type checker rejects any use of `at-block` with a `StaticCheckError` of kind `AtBlockUnavailable`. The deployment transaction is included in the block, it fails, and the miner collects the fee.

**Runtime (existing contracts):** When an already deployed contract invokes `at-block` during Epoch 3.4 or later, the VM immediately aborts with a `RuntimeCheckError` of kind `AtBlockUnavailable`, without evaluating the block hash argument or the closure. The enclosing transaction is included in the block, it fails, and the miner collects the fee.

## Epoch Gating

The deprecation is **only enforced in Epoch 3.4 and later**. For all prior epochs, the existing behavior is preserved. This means:

- Blocks produced before the Epoch 3.4 activation height are validated using the old rules, regardless of when they are replayed.
- Starting at the Epoch 3.4 activation height, any invocation of `at-block`, including from contracts deployed in earlier epochs and earlier Clarity versions, will fail with `AtBlockUnavailable`.

This is an epoch-level behavioral change, not a Clarity-version-level change. A contract deployed using Clarity 1 that calls `at-block` will still be subject to the deprecation when executed during Epoch 3.4. This is necessary because the deprecation is a property of the node's storage guarantees, not a property of the contract's language version.

## Impact on Existing Contracts

Any deployed contract that calls `at-block` will begin receiving runtime errors after Epoch 3.4 activates. This is a semantic change to existing contract behavior.

Based on analysis of historical mainnet transactions, the number of contracts affected is expected to be very small. The practical usage of `at-block` on mainnet is limited, and contracts that do use it can be redeployed without `at-block` calls prior to Epoch 3.4 activation.

# Related Work

- [SIP-002](https://github.com/stacksgov/sips/blob/main/sips/sip-002/sip-002-smart-contract-language.md) defines the Clarity smart contract language, including the original unbounded `at-block` built-in function.
- This SIP will activate in Epoch 3.4 together with SIP-039 and SIP-040.

# Backwards Compatibility

This SIP introduces a breaking change to the existing `at-block` built-in for all Clarity versions when executed in Epoch 3.4 or later.

All contracts that use `at-block`, regardless of the target block, will fail after Epoch 3.4 activates. This is an intentional and necessary trade-off to enable future chainstate pruning.

There are no changes to the chainstate database schemas in this SIP. Everyone who runs a Stacks node today will be able to upgrade to the Epoch 3.4 release and continue operating from their existing chainstate.

# Activation

This SIP will be a rider on SIP-039. It will be considered activated if and only if SIP-039 is activated and, as such, should be considered in the vote specified therein.

# Reference Implementation

Implementation of this SIP is in [at-blcok deprecation](https://github.com/stacks-network/stacks-core/pull/6937).
