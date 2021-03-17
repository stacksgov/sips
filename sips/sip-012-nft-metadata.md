# Preamble

SIP Number: 012

Title: Standard Trait Definition for Metadata for Non-Fungible Tokens

Author: Friedger Müffke (mail@friedger.de)

Consideration: Technical

Type: Standard

Status: Draft

Created: 17 March 2021

License: CC0-1.0

Sign-off:

# Abstract

Non-fungible tokens or NFTs are digital assets registered on blockchain with unique identifiers and properties that distinguish them from each other. SIP-009 defines the trait how ownership of an NFT is managed. This SIP aims to provide a flexible and easy-to-implement standard that can be used by developers mainly of wallet when managing NFTs.

# License and Copyright

This SIP is made available under the terms of the Creative Commons CC0 1.0 Universal license, available at https://creativecommons.org/publicdomain/zero/1.0/
This SIP’s copyright is held by the Stacks Open Internet Foundation.

# Introduction

Tokens are digital assets registered on blockchain through a smart contract. A non-fungible token (NFT) is a token that is globally unique and can be identified through its unique identifier. In blockchains with smart contracts, including the Stacks blockchain, developers and users can use smart contracts to register and interact with non-fungible tokens.

Some use cases of NFTs are name registration, digital art, certification, media and enternainment, real-estate. They all require that users associate certain content with an NFT. In general, it is helpful for the users to have a name, sound, image that represents this content.

# Specification

Every SIP-012 compliant smart contract in Stacks blockchain must implement the trait, `nft-meta`, defined in the [Trait](#trait) section and must meet the requirements for the following functions:

### Metadata of Defining Smart Contract

`(get-nft-meta () (response (optional {name: (string-uft8 30), image: (string-ascii 255)}) uint))`

Takes no arguments and returns a response containing the name and URL of an image representing the class of NFTs defined by this contract.

This function must never return an error response. It can be defined as read-only, i.e. `define-read-only`.

### Metadata of NFT

`(get-meta (uint) (response (optional {name: (string-uft8 30), image: (string-ascii 255)}) uint))` 

Takes no arguments and returns a response containing the name and URL of an image representing the class of NFTs defined by this contract. The data uple must be wrapped in an `optional`. If the corresponding NFT doesn't exist or the contract doesn't maintain metadata, the response must be `(ok none)`. If a valid URI exists for the NFT, the response must be `(ok (some metadata))`.

This function must never return an error response. It can be defined as read-only, i.e. `define-read-only`.

## Trait

```
(define-trait nft-meta
  (
    ;; Metadata of NFT class
    (get-meta (uint) (response (optional {name: (string-uft8 30), image: (string-ascii 255)}) uint))


    ;; Metadata of individual NFT
    (get-meta (uint) (response (optional {name: (string-uft8 30), image: (string-ascii 255)}) uint))
  )
)
```

# Using NFTs in applications

Developers who wish to represent non-fungible tokens in an application should first be provided, or keep track of, various different non-fungible token implementations. When validating metadata of a non-fungible token contract, they should fetch the interface and/or source code for that contract. If the contract implements the trait, then the application can use this standard's contract interface for making transfers and getting other details defined in this standard. Furthermore, the received metadata should be verified whether they are compliant with the applications guidelines.

All of the functions in this trait return the `response` type, which is a requirement of trait definitions in Clarity. All of these functions should be "fail-proof", in the sense that they should never return an error. These "fail-proof" functions are those that have been recommended as read-only. If a contract that implements this trait returns an error for these functions, it may be an indication of a non-compliant contract, and consumers of those contracts should proceed with caution.

We remind implementation authors that the empty string is a valid response to name and image if you don't want to supply parts of the metadata. We also remind everyone that any smart contract can use the same name and image as your contract. How a client may determine which smart contracts are well-known (canonical) is outside the scope of this standard.

# Related Work

NFTs are an established asset class on blockchains. Read for example [here](https://www.ledger.com/academy/what-are-nft).

## BNS
The Blockchain Naming System uses native non-fungible tokens. It does define metadata for a name through attachements. The schema for names owned by a person follows the definition of (schema.org/Person)[https://schema.org/Person]. This could be an alternative to token URIs.

## SIP 9
An NFT is defined in SIP-009.

## EIP 721
Metadata for NFTs on Ethereum are defined in [EIP 721](https://eips.ethereum.org/EIPS/eip-721). Compliant smart contracts have to implement a `name` and `symbol` function as human readable identifiers, as well as `tokenURI` for access to the actual metadat. The schema of the metadata contains name, description and image. For NFTs on the Stacks blockchain, a name for the nft is already defined by the underlying native asset. Therefore, `name` and `symbol` is not needed.

# Backwards Compatibility

## Boom 
The NFT contract for Boom implements a variation of this trait using similar naming, but returning other types than response types: https://explorer.stacks.co/txid/0x423d113e14791f5d60f5efbee19bbb05cf5e68d84bcec4e611f2c783b08d05aa?chain=mainnet

# Activation

This SIP is activated if 5 contracts are deployed that use the same trait that follows this specification. This must happen before Bitcoin tip #700,000.

# Reference Implementations

## Source code

// TODO