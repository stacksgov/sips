# Preamble

SIP Number: 027

Title: Non-sequential Multisig Transactions

Authors: Jeff Bencin <jbencin@hiro.so>, Vlad Bespalov <vlad@asigna.io>

Consideration: Technical

Type: Consensus

Status: Draft

Created: 2023-08-30

License: BSD 2-Clause

Sign-off:

Discussions-To: https://github.com/stacksgov/sips

# Abstract

This SIP proposes a new multisig transaction format which is intended to be easier to use than the current format described in SIP-005.
It does not remove support for the current format, rather it is intended to co-exist with the old format and give users a choice of which format to use.

The issue with the current format is that it establishes a signer order when funds are sent to multisig account address, and requires signers to sign in the same order to spend the funds.
In practice, the current format has proven difficult to understand and implement, as evidenced by the lack of Stacks multisig implementations today.

This new format intends to simplify the signing algorithm and remove the requirement for in-order signing, without comprimising on security or increasing transaction size.
It is expected that this will lead to better wallet support for Stacks multisig transactions.

# Introduction

Currently, a multisig transaction requires the first signer to sign the transaction itself, and subsequent signers to sign the signature of the previous signer.
For a transaction with *n* signers, the final signature is generated in the following way:

```
signature_n(...(signature_2(signature_1(tx))))
```

There are a few drawbacks to doing it this way:

- The order in which the signers must sign is fixed as soon as funds are sent to a multisig account, which limits flexibility when creating a spending transaction from a multisig account
- The process of signing a transaction requires each signer to validate the entire signature chain before signing, in order to make sure it matches the transaction.
  This means the time to fully sign a transaction is `O(n^2)`
- This does not reduce the size of a transaction, as each intermediate signature must still be included
- The algorithm for doing this is complex, and several developers have a hard time understanding and implementing it correctly

This document proposes having each signer sign the transaction directly:

```
signature_1(tx), signature_2(tx), ..., signature_n(tx)
```

This would address all of the concerns listed above, and would not increase transaction size or make it easier to forge a signature

## Examples

Imagine a DAO that has a management team comprised of five members.
They create a 3 out of 5 multisig account on Stacks.
The existing multisig standard mandates that all transactions from this account be signed in an order which is established upon account creation.
The ordering requirement creates a hierarchy where keys near the start of the sequence have more flexibility than those near the end.
To illustrate some of the limitations this creates:

- In a scenario where the 1st member initiates a transaction and the 4th signs it, it prohibits the 2nd and 3rd members from signing. The responsibility then falls solely on the 5th member to finalize the transaction.
- Once the 5th member has signed a transaction, no further signatures are possible.
- If the 3rd member initiates a transaction, only the 4th and 5th members are eligible to provide subsequent signatures.
- Initiating a transaction by the 4th or 5th member is impossible, as there are insufficient subsequent members to complete the signing process.

While such a multisig setup might suffice for smaller teams, as the number of required signers increases, it becomes increasingly difficult to create a transaction. This SIP aims to remove these limitations.

# Specification

This is intended to be an update and replacement for the existing
"[Transaction Authorization](https://github.com/stacksgov/sips/blob/main/sips/sip-005/sip-005-blocks-and-transactions.md#transaction-authorization)" and
"[Transaction Signing and Verifying](https://github.com/stacksgov/sips/blob/main/sips/sip-005/sip-005-blocks-and-transactions.md#transaction-signing-and-verifying)" sections of SIP-005.
For anything not mentioned here, the rules from SIP-005 still apply.

### Transaction Encoding

#### Transaction Authorization

Each transaction contains a transaction authorization structure, which is used
by the Stacks peer to identify the originating account and sponsored account, to
determine the fee that the spending account will pay, and to
and determine whether or not it is allowed to carry out the encoded state-transition.
It is encoded as follows:

