# SIP-0XX: Composable Fungible Tokens with Allowance

## Preamble

SIP Number: 0XX  
Title: Composable Fungible Tokens with Allowance  
Author: Jose Orlicki <jose@trustmachines.co>  
Consideration: Technical  
Type: Standard  
Status: Draft  
Created: [Date]  
License: CC0-1.0  
Sign-off: [Sign-off Name] <signoff@example.com>  

## Abstract

This proposal extends the SIP-010 standard trait for fungible tokens on the Stacks blockchain to support composable fungible tokens with allowances. It adds further requirements to the previous standard, which is the bare minimum to have a standard for a fungible token, featuring mainly token tranfers. There are no specifications how to make transfers via third-party services. For atomic and composable transfers we introduce allowances. The new trait includes functions for transferring tokens (`transfer` limited to the `contract-caller` sender), approving allowances (`approve` and `revoke`), checking allowances (`get-allowance`), and transferring tokens leveraging allowances (`transfer-from`). The recommended implementation of `approve` uses incremental allowances to avoid race conditions and double transfering.

## Motivation

The previous fungible token standard (SIP-010) had limitations that hindered composability in decentralized finance (DeFi) contracts. Specifically, it lacked a mechanism for users to grant allowances to other users or contracts, similar to signing a check or how POS Debit Card systems work. Additionally, the previous standard's resulted in applications including de-facto checks based on `tx-sender` that could lead to security vulnerabilities.

This proposal aims to enhance the fungible token standard to enable safer and more flexible composability in DeFi and other applications on the Stacks blockchain.

## Specification

### Extended Trait Functions

This proposal extends the SIP-010 trait with the following functions:

#### transfer

`(transfer (from principal) (to principal) (amount uint) (response bool uint))`

