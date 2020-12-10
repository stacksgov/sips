## Preamble
* Sip Number: 009
* Title: Standard Trait Definition for Non-Fungibe Tokens
* Author: Friedger Müffke (mail@friedger.de)
* Consideration: Technical
* Type: Standard
* Status: Draft
* Created: 2020-12-10
* License: CC0-1.0
* Sign-off:

## Abstract
Non-fungible token are unique digital assets that are registered on the Stacks blockchain through a smart contract with certain properties. 
Users should be able to identify a single non-fungible token. Users should be able to own it and transfer it. Non-fungible tokens can have more properties 
that are not specified in this standard.

## License and Copyright

This SIP is made available under the terms of the Creative Commons CC0 1.0 Universal license, available at https://creativecommons.org/publicdomain/zero/1.0/
This SIP’s copyright is held by the Stacks Open Internet Foundation.

## Introduction


## Specification

```

(define-trait stacks-token-nft-standard-v1
  (
    ;; Name, limited to 32 chars
    (name () (string-ascii 32)) 

    ;; Icon URL, limited to 2048 chars
    (icon-url () (string-ascii 2048))

    ;; Token ID, limited to uint range
    (last-token-id () uint) 

    ;; number of tokens owned by user
    (get-balance (principal) uint)

    ;; Owner of given token identifier
    (get-owner? (uint) (response principal (tuple (kind (string-ascii 32)))))

    ;; Transfer from to
    (transfer? (principal principal uint) (response bool (tuple (kind (string-ascii 32)))))

    ;; Approve
    (approve (principal uint) (response bool (tuple (kind (string-ascii 32)))))

    ;; Set approval for all
    (set-approval-for-all (principal bool) (response bool (tuple (kind (string-ascii 32)))))

  )
)
```
## Related Work

## Backwards Compatibility

## Activation

## Reference Implementations
