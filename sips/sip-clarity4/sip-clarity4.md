# Preamble

**SIP Number:** XYZ

**Title:** Clarity Smart Contract Language, version 4

**Authors:**

- Adriano Di Luzio <adriano@bitcoinl2labs.com>
- Brice Dobry <brice@hiro.so>
- Marvin Janssen <marvin@ryder.id>
- Jude Nelson <jude@stacks.org>

**Consideration:** Technical

**Type:** Consensus (hard fork)

**Status:** Draft

**Created:** 2025-06-20

**License:** CC0-1.0

**Sign-off:**

**Discussions-To:**
https://forum.stacks.org/t/clarity-4-proposal-new-builtins-for-vital-ecosystem-projects/18266

# Abstract

This SIP details Version 4 of the Clarity smart contract language, which
introduces new operations to make it easier to build secure smart contracts on
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

This SIP addresses common feedback and requests from developers in the
ecosystem. It proposes new Clarity features to make it easier for developers to
write secure and composable smart contracts. Specifically, it proposes:

1. **A new Clarity function to fetch the hash of a contract's code body.** This
   enables on-chain contract code validation, for example allowing contract A to
   validate that contract B follows a specific template and is therefore safe to
   interact with. This is especially useful for enabling services, such as
   bridges and marketplaces, to safely and trustlessly support a dynamic set of
   assets.
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
4. **A new Clarity keyword to get the timestamp of the _current_ block.** This
   keyword will allow developers to easily access the timestamp of the block
   currently being processed, enabling time-based logic and features in their
   smart contracts. This is especially important for DeFi applications.

# Specification

## Fetching the hash of a contract body: `contract-hash?`

Originally proposed here: https://github.com/clarity-lang/reference/issues/88

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
  - `(err u1)` if the principal is not a contract principal
  - `(err u2)` if the specified contract does not exist
- **Example**:
  ```clarity
  (contract-hash? 'SP2QEZ06AGJ3RKJPBV14SY1V5BBFNAW33D96YPGZF.BNS-V2) ;; Returns (ok 0x9f8104ff869aba1205cd5e15f6404dd05675f4c3fe0817c623c425588d981c2f)
  ```

## Limiting asset access: `restrict-assets?`

Originally proposed here: https://github.com/clarity-lang/reference/issues/64

`restrict-assets?` establishes a context with a deny-all outflow policy for a
specific principal during the evaluation of its body expressions. It accepts a
set of allowances, defined using `with-stx`, `with-ft`, `with-nft`, and
`with-stacking`, which selectively grant outflow allowances. After the body
expressions finish, the Clarity VM checks the **gross** outflow from the scoped
principal against the granted allowances. If any allowance is exceeded,
`restrict-assets?` returns an error; otherwise, it returns `ok` with the result
of the last body expression.

The most important use case of these new builtins is to allow a contract to
protect its own assets. To ensure that the contract's assets are safe by
default, the new `as-contract?` expression is similar to the existing
`as-contract` expression, but will implicitly behave as though there is a
`restrict-assets?` expression around its body, specifying the contract principal
as the asset owner. The old `as-contract` is no longer available in Clarity 4.
Similar to `restrict-assets?`, `as-contract?` accepts a set of `with-stx`,
`with-ft`, `with-nft`, and `with-stacking` expressions which selectively grant
outflow allowances from the contract's assets.

With this new `as-contract?`, the expression needed to get the principal of the
current contract, a common pattern, becomes ugly:

```clarity
(unwrap-panic (as-contract? () tx-sender))
```

To avoid that, a new builtin keyword `current-contract` is added which will
return the principal for the current contract.

The new allowance expressions are:

- `with-stx` grants an outflow allowance for a specific amount of STX via calls
  to the `stx-transfer?` function.
- `with-ft` grants an outflow allowance for a specific amount of the specified
  fungible token.
- `with-nft` grants an outflow allowance for a specific identifier of the
  specified NFT.
- `with-stacking` grants an outflow allowance for a specific amount of STX via
  calls to the `stack-stx` or `delegate-stx` functions of the active PoX
  contract.
- `with-all-assets-unsafe` is allowed only within `as-contract?` and grants
  unrestricted access to all assets of the contract and as such, should be used
  with caution.

