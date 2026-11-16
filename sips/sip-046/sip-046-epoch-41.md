# Preamble

SIP Number: 046

Title: Epoch 4.1: Clarity 7, sBTC deposit address v2, and rejection of defunct Bitcoin operations

Author(s):

- Hank Stoever <hank@stackslabs.com>

Status: Accepted

Consideration: Technical

Type: Consensus

Layer: Consensus (hard fork)

Requires: 044, 045

Created: 2026-10-21

License: BSD-2-Clause

Sign-off:

- Werner <werner@trustmachines.co>, SIP Editor; 2026-11-13

Discussions-To:

- https://github.com/stacksgov/sips/pull/284

# Abstract

This SIP defines the consensus changes that will activate with Stacks epoch 4.1.

The SIP introduces Clarity 7, which includes a number of changes to how contracts are analyzed and type checked. These changes improve the robustness of Clarity's overall type safety. Because of these improvements, contracts deployed after activation may only be deployed with the latest Clarity version, which is Clarity 7 in epoch 4.1.

The SIP also defines the move away from using a threshold-based deposit address for sBTC, which miners use to send BTC to the `pox-5` contract. After activation, miners will deposit to a pay-to-taproot (P2TR) multisig address.

Finally, the SIP rejects the `stack-stx`, `delegate-stx` and `vote-for-aggregate-key` Bitcoin operations, which target PoX contracts that `pox-5` has superseded.

# Copyright

This SIP is made available under the terms of the BSD-2-Clause license,
available at https://opensource.org/licenses/BSD-2-Clause. This SIP's copyright
is held by the Stacks Open Internet Foundation.

# Introduction

This SIP fixes known issues in the implementation of the Clarity VM. Except where noted, it does not change the intended behavior of the language. Because each fix changes which contracts can be deployed, the results of contract calls, or whether a transaction is valid, the fixes must activate at an epoch boundary. They fall into these categories:

1. **Type-checking soundness:** In a few cases, the type checker accepted code whose runtime values did not match their inferred types, or skipped checking some expressions entirely. These checks are tightened so that the inferred types match what happens at runtime.
2. **Analysis/runtime consistency:** The analyzer and the runtime sometimes resolved the same code differently. As a result, a contract could pass analysis and then behave unexpectedly at runtime. The runtime and the analyzer now follow the same rules.
3. **Consistent value limits:** Some values were not held to the rules that apply to values built in Clarity. They are now enforced no matter where a value comes from.
4. **Error classification and cost accounting:** Some failures made a transaction rejectable when they should have let it be included in a block as a failure, and some work was done without being charged. These errors are now includable where appropriate, and costs are charged for all the work performed, including type checking and the identifiers carried by trait and principal values.

To provide better guarantees about type safety and consistency in the future, this SIP also defines that contracts deployed after activation may only be deployed with the latest Clarity version.

This SIP also changes the sBTC deposit address that miners use to send BTC to the `pox-5` contract, from an address derived from the sBTC signers' aggregate key to a k-of-n multisig pay-to-taproot (P2TR) address.

Finally, this SIP rejects the `stack-stx`, `delegate-stx` and `vote-for-aggregate-key` Bitcoin operations, which have no purpose under `pox-5`.

# Specification

## Clarity type soundness and runtime consistency

Analysis changes affect only contracts deployed after activation; runtime changes, noted below, apply to all contracts.

### Removal of versioned contract deploys

After activation, contracts may only be deployed with the latest Clarity version, which is Clarity 7 in epoch 4.1. This removes the choice of version offered by the Versioned Smart Contract payload (payload type ID `0x06`) defined in [SIP-015](../sip-015/sip-015-network-upgrade.md). After activation, a transaction with this payload is invalid and cannot be included in a block. This ensures greater consistency in Clarity's type checking and runtime behavior.

### Joining tuples with different fields

The type checker let tuples with different fields unify to a narrower type, so a value could carry fields its static type did not have. Before activation, `fetch` is typed `{a: uint}` but returns `{a: u1, b: true}`, and the hidden `b` then shows up through `merge`, `is-eq` and list construction. After activation, tuple types with different fields no longer unify, so this fails analysis.

```clarity
(define-read-only (fetch)
  (if false {a: u1} {a: u1, b: true}))
```

### `fold` results

