# Preamble

Sip Number: 010

Title: Standard Trait Definition for Non-Fungibe Tokens

Author: Hank Stoever (hstove@gmail.com)

Consideration: Technical

Type: Standard

Status: Draft

Created: 25 January 2021

License: CC0-1.0

Sign-off:

Layer: Traits

Discussions-To: https://github.com/stacksgov/sips

# Abstract

Fungible tokens are digital assets that can be sent, received, combined, and divided. Most forms of currency and cryptocurrencies are fungible tokens. They have become a building block of almost all blockchains. This SIP aims to provide a flexible and easy-to-implement standard that can be used by developers on the Stacks blockchain when creating their own tokens.

# License and Copyright

This SIP is made available under the terms of the Creative Commons CC0 1.0 Universal license, available at https://creativecommons.org/publicdomain/zero/1.0/
This SIP’s copyright is held by the Stacks Open Internet Foundation.

# Introduction

Digital assets can be divided into two categories, based on the token's fungibility. A _fungible_ token can be broken down into small units and added together. An owner of a fungible asset only needs to care about their balance, that is, the total amount of a particular fungible asset that they own. Most well-known currencies are fungible.

For example, if a user owns 10 units of a fungible asset, they may send 2 units to a different user. At this point, their balance is 8 units. If they later receive more units, their total balance will be updated. For fungible tokens, there is no difference between any two different amounts of the fungible token.

On blockchains, fungible tokens are a core component. Blockchains with smart contracts, including the Stacks blockchain, allow developers and users to create and interact with smart contracts that use fungible tokens.

# Specification

The fungible token trait, `ft-trait`, has a few functions:

## Trait functions

### Transfer

`(transfer ((amount uint) (sender principal) (recipient principal)) (response bool uint))`

Transfer the fungible token from the sender of this transaction to the recipient. The `amount` is an unsigned integer. It is recommended that implementing contracts use the built-in `ft-transfer` Clarity method. If the sender does not have enough tokens to complete the transaction, the transaction should abort and return an `(err uint)`.

This method must be defined with `define-public`, as it alters state, and should be externally callable.

Contract implementers should take note to perform authorization of the `transfer` method. For example, most fungible token contracts should enforce that the `sender` argument is equal to the `tx-sender` keyword in Clarity.

When returning an error in this function, the error codes should follow the same patterns as the built-in `ft-transfer?` and `stx-transfer?` functions.

| error code | reason                                          |
| ---------- | ----------------------------------------------- |
| u1         | `sender` does not have enough balance           |
| u2         | `sender` and `recipient` are the same principal |
| u3         | `sender` and `recipient` are the same principal |
| u4         | `sender` is not the same as `tx-sender`         |

### Name

`(name () (response (string-ascii 32) uint))`

Return a human-readable name for the contract, such as "CoolPoints", etc.

This method should be defined as read-only, i.e. `define-read-only`.

### Symbol

`(symbol () (response (string-ascii 32) uint))`

Return a symbol that allows for a shorter representation of your token. This is sometimes referred to as a "ticker". Examples: "STX", "COOL", etc. Typically, your token could be referred to as $SYMBOL when referencing it in writing.

This method should be defined as read-only, i.e. `define-read-only`.

### Decimals

`(decimals () (response uint uint))`

The number of decimal places in your token. All fungible token balances must be represented as integers, but providing the number of decimals provides for an abstraction of your token that humans are more familiar dealing with. For example, the US Dollar has 2 decimals, if the base unit is "cents", as is typically done in accounting. Stacks has 6 decimals, Bitcoin has 8 decimals, and so on.

As another example, if your token has 4 decimals, and the `balance-of` a particular user returns `100345000`, wallets and exchanges would likely represent that value as `10034.5`.

This method should be defined as read-only, i.e. `define-read-only`.

### Balance of

`(balance-of (principal) (response uint uint))`

Return the balance of a particular principal (also known as "address" or "account"). Implementations should typically use the built-in Clarity method `ft-get-balance`.

This method should be defined as read-only, i.e. `define-read-only`.

### Total supply

`(total-supply () (response uint uint))`

Return the total supply of this token. Implementations should typically use the built-in Clarity method `ft-get-supply`.

This method should be defined as read-only, i.e. `define-read-only`.

## Trait implementation

An implementation of the proposed trait is provided below.

```clarity
(define-trait ft-trait
  (
    ;; Transfer from the caller to a new principal
    (transfer (uint principal principal) (response bool uint))

    ;; the human readable name of the token
    (name () (response (string-ascii 32) uint))

    ;; the ticker symbol, or empty if none
    (symbol () (response (string-ascii 32) uint))

    ;; the number of decimals used, e.g. 6 would mean 1_000_000 represents 1 token
    (decimals () (response uint uint))

    ;; the balance of the passed principal
    (balance-of (principal) (response uint uint))

    ;; the current total supply (which does not need to be a constant)
    (total-supply () (response uint uint))
  )
)
```

## Implementing in wallets and other applications

Developers who wish to interact with a fungible token contract should first be provided, or keep track of, various different fungible token implementations. When validating a fungible token contract, they should fetch the interface and/or source code for that contract. If the contract implements the trait, then the wallet can use this standard's contract interface for making transfers and getting balances.

## Use of post conditions

In addition to built-in methods for fungible token contracts, the Stacks blockchain includes a feature known as Post Conditions. By defining post conditions, users can create transactions that include pre-defined guarantees about what might happen in that contract.

One such post condition could be "I will transfer exactly 100 of X token", where "X token" is referenced as a specific contract's fungible token. When wallets and applications implement the `transfer` method, they should _always_ use post conditions to specify that the user will transfer exactly the amount of tokens that they specify in the `amount` argument of the `transfer` function. Only in very specific circumstances should such a post condition not be included.

# Related work

## Ethereum ERC20

[Ethereum ERC20 standard](https://ethereum.org/en/developers/docs/standards/tokens/erc-20/)

Perhaps the oldest, and most well known, standard for fungible tokens is Ethereum's [ERC20](https://ethereum.org/en/developers/docs/standards/tokens/erc-20/) standard. It has become one of the strongest building blocks for the Ethereum ecosystem. When all fungible tokens follow the same standard, any wallet or application developer can interact with it without having to create custom logic for handling each individual token.

Fungible tokens have become so popular that the Clarity smart contracting language has support for basic fungible token operations built-in. In fact, as can be seen in this proposal's reference implementation, very little code is required to implement a fungible token. The important part of this standard is defining a Clarity trait that all fungible tokens can implement. Even though Clarity has fungible token operations built-in, it is important for each contract to define the same methods so that their contracts are easy to integrate.

# Backwards Compatibility

Not applicable

# Activation

This trait will be considered activated when this trait is deployed to mainnet, and 3 contracts from different developers on implement this trait on mainnet.

# Reference Implementations

An example implementation has been submitted with this proposal, along with a Javascript client and tests. https://github.com/hstove/stacks-fungible-token

Other examples of Clarity contracts that implement fungible tokens, although not exactly according to this specification:

- [@psq's trait and implementation](https://github.com/psq/flexr/blob/master/contracts/src20-trait.clar)
- [@friedger's fungible token implementation](https://github.com/friedger/clarity-smart-contracts/blob/master/contracts/tokens/fungible-token.clar)
