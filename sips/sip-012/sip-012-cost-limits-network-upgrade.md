# Preamble

SIP Number: 012

Title: Burn height selection for network-upgrade to introduce new cost-limits

Authors:
* Diwaker Gupta <diwaker@hiro.so>
* Aaron Blankstein <aaron@hiro.so>
* Ludovic Galabru <ludo@hiro.so>

Consideration: Governance, Technical

Type: Consensus

Status: Draft

Created: 2021-10-08

License: BSD 2-Clause

Sign-off:

Discussions-To: https://github.com/stacksgov/sips

# Abstract

The current Clarity cost limits were set very conservatively in Stacks 2.0: transactions with contract-calls frequently exceed these limits, which negatively affects transaction throughput. This SIP proposes an update to these cost-limits via a network upgrade and further, that the network upgrade be executed at a block height chosen by an off-chain process described in this SIP.


# License and Copyright

This SIP is made available under the terms of the Creative Commons CC0 1.0 Universal license, available at https://creativecommons.org/publicdomain/zero/1.0/ This SIP’s copyright is held by the Stacks Open Internet Foundation.


# Introduction

Blocks on the Stacks blockchain tend to have anywhere between 10 to 50 transactions per block -- this is lower than the demands of many workloads and also lower than the theoretical maximum one would expect. On the other hand, the mempool consistently has hundreds of valid transactions pending at any given time; at peak there have been several thousand pending transactions. So what is preventing more transactions from being included in blocks?

The answer is cost-limits. An analysis of “full blocks” (meaning blocks where at least one cost dimension exceeds the block limit -- see SIP-006 for a description of all cost dimensions) found that roughly 72% of those blocks hit the `runtime` limit and ~27% hit the `read_count` limit. Another analysis of all transactions rejected due to cost limits found that 90% of those transactions exceeded the `runtime` limit. So the `runtime` limits are the primary bottleneck right now.

In the last few months, the [clarity-benchmarking](https://github.com/blockstack/clarity-benchmarking) project has done rigorous benchmarking on contemporary hardware to come up with more accurate cost-limits, with a focus on the `runtime` limits. The updated cost-limits are described in detail in [this forum post](https://forum.stacks.org/t/more-accurate-cost-functions-for-clarity-native-functions/12386).

Any modification of cost-limits is a consensus-breaking change. There seems to be broad community support for changing the cost-limits, the question is exactly how and when they go into effect. A previous proposal suggested using a voting contract to determine the block height at which a network-upgrade, described in detail in [this Github discussion](https://github.com/blockstack/stacks-blockchain/discussions/2845). Unfortunately, this path would take at least 4 months in the best-case scenario.

This SIP posits that the ongoing network congestion warrants a more expedient route to change the cost-limits, one that does not rely on an on-chain voting contract.


# Specification

## Assumptions

This SIP is a method of last resort, considering the circumstances an exception is justified. All future network upgrades should use the voting contract (if appropriate); all hard-forks must follow the process described in SIP-000.

## Proposal

The Stacks Foundation or the governance group should choose a Bitcoin block height for the network upgrade. The block number should be at least 3 calendar weeks out from when this SIP transitions into “Accepted” state, so as to provide sufficient heads up to node operators.

Miners, developers, Stackers and community members can demonstrate their support for this network upgrade in one of the following two ways:

* _Send a contract-call transaction to indicate support for the upgrade_: The contract would aggregate the STX balance on the tx-sender account. It could additionally call into the PoX contract to separately aggregate the total Stacked STX amount. See the Appendix for an initial draft of such a contract.
* _Send a BTC transaction to indicate support_: Many large STX holders are on a multi-sig BTC wallet that's unable to issue contract-calls. Such wallets could instead send a pure BTC transaction to indicate their support for the vote; it would be a no-op for Stacks [Aaron to add more details].

The SIP will be considered Recommended if wallets indicating support for the upgrade (through either mechanism) add up to > 10% of circulating supply of STX (approx 120M).

In terms of how these cost-limits would actually be applied, this SIP proposes the following:
* Add new functionality to stacks-blockchain that uses the current cost-limits by default and uses new cost-limits if the burn block height exceeds a configurable parameter (could be a compile time configuration to avoid runtime issues)
* Once a BTC block number has been determined, ship a new stacks-blockchain release at least one week before to give miners and node operators time to upgrade before the upgrade block height is reached
* In the subsequent release, remove all usage of the old cost-limits and just use the new cost-limits by default

# Activation

The SIP will be considered Active once:

* A new release of stacks-blockchain is available with the updated cost-limits and a mechanism to use the new cost-limits beyond a pre-determined Bitcoin block height
* This new release is deployed by independent miners, as determined by the continued operation of the Stacks blockchain beyond the Bitcoin block height selected for the network-upgrade. 