* A 1-byte **authorization type** field that indicates whether or not the
  transaction has a standard or sponsored authorization.
   * For standard authorizations, this value MUST be `0x04`.
   * For sponsored authorizations, this value MUST be `0x05`.
* One or two **spending conditions**, whose encoding is described below.  If the
  transaction's authorization type byte indicates that it is a standard
authorization, then there is one spending condition.  If it is a sponsored
authorization, then there are two spending conditions that follow.

_Spending conditions_ are encoded as follows:

* A 1-byte **hash mode** field that indicates how the origin account authorization's public
  keys and signatures should be used to calculate the account address.  Four
modes are supported, in the service of emulating the four hash modes supported
in Stacks v1 (which uses Bitcoin hashing routines):
   * `0x00`: A single public key is used.  Hash it like a Bitcoin P2PKH output.
   * `0x01`: One or more public keys are used.  Hash them as a Bitcoin multisig P2SH redeem script.
   * `0x02`: A single public key is used.  Hash it like a Bitcoin P2WPKH-P2SH
     output.
   * `0x03`: One or more public keys are used.  Hash them as a Bitcoin
     P2WSH-P2SH output.
* A 20-byte **public key hash**, which is derived from the public key(s) according to the
  hashing routine identified by the hash mode.  The hash mode and public key
hash uniquely identify the origin account, with the hash mode being used to
derive the appropriate account version number.
* An 8-byte **nonce**.
* An 8-byte **fee**.
* Either a **single-signature spending condition** or a **multisig spending
  condition**, described below.  If the hash mode byte is either `0x00` or
`0x02`, then a single-signature spending condition follows.  Otherwise, a
multisig spending condition follows.

A _single-signature spending condition_ is encoded as follows:

* A 1-byte **public key encoding** field to indicate whether or not the
  public key should be compressed before hashing.  It will be:
   * `0x00` for compressed
   * `0x01` for uncompressed
* A 65-byte **recoverable ECDSA signature**, which contains a signature
and metadata for a secp256k1 signature.

A _multisig spending condition_ is encoded as follows:

* A length-prefixed array of **spending authorization fields**, described
  below.
* A 2-byte **signature count** indicating the number of signatures that
  are required for the authorization to be valid.

A _spending authorization field_ is encoded as follows:

* A 1-byte **field ID**, which can be `0x00`, `0x01`, `0x02`, or
  `0x03`.
* The **spending field body**, which will be the following,
  depending on the field ID:
   * `0x00` or `0x01`:  The next 33 bytes are a compressed secp256k1 public key.
     If the field ID is `0x00`, the key will be loaded as a compressed
     secp256k1 public key.  If it is `0x01`, then the key will be loaded as
     an uncompressed secp256k1 public key.
   * `0x02` or `0x03`:  The next 65 bytes are a recoverable secp256k1 ECDSA
     signature.  If the field ID is `0x02`, then the recovered public
     key will be loaded as a compressed public key.  If it is `0x03`,
     then the recovered public key will be loaded as an uncompressed
     public key.

A _compressed secp256k1 public key_ has the following encoding:

* A 1-byte sign byte, which is either `0x02` for even values of the curve's `y`
  coordinate, or `0x03` for odd values.
* A 32-byte `x` curve coordinate.

An _uncompressed secp256k1 public key_ has the following encoding:

* A 1-byte constant `0x04`
* A 32-byte `x` coordinate
* A 32-byte `y` coordinate

A _recoverable ECDSA secp256k1 signature_ has the following encoding:

* A 1-byte **recovery ID**, which can have the value `0x00`, `0x01`, `0x02`, or
  `0x03`.
* A 32-byte `r` curve coordinate
* A 32-byte `s` curve coordinate.  Of the two possible `s` values that may be
  calculated from an ECDSA signature on secp256k1, the lower `s` value MUST be
used.

The number of required signatures and the list of public keys in a spending
condition structure uniquely identifies a standard account.
and can be used to generate its address per the following rules:

