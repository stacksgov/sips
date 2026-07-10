# Preamble

SIP Number: 044

Title: Clarity 6, staking and PoX post-conditions, and removal of the
cost-voting contract

Author(s):

- Jeff Bencin <jeff.bencin@gmail.com>
- Brice Dobry <brice@stackslabs.com>

Status: Accepted

Consideration: Technical

Type: Consensus

Layer: Consensus (hard fork)

Created: 2026-04-14

License: BSD-2-Clause

Sign-off:

Discussions-To:

# Abstract

This SIP defines the consensus changes that activate with Stacks Epoch 4.0.

First, it introduces Clarity 6, which extends the `concat` function to accept
more than two arguments, adds new cryptographic built-in functions, adds
built-ins for trustlessly verifying Bitcoin transaction outputs on-chain, and
adds new Clarity allowances for the PoX-5 staking model.

In addition to the Clarity changes, this SIP introduces a mechanism for handling
problematic transactions in blocks, and the deprecation of the long-unused
`cost-voting` contract. These changes are motivated by real-world developer
experience, operational concerns from miners and signers, and the ongoing
evolution of the PoX staking model.

# Copyright

This SIP is made available under the terms of the BSD-2-Clause license,
available at https://opensource.org/licenses/BSD-2-Clause. This SIP's copyright
is held by the Stacks Open Internet Foundation.

# Introduction

This SIP addresses several limitations and inconveniences that have been
reported by Clarity developers. Specifically, it makes the following changes:

1. **Variadic `concat`:** The `concat` function currently accepts only two
   arguments, so assembling a sequence from more than two parts requires deeply
   nested calls. This is verbose and hard to read, particularly in code that
   builds multi-field binary payloads (such as cross-chain bridge
   serialization).
2. **secp256k1 public key decompression:** There is currently no way to
   decompress a secp256k1 public key in Clarity. This forces protocols like
   Wormhole to use cumbersome workarounds involving uncompressed keys, leading
   to operational downtime when guardian sets change.