An empty sequence makes `fold` return its initial value unchanged, but the result type only came from the callback's return type. Here the callback's type is `(optional ...)` with only `none`, so `default-to u1` is typed `uint`. At runtime, `fetch` returns `"hello"`. After activation, the result type of `fold` is the least supertype of the initial value's type and the callback's return type. Here that is `(optional (string-ascii 5))`, so `default-to u1` fails analysis.

```clarity
(define-private (keep-none (x (buff 1)) (acc (optional (string-ascii 5)))) none)
(define-read-only (fetch)
  (default-to u1 (fold keep-none 0x (some "hello"))))
```

### Exact argument counts

Extra arguments to user-defined functions were never type-checked, but they were evaluated. That could even cause an early return before the runtime's argument-count check ran:

```clarity
(define-data-var touched bool false)
(define-private (one (x uint)) x)
(define-public (escape)
  (begin
    (one u1 (begin (var-set touched true) (asserts! false (ok true))))
    (ok false)))
```

After activation, a call with the wrong number of arguments fails analysis. This also applies to native Clarity functions, where the user could provide extra arguments. For example, `(map-set m u1 u2 u3)` will now fail analysis.

### `replace-at?` with zero-length values

A `(buff 1)` element type accepts `0x`, so `(replace-at? 0x0102 u0 0x)` passed analysis and then failed at runtime. It is now a type error when the element is empty at analysis time.

### `let` names vs globals

The runtime only checked `let` names against function names, not against other globals. Now every global is checked. If a clash still happened, the global wins, which is what the type checker already assumed.

### Using a contract's own traits during deployment

Previously, trait lookups always used a database lookup, so calling a self-defined trait during deployment would fail. The following example failed with `NoSuchContract` and succeeds after activation.

```clarity
(define-trait trait-1 ((foo () (response bool uint))))
(define-private (bar (f <trait-1>)) (unwrap-panic (contract-call? f foo)))
(bar .target)
```

### Exact tuple fields when decoding

`from-consensus-buff?` could build a tuple with duplicate keys, which breaks its own declared type. Typed decoding now requires exactly the declared fields; otherwise `from-consensus-buff?` returns `none`.

### 40-byte contract names

This SIP amends the Clarity value encoding of contract principals in [SIP-005](../sip-005/sip-005-blocks-and-transactions.md), which allows contract names of up to 128 bytes. After activation, contract names in contract principals inside Clarity values, including token-transfer and coinbase recipients, are limited to 40 bytes. Values already stored in chainstate stay readable. Contract-name fields encoded as a bare contract name (call targets, deploys, post-condition principals and asset identifiers) have been limited to 40 bytes since Stacks 2.0, despite the 128-byte limit stated in SIP-005.

Contract names longer than 40 bytes are now rejected everywhere:

- transaction arguments and recipients
- the asset value in NFT post-conditions
- `from-consensus-buff?` (returns `none`)
- `principal-destruct?` (errors)

### Type checking now runs before read-only checks

Previously, contract analysis ran the read-only check first. That check incurs no cost. Now, type analysis occurs before read-only checks, so contracts that fail analysis are now always charged for type checking.

### Changes to costs for contract and trait identifiers

Trait values and contract principals carry identifiers (such as a contract name and trait name), and those identifiers did not contribute to cost and memory charges. After epoch 4.1, these are charged appropriately. This also affects cost computations for existing values.

### Reserved names

After activation, a function may use a reserved name only to implement a method of a trait defined in an older Clarity version. New uses of `define-trait` with reserved names are rejected.

### Includable transactions

Includable transactions are transactions that may be included as failed transactions in a block, and still incur a fee. SIP-039 introduced the concept of includable transactions, and began the process of converting all known rejectable transactions to be includable. New classes of includable transactions are:

- An empty `replace-at?` element at runtime.
- Using `restrict-assets?` with `with-all-assets-unsafe`.
- `block-reward` now returns `none` until the value is written, instead of resulting in a rejectable transaction. Note that this may not result in a failed transaction.

## sBTC deposit address v2 for miner commits

Since epoch 4.0, miners send BTC to the `pox-5` contract by spending to an sBTC deposit address. The current miner code creates this address using the aggregate key published by the sBTC signers.

After activation, in the first reward cycle that starts after epoch 4.1 activates, miners will use the v2 sBTC deposit address format. This new format utilizes the public keys of sBTC signers to generate a k-of-n multisig pay-to-taproot address.