Use of `with-stx`, `with-ft`, `with-nft`, or `with-stacking` outside of
`restrict-assets?` or `as-contract?` results in an analysis error. Similarly,
use of `with-all-assets-unsafe` outside of `as-contract?` results in an analysis
error.

- `restrict-assets?`

  - **Input**:
    - `asset-owner`: `principal`: The principal whose assets are being
      protected.
    - `((with-stx|with-ft|with-nft|with-stacking)*)`: The set of allowances to
      grant during the evaluation of the body expressions.
    - `AnyType* A`: The Clarity expressions to be executed within the context,
      with the final expression returning type `A`, where `A` is not a
      `response`
  - **Output**: `(response A int)`
  - **Signature**:
    `(restrict-assets? asset-owner ((with-stx|with-ft|with-nft|with-stacking)*) expr-body1 expr-body2 ... expr-body-last)`
  - **Description**: Executes the body expressions, then checks the asset
    outflows against the granted allowances, in declaration order. If any
    allowance is violated, the body expressions are reverted, an error is
    returned, and an event is emitted with the full details of the violation to
    help with debugging. Note that the `asset-owner` and allowance setup
    expressions are evaluated before executing the body expressions. The final
    body expression cannot return a `response` value in order to avoid returning
    a nested `response` value from `restrict-assets?` (nested responses are
    error-prone). Returns:

    - `(ok x)` if the outflows are within the allowances, where `x` is the
      result of the final body expression and has type `A`.
    - `(err index)` if an allowance was violated, where `index` is the 0-based
      index of the first violated allowance in the list of granted allowances,
      or -1 if an asset with no allowance caused the violation.

  - **Example**:
    ```clarity
    (define-public (foo)
      (restrict-assets? tx-sender ()
        (try! (stx-transfer? u1000000 tx-sender 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM))
      )
    ) ;; Returns (err -1)
    (define-public (bar)
      (restrict-assets? tx-sender ()
        (+ u1 u2)
      )
    ) ;; Returns (ok u3)
    ```

- `with-stx`

  - **Input**:
    - `amount`: `uint`: The amount of uSTX to grant access to.
  - **Output**: Not applicable
  - **Signature**: `(with-stx amount)`
  - **Description**: Adds an outflow allowance for `amount` uSTX from the
    `asset-owner` of the enclosing `restrict-assets?` or `as-contract?`
    expression.
  - **Example**:
    ```clarity
    (restrict-assets? tx-sender
      ((with-stx u1000000))
      (try! (stx-transfer? u2000000 tx-sender 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM))
    ) ;; Returns (err 0)
    (restrict-assets? tx-sender
      ((with-stx u1000000))
      (try! (stx-transfer? u1000000 tx-sender 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM))
    ) ;; Returns (ok true)
    ```

- `with-ft`

  - **Input**:
    - `contract-id`: `principal`: The contract defining the FT asset.
    - `token-name`: `(string-ascii 128)`: The name of the FT or `"*"` for any FT
      defined in `contract-id`.
    - `amount`: `uint`: The amount of FT to grant access to.
  - **Output**: Not applicable
  - **Signature**: `(with-ft contract-id token-name amount)`
  - **Description**: Adds an outflow allowance for `amount` of the fungible
    token defined in `contract-id` with name `token-name` from the `asset-owner`
    of the enclosing `restrict-assets?` or `as-contract?` expression. Note that
    `token-name` should match the name used in the `define-fungible-token` call
    in the contract. When `"*"` is used for the token name, the allowance
    applies to **all** FTs defined in `contract-id`.
  - **Example**:
    ```clarity
    (restrict-assets? tx-sender
      ((with-ft (contract-of token-trait) "stackaroo" u50))
      (try! (contract-call? token-trait transfer u100 tx-sender 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM none))
    ) ;; Returns (err 0)
    (restrict-assets? tx-sender
      ((with-ft (contract-of token-trait) "stackaroo" u50))
      (try! (contract-call? token-trait transfer u20 tx-sender 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM none))
    ) ;; Returns (ok true)
    ```

