# Preamble

SIP Number: 013

Title: Standard Trait Definition for Semi-Fungible Tokens

Author: Marvin Janssen <https://github.com/MarvinJanssen>

Consideration: Technical

Type: Standard

Status: Draft

Created: 12 September 2021

License: CC0-1.0

Sign-off: 

Layer: Traits

Discussions-To: https://github.com/stacksgov/sips

# Abstract

Semi-Fungible Tokens, or SFTs, are digital assets that sit between fungible and non-fungible tokens. Fungible tokens are directly interchangeable, can be received, sent, and divided. Non-fungible tokens each have a unique identifier that distinguishes them from each other. Semi-fungible tokens have both an identifier and an amount. This SIP describes the SFT trait and provides a reference implementation.

# License and Copyright

This SIP is made available under the terms of the Creative Commons CC0 1.0 Universal license, available at https://creativecommons.org/publicdomain/zero/1.0/
This SIP's copyright is held by the Stacks Open Internet Foundation.

# Introduction

Digital assets commonly fall in one of two categories; namely, they are either fungible or non-fungible. Fungible tokens are assets like the native Stacks Token (STX), stablecoins, and so on. Non-Fungible Tokens (NFTs) are tokens expressed as digital artwork and other use-cases that demand them to be globally unique. However, not all asset classes can be represented as either exclusively fungible or non-fungible tokens. This is where semi-fungible tokens come in.

Semi-fungible tokens are a combination of the aforementioned digital asset types in that they have both an identifier and an amount. A single semi-fungible token class can therefore represent a multitude of digital assets within a single contract. A user may own ten tokens of ID 1 and twenty tokens of ID 2, for example. It effectively means that one contract can represent any combination of fungible and non-fungible tokens.

Some real-world examples can highlight the value and use-cases of semi-fungible tokens. People who collect trading cards or postage stamps will know that not all of them are of equal value, although there may be more than one of a specific kind. Video games can feature in-game items that have different economic values compared to others. There are many more such parallels to be found.

Semi-fungible tokens give operators the ability to create new token classes at will. They no longer need to deploy a new contract every time new token type is introduced. It greatly simplifies the flow for applications that require many new tokens and token types to come into existence.

Benefits of using semi-fungible tokens:
- Art NFTs can have series and be grouped in collections.
- Games can have their in-game currencies and items easily represented.
- DeFi protocols can leverage SFTs to transfer many tokens and settle multiple orders at once.
- Easy bulk trades and transfers in a single contract call, saving on transaction fees.

# Specification

The Semi-Fungible Token trait, `sip013-semi-fungible-token-trait`, has 10 functions:

## Trait functions

### Balance

`(get-balance ((token-id uint) (who principal)) (response uint uint))`

Returns the token type balance `token-id` of a specific principal `who` as an unsigned integer wrapped in an `ok` response. It has to respond with `u0` if the principal does not have a balance of the specified token or if no token with `token-id` exists. The function should never return an `err` response and is recommended to be defined as read-only.

### Overall balance

`(get-overall-balance ((who principal)) (response uint uint))`

Returns the overall SFT balance of a specific principal `who`. This is the sum of all the token type balances of that principal. The function has to respond with a zero value of `u0` if the principal does not have any balance. It should never return an `err` response and is recommended to be defined as read-only.

### Total supply

`(get-total-supply ((token-id uint)) (response uint uint))`

Returns the total supply of a token type. If the token type has no supply or does not exist, the function should respond with `u0`. It should never return an `err` response and is recommended to be defined as read-only.

### Overall supply

`(get-overall-supply () (response uint uint))`

Returns the overall supply of the SFT. This is the sum of all token type supplies. The function should never return an `err` response and is recommended to be defined as read-only.

### Decimals

`(get-decimals ((token-id uint)) (response uint uint))`

Returns the decimal places of a token type. This is purely for display reasons, where external applications may read this value to provide a better user experience. The ability to specify decimals for a token type can be useful for applications that represent different kinds of assets using one SFT. For example, a game may have an in-game currency with two decimals and a fuel commodity expressed in litres with four decimals.

