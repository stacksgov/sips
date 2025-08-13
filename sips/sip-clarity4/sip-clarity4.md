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

1. **A new Clarity function to fetch the hash of a contract's code body.** This
   enables on-chain contract code validation, for example allowing contract A to
   validate that contract B follows a specific template and is therefore safe to
   interact with. This is especially useful for enabling bridges and
   marketplaces to safely and trustlessly support a dynamic set of assets.
2. **A new Clarity function to allow a contract to set post-conditions to
   protect its assets.** This allows a contract to safely call arbitrary
   external contracts (e.g. passed in as traits) while ensuring that if the
   executed code moves assets beyond those specified, the changes will be rolled
   back.
3. **A new Clarity function to convert simple values into `string-ascii`
   values.** This function will enable developers to easily convert values like
   `bool`s and `principal`s into their ASCII string representations,
   facilitating the generation of string-based messages for interacting with
   cross-chain protocols.

# Specification

## Fetching the hash of a contract body: `contract-hash?`

Originally proposed [here](https://github.com/clarity-lang/reference/issues/88).

`contract-hash?` returns, on success, the SHA-512/256 hash of the code body of
the contract principal specified as input. This is useful to prove that a
deployed contract follows a specific template.

- **Input**: `principal`
- **Output**: `(response (buff 32) uint)`
- **Signature**: `(contract-hash? contract-principal)`
- **Description**: Returns the SHA-512/256 hash of the code body of the contract
  principal specified as input, or an error if the principal is not a contract,
  does not exist, or the body is too large. Returns:
  - `(ok 0x<hash>)`, where `<hash>` is the SHA-512/256 hash of the code body, on
    success
  - `(err u0)` if the principal is not a contract principal
  - `(err u1)` if the specified contract does not exist
- **Example**:
  ```clarity
  (contract-hash? 'SP2QEZ06AGJ3RKJPBV14SY1V5BBFNAW33D96YPGZF.BNS-V2) ;; Returns (ok 0x9f8104ff869aba1205cd5e15f6404dd05675f4c3fe0817c623c425588d981c2f)
  ```

## Limiting asset access: `with-post-conditions`

Originally proposed [here](https://github.com/clarity-lang/reference/issues/64).

`with-post-conditions` allows a contract to specify a set of conditions to check
after the execution of an expression, to ensure that the expression does not
move any assets from the contract that are not explicitly specified. This is
particularly useful when calling external contracts within an `as-contract`
scope, as it ensures that the called code cannot unexpectedly move the
contract's assets.

In order to implement this, a new Clarity type is introduced: `condition`. A
`condition` can be created using the following four new Clarity functions:

- `condition-stx`: Creates a condition that checks STX assets, specifying a
  maximum amount of STX that can be moved.
  - `(condition-stx amount:uint)`
- `condition-ft`: Creates a condition that checks fungible token assets,
  specifying a maximum amount of each token that can be moved.
  - `(condition-ft token-contract:principal amount:uint)`
- `condition-nft`: Creates a condition that checks non-fungible token assets,
  specifying a specific identifier that can be moved. `identifier` can be any
  type.
  - `(condition-nft token-contract:principal identifier:T)`
- `condition-state`: Creates a condition that checks contract state, specifying
  a data-var or map which may be modified.

  - `(condition-state contract-principal:principal name:(string-ascii 128)`

- **Input**:

  - `conditions`:`(list 32 condition)`: A list of conditions to be checked after
    the execution of the body of code.
  - `body`: A Clarity expression to be executed, with return type `A`

- **Output**: `(response A condition)`
- **Signature**: `(with-post-conditions conditions body)`
- **Description**: Executes the expression `body`, then evaluates the specified
  `conditions` to ensure that the assets moved by `body` do not exceed the
  specified limits. Any assets not explicitly specified in the list of
  conditions will have an implicit condition that they cannot be moved.

- **Example**:
  ```clarity
  (with-post-conditions
    (list (ft-condition (contract-of trait-a) amount-a))
    (as-contract (contract-call? trait-a transfer amount-a tx-sender caller none))
  )
  ```

## Conversion to `string-ascii`

Originally proposed [here](https://github.com/clarity-lang/reference/issues/82).

`to-ascii` is a new Clarity function that converts simple values into their
`string-ascii` representations.

- **Input**: `int` | `uint` | `bool` | `principal` | `(buff 524284)` |
  `(string-utf8 1048571)`
- **Output**: `(response (string-ascii 1048571) uint)`
- **Signature**: `(to-ascii value)`
- **Description**: Returns the `string-ascii` representation of the input value
  in an `ok` response on success. The only error condition is if the input type
  is `string-utf8` and the value contains non-ASCII characters, in which case,
  `(err u1)` is returned.
- **Example**:
  ```clarity
  (to-ascii true) ;; Returns (ok "true")
  (to-ascii 42) ;; Returns (ok "42")
  (to-ascii 'SP2QEZ06AGJ3RKJPBV14SY1V5BBFNAW33D96YPGZF) ;; Returns (ok "SP2QEZ06AGJ3RKJPBV14SY1V5BBFNAW33D96YPGZF")
  (to-ascii 0x12345678) ;; Returns (ok "0x12345678")
  ```

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
