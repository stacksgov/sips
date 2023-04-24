# Preamble

SIP Number: 023

Title: Fix to Orphan MEV

Authors:
    Friedger Müffke <mail@friedger.de>

Consideration: Technical, Governance, Economics

Type: Consensus

Status: Draft

Created: 24 April 2023

License: BSD 2-Clause

Sign-off: 

Discussions-To: https://github.com/stacks-network/stacks/discussions/468

# Abstract

The design of the current consensus rules about handling orphan blocks provides an incentive
for larger miners to orphan blocks mined by other miners. As a larger miner, their mined
sibling block has a higher change to become the canonical fork because the larger miner will
build on top of their own mined block. This results in no mining rewards for the other miner
and potentially pushing the miner out of the mining game and increasing the size of the larger miner
further.

This SIP proposes an **consensus-breaking change** that increases the cost for 
miners to create orphan blocks.

This SIP would constitute a consensus-rules version bump. The resulting system
version would be Stacks 2.3.

# Introduction

When Stacks miners build the next block S' of an earlier parent block P than the block S 
that was mined in the previous bitcoin block, then S and S' are siblings and a fork was created.
If the forks of S' becomes the canonical chain then block S becomes an orphane block and vice versa.

Miners of orphane blocks do not receive block rewards as described in SIP-001.

# Specification

The following additional rule to the consensus rules about block rewards specified in SIP-001 should 
be added:

* The coinbase reward is NOT distributed to the leader who mined the block if there exists
  a Stacks block mined in the previous Bitcoin block that is not part of the canonical chain.

Furthermore, the peer network version bits to `0x18000008`.  This ensures that follower 
nodes that do not upgrade to Stacks 2.3 will not be able to talk to Stacks 2.3 nodes.


# Related Work

SIP-001 describes some Seflish mining mitigation strategies. However, the current situation of
mining suggests that a coalition of miners achieved that new miners are prevented from participating
in mining through creating orphaned blocks.

The proposed solution of this SIP was described in https://github.com/stacks-network/stacks-blockchain/issues/3657.

Other solutions like pre-commit voting, fork temperature or mining off Bitcoin chain were 
discussed [here](https://github.com/stacks-network/stacks/discussions/468) and 
[here](https://forum.stacks.org/t/orphan-mev/14806).


# Backwards Compatibility

The specified change to the rules only effects the financial considerations of Stacks miners.
It does not affect database schemas or chain state semantics. 

# Activation

The SIP shall be activated at the same block height as SIP 22 is activated.

The node software for Stacks 2.3 shall be merged to the `master` branch of the
reference implementation no later than three days prior to the activation
height.  This means that everyone shall have at least three days to upgrade
their Stacks 2.2 nodes to Stacks 2.3.

# Reference Implementation

The reference implementation of this SIP is work in progress.