### Token URI

`(get-token-uri ((token-id uint)) (response (optional (string-ascii 256)) uint))`

Returns an optional ASCII string that is a valid URI which resolves to this token type's metadata. These files can provide off-chain metadata about that particular token type, like descriptions, imagery, or any other information. The exact structure of the metadata is out of scope for this SIP. However, the metadata file should be in JSON format and should include a `sip` property containing a number:

```JSON
{
	"sip": 16
	// ... any other properties
}
```

Applications consuming these metadata files can base display capabilities on the `sip` value. It should refer to a SIP number describing a JSON metadata standard.

### Transfer

`(transfer ((token-id uint) (amount uint) (sender principal) (recipient principal)) (response bool uint))`

Transfer a token from the sender to the recipient. It is recommended to leverage Clarity primitives like `ft-transfer?` to help safeguard users. The function should return `(ok true)` on success or an `err` response containing an unsigned integer on failure. The failure codes follow the existing conventions of `stx-transfer?` and `ft-transfer?`.

| Error code | Description                                      |
|------------|--------------------------------------------------|
| `u1`       | The sender has insufficient balance.             |
| `u2`       | The sender and recipient are the same principal. |
| `u3`       | Amount is `u0`.                                  |
| `u4`       | The sender is not authorised to transfer tokens. |

Error code `u4` is broad and may be returned under different cirumstances. For example, a token  contract with an allowance mechanism can return `(err u4)` when the `sender` parameter has no allowance for the specified token amount or if the sender is not equal to `tx-sender` or `contract-owner`. A token contract without an allowance mechanism can return `(err u4)` simply when the `sender` is not what is expected.

Since it is possible for smart contracts to own tokens, it is recommended to check for both `tx-sender` and `contract-caller` as it allows smart contracts to transfer tokens it owns without having to resort to using `as-contract`. Such a guard can be constructed as follows:

```clarity
(asserts! (or (is-eq sender tx-sender) (is-eq sender contract-caller)) (err u4))
```

The `transfer` function should emit a special transfer event, as detailed in the Events section of this document.

### Transfer with memo

`(transfer-memo ((token-id uint) (amount uint) (sender principal) (recipient principal) (memo (buff 34))) (response bool uint))`

Transfer a token from the sender to the recipient and emit a memo. This function follows the exact same procedure as `transfer` but emits the provided memo via `(print memo)`. The memo event should be the final event emitted by the contract. (See also the events section of this document below.)

### Bulk transfers

`(transfer-many ((transfers (list 100 {token-id: uint, amount: uint, sender: principal, recipient: principal}))) (response bool uint))`

Transfer many tokens in one contract call. Each transfer should follow the exact same procedure as if it were an individual `transfer` call. The whole function call should fail with an `err` response if one of the transfers fails.

### Bulk transfers with memos

`(transfer-many-memo ((transfers (list 100 {token-id: uint, amount: uint, sender: principal, recipient: principal, memo: (buff 34)}))) (response bool uint))`

Transfer many tokens in one contract call and emit a memo for each. This function follows the same procedure as `transfer-many` but will emit the memo contained in the tuple after each transfer. The whole function call should fail with an `err` response if one of the transfers fails.

## Trait definition

A definition of the proposed trait is provided below.

```clarity
(define-trait sip013-semi-fungible-token-trait
	(
		;; Get a token type balance of the passed principal.
		(get-balance (uint principal) (response uint uint))

		;; Get the total SFT balance of the passed principal.
		(get-overall-balance (principal) (response uint uint))

		;; Get the current total supply of a token type.
		(get-total-supply (uint) (response uint uint))

		;; Get the overall SFT supply.
		(get-overall-supply () (response uint uint))

		;; Get the number of decimal places of a token type.
		(get-decimals (uint) (response uint uint))

		;; Get an optional token URI that represents metadata for a specific token.
		(get-token-uri (uint) (response (optional (string-ascii 256)) uint))

		;; Transfer from one principal to another.
		(transfer (uint uint principal principal) (response bool uint))

		;; Transfer from one principal to another with a memo.
		(transfer-memo (uint uint principal principal (buff 34)) (response bool uint))

		;; Transfer many tokens at once.
		(transfer-many ((list 100 {token-id: uint, amount: uint, sender: principal, recipient: principal})) (response bool uint))

		;; Transfer many tokens at once with memos.
		(transfer-many-memo ((list 100 {token-id: uint, amount: uint, sender: principal, recipient: principal, memo: (buff 34)})) (response bool uint))
	)
)
```
## Events