This is the SIP-10 function signature but this improved SIP requires a certain security model. Transfer the specified amount of tokens from one principal to another. The `from` principal must always match the contract caller `contract-caller`, ensuring that only authorized parties can initiate transfers. Do not check and allow the execution if `sender` is `tx-sender`, this results in security weaknesses that make phishing and arbitrary token execution very dangerous (read https://www.coinfabrik.com/blog/tx-sender-in-clarity-smart-contracts/).

#### transfer-from

`(transfer-from (from principal) (to principal) (amount uint) (response bool uint))`

Transfer a specified amount of tokens from one principal to another using an allowance. The `from` principal must have previously approved the allowance for the `to` principal to transfer tokens on their behalf. This function facilitates composability by allowing third-party transfers within the approved limits.

#### approve

`(approve (spender principal) (amount uint) (response bool uint))`

Approve an incremental allowance for a specific principal or contract to spend a certain amount of tokens on behalf of the sender. This function is similar to signing a check, granting permission for a third party to make token transfers within the specified limit. This allowance must be incremental (it adds on top of previous allowances) to avoid race condition situations where an `transfer-from` call is executed before the `approve` and then another after the `approve` call.

#### revoke

`(revoke (spender principal) (response bool uint))`

Revoke an existing allowance granted to a specific principal or contract. This function sets the allowance for the specified spender to 0, effectively removing their permission to spend tokens on behalf of the sender. It provides a mechanism for the sender to revoke previously granted permissions when they are no longer needed or desired. You usually give a limited or exact allowance to a DeFi service, this service will grab the amount of token you approved and then provide some financial service. Is common practice in Web3 to give infinite or large allowance to Dapps to do only one `approve` call per token. But if you have given an infinite or large allowance to the Defi contract (a convenient common practice) and after the DeFi services have grabbed your tokens, you can revoke the infinite allowance by calling `revoke`. This helps mitigate the impact of bugs found in the DeFi contract in the future where an attacker might try to grab more of your tokens. If you intend to use the DeFi services only once or you no longer trust the service, you should call `revoke` immediately.

#### allowance

`(get-allowance (owner principal) (spender principal) (response uint uint))`

Check the remaining allowance of tokens that the `spender` principal is authorized to transfer on behalf of the `owner` principal. This function is useful for applications that need to verify the available allowance before initiating token transfers.

### Other Trait Functions

The new trait should also include the functions defined in SIP-010, including `get-name`, `get-symbol`, `get-decimals`, `get-balance`, `get-total-supply`, and `get-token-uri`.

## Trait Implementation

The extended trait `sip-0xx-trait` that includes the functions from `sip-010-trait` and the new functions introduced in SIP-0XX:

```clarity
(define-trait sip-0xx-trait
  (
    ;; Transfer from the caller to a new principal
    ;; first principal, sender, must be always equal to contract-caller
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))

    ;; the human readable name of the token
    (get-name () (response (string-ascii 32) uint))

    ;; the ticker symbol, or empty if none
    (get-symbol () (response (string-ascii 32) uint))

    ;; the number of decimals used, e.g. 6 would mean 1_000_000 represents 1 token
    (get-decimals () (response uint uint))

    ;; the balance of the passed principal
    (get-balance (principal) (response uint uint))

    ;; the current total supply (which does not need to be a constant)
    (get-total-supply () (response uint uint))

    ;; an optional URI that represents metadata of this token
    (get-token-uri () (response (optional (string-utf8 256)) uint))

    ;; Transfer from one principal to another using an allowance
    (transfer-from (uint principal principal uint) (response bool uint))

    ;; Approve an incremental allowance for a specific principal to spend tokens
    (approve (principal uint) (response bool uint))

    ;; Revoke an allowance, goes to 0, for a specific principal to spend tokens
    (revoke (principal) (response bool uint))

    ;; Check the remaining allowance of tokens for a spender
    (get-allowance (principal principal) (response uint uint))
  )
)
```

This extended trait, `sip-0xx-trait`, includes the functions from the original `sip-010-trait` and adds the new functions introduced in SIP-0XX: `transfer-from`, `approve`, `revoke`, and `get-allowance`. Developers can use this trait as a reference when implementing composable fungible tokens with allowances on the Stacks blockchain.

## Rationale

The extension of the SIP-010 trait with allowances and the ability to transfer tokens using allowances addresses the limitations of the previous standard. By introducing allowances, users can grant explicit permission for third parties to spend tokens on their behalf, improving the security and composability of DeFi contracts. The inclusion of additional functions from SIP-010 ensures compatibility with existing standards.

### Limiting Phishing 

With this new approach that has only a check for `(is-eq sender contract-caller)`, and in case of successful phishing attempt, the malicious Dapp has to ask for allowance for the specific token and drain that token, so the they have to request 2 transactions and can only drain 1 token. The previous standard, and the de-facto check of `(is-eq sender tx-sender)`, and the phishing attempt is successful, with a single transaction they can drain all of our standard tokens (several contracts) that only check the `tx-sender`.

### Challenges in Composable DeFi Contracts

In the context of DeFi, where _DeFiA_ represents a Yield Aggregator service and _DeFiB_ acts as a Yield service, there are scenarios where the current approaches with SIP-010 may face limitations:

1. **Attempted Double Transfer**
    1. A user initiates a transaction by calling `defi-service` from _DeFiA_.
    2. _DeFiA attempts to transfer tokens from the user to itself (`transfer(User, DeFiA)`), which is valid with the transaction sender as the user.
    3. However, within the same transaction, _DeFiA_ encounters an issue when trying to further transfer tokens to _DeFiB_ (`transfer(DeFiA, DeFiB)`) because the transaction sender remains the user.
2. **Direct User-to-DeFiB Transfer**
    1. A user initiates a transaction by calling `defi-service` from _DeFiA_.
    2. _DeFiA_ attempts to directly transfer tokens from the user to _DeFiB_ (`transfer(User, DeFiB)`), which is valid as the transaction sender is the user.
    3. Unfortunately, this approach is flawed since DeFiB may not support receiving tokens from third parties without the intermediary step of calling `another-defi-service` from _DeFiB_.
3. **Attempted Indirect Transfer**
   1. A user initiates a transaction by calling `defi-service` from _DeFiA_.
   2. _DeFiA_ initially transfers tokens from the user to itself (`transfer(User, DeFiA)`), maintaining the user as the transaction sender.
   3. _DeFiA_ then attempts to call `another-defi-service` from _DeFiB_.
   4. This approach also encounters an issue as the transaction sender remains the user, and if _DeFiB_ attempts to call `transfer(DeFiA, DeFiB)`, it lacks the necessary permissions.
  
These scenarios highlight the need for a more robust approach to composable DeFi contracts to ensure seamless interaction between different DeFi components.


### DeFi Composability Pattern

The most common DeFi pattern, that is supported by this new standard is:

1. The Dapp (decentralized application) _D_ generates a `approve` transaction for a single standard token _T_ and a single Dapp contract _C_.
2. The User signs the `approve` transaction and submits to blockchain.
3. The token _T_ get the allowance updated when the transaction ends on-chain.
4. The Dapp (decentralized application) _D_ generates a service `example-defi-service` transaction to start the service.
5. The User signs the `example-defi-service` and submits to blockchain.
6. The Dapp _D_ executes `example-defi-service` on-chain, this includes calling `transfer-from` to retrieve the tokens from User and, eventually, forwarding the tokens to a third-party service with `approve`, thus allowing for _Composability_.

## Backwards Compatibility

This proposal aims to maintain compatibility with the existing SIP-010 standard while introducing new functionality. Existing fungible token contracts can continue to use the SIP-010 functions without modification. Contracts that wish to utilize allowances and composable fungible tokens can implement the extended trait.

The current SIP10 Tokens are compatibles in the sense that they both will work on User Wallet using the same `(transfer(amount, user,recipient)`. Also to use a Single DeFi service, no Composability. If you use `transfer` to use a simple DeFi service like current approaches it will also work. Current SIP10 approach is not supporting properly combining a fungible token with two DeFi services, such as a Yield Aggregator using different Yield Services.

## Activation

The activation of this proposal will require deployment to the Stacks blockchain's mainnet. The activation criteria and timeline should be defined in accordance with the Stacks Improvement Proposal process.

## Reference Implementations

Reference implementations of this extended trait should be provided to assist developers in implementing fungible tokens with allowances on the Stacks blockchain. These implementations should follow the specifications outlined in this SIP.

* Trust Machines's [implementation](https://github.com/Trust-Machines/clarity-smart-contracts/blob/main/contracts/composable-fungible-token.clar) (based on [@friedger's](https://github.com/friedger/clarity-smart-contracts/blob/main/contracts/tokens/fungible-token.clar)).

## Copyright

This SIP is made available under the terms of the Creative Commons CC0 1.0 Universal license.

## Acknowledgments

The author acknowledges Trust Machines and the Stacks community and contributors for their input and feedback in the development of this proposal.


