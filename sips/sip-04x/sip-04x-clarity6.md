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
introduces quality-of-life improvements to the language syntax, relaxes naming
rules to work better with the new Clarity linter, adds new cryptographic
built-in functions, and adds new built-ins for trustlessly verifying Bitcoin
transaction outputs on-chain.
These changes are motivated by real-world developer experience and address
long-standing requests from the Clarity developer community.

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
3. **Underscore-prefixed identifiers:** The current naming rules prohibit
   identifiers from starting with `_`, preventing developers from using a
   widely-adopted convention for indicating intentionally unused bindings. This
   limitation affects developer tooling such as linters.
4. **Variadic `concat`:** The `concat` function currently accepts only two
   arguments, so assembling a sequence from more than two parts requires deeply
   nested calls. This is verbose and hard to read, particularly in code that
   builds multi-field binary payloads (such as cross-chain bridge serialization).
5. **secp256k1 public key decompression:** There is currently no way to
   decompress a secp256k1 public key in Clarity. This forces protocols like
   Wormhole to use cumbersome workarounds involving uncompressed keys, leading to
   operational downtime when guardian sets change.
6. **Ed25519 signature verification:** Clarity currently supports signature
   verification only on the secp256k1 curve (used by Bitcoin and Ethereum) and
   the secp256r1 curve (used by Apple's Secure Enclave and WebAuthn). There is
   no way to verify Ed25519 signatures, which are the standard for many other
   ecosystems (including Solana, Cardano, Polkadot, Stellar, Tor, SSH, and
   Signal). This blocks cross-chain bridges and attestation/identity systems
   that need to verify signatures produced by those ecosystems.
7. **Trustless Bitcoin transaction verification:** Clarity contracts have no
   native way to verify that a Bitcoin transaction output exists on the Bitcoin
   chain. Protocols that need this capability (such as BTC bridges and sBTC-style
   peg systems) must currently rely on off-chain oracles or trusted relayers, or
   reimplement Bitcoin transaction parsing and merkle-proof verification in
   user-space Clarity code, which is expensive, error-prone, and difficult to
   audit.

# Specification

This SIP requires a hard fork. Clarity 6 will activate at the onset of Stacks
Epoch 4.0. New contracts deployed in Epoch 4.0 will default to Clarity 6, but
contract authors can override this by specifying an earlier version in the
deploy transaction.

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

## Allow Identifiers to Start with `_`

Originally proposed here:
https://github.com/clarity-lang/reference/issues/101

Currently, Clarity identifiers cannot begin with the underscore character (`_`),
although underscores are permitted in other positions within a name. This
prevents developers from using the widely-adopted convention of prefixing unused
bindings with `_` to indicate that they are intentionally unused.

Beginning in Clarity 6, identifiers (including function, constant, map, and
data var names, function arguments, `let` and `match` bindings, and other named
definitions) may begin with an underscore.

Additionally, the bare identifier `_` (a single underscore) is allowed in
`let` and `match` bindings as a discard pattern, indicating that the bound
value is intentionally unused. Unlike other identifiers, `_` does not create
a binding that can be referenced later; attempting to reference `_` will
result in an analysis error.

### Examples

```clarity
;; Prefixing an unused binding
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
automatically detect genuinely unused bindings without false positives.

## Variadic `concat`

Originally proposed here:
https://github.com/stacks-network/stacks-core/issues/7112

The `concat` function currently accepts exactly two sequences (buffers, ASCII
strings, UTF-8 strings, or lists) and returns their concatenation. To combine
more than two sequences, developers must write nested `concat` calls, which
produce verbose, hard-to-read code — particularly in code that assembles
multi-field binary payloads such as cross-chain bridge serializations.

Beginning in Clarity 6, `concat` accepts two or more arguments. All arguments
must share the same sequence type (all buffers, all ASCII strings, all UTF-8
strings, or all lists with the same element type), and the result has a maximum
length equal to the sum of the maximum lengths of the inputs, subject to
Clarity's overall sequence-length limits. Calling `concat` with fewer than two
arguments remains an analysis error.

### Example

```clarity
;; Clarity 5 and below: nested calls required
(concat (concat (concat 0x11 amount-bytes) fee-bytes) chain-id)

;; Clarity 6: flat, variadic call
(concat 0x11 amount-bytes fee-bytes chain-id)
```

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

## Add `ed25519-verify` Function

Clarity currently provides signature verification only on the secp256k1 curve
(via `secp256k1-verify`) and the secp256r1 curve (via `secp256r1-verify`, added
in Clarity 5). There is no built-in for verifying Ed25519 signatures, even
though Ed25519 is the dominant signature scheme outside of the Bitcoin and
Ethereum ecosystems and is used by Solana, Cardano, Polkadot, Stellar, Tor,
SSH, and Signal, among many other systems.

This omission prevents Clarity contracts from natively verifying messages
signed by participants in any of those ecosystems, which is a hard requirement
for cross-chain bridges and for identity/attestation systems that rely on
Ed25519-keyed credentials.

Beginning in Clarity 6, a new built-in function `ed25519-verify` is available.

- **Input**: `buff, (buff 64), (buff 32)`: the message, the 64-byte Ed25519
  signature, and the 32-byte Ed25519 public key.
- **Output**: `bool`
- **Signature**: `(ed25519-verify message signature public-key)`
- **Description**: Verifies that `signature` is a valid Ed25519 signature of
  `message` under `public-key`, per
  [RFC 8032](https://datatracker.ietf.org/doc/html/rfc8032). Returns `true` if
  the signature is valid and `false` otherwise. Verification is performed in
  strict mode: non-canonical signatures (for example, signatures whose
  `s`-component is not in canonical range) are rejected, which prevents
  signature malleability.
- **Example** (using the standard test vector from RFC 8032 §7.1, TEST 2):
  ```clarity
  (ed25519-verify
    0x72
    0x92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00
    0x3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c)
  ;; Returns true

  ;; Same signature/key, but a different message: verification fails.
  (ed25519-verify
    0x00
    0x92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00
    0x3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c)
  ;; Returns false
  ```

## Bitcoin Transaction Verification Built-ins

Clarity contracts currently have no first-class way to verify that a Bitcoin
transaction output exists on the Bitcoin chain. Protocols such as BTC bridges
and sBTC-style peg systems must either rely on trusted off-chain relayers or
reimplement Bitcoin transaction parsing and merkle-proof verification in
user-space Clarity, where the cost of double-SHA-256 hashing and byte-level
parsing on large transactions is prohibitive and the risk of subtle bugs (such
as CVE-2012-2459-style merkle malleability) is high.

Beginning in Clarity 6, two new built-in functions, `get-bitcoin-tx-output?`
and `verify-merkle-proof`, are available. They are designed as a pair: the
`txid` returned by `get-bitcoin-tx-output?` is in the internal (raw) byte
order expected by `verify-merkle-proof` as a leaf hash. Combined with the
existing `get-burn-block-info?` built-in — whose `header-hash` property lets
a contract authenticate a user-supplied Bitcoin block header (and thereby
extract its merkle root) — they enable contracts to verify that a Bitcoin
output exists on-chain without trusting the caller to have correctly stripped
witness data or hashed the transaction.

### `get-bitcoin-tx-output?`

- **Input**: `buff, uint`: a serialized Bitcoin transaction (with or without
  SegWit witness data), and the output index (`vout`) to extract.
- **Output**: `(response (tuple (script (buff 1024)) (amount uint) (txid (buff 32))) uint)`
- **Signature**: `(get-bitcoin-tx-output? tx-bytes vout)`
- **Description**: Parses a serialized Bitcoin transaction and returns the
  output at the given `vout` index, along with the canonical (non-witness)
  `txid` of the transaction. The returned `txid` is in *internal* byte order
  (the raw double-SHA-256 result), ready to be passed directly to
  `verify-merkle-proof` as the leaf hash. The `script` field contains the raw
  `scriptPubKey` bytes of the output, so contracts can pattern-match on script
  prefixes to recognize P2WSH (`0x00 0x20 ...`), P2TR (`0x51 0x20 ...`),
  P2WPKH (`0x00 0x14 ...`), `OP_RETURN` (`0x6a ...`), or any other output
  script. Returns one of three error codes on failure:
  - `(err u1)` — `tx-bytes` did not deserialize as a Bitcoin transaction.
  - `(err u2)` — `vout` is out of range for this transaction.
  - `(err u3)` — the output's `scriptPubKey` exceeds the 1024-byte cap.
- **Example**:
  ```clarity
  ;; Parse the Bitcoin genesis block coinbase tx and return its sole output.
  (get-bitcoin-tx-output?
    0x01000000010000000000000000000000000000000000000000000000000000000000000000ffffffff4d04ffff001d0104455468652054696d65732030332f4a616e2f32303039204368616e63656c6c6f72206f6e206272696e6b206f66207365636f6e64206261696c6f757420666f722062616e6b73ffffffff0100f2052a01000000434104678afdb0fe5548271967f1a67130b7105cd6a828e03909a67962e0ea1f61deb649f6bc3f4cef38c4f35504e51ec112de5c384df7ba0b8d578a4c702b6bf11d5fac00000000
    u0)
  ;; Returns (ok (tuple
  ;;   (amount u5000000000)
  ;;   (script 0x4104678afdb0fe5548271967f1a67130b7105cd6a828e03909a67962e0ea1f61deb649f6bc3f4cef38c4f35504e51ec112de5c384df7ba0b8d578a4c702b6bf11d5fac)
  ;;   (txid 0x3ba3edfd7a7b12b27ac72c3e67768f617fc81bc3888a51323a9fb8aa4b1e5e4a)))

  (get-bitcoin-tx-output? 0x00 u0) ;; Returns (err u1)
  ```

### `verify-merkle-proof`

- **Input**: `(buff 32), (buff 32), uint, uint, (list 24 (buff 32))`: the leaf
  hash, the merkle root hash, the leaf's index in the tree, the total
  transaction count of the block, and the list of sibling hashes along the
  path from the leaf to the root.
- **Output**: `bool`
- **Signature**: `(verify-merkle-proof leaf-hash root-hash tx-index tx-count sibling-hashes)`
- **Description**: Verifies a Bitcoin-style merkle inclusion proof using
  double-SHA-256 hashing with the "duplicate the last node on odd-sized rows"
  rule. Given a `leaf-hash` (typically a Bitcoin txid), the merkle `root-hash`
  of a block, the `tx-index` of the leaf within the tree (0-indexed), the
  `tx-count` of transactions in the block, and the `sibling-hashes` along the
  path from the leaf to the root, the function returns `true` iff hashing
  pairwise up the tree in the order described by `tx-index` produces
  `root-hash`.

  The `tx-count` argument pins down the canonical Bitcoin tree shape and is
  required to defend against
  [CVE-2012-2459](https://bitcointalk.org/?topic=102395)-style attacks, where
  an intermediate node in an odd-row-padded tree could otherwise be passed off
  as a leaf. The function rejects any proof whose path length does not match
  `ceil(log2(tx-count))` and any `tx-index` not less than `tx-count`. It
  returns `false` for any malformed proof and `true` for a valid proof.

  All 32-byte hashes (leaf, root, siblings) are passed in *internal* (raw)
  byte order, not the display (reversed) order conventionally used for
  Bitcoin txids and block hashes. The `txid` returned by
  `get-bitcoin-tx-output?` is already in internal byte order and can be
  passed directly as `leaf-hash`.
- **Example**:
  ```clarity
  ;; The Bitcoin genesis block contains a single tx, so its coinbase txid
  ;; (in internal byte order) is also the block's merkle root. A proof
  ;; with an empty sibling list verifies trivially.
  (verify-merkle-proof
    0x3ba3edfd7a7b12b27ac72c3e67768f617fc81bc3888a51323a9fb8aa4b1e5e4a
    0x3ba3edfd7a7b12b27ac72c3e67768f617fc81bc3888a51323a9fb8aa4b1e5e4a
    u0
    u1
    (list)) ;; Returns true
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
identifiers) and new built-in functions (`secp256k1-decompress?`,
`ed25519-verify`, `get-bitcoin-tx-output?`, and `verify-merkle-proof`), it is a
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
