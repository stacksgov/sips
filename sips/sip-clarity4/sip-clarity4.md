# Preamble

**SIP Number:** XYZ

**Title:** Clarity Smart Contract Language, version 4

**Authors:**

- Adriano Di Luzio <adriano@bitcoinl2labs.com>
- Brice Dobry <brice@hiro.so>
- Marvin Janssen <marvin@ryder.id>
- Jude Nelson <jude@stacks.org>

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
2. **A new set of Clarity functions to allow a contract to set post-conditions
   to protect its assets.** These allow a contract to safely call arbitrary
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
  principal specified as input, or an error if the principal is not a contract
  or the specified contract does not exist. Returns:
  - `(ok 0x<hash>)`, where `<hash>` is the SHA-512/256 hash of the code body, on
    success
  - `(err u0)` if the principal is not a contract principal
  - `(err u1)` if the specified contract does not exist
- **Example**:
  ```clarity
  (contract-hash? 'SP2QEZ06AGJ3RKJPBV14SY1V5BBFNAW33D96YPGZF.BNS-V2) ;; Returns (ok 0x9f8104ff869aba1205cd5e15f6404dd05675f4c3fe0817c623c425588d981c2f)
  ```

## Limiting asset access: `restrict-assets?`

Originally proposed [here](https://github.com/clarity-lang/reference/issues/64).

`restrict-assets?` establishes a deny-all outflow policy for a specific
principal during the evaluation of its inner expression. Within the inner
expression, the contract may selectively grant outflow allowances using
`with-stx`, `with-ft`, and `with-nft`. After the inner expression finishes, the
Clarity VM compares the net outflow of the scoped principal against the granted
allowances. If any allowance is exceeded, `restrict-assets?` returns an error;
otherwise, it returns `ok` with the result of the inner expression.

The most important use case of these new builtins is to allow a contract to
protect its own assets. To ensure that the contract's assets are safe by
default, the existing `as-contract` expression will now implicitly behave as
though there is a `restrict-assets?` expression around its body, specifying the
contract principal. The `with-stx`, `with-ft`, and `with-nft` builtins can be
used within the `as-contract` body to allow access to specific assets owned by
the contract, and `with-stacking` can be used to allow the body to stack STX via
calls to the `stack-stx` or `delegate-stx` functions of the active PoX contract.

`with-stx`, `with-ft`, `with-nft`, and `with-stacking` apply to the principal
specified by the nearest enclosing `restrict-assets?` or `as-contract`
expression in the lexical scope. Using any of these forms outside such a scope
results in an analysis error.

- `restrict-assets?`

  - **Input**:
    - `asset-owner`: `principal`: The principal whose assets are being
      protected.
    - `body`: `A`: A Clarity expression to be executed, with return type `A`
  - **Output**: `(response A uint)`
  - **Signature**: `(restrict-assets? asset-owner body)`
  - **Description**: Executes the expression `body`, then checks the asset
    outflows against the granted allowances. Returns:

    - `(ok result)` if the outflows are within the allowances, where `result` is
      the result of the `body` expression.
    - `(err u1)` if an STX allowance was violated
    - `(err u2)` if an FT allowance was violated
    - `(err u3)` if an NFT allowance was violated

  - **Example**:
    ```clarity
    (define-public (foo)
      (restrict-assets? tx-sender
        (try! (stx-transfer? u1000000 tx-sender (as-contract tx-sender)))
      )
    ) ;; Returns (err u1)
    (define-public (bar)
      (restrict-assets? tx-sender
        (+ u1 u2)
      )
    ) ;; Returns (ok u3)
    ```

- `with-stx`

  - **Input**:
    - `amount`: `uint`: The amount of uSTX to grant access to.
    - `body`: `A`: A Clarity expression to be executed, with return type `A`
  - **Output**: `A`
  - **Signature**: `(with-stx amount body)`
  - **Description**: Adds an outflow allowance for `amount` uSTX from the
    `asset-owner` of the nearest enclosing `restrict-assets?` or `as-contract`
    expression, then executes the expression `body` and returns its result.
  - **Example**:
    ```clarity
    (restrict-assets? tx-sender
      (with-stx u1000000
        (try! (stx-transfer? u2000000 tx-sender (as-contract tx-sender)))
      )) ;; Returns (err u1)
    (restrict-assets? tx-sender
      (with-stx u1000000
        (try! (stx-transfer? u1000000 tx-sender (as-contract tx-sender)))
      )) ;; Returns (ok true)
    ```

- `with-ft`

  - **Input**:
    - `contract-id`: `principal`: The contract defining the FT asset.
    - `token-name`: `(string-ascii 128)`: The name of the FT.
    - `amount`: `uint`: The amount of FT to grant access to.
    - `body`: `A`: A Clarity expression to be executed, with return type `A`
  - **Output**: `A`
  - **Signature**: `(with-ft contract-id token-name amount body)`
  - **Description**: Adds an outflow allowance for `amount` of the fungible
    token defined in `contract-id` with name `token-name` from the `asset-owner`
    of the nearest enclosing `restrict-assets?` or `as-contract` expression,
    then executes the expression `body` and returns its result.
  - **Example**:
    ```clarity
    (restrict-assets? tx-sender
      (with-ft token-trait "stackaroo" u50
        (try! (contract-call? token-trait transfer u100 tx-sender (as-contract tx-sender) none))
      )) ;; Returns (err u2)
    (restrict-assets? tx-sender
      (with-ft token-trait "stackaroo" u50
        (try! (contract-call? token-trait transfer u20 tx-sender (as-contract tx-sender) none))
      )) ;; Returns (ok true)
    ```

- `with-nft`

  - **Input**:
    - `contract-id`: `principal`: The contract defining the NFT asset.
    - `token-name`: `(string-ascii 128)`: The name of the NFT.
    - `identifier`: `T`: The identifier of the token to grant access to.
    - `body`: `A`: A Clarity expression to be executed, with return type `A`
  - **Output**: `A`
  - **Signature**: `(with-nft contract-id token-name identifier body)`
  - **Description**: Adds an outflow allowance the non-fungible token identified
    by `identifier` defined in `contract-id` with name `token-name` from the
    `asset-owner` of the nearest enclosing `restrict-assets?` or `as-contract`
    expression, then executes the expression `body` and returns its result.
  - **Example**:
    ```clarity
    (restrict-assets? tx-sender
      (with-nft nft-trait "stackaroo" u123
        (try! (contract-call? nft-trait transfer u4 tx-sender (as-contract tx-sender)))
      )) ;; Returns (err u3)
    (restrict-assets? tx-sender
      (with-nft nft-trait "stackaroo" u123
        (try! (contract-call? nft-trait transfer u123 tx-sender (as-contract tx-sender)))
      )) ;; Returns (ok true)
    ```

- `with-stacking`

  - **Input**:
    - `amount`: `uint`: The amount of uSTX that can be locked.
    - `body`: `A`: A Clarity expression to be executed, with return type `A`
  - **Output**: `A`
  - **Signature**: `(with-stacking amount body)`
  - **Description**: Adds a stacking allowance for `amount` uSTX from the
    `asset-owner` of the nearest enclosing `restrict-assets?` or `as-contract`
    expression, then executes the expression `body` and returns its result. This
    restricts calls to `delegate-stx` and `stack-stx` to lock less than or equal
    to the amount specified in PoX.
  - **Example**:
    ```clarity
    (restrict-assets? tx-sender
      (with-stacking u1000000000000
        (try! (contract-call? 'SP000000000000000000002Q6VF78.pox-4 delegate-stx
          u1100000000000 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM none none
        ))
      )) ;; Returns (err u1)
    (restrict-assets? tx-sender
      (with-stacking u1000000000000
        (try! (contract-call? 'SP000000000000000000002Q6VF78.pox-4 delegate-stx
          u900000000000 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM none none
        ))
      )) ;; Returns (ok true)
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
