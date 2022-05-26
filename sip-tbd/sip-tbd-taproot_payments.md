# Preamble

SIP Number: [TBD]

Title: Taproot Payments Integration

Authors: Rena Shah ([rena@trustmachines.co](mailto:rena@trustmachines.co))

Consideration: Governance, Technical

Type: Consensus

Status: Draft

Created: 24 May 2022

License: CC0-1.0

Sign-off: 

# Abstract

This SIP proposes an important change to enable mining payouts to Taproot scripts. Taproot scripts were enabled at block 709,632 on the Bitcoin Network on November 14, 2021. 

We believe that with this change, mining pools are more realistic where people can pool their mining bids into a Taproot script while running independent miners. Doing so further increases the number of independent miners and aids decentralization. Taproot scripts alleviate bandwidth issues on the Bitcoin network since the pool resembles a single miner. Furthermore, we’d like to implement the optionality to send Taproot payments scripts to both Stacks wallets or Stacks smart contracts to streamline operations. 

# License and Copyright

This SIP is made available under the terms of the Creative Commons CC0 1.0 Universal license, available at [Creative Commons — CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/). This SIP’s copyright is held by the Stacks Open Internet Foundation.

# Introduction
The Taproot upgrade was first proposed to the Bitcoin network in 2018 to improve efficiency. As a result, one of the core updates was a technique called “key aggregation,” which enables multi-signature transactions to commit the same amount of data to the Bitcoin blockchain as a single standard transaction. With this technique, transactions are batched into a single transaction, resulting in a lighter load. 

With this technology, there are benefits to the Stacks ecosystem with respect to mining. Enabling Taproot scripts allows independent miners to pool together their mining bids as a single transaction. With that change, more independent miners can come on board to pool together for block bids. Adding the optionality to send Taproot payments to Stacks smart contracts streamlines mining pools operations within their protocol. 

# Modification

This SIP proposes to integrate Taproot script payments to the Stacks blockchain. Additionally, this SIP also proposes to allow the option to send Taproot script payments to Stacks Smart Contracts.

# Rationale

In the current state, approximately ~5 miners are operating to secure the Stacks network [1].  
<img width="1175" alt="Onstacks Mining Stats 5-24-2022" src="https://user-images.githubusercontent.com/46361137/170338141-28ddbd5f-efe8-4e73-87b2-afb509fda8ab.png">
                          **Source:** [OnStacks](https://app.onstacks.com/), accurate as of 24 May 2022

In the event that these ~5 miners go offline, Stacks blockchain is open to vulnerabilities. Allowing independent miners to pool together through Taproot scripts further decentralizes the mining of Stacks. In general, greater miner numbers increase resiliency and decentralization of the Stacks blockchain which is a favorable outcome for the ecosystem.

A new Stacks block may be mined once per Bitcoin block, amassing 144 blockers per day. To be considered for mining a block, a miner must have a block commit included in a Bitcoin block. This is determined by the amount of Bitcoin the miners have sent to be burned. Oftentimes, independent miners will not “win” the block as they do not have enough Bitcoin committed. However, with Taproot payments, independent miners can form something akin to a mining pool with a single transaction commitment. This update avoids many Bitcoin bandwidth bottleneck issues because to the Bitcoin network, the pool just looks like a single miner.

To minimize risk and mine optimally, miners need approximately 2.5 BTC for every 500 blocks of Stacks mined, as-of January 31, 2022, when an independent analysis was conducted by [Syvita Mining](https://syvitamining.com/)’s [MattySTX](https://twitter.com/MattySTX). This analysis represented the worst 5% of outcomes, taken to the 95th percentile of confidence levels.

For the majority of miners, this upfront capital cost may be out of reach. Coupled with the technical burdens to run a node, everyday folks are disproportionately at a disadvantage. Mining pools make a compelling use case for people to collaborate while securing the Stacks network.

Scanning the Bitcoin Network shows at least 15 independent mining pools securing the network. [2]. Of those pools, some like Slushpool have upwards of ~16,000 independent users [3]. 

<img width="1302" alt="Slushpool" src="https://user-images.githubusercontent.com/46361137/170338217-80aecf96-b845-45fe-871f-387a20fd1759.png">
 **Source:** [Slushpool](https://slushpool.com/en/stats/btc/), accurate as of May 24, 2022

Integrating Taproot scripts could have a positive impact on the Stacks ecosystem. Taking this a step further to incorporate optionality for Taproot script payouts to smart contracts aids new mining pools to start mining. 

# Backwards Compatibility

No.

# Activation

The activation criteria for this SIP need input and debate, and should ultimately be defined by the Stacks community.

# References

[1] - https://app.onstacks.com/
[2] - https://www.theblockcrypto.com/data/on-chain-metrics/bitcoin
[3] - https://slushpool.com/en/stats/btc/