For more information on the v2 deposit address format, refer to [sbtc#2142](https://github.com/stacks-sbtc/sbtc/issues/2142).

## Rejection of defunct Bitcoin operations

Stacks supports a set of operations that are sent as Bitcoin transactions. Three of these were designed for `pox-4` and `.signers-voting`, and have no purpose under `pox-5`:

- `stack-stx`
- `delegate-stx`
- `vote-for-aggregate-key`

Before epoch 4.1, these operations are accepted by the sortition DB and processed by the Stacks chainstate:

- `stack-stx` and `delegate-stx` call the active PoX contract, `pox-5`, which does not define these functions. The call fails and is rolled back without a receipt, so the operation has no effect.
- `vote-for-aggregate-key` calls `.signers-voting`, which still executes and produces a receipt, but nothing uses the result.

After activation, these operations are rejected if the Bitcoin block they are mined in is in epoch 4.1 or later. They are not recorded in the sortition DB, so they are excluded from the burn block's consensus hash and the Stacks chainstate never processes them. As a result, `vote-for-aggregate-key` operations no longer produce receipts. Operations mined before epoch 4.1 are still accepted, so replaying the chain history gives the same results.

# Related Work

This SIP builds upon the existing definitions of the Clarity language:

- [SIP-002 (Clarity 1)](../sip-002/sip-002-smart-contract-language.md)
- [SIP-015 (Clarity 2)](../sip-015/sip-015-network-upgrade.md)
- [SIP-021 (Clarity 3)](../sip-021/sip-021-nakamoto.md)
- [SIP-033 (Clarity 4)](../sip-033/sip-033-clarity4.md)
- [SIP-039 (Clarity 5)](../sip-039/sip-039-clarity5.md)
- [SIP-044 (Clarity 6)](../sip-044/sip-044-clarity6.md)

It also builds upon the introduction of Bitcoin Staking as it relates to how miners send funds through sBTC, introduced in [SIP-045](../sip-045/sip-045-pox-5-bitcoin-staking.md).

It amends the Clarity value encoding of contract principals in
[SIP-005](../sip-005/sip-005-blocks-and-transactions.md) and removes the
Versioned Smart Contract transaction payload defined in
[SIP-015](../sip-015/sip-015-network-upgrade.md).

# Backwards Compatibility

There are a number of consensus-breaking changes in this SIP that require a hard fork. These include a variety of changes to the Clarity language, included in Clarity 7 and described in this SIP.

The removal of versioned smart contract deploys may require wallets and developer tools to be updated.

The new deposit address format for sBTC that will be used by miners may require tooling that monitors PoX-5 deposit transactions to be updated.

# Activation

Users can vote to approve this SIP with either their staked STX or with liquid
STX, or both.

In order for this SIP to activate, the following criteria must be met:

- At least 80 million staked STX must participate in the vote, and at least 80%
  of all staked STX committed by voting must be in favor of the proposal (vote
  "yes").
- At least 80% of all liquid STX committed by voting must be in favor of the
  proposal (vote "yes").

All STX holders vote by sending Stacks dust to the corresponding Stacks address
from the account where their STX are held (staked or liquid). Voting power is
determined by a snapshot of the amount of STX (staked and liquid) in that
account at Bitcoin block height 976,450, the height at which voting starts.
This prevents the same STX from being transferred between accounts and used to
vote twice.

Bitcoin stakers vote the same way, from the Stacks account that registered
their bond. The STX locked in that account counts as staked STX. There is no
Bitcoin voting transaction for this vote.

| Vote | Stacks                                | ASCII Encoding         | Msg        |
| ---- | ------------------------------------- | ---------------------- | ---------- |
| yes  | `SP00000000001WPAWSDEDMQ0B9M6VRF7M9A` | `7965732d7369702d3436` | yes-sip-46 |
| no   | `SP000000000006WVSDEDMQ0B9M6VQKRB6B`  | `6e6f2d7369702d3436`   | no-sip-46  |

Voting starts at Bitcoin block height 976,450 and ends at Bitcoin block height
978,450. Votes confirmed outside this window are not counted. If the criteria
are not met at the end of Bitcoin block height 978,450, the SIP is Rejected.

## Activation Height

If the SIP is approved, epoch 4.1 will activate at Bitcoin block height
979,500.

# Reference Implementation

All functionality proposed in this SIP is implemented or in progress in the [`main` branch](https://github.com/stacks-network/stacks-core/tree/main) of [stacks-core](https://github.com/stacks-network/stacks-core).