Semi-fungible token contracts should emit custom events in certain situations via `print`. These events should be emitted after any built-in token events (such as those emitted by `ft-transfer?`) and before the memo in the case of `transfer-memo` and `transfer-many-memo`.

| Event name           | Tuple structure                                                                                 | Description                          |
|----------------------|-------------------------------------------------------------------------------------------------|--------------------------------------|
| `sft_transfer`       | `{type: "sft_transfer", token-id: uint, amount: uint, sender: principal, recipient: principal}` | Emitted when tokens are transferred. |
| `sft_mint`           | `{type: "sft_mint", token-id: uint, amount: uint, recipient: principal}`                        | Emitted when new tokens are minted.  |
| `sft_burn`           | `{type: "sft_burn", token-id: uint, amount: uint, sender: principal}`                           | Emitted when tokens are burned.      |


## Use of native asset functions

Contract implementers should always use the built-in native assets that are provided as Clarity primitives whenever possible. This allows clients to use Post Conditions (explained below) and takes advantage of other benefits like native events and asset balances. However, there are no language primitives specific to semi-fungible tokens. The reference implementation included in this SIP therefore leverages the primitives to the extent that Clarity allows for.

The recommended native asset primitives to use:

- `define-fungible-token`
- `ft-burn?`
- `ft-get-balance`
- `ft-get-supply`
- `ft-mint?`
- `ft-transfer?`
- And their NFT equivalents.

## Implementing in wallets and other applications

Applications that interact with semi-fungible token contracts should validate if those contracts implement the SFT trait. If they do, then the application can use the interface described in this SIP for making transfers and getting other token information.

All of the functions in this trait return the `response` type, which is a requirement of trait definitions in Clarity. However, some of these functions should be "fail-proof", in the sense that they should never return an error. The "fail-proof" functions are those that have been recommended as read-only. If a contract that implements this trait returns an error for these functions, it may be an indication of a faulty contract, and consumers of those contracts should proceed with caution.

## Use of post conditions

The Stacks blockchain includes a feature known as Post Conditions. By defining post conditions, users can create transactions that include pre-defined guarantees about what might happen in a contract. These post conditions can also be used to provide guarantees for custom fungible and non-fungible tokens that were defined using built-in Clarity primitives.

There are no Clarity primitive counterparts for semi-fungible tokens, but contract developers can leverage a combination of post conditions to achieve the same result.

There are two factor that should be checked by post conditions:

1. The amount of semi-fungible tokens being transferred.
2. The token ID of the semi-fungible token being transferred.

To that end, it is recommended that developers use both Clarity primitives in their design. Semi-fungible token contracts can achieve complete post condition coverage by using both `define-fungible-token` and `define-non-fungible-token`.

For strategies on how to best guard a semi-fungible token contract with post conditions, see the reference implementation at the end of this document.

# Related work

## Ethereum ERC1155

- [EIP-1155](https://eips.ethereum.org/EIPS/eip-1155)

# Backwards Compatibility

Not applicable

# Activation

Trait deployments:

- mainnet: [TODO](#TODO)
- Testnet: [TODO](#TODO)

This trait will be considered activated when this trait is deployed to mainnet, and 3 different implementations of the trait have been deployed to mainnet, no later than Bitcoin block TODO.

# Reference Implementations

https://github.com/MarvinJanssen/stx-semi-fungible-token
