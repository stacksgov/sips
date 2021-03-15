# Preamble

SIP Number: 009

Title: Standard Trait Definition for Non-Fungibe Tokens

Author: Friedger Müffke (mail@friedger.de)

Consideration: Technical

Type: Standard

Status: Draft

Created: 10 December 2020

License: CC0-1.0

Sign-off:

# Abstract

Non-fungible token are unique digital assets that are registered on the Stacks blockchain through a smart contract with certain properties.
Users should be able to identify a single non-fungible token. Users should be able to own it and transfer it. Non-fungible tokens can have more properties that are not specified in this standard.

# License and Copyright

This SIP is made available under the terms of the Creative Commons CC0 1.0 Universal license, available at https://creativecommons.org/publicdomain/zero/1.0/
This SIP’s copyright is held by the Stacks Open Internet Foundation.

# Introduction

Tokens are digital assets that are registered on the Stacks blockchain through a smart contract. A non-fungible token (NFT) is a token that is globally unique and that users can identify through its identifier. The smart contract that registers the NFTs defines a name for the group of NFTs.

NFTs are enumerated, the id starts at 1 and the current last id is provided by the smart contract.

# Specification

NFT smart contract shall implement the trait defined at `ST314JC8J24YWNVAEJJHQXS5Q4S9DX1FW5Z9DK9NT.nft-trait` as well as satisfy the additional conditions.
The trait has three functions:
* `get-last-token-id` does not take any arguments and returns the highest number that is used as an identifier for any NFT. This is the upper limit when iterating through all NFTs.
* `get-token-uri` takes an NFT identifier and returns a response containg a URI pointing to meta data of the given identifier. The URI is wrapped as an optional, which means if the corresponding NFT exists or the contract does not maintain meta data the response is `(ok none)`, otherwise, e.g. `(ok (some "https://example.com"))`. The length of the returned uri is limited to 256. The specification of the meta data should be covered in a separate SIP.
* `get-owner` takes an NFT identifier and returns a response containing the principal owning the NFT for the given identifier. The principal is wrapped as an optional, which means if the corresponding NFT does not exists the response is `(ok none)`, otherwise, e.g. `(ok (some 'ST12...))`. The owner can be a contract principal.
* `transfer` takes an NFT identifier, a sender principal and a receiver principal. The function changes the ownership of the NFT for the given identifier. The change has to be reflected in the `get-owner` function, for details see implementation rules.

## Trait

```
(define-trait stacks-token-nft-standard-v1
  (
    ;; Token ID, limited to uint range
    (get-last-token-id () (response uint uint))

    ;; URI for meta data about the token 
    (get-token-uri (uint) (response (optional (string-ascii 256)) uint))

     ;; Owner of given token identifier
    (get-owner (uint) (response (optional principal) uint))

    ;; Transfer from to
    (transfer (uint principal principal) (response bool (tuple (kind (string-ascii 32)) (code uint))))
  )
)
```

## Implementation rules

1. Contracts must use a least one NFT asset. A post condition with deny mode and without any NFT condition about a changed owner must fail for `transfer` function calls.
1. After a successful call to function `transfer`, the function `get-owner` must return the recipient of the `transfer` call as the new owner.
1. If a call to function `get-owner` returns some principal `A` value then it must return the same value until `transfer` is called with principal `A` as a sender
1. For any call to `get-owner`, resp. `transfer` with an id greater than `last-token-id`, the call should return a response `none`, resp. failed transfer. 
1. The following error codes are defined

| function | error | description |
|----------|-------|-------------| 
|`transfer`|`{kind: "nft-transfer-failed", code: from-nft-transfer}`| Error if the call failed due to the underlying asset transfer. The code `from-nft-transfer` is the error code from the native asset transfer function|

1. The methods `get-last-token-id`. `get-token-uri` and `get-owner` can be implemented as read-only functions.

# Related Work

NFTs are an established asset class on blockchains. Read for example [here](https://www.ledger.com/academy/what-are-nft).

## EIP 721
Ethereum has [ERP 721](https://eips.ethereum.org/EIPS/eip-721) that defined non-fungible tokens on the Ethereum blockchain. Notable differences are that the transfer function in EIP 721 uses a different ordering of the arguments ending with the token id. This SIP uses the token id as the first argument which is in line with all transfer functions in Clarity. Furthermore, this SIP only defines a URI pointing to meta data. There are not specifications about schema or other properties of token meta data. These should be specified in a separate SIP.


# Backwards Compatibility

Not applicable

# Activation

This SIP is activated if 5 contracts are deployed that are using the same trait that follows this specification. This has to happen before Bitcoin tip #700,000.

# Reference Implementations

Source code
https://github.com/friedger/clarity-smart-contracts/blob/master/contracts/sips/nft-trait.clar

Deployment on testnet: TODO
