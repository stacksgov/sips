# Preamble

SIP Number: XXX

Title: Epoch 4.1 and Clarity 7

Author(s):

- Hank Stoever <hank@stackslabs.com>

Status: Draft

Consideration: Technical

Type: Consensus

Layer: Consensus (hard fork)

Created: 2026-10-21

License: BSD-2-Clause

Sign-off:

Discussions-To:

# Abstract

This SIP defines the consensus changes that will activate with Stacks epoch 4.1.

The SIP introduces Clarity 7, which includes a number of changes to how contracts are analyzed and type checked. These changes improve the robustness of Clarity's overall type safety. Because of these improvements, new contracts after activation may only be deployed with Clarity 7.

The SIP also defines the move away from using a threshold-based deposit address for sBTC, which miners use to send BTC to the `pox-5` contract. After activation, miners will deposit to a pay-to-taproot (P2TR) multisig address.

# Copyright

This SIP is made available under the terms of the BSD-2-Clause license,
available at https://opensource.org/licenses/BSD-2-Clause. This SIP's copyright
is held by the Stacks Open Internet Foundation.

# Introduction

This SIP fixes known issues in the implementation of the Clarity VM. Except where noted, it does not change the intended behavior of the language. Because each fix changes which contracts can be deployed, the results of contract calls, or whether a transaction is valid, the fixes must activate at an epoch boundary. They fall into these categories:

1. **Type-checking soundness:** In a few cases, the type checker accepted code whose runtime values didn't match their inferred types, or skipped checking some expressions entirely. These checks are tightened so that the inferred types match what happens at runtime.
2. **Analysis/runtime consistency:** The analyzer and the runtime sometimes resolved the same code differently. As a result, a contract could pass analysis and then behave unexpectedly at runtime. The runtime and the analyzer now follow the same rules.
3. **Consistent value limits:** Some values were not held to the rules that apply to values built in Clarity. They are now enforced no matter where a value comes from.
4. **Error classification and cost accounting:** Some failures made a transaction rejectable when they should have let it be included in a block as a failure, and some work was done without being charged. These errors are now includable where appropriate, and costs are charged for all the work performed, including type checking and the identifiers carried by trait and principal values.

To provide better guarantees about type safety and consistency in the future, this SIP also defines that newly deployed contracts may only be deployed with the latest version of Clarity.

# Specification

## Clarity Type Soundness and Runtime consistency

Analysis changes affect only contracts deployed after activation; runtime changes, noted below, apply to all contracts.

### Removal of versioned contract deploys

After activation, users will no longer be able to deploy contracts with a specified version. Instead, newly deployed contracts will only be deployed with the latest Clarity version. This ensures greater consistency in Clarity's type checking and runtime behavior.

### Joining tuples with different fields

The type checker let tuples with different fields unify to a narrower type, so a value could carry fields its static type didn't have. Before 4.1, `fetch` is typed `{a: uint}` but returns `{a: u1, b: true}`, and the hidden `b` then shows up through `merge`, `is-eq` and list construction. From 4.1 this fails analysis.

```clarity
(define-read-only (fetch)
  (if false {a: u1} {a: u1, b: true}))
```

### `fold` results

An empty sequence makes `fold` return its initial value unchanged, but the result type only came from the callback's return type. Here the callback's type is `(optional ...)` with only `none`, so `default-to u1` is typed `uint`. At runtime, `fetch` returns `"hello"`. After activation, this will fail analysis.

```clarity
(define-private (keep-none (x (buff 1)) (acc (optional (string-ascii 5)))) none)
(define-read-only (fetch)
  (default-to u1 (fold keep-none 0x (some "hello"))))
```

### Exact argument counts

Extra arguments to user-defined functions were never type-checked, but they were evaluated. That could even cause an early return before the runtime's argument-count check ran:

```clarity
(define-private (one (x uint)) x)
(define-public (escape)
  (begin
    (one u1 (begin (var-set touched true) (asserts! false (ok true))))
    (ok false)))
```

This also applies to native Clarity functions, where the user could provide extra arguments. For example, `(map-set m u1 u2 u3)` will now fail analysis.

### `replace-at?` with zero-length values

A `(buff 1)` element type accepts `0x`, so `(replace-at? 0x0102 u0 0x)` passed analysis and then failed at runtime. It's now a type error when the element is empty at analysis time.

