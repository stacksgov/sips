# Preamble

SIP Number: 043

Title: Clarity 6: Language Improvements and New Built-ins

Author(s):

- Jeff Bencin <jeff.bencin@gmail.com>

Status: Draft

Consideration: Technical

Type: Consensus

Layer: Consensus (hard fork)

Created: 2026-04-14

License: BSD-2-Clause

Sign-off:

Discussions-To:

# Abstract

This SIP specifies Version 6 of the Clarity smart contract language. It
introduces quality-of-life improvements to the language syntax, relaxes naming rules
to work better with the new Clarity linter, and adds a new cryptographic
built-in function. These changes are motivated by real-world developer experience
and address long-standing requests from the Clarity developer community.

# Copyright

This SIP is made available under the terms of the BSD-2-Clause license,
available at https://opensource.org/licenses/BSD-2-Clause. This SIP's copyright
is held by the Stacks Open Internet Foundation.

# Introduction

This SIP addresses several limitations and inconveniences that have been reported
by Clarity developers. Specifically, it makes the following changes:

1. **Allow constants in place of literal values:** Clarity currently requires
   literal values in type definitions (such as list lengths) and in certain
   built-in functions (such as `as-max-len?`), even though constants are also known
   during deployment. This forces developers to duplicate magic numbers throughout
   their code, increasing the risk of inconsistencies.
2. **Numeric separators:** Large numeric literals are common in Clarity contracts
   (especially when working with micro-denominated tokens), but they are
   difficult to read without visual grouping. Many modern languages support
   underscore separators in numeric literals for this purpose.
3. **Underscore-prefixed variable names:** The current naming rules prohibit
   identifiers from starting with `_`, preventing developers from using a
   widely-adopted convention for indicating intentionally unused variables. This
   limitation affects developer tooling such as linters.
4. **secp256k1 public key decompression:** There is currently no way to
   decompress a secp256k1 public key in Clarity. This forces protocols like
   Wormhole to use cumbersome workarounds involving uncompressed keys, leading to
   operational downtime when guardian sets change.

# Specification

## Allow Constants in Type Positions

Originally proposed here:
https://github.com/clarity-lang/reference/issues/78

Currently, Clarity requires literal values when specifying type parameters such
as list lengths. Constants cannot be used in these positions, even though their
values are known during analysis.

Beginning in Clarity 6, constants defined with `define-constant` may be used
wherever a literal unsigned integer is required in a type specification. This
includes list length parameters in type definitions, function signatures, and
anywhere else a literal is currently expected for a type parameter.

### Example

```clarity
(define-constant MAX_SIZE u30)

(define-read-only (foo (l (list MAX_SIZE int)))
  (len l)
)
```

In Clarity 5 and below, the above would produce an error. In Clarity 6, it is
valid and equivalent to writing `(list 30 int)`.

The constant must evaluate to an unsigned integer (`uint`) value. Using a
constant that evaluates to any other type in a type position will result in an
analysis error.

## Allow Constants in `as-max-len?`

Originally proposed here:
https://github.com/clarity-lang/reference/issues/80

The `as-max-len?` function currently requires a literal unsigned integer for its
second argument, which specifies the target maximum length. Constants cannot be
substituted for this literal, even though the value is equally fixed and known
during analysis.

Beginning in Clarity 6, a constant defined with `define-constant` may be used as
the second argument to `as-max-len?`, provided the constant evaluates to a
`uint`.

### Example

```clarity
(define-constant GOV_MAX_GUARDIANS u30)

(unwrap-panic (as-max-len? updated-public-keys GOV_MAX_GUARDIANS))
```

In Clarity 5 and below, this would produce an error. In Clarity 6, it is valid
and equivalent to writing `(as-max-len? updated-public-keys u30)`.

This change, combined with the previous change allowing constants in type
positions, enables developers to define a single constant for a length limit and
use it consistently throughout their contract.

## Numeric Separator with `_`

Originally proposed here:
https://github.com/clarity-lang/reference/issues/92

Large numeric literals are common in Clarity smart contracts, particularly when
dealing with micro-denominated values (e.g. uSTX). These large numbers are
difficult to read and error-prone to write.

Beginning in Clarity 6, the underscore character (`_`) may be used as a visual
separator within signed and unsigned integer literals. The underscores are
purely cosmetic and have no effect on the value of the literal: They are stripped
during parsing.

### Rules

- Underscores may appear between any two digits in an integer or unsigned integer
  literal.
- Underscores may not appear at the beginning or end of a numeric literal, nor
  adjacent to the `u` prefix for unsigned integers.
- Multiple consecutive underscores are not allowed.
- The presence or absence of underscores does not affect the type or value of the
  literal.

### Examples

```clarity
;; With separators (Clarity 6)
(define-constant INITIAL_MINT_AMOUNT u200_000_000_000_000) ;; 200,000,000 STX

;; Equivalent to (Clarity 5 and below)
(define-constant INITIAL_MINT_AMOUNT u200000000000000)

;; Additional examples
(define-constant ONE_MILLION 1_000_000)
(define-constant SOME_VALUE u1_234_567)
```

This feature is supported by many popular programming languages including Rust,
JavaScript, Solidity, and Go.

## Allow Variables to Start with `_`

Originally proposed here:
https://github.com/clarity-lang/reference/issues/101

Currently, Clarity identifiers cannot begin with the underscore character (`_`),
although underscores are permitted in other positions within a name. This
prevents developers from using the widely-adopted convention of prefixing unused
variables with `_` to indicate that they are intentionally unused.

