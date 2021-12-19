# SIP-017 — Schnorr signatures

## Preamble

**SIP:** 017 (awaiting acceptance)

**Title:** Schnorr signatures

**Author:** Asteria [asteria@syvita.org](mailto:asteria@syvita.org)

**Consideration:** Technical

**Type:** Consensus

**Layer:** Consensus (soft fork)

**Status:** Draft

**Created:** 19 December 2021

**License:** BSD 2-Clause

**Sign-off:** —

## Abstract

This SIP describes the addition of Schnorr signature structure and validation to the account model for the Stacks blockchain.

## Introduction

The Stacks blockchain signing system was initially built on ECDSA, similar to how the Bitcoin blockchain was. However, it is widely acknowledged that Schnorr is the better signing algorithm over ECDSA. The primary reason it wasn’t used in the Bitcoin blockchain for many years is that Schnorr was patented until 2008, the same year Bitcoin was invented. At the time, Satoshi Nakomoto decided that Schnorr signatures lacked the popularity and testing required to secure a system as critical as Bitcoin.

13 years later, Schnorr now has been tested and popularised through the Bitcoin Taproot upgrade in November 2021. Now that Schnorr has been implemented on Bitcoin, I believe we should adopt it for Stacks too.

Schnorr signatures have many advantages over ECDSA ones:

- **Better privacy**, by making different multisig spending policies indistinguishable on-chain. Used in Stacks transactions, these spending policies become a single signature on-chain, regardless of number of participants in an account. This opens up opportunities for decentralised organisations (DAOs) such as the Syvita Guild to coordinate Stacks transaction activity offchain, as the compute cost to verify a Schnorr signature on Stacks made from one or a million people is identical.
- Enabling **simpler higher-level protocols**, which can be used to build more efficient payment channel constructions (such as [Stacks subnets](https://gist.github.com/jcnelson/06dedca12f7121349936b1b5bc853d5a)).
- Improving **verification speed**, by supporting batch validation of all signatures in a block at once (for a fraction of the speed of validating them individually).
- Switching to a **provably secure construction**, perhaps preventing [an exploit against ECDSA in the future](https://eprint.iacr.org/2019/023.pdf).

## Specification

This specification inherits the current transaction authorization structure from SIP-005 and expands it to incorporate Schnorr signatures, which are implemented as single-signature spending policies

### Transaction Authorization

Each transaction contains a transaction authorization structure, which is used by the Stacks peer to identify the originating account and sponsored account, to determine the fee that the spending account will pay, and to and determine whether or not it is allowed to carry out the encoded state-transition.

It is encoded as follows:

- A 1-byte **authorization type** field that indicates whether or not the transaction has a standard or sponsored authorization.
 - For standard authorizations, this value MUST be `0x04`.
 - For sponsored authorizations, this value MUST be `0x05`.
- One or two **spending conditions**, whose encoding is described below.  If the transaction's authorization type byte indicates that it is a standard authorization, then there is one spending condition.  If it is a sponsored authorization, then there are two spending conditions that follow.

*Spending conditions* are encoded as follows:

- A 1-byte **hash mode** field that indicates how the origin account authorization's public keys and signatures should be used to calculate the account address.  Four modes are supported, in the service of emulating the four hash modes supported in Stacks v1 (which uses Bitcoin hashing routines):
   - `0x00`: A single public key is used.  Hash it like a Bitcoin P2PKH output.
   - `0x01`: One or more public keys are used.  Hash them as a Bitcoin multisig P2SH redeem script.
   - `0x02`: A single public key is used.  Hash it like a Bitcoin P2WPKH-P2SH output.
   - `0x03`: One or more public keys are used.  Hash them as a Bitcoin P2WSH-P2SH output.
- A 20-byte **public key hash**, which is derived from the public key(s) according to the hashing routine identified by the hash mode.  The hash mode and public key hash uniquely identify the origin account, with the hash mode being used to derive the appropriate account version number.
- An 8-byte **nonce**.
- An 8-byte **fee**.
- Either a **single-signature spending condition** or a **multisig spending condition**, described below.  If the hash mode byte is either `0x00` or `0x02`, then a single-signature spending condition follows. Otherwise, a multisig spending condition follows.

A *single-signature spending condition* is encoded as follows:

- A 1-byte **public key encoding** field to indicate whether or not the public key should be compressed before hashing.  It will be:
   - `0x00` for compressed
   - `0x01` for uncompressed
- A 65-byte **recoverable ECDSA signature**, which contains a signature and metadata for a secp256k1 signature.

A *multisig spending condition* is encoded as follows:

- A length-prefixed array of **spending authorization fields**, described below.
- A 2-byte **signature count** indicating the number of signatures thatare required for the authorization to be valid.

A *spending authorization field* is encoded as follows:

- A 1-byte **field ID**, which can be `0x00`, `0x01`, `0x02`, or `0x03`.
- The **spending field body**, which will be the following, depending on the field ID:
   - `0x00` or `0x01`:  The next 33 bytes are a compressed secp256k1 public key. If the field ID is `0x00`, the key will be loaded as a compressed secp256k1 public key.  If it is `0x01`, then the key will be loaded as an uncompressed secp256k1 public key.
   - `0x02` or `0x03`:  The next 65 bytes are a recoverable secp256k1 ECDSA signature.  If the field ID is `0x02`, then the recovered public key will be loaded as a compressed public key.  If it is `0x03`, then the recovered public key will be loaded as an uncompressed public key.

A *compressed secp256k1 public key* has the following encoding:

- A 1-byte sign byte, which is either `0x02` for even values of the curve's `y` coordinate, or `0x03` for odd values.
- A 32-byte `x` curve coordinate.

An *uncompressed secp256k1 public key* has the following encoding:

- A 1-byte constant `0x04`
- A 32-byte `x` coordinate
- A 32-byte `y` coordinate

A *recoverable ECDSA secp256k1 signature* has the following encoding:

- A 1-byte **recovery ID**, which can have the value `0x00`, `0x01`, `0x02`, or `0x03`.
- A 32-byte `r` curve coordinate
- A 32-byte `s` curve coordinate.  Of the two possible `s` values that may be calculated from an ECDSA signature on secp256k1, the lower `s` value MUST be used.

The number of required signatures and the list of public keys in a spending condition structure uniquely identifies a standard account and can be used to generate its address per the following rules:

The `x version` columns contain the c32 alphabet value in brackets.

| **Hash mode** | **Spending Condition** | **Mainnet version** | **Testnet version** | **Hash algorithm**         |
| ------------- | ---------------------- | ------------------- | ------------------- | -------------------------- |
| `0x00`        | Single-signature       | 22 (`P`)            | 26 (`T`)            | Bitcoin P2PKH              |
| `0x01`        | Multi-signature        | 20 (`M`)            | 21 (`N`)            | Bitcoin redeem script P2SH |
| `0x02`        | Single-signature       | 20 (`M`)            | 21 (`N`)            | Bitcoin P2WPK-P2SH         |
| `0x03`        | Multi-signature        | 20 (`M`)            | 21 (`N`)            | Bitcoin P2WSH-P2SH         |
| `0x04`        | Single-signature       | 24 (`R`)            | 23 (`Q`)            | Bitcoin P2TR               |

The first four hash algorithms are described in SIP-005 briefly, and mirror hash algorithms used today in Bitcoin. This is necessary for backwards compatibility with Stacks v1 accounts, which rely on Bitcoin's scripting language for authorizations.

Bitcoin P2TR is described in BIP341, a copy of which is attached to this SIP.