### `let` names vs globals

The runtime only checked `let` names against function names, not against other globals. Now every global is checked. If a clash still happened, the global wins, which is what the type checker already assumed.

### Using a contract's own traits during deployment

Previously, trait lookups always used a database lookup, so calling a self-defined trait during deployment would fail. Previously, the following example would fail with `NoSuchContract`, but will work after activation.

```clarity
(define-trait trait-1 ((foo () (response bool uint))))
(define-private (bar (f <trait-1>)) (unwrap-panic (contract-call? f foo)))
(bar .target)
```

### Exact tuple fields when decoding

`from-consensus-buff?` could build a tuple with duplicate keys, which breaks its own declared type. Typed decoding now requires exactly the declared fields; otherwise `from-consensus-buff?` returns `none`.

### 40-byte contract names

Contract names longer than 40 bytes are now rejected everywhere:

- transaction arguments and recipients
- NFT post-conditions
- `from-consensus-buff?` (returns `none`)
- `principal-destruct?` (errors)

### Costs for type checking now run before read-only checks

Previously, contract analysis would first run a read-only check before type analysis, which doesn't incur any cost. Now, type analysis occurs before read-only checks, so contracts that fail analysis are now always charged for type checking.

### Changes to costs for contract and trait identifiers

Trait values and contract principals carry identifiers (such as a contract name and trait name), and those values didn't contribute to cost and memory charges. After epoch 4.1, these are charged appropriately. This also affects cost computations for existing values.

### Reserved names

After activation, a function may use a reserved name only to implement a method of a trait defined in an older Clarity version. New uses of `define-trait` with reserved names are rejected.

### Includable transactions

"Includable" transactions refer to transactions that may be included as failed transactions in a block, and still incur a fee. SIP-039 introduced the concept of includable transactions, and began the process of converting all known rejectable transactions to be includable. New classes of includable transactions are:

- An empty `replace-at?` element at runtime
- Using `restrict-assets?` with `with-all-assets-unsafe`
- `block-reward` now returns `none` until the value is written, instead of resulting in a rejectable transaction. Note that this may not result in a failed transaction.

## sBTC deposit address v2 for miner commits

Since epoch 4.0, miners send BTC to the `pox-5` contract by spending to an sBTC deposit address. The current miner code creates this address using the aggregate key published by the sBTC signers.

After activation, in the first reward cycle that starts after epoch 4.1, miners will use the v2 sBTC deposit address format. This new format utilizes the public keys of sBTC signers to generate a k-of-n multisig pay-to-taproot address.

For more information on the v2 deposit address format, refer to [sbtc#2142](https://github.com/stacks-sbtc/sbtc/issues/2142).

# Related Work

This SIP builds upon the existing definitions of the Clarity language:

- [SIP-002 (Clarity 1)](../sip-002/sip-002-smart-contract-language.md)
- [SIP-015 (Clarity 2)](../sip-015/sip-015-network-upgrade.md)
- [SIP-021 (Clarity 3)](../sip-021/sip-021-nakamoto.md)
- [SIP-033 (Clarity 4)](../sip-033/sip-033-clarity4.md)
- [SIP-039 (Clarity 5)](../sip-039/sip-039-clarity5.md)
- [SIP-044 (Clarity 6)](../sip-044/sip-044-clarity6.md)

It also builds upon the introduction of Bitcoin Staking as it relates to how miners send funds through sBTC, as defined in [SIP-045](../sip-045/sip-045-pox-5-bitcoin-staking.md).

# Backwards Compatibility

There are a number of consensus-breaking changes in this SIP that require a hard fork. These include a variety of changes to the Clarity language, included in Clarity 7 and described in this SIP.

The removal of versioned smart contract deploys may require wallets and developer tools to be updated.

The new deposit address format for sBTC that will be used by miners may require tooling that monitors PoX-5 deposit transactions to be updated.

# Activation

This SIP should be activated upon receiving sign off from the Technical CAB, ensuring that the details described herein are correct.

# Reference Implementation

All functionality proposed in this SIP is implemented or in progress in the
[`main` branch](https://github.com/stacks-network/stacks-core/tree/main)
on https://github.com/stacks-network/stacks-core.
