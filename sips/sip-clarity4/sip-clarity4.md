# Preamble

**SIP Number:** XYZ

**Title:** Clarity Smart Contract Language, version 4

**Authors:**

- Marvin Janssen <marvin@ryder.id>
- Adriano Di Luzio <adriano@bitcoinl2labs.com>
- Brice Dobry <brice@hiro.so>

**Consideration:** Technical

**Type:** Consensus

**Status:** Draft

**Created:** 2025-06-20

**License:** CC0-1.0

**Sign-off:**

**Discussions-To:** https://github.com/stacksgov/sips

# Abstract

This SIP details Version 4 of the Clarity Smart Contract Language, which
introduces new operations to make it easier to build secure Smart Contracts on
Stacks.

# License and Copyright

This SIP is made available under the terms of the CC0 (Creative Commons Zero)
license, available at https://opensource.org/licenses/CC0-1.0. This SIP’s
copyright is held by the Stacks Open Internet Foundation.

# Introduction

The Clarity smart contract language powers decentralized applications across a
wide range of domains. Over years of real-world use, developers have encountered
several pain points when interacting with other, sometimes untrusted, contracts.
Securely calling unknown contracts unlocks powerful use cases, but demands
careful safeguards.

This SIP addresses common feedback and requests from builders in the ecosystem.
It proposes new Clarity features to make it easier for developers to write
secure and composable smart contracts. Specifically, it proposes:

1. **A new Clarity function to fetch a contract's code body.** This enables
   on-chain code inspection, for example allowing contract A to validate that
   contract B follows a specific template and is therefore safe to interact
   with. This is especially useful for enabling safe, trustless self-listing of
   tokens in marketplaces.
2. **A new Clarity function to limit asset access within a body of code.** This
   allows a contract to safely call arbitrarty external contracts (e.g. passed
   in as traits) while ensuring that the executed code has only limited access
   to the contract's assets, protecting against potential malicious behavior.

# Specification

## Fetching a contract body: `code-body-of?`

Originally proposed [here](https://github.com/clarity-lang/reference/issues/88).

`code-body-of?` returns, on success, the code body of the contract principal
specified as input. Useful to prove that a deployed contract respects specific
invariants and design properties.

- **Input**: `principal`
- **Output**: `(response (string-ascii 1048576) uint)`
- **Signature**: `(code-body-of? contract-principal)`
- **Description**: Returns the code body of the contract principal specified as
  input, or an error if the principal is not a contract, does not exist, or the
  body is too large. Returns:
  - `(ok "code body string")` on success.
  - `(err u0)` if the principal is not a contract principal.
  - `(err u1)` if the specified contract does not exist.
  - `(err u2)` if the code body does not fit in the string-ascii.
- **Example**:
  ```clarity
  (code-body-of? 'SP2QEZ06AGJ3RKJPBV14SY1V5BBFNAW33D96YPGZF.BNS-V2)
  ```

## Limiting asset access: `with-assets`

Originally proposed [here](https://github.com/clarity-lang/reference/issues/64).

`with-assets` allows a contract to limit a body of code to only have access to a
specific set of its assets, preventing unauthorized access to those not
explicitly listed. This is particularly useful when calling external contracts
within an `as-contract` scope, as it ensures that the called code cannot
unexpectedly move the contract's assets. Within the body of code, attempts to
transfer or burn assets not listed in the `with-assets` call will result in an
error, in the same way as if the contract did not own those assets.

- **Input**:

```
{
  stx: uint,
  fts: (list
    32
    {
      contract: principal,
      token: (string-ascii 128),
      amount: uint,
    }
  ),
  nfts: (list
    32
    {
      contract: principal,
      token: (string-ascii 128),
      identifier: uint,
    }
  ),
}
```

`A` (result type of the body of code)

- **Output**: `A` (result type of the body of code)
- **Signature**: `(with-assets assets body)`
- **Description**: Executes the body of code with the specified assets available
  for transfer or burn. The assets are defined as a map containing:

  - `stx`: The amount of STX available for transfer.
  - `fts`: A list of fungible tokens, each defined by its contract principal,
    token name, and amount.
  - `nfts`: A list of non-fungible tokens, each defined by its contract
    principal, token name, and identifier.

  Within the body of code, only the assets listed in the `with-assets` call can
  be transferred or burned. Any attempt to access other assets will result in an
  error, as though the contract did not own those assets. The return value of
  the body of code is returned as the result of the `with-assets` call.

# Related Work

Not applicable.

# Backwards Compatibility

Because this SIP introduces new Clarity operators, it is a consensus-breaking
change. A contract that uses one of these new operators would be invalid before
this SIP is activated, and valid after it is activated.

# Activation

TBD

# Reference Implementations

TBD
