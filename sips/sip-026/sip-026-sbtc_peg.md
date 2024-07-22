# SIP-028: sBTC Bootstrap

- **SIP Number:** 028
- **Title:** A Decentralized, Programmable Asset Backed 1:1 with BTC 
- **Consideration:** Technical, Economics
- **Type:** Standard
- **Status:** Draft
- **Authors:**
  - Andre Serrano
  - Ashton Stephens
  - Joey Yandle
  - Mårten Blankfors
  - Jesus Najera
  - Jude Nelson
  - Friedger Müffke
  - Tycho Onnasch

## Abstract
sBTC is a SIP-010 token on the Stacks blockchain, backed 1:1 against BTC, and operated by a decentralized set of signers such that only a 70% majority can access the funds to maintain the protocol.

While Bitcoin on its own cannot be used with smart contracts, sBTC provides a bridge of value from the Bitcoin Blockchain to the Stacks Blockchain to enable users who only own BTC to utilize the capability of smart contracts without switching to a new currency. This SIP aims to describe the high level sBTC system and the criteria for signer selection. 

The sBTC Bootstrap phase is part of an iterative release process to simplify implementation and accelerate the sBTC release timeline. The initial phase does not include the complete feature set described in the [original sBTC design documents](https://github.com/stacksgov/sips/blob/e6b3233e76c22cfd6ef02f21add66696b9e4c314/sips/sip-025/sip-025-sbtc.md). This SIP does not attempt to describe the low-level technical details of any subsequent releases, which will be provided in a future SIP addendum. 

## Introduction

### Glossary

| Term               | Definition                                                                                              |
|--------------------|---------------------------------------------------------------------------------------------------------|
| SIP-10 Token       | A token on the Stacks blockchain that adheres to the fungible token standards outlined in [SIP-10](https://github.com/stacksgov/sips/blob/main/sips/sip-010/sip-010-fungible-token-standard.md).        |
| sBTC               | A SIP-10 token on the Stacks Blockchain that can be turned back into BTC on the Bitcoin Blockchain. 1 sBTC is equivalent to 1 BTC on the Bitcoin Blockchain. |
| sBTC operation     | An operation that initiates some action from the sBTC protocol.                                         |
| .sbtc contract     | A smart contract (or a collection of contracts) defining the sBTC token and functions related to it     |
| sBTC Peg Wallet    | The single UTXO holding the entire BTC balance that’s pegged into sBTC. This peg wallet is managed and maintained by the sBTC Signers. |
| Stacks Signer      | An entity that receives PoX payouts for stacking their STX tokens and actively participating in the Stacks protocol by signing mined blocks. |
| sBTC Signer        | An entity that will sign sBTC operations and communicate with contracts on the chain to make that feasible. This entity has partial access to spending the sBTC UTXO. In this release, the sBTC signer is wholly separate from the Stacks Signer |
| sBTC Signer Set    | The set of all sBTC signers. Each is registered with the .sbtc contract and the transfer. These entities as a group have full democratic access to the sBTC UTXO. |
| sBTC Signer API    | API exposed by the sBTC Signer that handles basic low level commands. Remains private except to the Deposit API. |
| Deposit API        | A third party API that communicates with the sBTC Bootstrap Signers via the sBTC Signer API.             |

## Problem Statement
Bitcoin is limited in its programmability and scalability. While its security and censorship-resistance make it a compelling platform to build decentralized applications, transaction confirmation times do not meet the modern needs of users and developers. 

- **Bitcoin’s Limited Programmability:** Bitcoin’s script has limited programmability, making it unsuitable for most decentralized applications. This leaves users with very few options to use financial applications, like lending and trading, without entrusting their Bitcoin to centralized entities. This also exposes users to counterparty risk, which has the potential to result in lost funds. 
- **Bitcoin’s Slow Transaction Times:** Bitcoin is limited in its ability to process large amounts of data quickly and efficiently. Today, Bitcoin creates new blocks every 10 minutes on average, an interval which is longer than some alternative blockchains. This prohibits many types of applications that require faster confirmation times. 

## Proposed Solution
sBTC aims to solve Bitcoin’s limitations by combining the capability of the Stacks Blockchain with the stability of Bitcoin’s value. By enabling secure movement of BTC in and out of the Stacks Blockchain via the sBTC protocol, users can interact with their BTC on Stacks using Clarity smart contracts and fast block times. Users can deposit BTC into the protocol, seamlessly transact using sBTC on the Stacks blockchain and have the freedom to redeem sBTC tokens for the underlying BTC at any time. 

- **Programmability:** [Clarity](https://docs.stacks.co/clarity/overview) is the smart contract language on Stacks, which allows developers to encode essential business logic on a blockchain. Using smart contracts, developers can build more expressive decentralized applications that interact with sBTC, such as DeFi protocols, stablecoins, payments and more.
- **Fast Blocks:** The Stacks Nakamoto Upgrade, proposed in [SIP-021](https://github.com/stacksgov/sips/blob/feat/sip-021-nakamoto/sips/sip-021/sip-021-nakamoto.md#proposed-solution), enables fast blocks where “user-submitted transactions will now take on the order of seconds, instead of tens of minutes.” Thus, sBTC on Stacks Nakamoto will offer an improvement to Bitcoin’s current transaction times. 

The sBTC protocol not only addresses the limitations of the Bitcoin scripting system but also provides a secure and decentralized solution for utilizing Bitcoin in various applications.

## Design
This proposal describes a system in which the following are true:

- sBTC is a SIP-10 token backed by 1:1 by BTC.
- The sBTC peg wallet is maintained by the set of sBTC signers. These signers are responsible for the security and maintenance of the wallet, ensuring that sBTC is redeemable for BTC.
- Bitcoin can be converted into sBTC within 3 Bitcoin blocks.
- sBTC can be converted into Bitcoin within 6 Bitcoin blocks. This ensures sBTC on and off ramps are faster than other BTC assets on the market.
- The sBTC SIP-10 token contract remains consistent across sBTC releases. This provides reliability for users and developers, meaning no adjustment from builders will be needed as the system evolves through subsequent sBTC releases.  

## Overview of the sBTC Bootstrap Release
In the bootstrap phase, the criteria for sBTC Signers is determined through the community governance process of ratifying this SIP. sBTC Signers will be responsible for signing sBTC deposit and withdrawal transactions on the network. During this phase, sBTC will have an unchangeable and distinct signer set that will not explicitly be part of Stacks consensus. As a result, this release can activate without a hard fork.

Management of the sBTC peg wallet on the Bitcoin blockchain is decentralized, involving the sBTC signer set rather than a single custodian. This ensures a more resilient and trustworthy system, where signers are economically incentivized to execute peg-out transactions efficiently. The system is live ("resilient") if at least 70% of the sBTC signer voting power are online and honest. Then (and only then), deposits and withdrawals happen in a timely manner. The system is safe ("trustworthy") if at least 30% of the sBTC signer voting power is honest. Then, no theft of funds can occur.

### Differences in the sBTC Bootstrap Phase:
- Eligibility criteria to become an sBTC Signer will be selected through an open community governance process. The eligibility criteria to become an sBTC signer is described below and will take into account Signer performance and availability. 
- sBTC Bootstrap Signers are separate from Stacks Signers. The bootstrapping period uses a separate subset of Stacks signers to secure the sBTC protocol and Signer operations are not explicitly linked with slashing of rewards.
- sBTC deposits will be triggered via an API call. During the bootstrap phase sBTC deposit fulfillment must be initiated via an API call to alert the signers to the presence of a deposit. 

### Auxiliary Features
Auxiliary features of the sBTC Bootstrap protocol are described below. 

- **Stacks Transaction Fee Sponsorship:** sBTC will include the option to have sBTC transactions on Stacks be sponsored in return for some sBTC. Using the approach suggested in this [issue](https://github.com/stacks-network/stacks-core/issues/4235), sBTC users will be able to nearly spend sBTC as gas by getting support from an existing STX holder.
- **Signer Key Rotation:** Mechanisms are provided for the scenario where a signer wants to rotate their key. For this to happen, signers must coordinate offline and vote on-chain on the new signer set (aka set of keys). Once the new signer set is determined, the signers conduct a wallet handoff and re-execute DKG.

## sBTC Bootstrap Signers

### Responsibilities
The sBTC bootstrap signers are responsible for accepting or rejecting all sBTC operations submitted, and for a transaction to be fulfilled at least 70% of the signers need to approve the fulfilling of the transaction; this means that the liveness and reliability of the signers is crucial to the success of the protocol.

While up to 30% of the signers can be down without a user impact to the functioning of the protocol, it becomes more critical for the rest of the signers to approve sBTC operations because operations necessarily still need to meet 70% of the original signing power. If more than 30% of signers become unavailable no sBTC operations will be approved because it will be impossible to get 70% approval when less than 70% are online. 

An operation that isn’t approved will become spendable by the user without bridging to the other blockchain after a period of time without Signer interaction.

### Eligibility Criteria
For the sBTC Bootstrap release Signers will run the sBTC binary in addition to the core Stacks signer software and must meet the following criteria in order to strongly ensure reliable functioning of the sBTC protocol at all times.

The following eligibility criteria has been used to identify the sBTC Bootstrap Signers:  
- **Stacks 2.5 Participation:** Active participation running a signer on Stacks 2.5 testnet or mainnet. 
- **Technical Performance and Uptime:** Consistency in operational status and network stability. 
- **Communication & Availability:** Running an sBTC Signer is a pivotal role in the Stacks ecosystem, which requires a high degree of availability and communication with Stacks core developers. Signers should generally be able to respond to updates within 24 hours. 
- **Ecosystem Alignment:** Commitment to the growth of the Stacks ecosystem with contributions to support the network. Examples include (but are not limited to): publishing independent research or contributing to a Stacks working group.

### Selection Process
The sBTC Bootstrap Signers will be selected from the group of eligible signers by the [sBTC working group](https://github.com/orgs/stacks-network/discussions/469).

## Comparison to Other Protocols

### [WBTC](https://wbtc.network/assets/wrapped-tokens-whitepaper.pdf)
WBTC is made up of 50+ merchants and custodians with keys to the WBTC multisig contract on Ethereum. WBTC deposits and withdrawals can only be performed by the authorized merchants and end users purchase WBTC directly from the merchants. Although the merchants manage issuance and redemption, all BTC backing WBTC is held by a single custodian.

### [tBTC v2](https://whitepaper.io/document/691/tbtc-whitepaper)
tBTC is an open membership system, where the BTC is managed by a rotating set of randomly selected nodes which manage a threshold wallet. The system requires that  51-of-100 randomly selected wallet signers must collaborate to produce a proper signature. 

### [RBTC](https://rootstock.io/static/a79b27d4889409602174df4710102056/RS-whitepaper.pdf)
Rootstock’s (RSK) 2-way peg protocol is called “the Powpeg”. Peg operations settle to Bitcoin via merge mining on the RSK side-chain. Peg operators are incentivized by earning a portion of Rootstock transaction fees. PowPeg operators keep specialized hardware called PowHSMs active and connected to special types of Rootstock full nodes. Since the Bitcoin blockchain and the Rootstock sidechain are not entangled in a single blockchain or in a parent-child relation, peg-in and peg-out transactions require a high number of block confirmations. Peg-ins require 100 Bitcoin blocks, and peg-outs require 200 Bitcoin blocks.

## Activation
sBTC Bootstrap is designed to activate on Stacks Nakamoto as defined in [SIP-021](https://github.com/stacksgov/sips/blob/feat/sip-021-nakamoto/sips/sip-021/sip-021-nakamoto.md). Therefore, this SIP is only meaningful when SIP-021 activates. The sBTC Working Group plans to observe at least 2-4 weeks of network behavior on Stacks Nakamoto to ensure a stable release. After this period, sBTC Bootstrap can be activated on the Stacks network without requiring a separate hard fork.

### Process of Activation
Users can vote to approve this SIP with either their locked/stacked STX or with unlocked/liquid STX, or both. The criteria for the stacker and non-stacker voting is as follows.

**For Stackers:**
In order for this SIP to activate, the following criteria must be met by the set of Stacked STX:
- At least 80 million Stacked STX must vote at all to activate this SIP.
- Of the Stacked STX that vote, at least 66% of them must vote "yes."

The voting addresses will be;
- **Bitcoin Yes Address:** 3Jq9UT81fnT2t24XjNVY7wijpsSmNSivbK
- **Bitcoin No Address:** 3QGZ1fDa97yZCXpAnXQd6JHF4CBC6bk1r4
- **Stacks Yes Address:** SP36GHEPEZPGD53G2F29P5NEY884DXQR7TX90QE3T
- **Stacks No Address:** SP3YAKFMGWSSATYNCKXKJHE2Z5JJ6DH88E4T8XJPK

which encode the hashes of the following phrases into bitcoin / stacks addresses:

- Yes to A Decentralized Two-Way Bitcoin Peg
- No to A Decentralized Two-Way Bitcoin Peg

Stackers (pool and solo) vote by sending a stacks dust transaction to the corresponding stacks address from the account where their stacks are locked.

Solo stackers only, can also vote by sending a bitcoin dust transaction (6000 sats) to the corresponding bitcoin address.

**For Non-Stackers:**
Users with liquid STX can vote on proposals using the Ecosystem DAO. Liquid STX is the users balance, less any STX they have locked in PoX stacking protocol, at the block height at which the voting started (preventing the same STX from being transferred between accounts and used to effectively double vote). This is referred to generally as "snapshot" voting.

For this SIP to pass, 66% of all liquid STX committed by voting must be in favor of the proposal. This precedent was set by [SIP-015](https://github.com/stacksgov/sips/blob/feat/sip-015/sips/sip-015/sip-015-network-upgrade.md). 

The act of not voting is the act of siding with the outcome, whatever it may be. We believe that these thresholds are sufficient to demonstrate interest from Stackers -- Stacks users who have a long-term interest in the Stacks blockchain's successful operation -- in performing this upgrade.

## Appendix

### Specification

**Deposits**
The main steps of the sBTC Deposit flow will be as follows.
1. **Deposit request:** A bitcoin holder creates a transaction on Bitcoin.
    - The deposit transaction contains a UTXO (deposit UTXO) spendable by sBTC Signers, with an OP_DROP payload.
    - The payload contains the recipient address of the sBTC among other relevant info for the deposit.
    - The relevant info could contain fee suggestion or max_fee
2. **Proof of deposit:** The bitcoin holder submits a proof of deposit on Stacks by invoking the Signer binary API
3. **Deposit accept:**
4. **Deposit redeem:** The sBTC Signers redeem the deposit by consuming the deposit UTXO, consolidating it into the sBTC UTXO.
5. **Mint:** The sBTC Signers finalize the deposit acceptance making a clarity contract call that mints the sBTC on the Stacks Layer.

**Withdrawals (Redeeming sBTC)**
The main steps of the sBTC withdrawal flow are as follows.
1. **Withdrawal request:** An sBTC holder calls the withdraw-request function in the .sbtc contract.
    - This transfers the requested amount of sBTC to the .sbtc contract & mints the user a non-transferable locked-sBTC as a placeholder
2. **Withdrawal accept:** If accepted, the following happens
    - The signers create a transaction on Bitcoin which returns the requested amount to the designated address.
    - Once the Bitcoin transaction is confirmed the signers make a smart contract call to one of the .sbtc contracts to mark the transaction as fulfilled.
    - If successful, the resulting Stacks transaction will record the withdrawal request as complete & will accordingly burn the user’s locked-sBTC.
3. **Withdrawal reject:** If instead the request is rejected, the sBTC signers will call the withdraw-reject function in the .sbtc smart contract. This function does the following:
    - Returns the sBTC to the holder.
    - Records the signer votes.