| Hash mode | Spending Condition | Mainnet version | Hash algorithm |
| --------- | ------------------ | --------------- | -------------- |
| `0x00` | Single-signature | 22 | Bitcoin P2PKH |
| `0x01` | Multi-signature | 20 | Bitcoin redeem script P2SH |
| `0x02` | Single-signature | 20 | Bitcoin P2WPK-P2SH |
| `0x03` | Multi-signature | 20 | Bitcoin P2WSH-P2SH |

In addition to the hash modes specified in SIP-005, this SIP adds two new hash modes: `0x05` and `0x07`.
These numbers were chosen in order to maintain the following relationships:
 - `is_multisig = hash_mode & 0x1`
 - `is_p2wsh_p2sh = hash_mode & 0x2`
 - `is_non_sequential_multisig = hash_mode & 0x4`

| Hash mode | Spending Condition | Mainnet version | Hash algorithm |
| --------- | ------------------ | --------------- | -------------- |
| `0x05` | Non-sequential multi-signature | 20 | Bitcoin redeem script P2SH |
| `0x07` | Non-sequential multi-signature | 20 | Bitcoin P2WSH-P2SH |

The corresponding testnet address versions are:
*  For 22 (`P` in the c32 alphabet), use 26 (`T` in the c32 alphabet)
*  For 20 (`M` in the c32 alphabet), use 21 (`N` in the c32 alphabet).

The hash algorithms are described below briefly, and mirror hash algorithms used
today in Bitcoin.  This is necessary for backwards compatibility with Stacks v1
accounts, which rely on Bitcoin's scripting language for authorizations.

_Hash160_:  Takes the SHA256 hash of its input, and then takes the RIPEMD160
hash of the 32-byte

_Bitcoin P2PKH_:  This algorithm takes the ECDSA recoverable signature and
public key encoding byte from the single-signature spending condition, converts them to
a public key, and then calculates the Hash160 of the key's byte representation
(i.e., by serializing the key as a compressed or uncompressed secp256k1 public
key).

_Bitcoin redeem script P2SH_:  This algorithm converts a multisig spending
condition's public keys and recoverable signatures
into a Bitcoin BIP16 P2SH redeem script, and calculates the Hash160
over the redeem script's bytes (as is done in BIP16).  It converts the given ECDSA
recoverable signatures and public key encoding byte values into their respective
(un)compressed secp256k1 public keys to do so.

_Bitcoin P2WPKH-P2SH_:  This algorithm takes the ECDSA recoverable signature and
public key encoding byte from the single-signature spending condition, converts
them to a public key, and generates a P2WPKH witness program, P2SH redeem
script, and finally the Hash160 of the redeem script to get the address's public
key hash.

_Bitcoin P2WSH-P2SH_:  This algorithm takes the ECDSA recoverable signatures and
public key encoding bytes, as well as any given public keys, and converts them
into a multisig P2WSH witness program.  It then generates a P2SH redeem script
from the witness program, and obtains the address's public key hash from the
Hash160 of the redeem script.

The resulting public key hash must match the public key hash given in the
transaction authorization structure.  This is only possible if the ECDSA
recoverable signatures recover to the correct public keys, which in turn is only
possible if the corresponding private key(s) signed this transaction.

#### Transaction Signing and Verifying

A transaction may have one or two spending conditions.  The act of signing
a transaction is the act of generating the signatures for its authorization
structure's spending conditions, and the act of verifying a transaction is the act of (1) verifying
the signatures in each spending condition and (2) verifying that the public key(s)
of each spending condition hash to its address.

Signing a transaction is performed after all other fields in the transaction are
filled in.  The high-level algorithm for filling in the signatures in a spending
condition structure is as follows:

0. Set the spending condition address, and optionally, its signature count.
1. Clear the other spending condition fields, using the appropriate algorithm below.
   If this is a sponsored transaction, and the signer is the origin, then set the sponsor spending condition
   to the "signing sentinel" value (see below).