Beginning in Clarity 6, identifiers (including variable names, function names,
map names, data variable names, and other named definitions) may begin with an
underscore.

Additionally, the bare identifier `_` (a single underscore) is allowed as a
variable name in `let` and `match` bindings. This serves as a discard pattern,
indicating that the value is intentionally unused. Unlike other variable names,
`_` does not create a binding that can be referenced later; attempting to
reference `_` as a variable will result in an analysis error.

### Examples

```clarity
;; Prefixing an unused variable
(define-public (remove-admin (address principal))
  (let ((_admin (try! (check-admin)))
        (deleted (map-delete admins address)))
    (ok deleted)))

;; Using _ as a discard pattern
(define-public (remove-admin (address principal))
  (let ((_ (try! (check-admin)))
        (deleted (map-delete admins address)))
    (ok deleted)))
```

This convention is familiar to developers coming from Rust, TypeScript, Python,
and many other languages. It also enables linters and static analysis tools to
automatically detect genuinely unused variables without false positives.

## Add `secp256k1-decompress?` Function

Originally proposed here:
https://github.com/clarity-lang/reference/issues/103

There is currently no built-in function in Clarity to decompress a secp256k1
public key. Decompression requires computing a modular square root on the
secp256k1 elliptic curve, which involves 256-bit modular arithmetic that is not
feasible to implement in Clarity's 128-bit integer system.

This limitation has real-world consequences. For example, the Wormhole bridge
protocol on Stacks needs to store uncompressed public keys during guardian set
updates because there is no way to derive them on-chain from the VAA signatures.
Obtaining these uncompressed keys has proven to be difficult, and has led to
protocol downtime during guardian rotations.

Beginning in Clarity 6, a new built-in function `secp256k1-decompress?` is
available.

- **Input**: `(buff 33)`: a compressed secp256k1 public key
- **Output**: `(optional (buff 65))`: the uncompressed public key, or `none`
  if the input is not a valid compressed public key
- **Signature**: `(secp256k1-decompress? compressed-public-key)`
- **Description**: Takes a 33-byte compressed secp256k1 public key (where the
  first byte is `0x02` or `0x03` indicating the parity of the y-coordinate) and
  returns the corresponding 65-byte uncompressed public key (with a `0x04`
  prefix followed by the 32-byte x-coordinate and 32-byte y-coordinate). Returns
  `none` if the input is not a valid compressed secp256k1 public key.
- **Example**:
  ```clarity
  ;; Decompress a valid compressed public key
  (secp256k1-decompress? 0x0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798)
  ;; Returns (some 0x0479be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8)

  ;; Invalid input returns none
  (secp256k1-decompress? 0x00)
  ;; Returns none
  ```

### Deriving an Ethereum Address

With `secp256k1-decompress?`, developers can derive an Ethereum address from a
compressed public key on-chain:

```clarity
(define-read-only (compressed-pubkey-to-eth-address (compressed-key (buff 33)))
  (match (secp256k1-decompress? compressed-key)
    uncompressed-key (some
      (unwrap-panic (as-max-len?
        (unwrap-panic (slice?
          (keccak256 (unwrap-panic (slice? uncompressed-key u1 u65)))
          u12 u32))
        u20)))
    none))
```

# Related Work

This SIP builds upon the existing definitions of the Clarity language:

- [SIP-002 (Clarity 1)](../sip-002/sip-002-smart-contract-language.md)
- [SIP-015 (Clarity 2)](../sip-015/sip-015-network-upgrade.md)
- [SIP-021 (Clarity 3)](../sip-021/sip-021-nakamoto.md)
- [SIP-033 (Clarity 4)](../sip-033/sip-033-clarity4.md)
- [SIP-039 (Clarity 5)](../sip-039/sip-039-clarity5.md)

# Backwards Compatibility

Because this SIP introduces new syntax (numeric separators, underscore-prefixed
identifiers) and a new built-in function (`secp256k1-decompress?`), it is a
consensus-breaking change. A contract that uses any of these new features would
be invalid before this SIP is activated, and valid after it is activated.

All new keywords introduced in Clarity 6 can no longer be used as identifiers in
a Clarity 6 smart contract. Smart contracts can continue to be published using
older versions of Clarity by specifying the version in the deploy transaction.

Existing contracts deployed with previous Clarity versions are unaffected and
will continue to execute with their existing behavior.

# Activation

Users can vote to approve this SIP with either their locked/stacked STX or with
unlocked/liquid STX, or both.

In order for this SIP to activate, the following criteria must be met:

- At least 80 million stacked STX must vote, with at least 80% of all stacked
  STX committed by voting must be in favor of the proposal (vote "yes").
- At least 80% of all liquid STX committed by voting must be in favor of the
  proposal (vote "yes").

All STX holders vote by sending Stacks dust to the corresponding Stacks address
from the account where their Stacks are held (stacked or liquid). Voting power
is determined by a snapshot of the amount of STX (stacked and unstacked) at the
block height at which the voting started (preventing the same STX from being
transferred between accounts and used to effectively double vote).

Solo stackers only can also vote by sending a bitcoin dust transaction (6000
sats) to the corresponding bitcoin address.

| Vote | Bitcoin | Stacks | ASCII Encoding | Msg |
| ---- | ------- | ------ | -------------- | --- |
| yes  | TBD     | TBD    | TBD            | yes-sip-43 |
| no   | TBD     | TBD    | TBD            | no-sip-43  |

If the SIP is approved, a Bitcoin block height will be selected to activate the
new behavior.

# Reference Implementation

No reference implementation is available at the time of writing. Links to
implementation PRs will be added here as they become available.