3. **Ed25519 signature verification:** Clarity currently supports signature
   verification only on the secp256k1 curve (used by Bitcoin and Ethereum) and
   the secp256r1 curve (used by Apple's Secure Enclave and WebAuthn). There is
   no way to verify Ed25519 signatures, which are the standard for many other
   ecosystems (including Solana, Cardano, Polkadot, Stellar, Tor, SSH, and
   Signal). This blocks cross-chain bridges and attestation/identity systems
   that need to verify signatures produced by those ecosystems.
4. **Trustless Bitcoin transaction verification:** Clarity contracts have no
   native way to verify that a Bitcoin transaction output exists on the Bitcoin
   chain. Protocols that need this capability (such as BTC bridges and
   sBTC-style peg systems) must currently rely on off-chain oracles or trusted
   relayers, or reimplement Bitcoin transaction parsing and merkle-proof
   verification in user-space Clarity code, which is expensive, error-prone, and
   difficult to audit.
5. **PoX allowance:** A new in-contract allowance, `with-pox`, is added, for use
   in `as-contract?` and `restrict-assets?` expressions. This new allowance
   controls whether the protected body is allowed to modify state in the active
   PoX contract. This is an addition to the existing `with-stacking`, which is
   also renamed to `with-staking`, which allows the body to stake (or update) a
   specific amount of STX.

Additionally, it addresses the need for new functionality, as a result of the
new Bitcoin-staking model, described in SIP-045, on which this SIP is a rider:

1. **Problematic transactions** Transactions that are deemed to be problematic
   by agreement between miners and signers should be included in a block, with
   their fees taken.
2. **Disable `cost-voting`** This contract was originally designed as a
   mechanism to allow the cost of a specific function call to be overwritten
   without the need for a hard-fork. The handling of this contract complicates
   the code and slows down execution, but it has never been used, so it is
   better for the network to disable this functionality and continue to make
   cost changes through the SIP process, which has been working smoothly.

As with every Clarity upgrade, cost computations and budgets are re-evaluated
alongside the language changes. The updated costs take effect when this SIP
activates.

# Specification

This SIP requires a hard fork. The changes specified below all activate together
at the onset of Stacks Epoch 4.0. New contracts deployed in Epoch 4.0 will
default to Clarity 6, though contract authors can override this by specifying an
earlier version in the deploy transaction.

## Clarity 6

### Variadic `concat`

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

#### Example

```clarity
;; Clarity 5 and below: nested calls required
(concat (concat (concat 0x11 amount-bytes) fee-bytes) chain-id)

;; Clarity 6: flat, variadic call
(concat 0x11 amount-bytes fee-bytes chain-id)
```

### Add `secp256k1-decompress?` Function

Originally proposed here: https://github.com/clarity-lang/reference/issues/103

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
- **Output**: `(optional (buff 65))`: the uncompressed public key, or `none` if
  the input is not a valid compressed public key
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

#### Deriving an Ethereum Address

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

### Add `ed25519-verify` Function

Clarity currently provides signature verification only on the secp256k1 curve
(via `secp256k1-verify`) and the secp256r1 curve (via `secp256r1-verify`, added
in Clarity 5). There is no built-in for verifying Ed25519 signatures, even
though Ed25519 is the dominant signature scheme outside of the Bitcoin and
Ethereum ecosystems and is used by Solana, Cardano, Polkadot, Stellar, Tor, SSH,
and Signal, among many other systems.

This omission prevents Clarity contracts from natively verifying messages signed
by participants in any of those ecosystems, which is a hard requirement for
cross-chain bridges and for identity/attestation systems that rely on
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

### Bitcoin Transaction Verification Built-ins

Clarity contracts currently have no first-class way to verify that a Bitcoin
transaction output exists on the Bitcoin chain. Protocols such as BTC bridges
and sBTC-style peg systems must either rely on trusted off-chain relayers or
reimplement Bitcoin transaction parsing and merkle-proof verification in
user-space Clarity, where the cost of double-SHA-256 hashing and byte-level
parsing on large transactions is prohibitive and the risk of subtle bugs (such
as CVE-2012-2459-style merkle malleability) is high.

Beginning in Clarity 6, two new built-in functions, `get-bitcoin-tx-output?` and
`verify-merkle-proof`, are available. They are designed as a pair: the `txid`
returned by `get-bitcoin-tx-output?` is in the internal (raw) byte order
expected by `verify-merkle-proof` as a leaf hash. Combined with the existing
`get-burn-block-info?` built-in — whose `header-hash` property lets a contract
authenticate a user-supplied Bitcoin block header (and thereby extract its
merkle root) — they enable contracts to verify that a Bitcoin output exists
on-chain without trusting the caller to have correctly stripped witness data or
hashed the transaction.

#### `get-bitcoin-tx-output?`

- **Input**: `buff, uint`: a serialized Bitcoin transaction (with or without
  SegWit witness data), and the output index (`vout`) to extract.
- **Output**:
  `(response (tuple (script (buff 1024)) (amount uint) (txid (buff 32))) uint)`
- **Signature**: `(get-bitcoin-tx-output? tx-bytes vout)`
- **Description**: Parses a serialized Bitcoin transaction and returns the
  output at the given `vout` index, along with the canonical (non-witness)
  `txid` of the transaction. The returned `txid` is in _internal_ byte order
  (the raw double-SHA-256 result), ready to be passed directly to
  `verify-merkle-proof` as the leaf hash. The `script` field contains the raw
  `scriptPubKey` bytes of the output, so contracts can pattern-match on script
  prefixes to recognize P2WSH (`0x00 0x20 ...`), P2TR (`0x51 0x20 ...`), P2WPKH
  (`0x00 0x14 ...`), `OP_RETURN` (`0x6a ...`), or any other output script.
  Returns one of three error codes on failure:
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

#### `verify-merkle-proof`

- **Input**: `(buff 32), (buff 32), uint, uint, (list 24 (buff 32))`: the leaf
  hash, the merkle root hash, the leaf's index in the tree, the total
  transaction count of the block, and the list of sibling hashes along the path
  from the leaf to the root.
- **Output**: `bool`
- **Signature**:
  `(verify-merkle-proof leaf-hash root-hash tx-index tx-count sibling-hashes)`
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
  [CVE-2012-2459](https://bitcointalk.org/?topic=102395)-style attacks, where an
  intermediate node in an odd-row-padded tree could otherwise be passed off as a
  leaf. The function rejects any proof whose path length does not match
  `ceil(log2(tx-count))` and any `tx-index` not less than `tx-count`. It returns
  `false` for any malformed proof and `true` for a valid proof.

  All 32-byte hashes (leaf, root, siblings) are passed in _internal_ (raw) byte
  order, not the display (reversed) order conventionally used for Bitcoin txids
  and block hashes. The `txid` returned by `get-bitcoin-tx-output?` is already
  in internal byte order and can be passed directly as `leaf-hash`.

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

### `with-staking`

- **Input**:
  - `amount`: `uint`: The amount of uSTX that can be locked.
- **Output**: Not applicable
- **Signature**: `(with-staking amount)`
- **Description**: Adds a staking allowance for `amount` uSTX from the
  `asset-owner` of the enclosing `restrict-assets?` or `as-contract?`
  expression. This restricts calls to the active PoX contract that modify the
  `tx-sender`'s STX staking status, ensuring that the locked amount is limited
  by the amount of uSTX specified. `with-staking` replaces Clarity 4's
  `with-stacking` to match the new naming. The following public functions in the
  new pox-5 contract will trigger this restriction:
  - `stake`
  - `register-for-bond`
  - `stake-update`
- **Example**:
  ```clarity
  (restrict-assets? tx-sender ((with-staking u1000000000000))
    (try! (contract-call? 'SP000000000000000000002Q6VF78.pox-5 stake
      'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.signer u1100000000000 u12 u1000
      none
    ))
  );; Returns (err u0)
  (restrict-assets? tx-sender ((with-staking u1000000000000))
    (try! (contract-call? 'SP000000000000000000002Q6VF78.pox-5 stake
      'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.signer u1000000000000 u12 u1000
      none
    ))
  );; Returns (ok true)
  ```

### `with-pox`

- **Input**: Not applicable
- **Output**: Not applicable
- **Signature**: `(with-pox)`
- **Description**: Adds an allowance for interacting with the latest PoX
  contract for the `asset-owner` of the enclosing `restrict-assets?` or
  `as-contract?` expression, specifically calling functions that act on behalf
  of the `tx-sender` and do not trigger a staking event (see `with-staking`).
  This includes the following public functions from the new pox-5 contract:
  - `unstake`
  - `unstake-sbtc`
  - `update-bond-registration`
  - `announce-l1-early-exit`
- **Example**:
  ```clarity
  (restrict-assets? tx-sender ()
    (try! (contract-call? 'SP000000000000000000002Q6VF78.pox-5 unstake
      'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.signer
    ))
  );; Returns (err u0)
  (restrict-assets? tx-sender ((with-pox))
    (try! (contract-call? 'SP000000000000000000002Q6VF78.pox-5 unstake
      'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.signer
    ))
  );; Returns (ok true)
  ```

## Problematic Transactions

A Stacks miner needs a mechanism to charge a fee for all transactions for which
it does work. For example, if a miner attempts to mine a transaction and during
execution, it is determined to be too expensive to fit in a block, the miner
should still be able to collect the fee from that transaction and remove it from
the mempool. This is useful to protect both the miner, and the user, whose
account would otherwise be blocked by this unmineable nonce, requiring a
replace-by-fee, or waiting for the transaction to time out of the mempool.

Epoch 4.0 will add a new mechanism to allow a miner to identify problematic
transactions in the block header. When other nodes verify this block, they do
not execute those problematic transactions, but simply debit the fee and
increment the nonces. The specification of this list of transactions is defined
as part of this hard fork. The mechanism for determining whether a transaction
may be marked as problematic is an agreement between miners and signers. A miner
can add transactions to this list in a block proposal and signers will analyze
the transactions and decide whether to accept that list or reject it.
Alternatively, a miner might propose a block including transactions normally,
but then the signers analyze the block and decide that one of the transactions
is problematic, and sends that information back to the miner as part of the
block rejection.

### Block header version

The Nakamoto block header carries a single-byte version field. The high bit
(0x80) is reserved as the shadow-block flag; the header version number is the
low 7 bits (version & 0x7f).

This SIP defines:

- 0 - the header version for Nakamoto epochs prior to Epoch 4.0.
- 1 - the header version for Epoch 4.0 and later.

A block is invalid if `(version & 0x7f) != expected_version(epoch)`, where epoch
is the Stacks epoch of the block's tenure (the epoch at the block's tenure burn
height).

### The `problematic_txs` field

A `problematic_txs` field is appended to the `NakamotoBlockHeader`. The field is
present in the header's serialization (and in all header hashes) iff the header
version number is >= 1. For version-0 headers the field is absent from the byte
stream entirely; on deserialization of a version-0 header it decodes to the
empty list and consumes no bytes.

### `ProblematicTxMarker` encoding

```rust
ProblematicTxMarker {
    tx_index: u32,   // index into NakamotoBlock::txs
    category: u8,    // opaque-to-consensus reason code
}
```

Consensus serialization (network byte order):

| field      | size    | encoding       |
| ---------- | ------- | -------------- |
| `tx_index` | 4 bytes | big-endian u32 |
| `category` | 1 byte  | u8             |

Total: 5 bytes per marker. The list is length-prefixed with a big-endian u32
count, per the standard Stacks vector encoding.

`tx_index` is the 0-based position of the marked transaction in the block's
transaction vector. `category` is opaque to consensus, but it conveys the reason
the transaction was flagged (for observers and tooling) but is not interpreted
by validation. It participates in the block hash and must be agreed upon, but
any value is accepted.

### Serialization and hashing

When (and only when) the header version number is >= 1, `problematic_txs` is
included in all of:

- `consensus_serialize` (the wire/disk encoding of the header),
- the miner signature hash preimage,
- the signer signature hash preimage, which is also the block hash
  (`block_id = SHA512/256` over the header excluding signatures, combined with
  the consensus hash).

A single shared predicate governs the field's presence at all four sites, so it
can never diverge between them.

### Consensus validation rules

A block's `problematic_txs` is valid iff all of the following hold:

1. **Version/epoch agreement**: `(version & 0x7f) == expected_version(epoch)`.
2. **Epoch gate**: before Epoch 4.0 the list MUST be empty.
3. **Cardinality**: `problematic_txs.len() <= MAX_PROBLEMATIC_TX_MARKERS`.
4. **Strictly increasing**: `tx_index` values are strictly increasing (which
   also forbids duplicates).
5. **In range**: every `tx_index < block.txs.len()`.
6. **Never coinbase or tenure-change**: no marker may point at a `Coinbase` or
   `TenureChange` transaction; those must always execute.

`MAX_PROBLEMATIC_TX_MARKERS` is defined as
`MAX_BLOCK_LEN / MIN_TRANSACTION_LEN = 2,097,152 / 180 = 11,650`, the maximum
number of transactions that can fit in a block, since a marker addresses a
distinct transaction and as such never needs to exceed the block's transaction
count. This bound is also enforced during deserialization (the marker list is
read with this cap), so a malformed length prefix cannot force unbounded
allocation.

### Replay semantics

For each transaction in the block, in order, replaying nodes determine whether
its index appears in `problematic_txs`. If it does, the transaction is skipped,
performing only the following actions:

1. Run the static transaction precheck (size, auth mode, chain ID, network,
   post-condition mode, requested Clarity version, …). A precheck failure still
   invalidates the block.
2. Debit the transaction fee from the payer.
3. Increment the origin nonce, and the sponsor nonce if the payer differs from
   the origin.
4. Do **not** call `process_transaction_payload`. No Clarity code runs; no
   contract is deployed; no events are emitted.

The resulting transaction receipt has execution_cost = 0, an empty event list, a
result of `(err none)`, and a status of `problematic_skipped` (carrying the
category byte) in event payloads.

All other transactions execute normally.

## Disable `cost-voting`

At the launch of Epoch 2.0, the
[`cost-voting` contract](https://explorer.hiro.so/txid/SP000000000000000000002Q6VF78.cost-voting?chain=mainnet)
was deployed to provide a mechanism to change the cost charged for the execution
of a contract call without requiring any hard-fork. While the idea was sound,
the functionality has not been used in the 8-million+ blocks that have since
been mined, likely because it requires locking STX, which cannot be stacked.
During that time, the community has clarified and successfully exercised the SIP
process several times to make changes to Clarity costs, making this mechanism no
longer necessary. By disabling the functionality of the `cost-voting` contract,
the code in the `stacks-node` can be made more performant and at the same time,
simplified.

Once Epoch 4.0 activates, the `cost-voting` contract will no longer have any
effect on consensus and can be ignored.

# Related Work

This SIP builds upon the existing definitions of the Clarity language:

- [SIP-002 (Clarity 1)](../sip-002/sip-002-smart-contract-language.md)
- [SIP-015 (Clarity 2)](../sip-015/sip-015-network-upgrade.md)
- [SIP-021 (Clarity 3)](../sip-021/sip-021-nakamoto.md)
- [SIP-033 (Clarity 4)](../sip-033/sip-033-clarity4.md)
- [SIP-039 (Clarity 5)](../sip-039/sip-039-clarity5.md)

Parts of this SIP depend upon
[SIP-045 (Bitcoin Staking)](https://github.com/adriano-stacks/sips/blob/main/sips/sip-xxx/sip-0XX-pox-5-bitcoin-staking.md)
and this SIP is intended to activate together with it.

The new transaction-level post-conditions build upon the post-conditions defined
in [SIP-005](../sip-005/sip-005-blocks-and-transactions.md).

# Backwards Compatibility

Because this SIP extends the `concat` function to accept more than two arguments
and adds new built-in functions (`secp256k1-decompress?`, `ed25519-verify`,
`get-bitcoin-tx-output?`, and `verify-merkle-proof`), it is a consensus-breaking
change. A contract that uses any of these new features would be invalid before
this SIP is activated, and valid after it is activated.

All new keywords introduced in Clarity 6 can no longer be used as identifiers in
a Clarity 6 smart contract. Smart contracts can continue to be published using
older versions of Clarity by specifying the version in the deploy transaction.

Existing contracts deployed with previous Clarity versions are unaffected and
will continue to execute with their existing behavior.

# Activation

Users can vote to approve this SIP with either their locked/stacked STX or with
unlocked/liquid STX, or both.

In order for this SIP to activate, the following criteria must be met:

- At least 80 million stacked STX must participate in the vote, and at least 80%
  of all stacked STX committed by voting must be in favor of the proposal (vote
  "yes").
- At least 80% of all liquid STX committed by voting must be in favor of the
  proposal (vote "yes").

All STX holders vote by sending Stacks dust to the corresponding Stacks address
from the account where their Stacks are held (stacked or liquid). Voting power
is determined by a snapshot of the amount of STX (stacked and unstacked) at the
block height at which the voting started (preventing the same STX from being
transferred between accounts and used to effectively double vote).

Solo stackers can also vote by sending a bitcoin dust transaction (6000 sats) to
the corresponding bitcoin address, from their PoX address.

| Vote | Bitcoin                          | Stacks                                | ASCII Encoding         | Msg        |
| ---- | -------------------------------- | ------------------------------------- | ---------------------- | ---------- |
| yes  | `11111111111mdWK2VXcrA1f72DmUku` | `SP00000000001WPAWSDEDMQ0B9M6HQVS7Q6` | `7965732d7369702d3434` | yes-sip-44 |
| no   | `111111111111ACW5wa4RwyfJspnNhu` | `SP000000000006WVSDEDMQ0B9M6K3NTSJK`  | `6e6f2d7369702d3434`   | no-sip-44  |

Voting will take place over the same voting window as SIP-045, to be identified
during the community review period, following the precedent of SIP-021 and
SIP-029 of finalizing block heights during vote preparation. If the criteria are
not met within that window, the SIP is Rejected.

If approved, the activation block height will be finalized during vote
preparation, together with SIP-045.

# Reference Implementation

All functionality proposed in this SIP is implemented or in progress in the
[`pox-wf-integration` branch](https://github.com/stacks-network/stacks-core/tree/pox-wf-integration)
on https://github.com/stacks-network/stacks-core.