2. Serialize the transaction into a byte sequence, and hash it to form an
   initial `sighash`.
3. Calculate the `presign-sighash` over the `sighash` by hashing the
   `sighash` with the authorization type byte (0x04 or 0x05), the fee (as an 8-byte big-endian value),
   and the nonce (as an 8-byte big-endian value).

For sequential hash modes `0x00`, `0x01`, `0x02`, and `0x03`:

4. Calculate the ECDSA signature over the `presign-sighash` by treating this
   hash as the message digest.  Note that the signature must be a `libsecp256k1`
   recoverable signature.
5. Calculate the `postsign-sighash` over the resulting signature and public key
   by hashing the `presign-sighash` hash, the signing key's public key encoding byte, and the
   signature from step 4 to form the next `sighash`.  Store the message
   signature and public key encoding byte as a signature auth field.
6. Repeat steps 3-5 for each private key that must sign, using the new `sighash`
   from step 5.

For non-sequential hash modes `0x05` and `0x07`:

4. Calculate the ECDSA signature over the `presign-sighash` by treating this
   hash as the message digest.  Note that the signature must be a `libsecp256k1`
   recoverable signature. Store the message signature and public key encoding byte as a signature auth field.
5. Repeat step 4 until the signer threshold is reached.

The algorithms for clearing an authorization structure are as follows:
* If this is a single-signature spending condition, then set the fee and
  nonce to 0, and set the signature bytes to 0 (note that the address is _preserved_).
* If this is a multi-signature spending condition, then set the fee and
  nonce to 0, and set the vector of authorization fields to the empty vector
  (note that the address and the 2-byte signature count are _preserved_).

While signing a transaction, the implementation keeps a running list of public
keys, public key encoding bytes, and signatures to use to fill in the spending condition once signing
is complete.  For single-signature spending conditions, the only data the
signing algorithm needs to return is the public key encoding byte and message signature.  For multi-signature
spending conditions, the implementation returns the sequence of public keys and
(public key encoding byte, ECDSA recoverable signature) pairs that make up the condition's authorization fields.
The implementation must take care to preserve the order of public keys and
(encoding-byte, signature) pairs in the multisig spending condition, so that
the verifying algorithm will hash them all in the right order when verifying the
address.

When signing a sponsored transaction, the origin spending condition signatures
are calculated first, and the sponsor spending conditions are calculated second.
When the origin key(s) sign, the set the sponsor spending condition to a
specially-crafted "signing sentinel" structure.  This structure is a
single-signature spending condition, with a hash mode equal to 0x00, an
address and signature of all 0's, a fee and a nonce equal to 0, and a
public key encoding byte equal to 0x00.  This way, the origin commits to the
fact that the transaction is sponsored without having to know anything about the
sponsor's spending conditions.

When sponsoring a transaction, the sponsor uses the same algorithm as above to
calculate its signatures.  This way, the sponsor commits to the signature(s) of
the origin when calculating its signatures.

When verifying a transaction, the implementation verifies the sponsor spending
condition (if present), and then the origin spending condition.  It effectively
performs the signing algorithm again, but this time, it verifies signatures and
recovers public keys.

0. Extract the public key(s) and signature(s) from the spending condition.
1. Clear the spending condition.
2. Serialize the transaction into a byte sequence, and hash it to form an
   initial `sighash`.
3. Calculate the `presign-sighash` from the `sighash`, authorization type byte,
   fee, and nonce.
4. Use the `presign-sighash` and the next (public key encoding byte,
   ECDSA recoverable signature) pair to recover the public key that generated it.

For sequential hash modes `0x00`, `0x01`, `0x02`, and `0x03`:

5. Calculate the `postsign-sighash` from `presign-sighash`, the signature, public key encoding
   byte,
6. Repeat steps 3-5 for each signature, so that all of the public keys are
   recovered.
