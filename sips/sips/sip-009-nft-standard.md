# Preamble

SIP Number: 009

Title: Standard Trait Definition for Non-Fungible Tokens

Author: Friedger Müffke (mail@friedger.de), Muneeb Majeed

Consideration: Technical

Type: Standard

Status: Draft

Created: 10 December 2020

License: CC0-1.0

Sign-off:

# Abstract

Non-fungible tokens or NFTs are digital assets registered on blockchain with unique identifiers and properties that distinguish them from each other. 
It should be possible to uniquely identify, own and transfer a non-fungible token.  This SIP aims to provide a flexible and easy-to-implement standard that can be used by developers on the Stacks blockchain when creating their own NFTs. This standard only specifies a basic set of requirements, non-fungible tokens can have more features than what's specified in this standard.
# License and Copyright

This SIP is made available under the terms of the Creative Commons CC0 1.0 Universal license, available at https://creativecommons.org/publicdomain/zero/1.0/
This SIP’s copyright is held by the Stacks Open Internet Foundation.

# Introduction

Tokens are digital assets registered on blockchain through a smart contract. A non-fungible token (NFT) is a token that is globally unique and can be identified through its unique identifier.

In blockchains with smart contracts, including the Stacks blockchain, developers and users can use smart contracts to register and interact with non-fungible tokens.

The Stacks blockchain's programming language for developing smart contracts, Clarity, has built-in language primitives to define and use non-fungible tokens. Although those primitives exists, there is value in defining a common interface (known in Clarity as a "trait") that allows different smart contracts to interoperate with non-fungible token contracts in a reusable way. This SIP defines that trait.

Each NFT always belong to one smart contract. NFTs of a smart contract are enumerated starting at 1. The current last ID is provided by a smart contract function. The asset ID together with the contract ID defines a globally unique NFT.

# Specification