- `with-nft`

  - **Input**:
    - `contract-id`: `principal`: The contract defining the NFT asset.
    - `token-name`: `(string-ascii 128)`: The name of the NFT or `"*"` for any
      NFT defined in `contract-id`.
    - `identifiers`: `(list 128 T)`: The identifiers of the token to grant
      access to.
  - **Output**: Not applicable
  - **Signature**: `(with-nft contract-id token-name identifiers)`
  - **Description**: Adds an outflow allowance for the non-fungible token(s)
    identified by `identifiers` defined in `contract-id` with name `token-name`
    from the `asset-owner` of the enclosing `restrict-assets?` or `as-contract?`
    expression. Note that `token-name` should match the name used in the
    `define-non-fungible-token` call in the contract. When `"*"` is used for the
    token name, the allowance applies to **all** NFTs defined in `contract-id`.
  - **Example**:
    ```clarity
    (restrict-assets? tx-sender
      ((with-nft (contract-of nft-trait) "stackaroo" (list u123)))
      (try! (contract-call? nft-trait transfer u4 tx-sender 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM))
    ) ;; Returns (err 0)
    (restrict-assets? tx-sender
      ((with-nft (contract-of nft-trait) "stackaroo" (list u123)))
      (try! (contract-call? nft-trait transfer u123 tx-sender 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM))
    ) ;; Returns (ok true)
    ```

- `with-stacking`

  - **Input**:
    - `amount`: `uint`: The amount of uSTX that can be locked.
  - **Output**: Not applicable
  - **Signature**: `(with-stacking amount)`
  - **Description**: Adds a stacking allowance for `amount` uSTX from the
    `asset-owner` of the enclosing `restrict-assets?` or `as-contract?`
    expression. This restricts calls to the active PoX contract that either
    delegate funds for stacking or stack directly, ensuring that the locked
    amount is limited by the amount of uSTX specified.
  - **Example**:
    ```clarity
    (restrict-assets? tx-sender
      ((with-stacking u1000000000000))
      (try! (contract-call? 'SP000000000000000000002Q6VF78.pox-4 delegate-stx
        u1100000000000 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM none none
      ))
    ) ;; Returns (err 0)
    (restrict-assets? tx-sender
      ((with-stacking u1000000000000))
      (try! (contract-call? 'SP000000000000000000002Q6VF78.pox-4 delegate-stx
        u900000000000 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM none none
      ))
    ) ;; Returns (ok true)
    ```

- `with-all-assets-unsafe`

  - **Input**: None
  - **Output**: Not applicable
  - **Signature**: `(with-all-assets-unsafe)`
  - **Description**: Grants unrestricted access to all assets of the contract to
    the enclosing `as-contract?` expression. Note that this is not allowed in
    `restrict-assets?` and will trigger an analysis error, since usage there
    does not make sense (i.e. just remove the `restrict-assets?` instead). **_⚠️
    Security Warning: This should be used with extreme caution, as it
    effectively disables all asset protection for the contract. ⚠️_** This
    dangerous allowance should only be used when the code executing within the
    `as-contract?` body is verified to be trusted through other means (e.g.
    checking traits against an allow list, passed in from a trusted caller), and
    even then the more restrictive allowances should be preferred when possible.
    - **Example**:
    ```clarity
    (define-public (execute-trait (trusted-trait <sample-trait>))
      (begin
        (asserts! (is-eq contract-caller TRUSTED_CALLER) ERR_UNTRUSTED_CALLER)
        (as-contract? ((with-all-assets-unsafe))
          (contract-call? trusted-trait execute)
        )
      )
    )
    ```