7. Verify that the sequence of public keys hash to the address, using
   the address's indicated public key hashing algorithm, and the number of signatures
   matches **exactly** the required number of signatures.

For non-sequential hash modes `0x05` and `0x07`:

5. Repeat step 4 for each signature, so that all of the public keys are
   recovered.
6. Verify that the sequence of public keys hash to the address, using
   the address's indicated public key hashing algorithm, and the number of signatures
   is **at least** the required number of signatures.

When verifying a sponsored transaction, the sponsor's signatures are verified
first.  Once verified, the sponsor spending condition is set to the "signing
sentinel" value in order to verify the origin spending condition.

#### Additional Recommendations

While this SIP allows signers to sign in any order, the ordering of public keys in the transaction auth fields still affects multisig account address generation.
When funding a multisig account or creating a transaction, it is strongly recommended, but not required, to order public keys from least to greatest (equivalant to lexographically sorting the hex-encoded strings).
This will remove the requirement to remember key order and result in consistent address generation.

# Related Work

[PR #139](https://github.com/stacksgov/sips/pull/139): This draft SIP was created earlier but lacked the technical specifications for implementation. The author has since closed this PR in favor of this draft

# Layer

Consensus (hard fork)

# Requires

[SIP-005](https://github.com/stacksgov/sips/blob/main/sips/sip-005/sip-005-blocks-and-transactions.md)

# Backwards Compatibility

The Stacks Blockchain will continue to treat multisig transactions using the current format as valid.
Existing multisig accounts will be able to use the new transaction types to spend previously recieved funds.

# Activation

Since this SIP requires a change to the stacks consensus rules a community vote is additionally required.

## Process of Activation
Users can vote to approve this SIP with either their locked/stacked STX or with unlocked/liquid STX, or both. The criteria for the stacker and non-stacker voting is as follows.

## For Stackers:

In order for this SIP to activate, the following criteria must be met by the set of Stacked STX:

- At least double the amount of Stacked STX locked by the largest Stacker in the cycle preceding the vote must vote at all to activate this SIP.
- Of the Stacked STX that vote, at least 70% of them must vote "yes."

The voting addresses will be:

- Bitcoin **YES** Address: 399iMhKN9fjpPJLYHzieZA1PfHsFxijyVY
- Bitcoin **NO** Address: 31ssu69FmpxS6bAxjNrX1DfApD8RekK7kp
- Stacks **YES** Address: SPA17ZSXKXS4D8FC51H1KWQDFS31NM29SKZRTCF8
- Stacks **NO** Address: SP39DK8BWFM2SA0E3F6NA72104EYG9XB8NXZ91NBE

which encode the hashes of the following phrases into Bitcoin / Stacks addresses:

- **YES** to Non-sequential Multisig Transactions
- **NO** to Non-sequential Multisig Transactions

Stackers (pool and solo) vote by sending a dust stacks to the corresponding stacks address **from the account where their STX are locked**.

Solo stackers only, can also vote by sending a Bitcoin dust transaction (6000 sats) to the corresponding bitcoin address.

## For Non-Stackers:

Users with liquid STX can vote on proposals using the Ecosystem DAO. Liquid STX is the users balance, less any STX they have locked in PoX stacking protocol, at the block height at which the voting started (preventing the same STX from being transferred between accounts and used to effectively double vote). This is referred to generally as "snapshot" voting.

For this SIP to pass, 66% of all liquid STX committed by voting must be in favour of the proposal.

The act of not voting is the act of siding with the outcome, whatever it may be. We believe that these thresholds are sufficient to demonstrate interest from Stackers -- Stacks users who have a long-term interest in the Stacks blockchain's successful operation -- in performing this upgrade.

If the majority vote is **YES**, order-independent multisig transactions will be enabled upon reaching Stacks Epoch 3.0.

# Reference Implementations

To be implemented in Rust. See https://github.com/stacks-network/stacks-blockchain/pull/3710.
