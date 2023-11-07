# Preamble

SIP-Number: SIP-026
Title: Clarity DeFi Vault
Author: Tycho Onnasch, Fernando Foy, Philip de Smedt, Christian Hresko
Consideration: Technical
Type: Standard
Status: Accepted
Created: Sep 7, 2023
Last-Modified: Sep 7, 2023
Sign-off:
Discussions-To: https://forum.stacks.org/t/clarity-defi-vault-sip/15567
License: Creative Commons CC0 1.0 Universal license
Layer: Trait

# Abstract

This Stacks Improvement Proposal (SIP) aims to address the issue of commingled collateral positions on the Stacks blockchain's Clarity-based DeFi applications. Currently, due to Clarity's design, it is challenging for users to identify their specific collateral positions within the Stacks Explorer. This SIP proposes the creation of a common interface for contracts that hold SIP-010 assets. Implementing this interface will enable users to view their collateral positions distinctly, improving the overall user experience of Stacks DeFi applications.

# License and Copyright

This SIP is made available under the terms of the Creative Commons CC0 1.0 Universal license, available at https://creativecommons.org/publicdomain/zero/1.0/. This SIP's copyright is held by the Stacks Open Internet Foundation.

# Introduction

#### Problem Statement

Clarity, the smart contract language of the Stacks blockchain, presents a challenge in providing users with the ability to identify their collateral positions within Clarity-based DeFi applications. Unlike other blockchain ecosystems like Ethereum, where users can distinctly view their collateral in separate smart contracts on the chain's explorer, Clarity currently lacks this capability.

As a result, users who post collateral on Stacks DeFi apps might perceive their collateral funds as commingled with other users' collateral, leading to a suboptimal user experience. The ability to natively inspect collateral positions on-chain is a crucial value proposition of DeFi over CeFi.

#### Technical Background of the Problem

In Solidity, the Ethereum smart contract language, contracts can be deployed by executing Solidity code in transactions. This allows the deployment of contracts that represent vaults holding ERC-20s separately. These distinct collateral-holding contracts can be effortlessly looked up on explorers such as Etherscan, facilitating users' oversight of DeFi protocol collateralization.

However, Clarity's design differs significantly. It does not allow contract deployment during transaction execution to maintain deterministic behavior and avoid infinite recursion. Consequently, representing entities that hold SIP-010 assets requires implementing logic within a single contract address.

# Specification

The proposed solution is to create a common interface for contracts that hold SIP-010 assets. While Clarity does not permit contract deployment during transactions, different entities can be logically separated within the same contract. This is used in the Arkadiko protocol contracts to differentiate between different vaults. If the Stacks Explorer implements this common interface, users will be able to view their collateral positions distinctly, providing a user experience similar to DeFi on other blockchain platforms like Ethereum and Solana.

New vault IDs are generated incrementally starting from 0. Vaults are separated logically based on this ID with a numerical value.

The SIPXXX Vault trait, `sipxxx-vault-trait`, has 3 functions. These functions
do not update state, they are view-only and they allow for a common interface:

## Trait functions

### asset-contract

`(asset-contract ((vault-id uint)) (response principal uint))`

Returns the principal of the asset being held by the vault identified by `vault-id`.

Returns the token type balance `token-id` of a specific principal `who` as an
unsigned integer wrapped in an `ok` response. It has to respond with `u0` if the
principal does not have a balance of the specified token or if no token with
`token-id` exists. The function should never return an `err` response and is
recommended to be defined as read-only.

### holdings

`(holdings ((vault-id uint) (asset <sip-010-trait>)) (response uint uint))`

Returns the total amount of the underlying asset held by the vault identified by `vault-id`.

### holdings-of

`(holdings-of ((vault-id uint) (asset <sip-010-trait>) (owner principal)) (response uint uint))`

Returns the total amount of the underlying asset held by the vault identified by
their vault ID for `owner`. This is used when underlying assets are divided by vault id
and are grouped by the principal of `owner`.

If the implementation does not group the vault assets by owner, return `0`.

```clarity
(use-trait sip-010-trait .sip-010-trait-ft-standard.sip-010-trait)

(define-trait vault-trait
  (
    (asset-contract (uint) (response principal uint))

    (holdings (uint) (response uint uint))

    (holdings-of (uint principal) (response uint uint))
  )
)
```

# Related Work

The dicussion on a vault Solidity implementation can be found here [Forum Discussion](https://ethereum-magicians.org/t/eip-4626-yield-bearing-vault-standard/7900)

# Backwards Compatibility

The vault implementation was inspired by the vaults used in the Arkadiko protocol. Specifically, the Vault manager contract that is meant to abstract the data used in Arkadiko vaults. A vault trait contract can be deployed to interface with the Vault manager contract to be compliant with the standard (wrapping the original contract).

# Activation

This trait will be considered activated when this trait is deployed to mainnet, and 3 different implementations of the trait have been deployed to mainnet, no later than Bitcoin block 900000.

# Reference Implementation

A reference implementation of this SIP can be found in the following GitHub repository:
GitHub: https://github.com/FriendsFerdinand/clarity-defi-vault