- `as-contract?`

  - **Input**:
    - `((with-stx|with-ft|with-nft|with-stacking)*|with-all-assets-unsafe)`: The
      set of allowances to grant during the evaluation of the body expressions.
      Note that `with-all-assets-unsafe` is mutually exclusive with other
      allowances.
    - `AnyType* A`: The Clarity expressions to be executed within the context,
      with the final expression returning type `A`, where `A` is not a
      `response`
  - **Output**: `(response A int)`
  - **Signature**:
    `(as-contract? ((with-stx|with-ft|with-nft|with-stacking)*|with-all-assets-unsafe) expr-body1 expr-body2 ... expr-body-last)`
  - **Description**: Switches the current context's `tx-sender` and
    `contract-caller` values to the contract's principal and executes the body
    expressions within that context, then checks the asset outflows from the
    contract against the granted allowances, in declaration order. If any
    allowance is violated, the body expressions are reverted, an error is
    returned, and an event is emitted with the full details of the violation to
    help with debugging. Note that the allowance setup expressions are evaluated
    before executing the body expressions. The final body expression cannot
    return a `response` value in order to avoid returning a nested `response`
    value from `as-contract?` (nested responses are error-prone). Returns:

    - `(ok x)` if the outflows are within the allowances, where `x` is the
      result of the final body expression and has type `A`.
    - `(err index)` if an allowance was violated, where `index` is the 0-based
      index of the first violated allowance in the list of granted allowances,
      or -1 if an asset with no allowance caused the violation.

  - **Example**:
    ```clarity
    (define-public (foo)
      (as-contract? ()
        (try! (stx-transfer? u1000000 tx-sender recipient))
      )
    ) ;; Returns (err -1)
    (define-public (bar)
      (as-contract? ((with-stx u1000000))
        (try! (stx-transfer? u1000000 tx-sender recipient))
      )
    ) ;; Returns (ok true)
    ```

## Built-in keyword: `current-contract`

In many smart contracts, there is a common pattern for retrieving the current
contract's principal:

```clarity
(as-contract tx-sender)
```

With the new `as-contract?` and the removal of `as-contract`, the expression
required to retrieve the current contract's principal has changed to:

```clarity
(unwrap-panic (as-contract? () tx-sender))
```

This new expression is more verbose and less readable. To address this, a new
built-in keyword `current-contract` is introduced. This keyword provides a
straightforward way to access the current contract's principal.

- **Description**: Returns the principal of the current contract.
- **Output**: `principal`
- **Example**:
  ```clarity
  (stx-transfer? u1000000 tx-sender current-contract)
  ```

## Conversion to `string-ascii`: `to-ascii?`

Originally proposed here: https://github.com/clarity-lang/reference/issues/82

`to-ascii?` is a new Clarity function that converts simple values into their
`string-ascii` representations.

- **Input**: `int` | `uint` | `bool` | `principal` | `(buff 524284)` |
  `(string-utf8 262144)`
- **Output**: `(response (string-ascii 1048571) uint)`
- **Signature**: `(to-ascii? value)`
- **Description**: Returns the `string-ascii` representation of the input value
  in an `ok` response on success. The only error condition is if the input type
  is `string-utf8` and the value contains non-ASCII characters, in which case,
  `(err u1)` is returned.
- **Example**:
  ```clarity
  (to-ascii? true) ;; Returns (ok "true")
  (to-ascii? 42) ;; Returns (ok "42")
  (to-ascii? 'SP2QEZ06AGJ3RKJPBV14SY1V5BBFNAW33D96YPGZF) ;; Returns (ok "SP2QEZ06AGJ3RKJPBV14SY1V5BBFNAW33D96YPGZF")
  (to-ascii? 0x12345678) ;; Returns (ok "0x12345678")
  ```

## Timestamp for current block: `block-time`

`block-time` is a new Clarity keyword that returns the timestamp of the current
block in seconds since the Unix epoch. This is the same timestamp that is in the
block header, which is verified by the signers to be:

- Greater than the timestamp of its parent block
- At most 15 seconds into the future

This same timestamp can also be retrieved for previous blocks using
`(get-stacks-block-info? time height)`, which exists since Clarity 3, but cannot
be used for the current block.

Note that `block-time` will properly account for the context of an `at-block`
expression. If the `at-block` sets the context to a block that is from before
Clarity 4 has activated, attempting to use `block-time` in that context will
result in a runtime error.

- **Output**: `uint`
- **Example**:
  ```clarity
  (if (> block-time 1755820800)
    (print "after 2025-07-22")
    (print "before 2025-07-22"))
  ```

# Related Work

Not applicable.

# Backwards Compatibility

Because this SIP introduces new Clarity operators, it is a consensus-breaking
change. A contract that uses one of these new operators would be invalid before
this SIP is activated, and valid after it is activated.

The old `as-contract` builtin function is no longer available in Clarity 4,
since it has been replaced with the safer `as-contract?`.

All new keywords introduced in Clarity 4 can no longer be used as identifiers in
a Clarity 4 smart contract. This means that some existing contracts would need
to be modified if published as Clarity 4 contracts.

# Activation

TBD

# Reference Implementations

TBD