Every SIP-009 compliant smart contract in Stacks blockchain must implement the trait, `nft-trait`, defined in the [Trait](#trait) section and must meet the requirements for the following functions:

### Last token ID

`(get-last-token-id () (response uint uint))`

Takes no arguments and returns the identifier for the last NFT registered using the contract. The returned ID can be used as the upper limit when iterating through all NFTs.

This function must never return an error response. It can be defined as read-only, i.e. `define-read-only`.

### Token URI

`(get-token-uri (uint) (response (optional (string-ascii 256)) uint))` 

Takes an NFT identifier and returns a response containing a valid URI which resolves to the NFT's metadata. The URI string must be wrapped in an `optional`. If the corresponding NFT doesn't exist or the contract doesn't maintain metadata, the response must be `(ok none)`. If a valid URI exists for the NFT, the response must be `(ok (some "<URI>"))`. The length of the returned URI is limited to 256 characters. The specification of the metadata should be covered in a separate SIP.

This function must never return an error response. It can be defined as read-only, i.e. `define-read-only`.

### Owner

`(get-owner (uint) (response (optional principal) uint))` 

Takes an NFT identifier and returns a response containing the principal owning the NFT with the given identifier. The principal must be wrapped in an optional. If the corresponding NFT doesn't exist, the response must be `(ok none)`. The owner can be a contract principal. 

If a call to function `get-owner` returns some principal `A`, then it must return the same value until the `transfer` function is called with principal `A` as the sender.

For any call to `get-owner` with an ID greater than the last token ID returned by the `get-last-token-id` function, the call must return a response `(ok none)`.

This function must never return an error response. It can be defined as read-only, i.e. `define-read-only`. 

### Transfer

`(transfer (uint principal principal) (response bool (tuple (kind (string-ascii 32)) (code uint))))` 

The function changes the ownership of the NFT for the given identifier from the sender principal to the recipient principal.

This function must be defined with define-public, as it alters state, and must be externally callable.

After a successful call to `transfer`, the function `get-owner` must return the recipient of the `transfer` call as the new owner.

For any call to `transfer` with an ID greater than the last token ID returned by the `get-last-token-id` function, the call must return an error response.

When returning an error from this function, the error must follow the pattern defined below:

| error | description |
|-------|-------------| 
|`{kind: "nft-transfer-failed", code: from-nft-transfer}`| Error if the call failed due to the underlying asset transfer. The code `from-nft-transfer` is the error code from the native asset transfer function|
## Trait

```
(define-trait nft-trait
  (
    ;; Last token ID, limited to uint range
    (get-last-token-id () (response uint uint))

    ;; URI for metadata associated with the token 
    (get-token-uri (uint) (response (optional (string-ascii 256)) uint))

     ;; Owner of a given token identifier
    (get-owner (uint) (response (optional principal) uint))

    ;; Transfer from the sender to a new principal
    (transfer (uint principal principal) (response bool (tuple (kind (string-ascii 32)) (code uint))))
  )
)
```

## Use of native asset functions

Although it is not possible to mandate in a Clarity trait, contract implementers must define at least one built-in native non-fungible [asset class](https://app.sigle.io/friedger.id/FDwT_3yuMrHDQm-Ai1OVS) that are provided as Clarity primitives. This allows clients to use Post Conditions (explained below), and takes advantages of other benefits, like native support for these asset balances and transfers through `stacks-blockchain-api`. The reference implementations included in this SIP use the native asset primitives, and provide a good boilerplate for their usage.

The native asset functions include:

- `define-non-fungible-token`
- `nft-burn?`
- `nft-get-owner?`
- `nft-mint?`
- `nft-transfer?`

The following requirements for using native asset functions are defined:
### Transfer
If the `transfer` function is called from a client without a [post-condition](https://docs.blockstack.org/understand-stacks/transactions#post-conditions) in deny mode or without any NFT condition about a changed owner, then the function call must fail with `abort_by_post_condition`.
# Using NFTs in applications

Developers who wish to use a non-fungible token contract in an application should first be provided, or keep track of, various different non-fungible token implementations. When validating a non-fungible token contract, they should fetch the interface and/or source code for that contract. If the contract implements the trait, then the application can use this standard's contract interface for making transfers and getting other details defined in this standard.

All of the functions in this trait return the `response` type, which is a requirement of trait definitions in Clarity. However, some of these functions should be "fail-proof", in the sense that they should never return an error. These "fail-proof" functions are those that have been recommended as read-only. If a contract that implements this trait returns an error for these functions, it may be an indication of a non-compliant contract, and consumers of those contracts should proceed with caution.

## Use of Post-conditions

The Stacks blockchain includes a feature known as "Post-Conditions" or "Constraints". By defining post-conditions, users can create transactions that include pre-defined guarantees about what might happen in that contract.

For example, when applications call the `transfer` function, they should _always_ use post conditions to specify that the new owner of the NFT is the recipient principal in the `transfer` function call.

# Related Work

NFTs are an established asset class on blockchains. Read for example [here](https://www.ledger.com/academy/what-are-nft).

## EIP 721
Ethereum has [EIP 721](https://eips.ethereum.org/EIPS/eip-721) that defined non-fungible tokens on the Ethereum blockchain. Notable differences are that the transfer function in EIP 721 uses a different ordering of the arguments ending with the token id. The transfer function in this SIP uses the token ID as the first argument which is in line with the other native functions in Clarity. Furthermore, this SIP only defines a function for getting the URI pointing to the metadata of an NFT. The specifications for schema and other properties of the token metadata should be defined in a separate SIP.

# Backwards Compatibility

Not applicable

# Activation

This SIP is activated if 5 contracts are deployed that use the same trait that follows this specification. This must happen before Bitcoin tip #700,000.

A trait that follows this specification is available on mainnet as [`SP1JSH2FPE8BWNTP228YZ1AZZ0HE0064PS6RXRAY4.nft-trait.nft-trait`](https://explorer.stacks.co/txid/0xe547bca01878eaaf4758a067d3f522691a8928fcade0b0a4930a825c10d082bc?chain=mainnet) and on testnet as [`ST1JSH2FPE8BWNTP228YZ1AZZ0HE0064PS54Q30F0.nft-trait.nft-trait`](https://explorer.stacks.co/txid/0x07922820aca1ef6bbadddd1a19212befe11c9dc5da9bce0248d93915e2fb80d4?chain=testnet).

# Reference Implementations

## Source code
### Friedger's clarity-smart-contracts
https://github.com/friedger/clarity-smart-contracts/blob/master/contracts/sips/nft-trait.clar
