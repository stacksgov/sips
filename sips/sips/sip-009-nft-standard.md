## Preamble

- Sip Number: 009
- Title: Standard Trait Definition for Non-Fungibe Tokens
- Author: Friedger Müffke (mail@friedger.de)
- Consideration: Technical
- Type: Standard
- Status: Draft
- Created: 2020-12-10
- License: CC0-1.0
- Sign-off:

## Abstract

Non-fungible token are unique digital assets that are registered on the Stacks blockchain through a smart contract with certain properties.
Users should be able to identify a single non-fungible token. Users should be able to own it and transfer it. Non-fungible tokens can have more properties
that are not specified in this standard.

## License and Copyright

This SIP is made available under the terms of the Creative Commons CC0 1.0 Universal license, available at https://creativecommons.org/publicdomain/zero/1.0/
This SIP’s copyright is held by the Stacks Open Internet Foundation.

## Introduction

Tokens are digital assets that are registered on the Stacks blockchain through a smart contract. A non-fungible token (NFT) is a token that is globally unique and that users can identify through its identifier. The smart contract that registers the NFTs defines a name for the group of NFTs.

NFTs are enumerated, the id starts at 1 and the current last id is provided by the smart contract.

## Specification

```

(define-trait stacks-token-nft-standard-v1
  (
    ;; Token ID, limited to uint range
    (last-token-id () uint)

    ;; Owner of given token identifier
    (get-owner? (uint) (optional principal))

    ;; Transfer from to
    (transfer? (uint principal principal) (response bool (tuple (kind (string-ascii 32)) (code uint))))
  )
)
```

## Related Work

https://eips.ethereum.org/EIPS/eip-721
https://www.ledger.com/academy/what-are-nft

## Backwards Compatibility

Not applicable

## Activation

This SIP is activated as soon as 5 contracts are using the same trait that follows this specification.

## Reference Implementations
