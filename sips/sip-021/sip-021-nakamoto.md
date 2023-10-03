# Preamble

SIP Number: 021

Title: Fast and Reliable Blocks through PoX-assisted Block Propagation

Authors:
* Aaron Blankstein <aaron@hiro.so>
* Brice Dobry <brice@hiro.so>
* Jacinta Ferrent <jacinta@trustmachines.co>
* Jude Nelson <jude@stacks.org>
* Ashton Stephens <ashton@trustmachines.co>
* Joey Yandle <joey@trustmachines.co>

Consideration: Governance, Technical

Type: Consensus

Status: Draft

Created: 2023-09-28

License: BSD 2-Clause

# Abstract

This document describes a consensus-breaking change to the Stacks blockchain
that would enable faster and more reliable Stacks blocks.  In this proposal,
Stacks block production would no longer be tied to cryptographic sortitions.
Instead, miners produce blocks at a fixed cadence, and the set of PoX Stackers
rely on the cryptographic sortitions to determine when the current miner should
stop producing blocks and a new miner should start.  This blockchain does not
fork, and chain reorganization is as difficult as reorganizing the underlying
burnchain.

This proposal, dubbed the "Nakamoto" release, represents a substantial
architectural change to the current Stacks blockchain.  If adopted, the Stacks
major version would be bumped from 2 to 3.  The first Nakamoto release would be
3.0.0.0.0.

# Introduction

## Glossary

| Term | Definition |
|:-:|:-|
|MEV| **Miner Extractable Value:** It is any extra amount of value that a miner can extract from the network by deviating from expected behavior: including, excluding, or reordering transactions in a block. |
| cryptographic sortition | A process of randomly selecting one or more entities from a set using cryptography. This is a decentralized and verifiable way to select participants for a variety of tasks, such as consensus protocols, lotteries, and auctions. Further details are in [SIP-001][SIP-001-LINK]. |
| stacker | Someone who locks up their STX tokens in order to support the network and earn Bitcoin rewards. Read more about [how stacking helps the network][HOW-STACKING-HELPS-THE-NETWORK-GIST]. |
| stacks miner | Someone who spends Bitcoin to participate in miner elections and create the new block on the Stacks blockchain. Miners are rewarded with STX tokens. |
| PoX | **Proof of Transfer:** Miners commit Bitcoin to the Stacks network in order to be eligible to mine blocks. The more Bitcoin a miner commits, the higher their chances of winning the block lottery selected via cryptographic sortition. If a miner wins the block lottery, they are awarded STX tokens as a reward. Further details are in [SIP-007][SIP-007-LINK]. |
| Bitcoin finality | The level of difficulty inherent to reversing a confirmed Bitcoin transaction by means of producing a Bitcoin fork with a higher total chainwork which excludes said transaction. |

## Current Design

The Stacks blockchain today produces blocks in accordance to the algorithms
described in [SIP-001][SIP-001-LINK] and [SIP-007][SIP-007-LINK]. Miners compete
to append a block to the blockchain through a cryptographic sortition process.
Miners submit a `block-commit` transaction to the underlying burnchain (i.e.
Bitcoin), which commits to the hash of the block the miner intends to append.
The cryptographic sortition process selects at most one `block-commit` in the
subsequent burnchain block, which entitles the submitter to propagate their
block and earn a block reward.

## Problem Statement


Over the last three years the stacks community has identified several issues:

1. **Forks and missing blocks are disruptive to on-chain applications.** The act
of waiting to produce a new block until after a cryptographic sortition ties
best-case Stacks block production rate to the block production rate of its
underlying burnchain, leading to very high transaction confirmation latency.
While microblocks have the potential to mitigate both of these effects, they did
not work in practice because the protocol cannot ensure that microblocks will be
confirmed until the next sortition happens.
1. **Stacks forks imply an independent security budget for the Stacks
blockchain.** The cost to reorg the last _N_ blocks in the Stacks blockchain is
the cost to produce the next _N + 1_ Stacks blocks.
1. **Stacks forks arise due to poorly-connected miners.** If a set of miners has
a hard time learning the canonical Stacks chain tip when they submit
`block-commit`s, then they will collectively orphan other miners who are
better-connected.  This appears to have borne out in practice.
1. **Some Bitcoin miners run their own Stacks miners and deliberately exclude
other Stacks miners' `block-commit`s from their Bitcoin blocks.** Once the STX
block reward became sufficiently large this allowed them to pay a trivial PoX
payout while guaranteeing that they would win the cryptographic sortition in
their Bitcoin block. This was anticipated in the original design but the
regularity with which it happens today is greater than the original protocol
accounted for, and thus must be addressed now.

## Proposed Solution

To address these shortcomings, this proposal calls for four fundamental changes
to the way Stacks works.

* **Fast blocks**:  The time taken for a user-submitted transaction to be mined
  within a block (and thus confirmed) will now take on the order of seconds,
instead of tens of minutes.  This is achieved by separating block production
from cryptographic sortitions -- a winning miner may produce many blocks between
two subsequent sortitions.
* **Bitcoin finality**: Once a transaction is confirmed, reversing it is at
  least as hard as reversing a Bitcoin transaction.  The Stacks blockchain no
longer forks on its own.
* **Bitcoin fork resistance**: If there is a Bitcoin reorg, then Stacks
  transactions which remain valid after the fork are re-mined in the same order
they were in before.  However, transactions that become invalid as a result of a
Bitcoin fork are dropped.  This is _not_ a consensus-critical feature, and can
be incrementally deployed after this SIP is ratified.  However, this is
described in this proposal as future work.
* **No Bicoin miner MEV**:  This proposal alters the sortition algorithm to
  ensure that Bitcoin miners do not have an advantage as Stacks miners.  They
must spend competitive amounts of BTC to have a chance of earning STX.

## Design

To achieve these goals this proposal makes the following changes to the stacks
protocol:

1. **Decouple Stacks tenure changes from Bitcoin block arrivals.** A miner may
create many Stacks blocks per Bitcoin block, and the next miner must confirm
_all of them_. There are no more microblocks or Bitcoin-anchored blocks;
instead, there are only Nakamoto Stacks blocks. **This will achieve fast block
times.**
1. **Require stackers to collaborate before the next block can be produced.**
PoX Stacksrs will need to collectively validate, store, sign, and replicate each
Stacks block the miner produces before the next block can be produced to be
selected by cryptographic sortition. Stackers must do this in order to earn
their PoX payouts and unlock their STX (i.e. PoX is now treated as compensation
from the miner for playing this essential role).  In the proposed system, a
cryptographic sortition only selects a new miner; it does not give the miner the
power to orphan confirmed transactions as it does today. This will ensure that
miners **do not produce fork and are able to confirm all prior Stacks blocks
prior to selection.**
1. **Use stackers to police miner behavior.**  A cryptographic sortition causes
the Stackers to carry out a _tenure change_ by (a) agreeing on a "last-signed"
block from the current miner, and (b) agreeing to only sign blocks from the new
miner which descend from this last-signed block. Thus, Stackers police miner
behavior --  Stackers prevent miners from mining forks during their tenure, and
ensure that they begin their tenures by building atop the canonical chain tip.
This **further prevents miners from forking the stacks blockchain.**
1. **Require Stacks miners to commit the _indexed block hash_ of the first block
produced by the last Stacks miner in their block-commit transactions on
Bitcoin.** This is the SHA512/256 hash of both the _consensus hash_ of all
previously-accepted burnchain transactions that Stacks recognizes, as well as
the hash of the block itself (a `block-commit` today only contains the hash of
the Stacks block).  This will anchor the Stacks chain history to Bitcoin up to
the start of the previous miner's tenure, _as well as_ all causally-dependent
Bitcoin state that Stacks has processed. This **ensures Bitcoin finality**,
**resolves miner connectivity issues** by putting fork prevention on stackers,
and allows nodes with up-to-date copies of the Stacks chain state to **identify
which Stacks blocks are affected by a Bitcoin reorg** and recover the affected
Stacks transactions.
1. **Stackers identify the sequence of orphaned transactions after a fork for
transaction replay.** This can be implemented after this SIP is ratified because
it is not consensus-critical, and can be deployed incrementally because it only
requires sufficient numbers of Stackers to cooperate.
1. **Adopt a Bitcoin MEV solution which punishes block-commit censorship.** The
probability should be altered such that:
    1. The probability of winning is non-zero only if the miner attempted to
mine in the majority of the past ten cryptographic sortitions. This is not true
today -- if a miner is the sole miner in a Bitcoin block, then it has 100%
chance of winning. In this system, it can be the case that no miner has a
non-zero chance of winning. A Bitcoin MEV miner who spends a _de minimis_ PoX
payout in Bitcoin blocks it wins, but does not compete in other blocks, will
_never_ win sortition unless the Bitcoin miner also has the majority of Bitcoin
mining power.
    1. The probability of winning is inversely proportional to the larger of
either the system's total commits in the current block, or the system's median
total commits over the past ten blocks.  This means that a sudden decrease in
the Bitcoin block's total PoX payout, such as due to the exclusion of other
Stacks miners' `block-commit`s by a Bitcoin MEV miner, does _not_ increase the
likelihood that the MEV miner's _de minimis_ `block-commit` wins.
    1. The probability of winning is absolute, not relative. The sum of each
miner's probability of winning may be less than 1.0, meaning that there is a
chance that a cryptographic sortition chooses no winner even if there are
`block-commit`s present.  This outcome is treated as an empty sortition.

All together these changes will achieve the goals outlined in section 2.4,
resolving key areas of improvement for the stacks protocol.

# Specification

## Overview

Stackers subsume an essential role in the Nakamoto system that had previously
been the responsibility of miners.  Before, miners both decided the contents of
blocks, and decided whether or not to include them in the chain (i.e. by
deciding whether or not to confirm them).  In this system, miners only decide
the contents of blocks.  They do not get to decide whether or not they are
included in the chain.  Instead, Stackers decide whether or not the block is
included in the chain.  However, Stackers do not get to decide the contents of
blocks without becoming miners.  This separation of responsibilities is
necessary to make the system function reliably without forks.

The bulk of the complexity of the proposed changes is in separating these two
concerns, while ensuring that both mining and Stacking remain open-membership
processes.  Crucially, anyone can become a miner and anyone can become a
Stacker, just as before.  The most substantial changes are in getting miners and
Stackers to work together in their new roles in order to achieve this proposal's
goals.

The key idea is that Stackers are required to acknowledge and validate a miner's
block before it can be appended to the chain.  To do so, Stackers must first
agree on the canonical chain tip, and then apply (and roll back) the block on
this chain tip to determine its validity.  Once Stackers agree that the block is
both canonical and valid, they collectively sign it and replicate it to the rest
of the Stacks peer network.  Only at this point do nodes append the block to
their chain histories.

This new behavior prevents forks from arising.  If a miner builds a block atop a
stale tip, Stackers will refuse to sign the block.  If Stackers cannot agree on
the canonical Stacks tip, then no block will be appended in the first place.
While this behavior creates a new failure mode for Stacks -- namely, the **chain
can halt indefinitely** if Stackers cannot agree on the chain tip -- this is
mitigated by having a large and diverse body of Stackers such that enough of
them are online at all times to meet quorum.

## Stacker Signing

The means by which Stackers agree on the canonical chain tip and agree to append
blocks is tied to PoX.  In each reward cycle, a Stacker clinches one or more
reward slots; there are at most 4,000 reward slots per reward cycle.  Stackers
vote to accept blocks by producing a _weighted threshold signature_ over the
block.  The signature must represent a substantial fraction of the total STX
locked in PoX (the threshold), and each Stacker's share of the signature (its
weight) is proportional to the fraction of locked STX it owns.

The weighted threshold signature is a Schnorr signature generated through a
variation of the FROST protocol [1].  Each Stacker generates a signing key pair,
and they collectively generate an aggregate public key for nodes to use to
verify signatures computed through a distributed signing protocol.  This signing
protocol allocates shares of the associated aggregate private key to Stackers
proportional to the number of reward slots they clinch.  No Stacker learns the
aggregate private key; Stackers instead compute shares of the private key and
use them to compute shares of a signature, which can be combined into a single
Schnorr signature.

When a miner produces a block, Stackers execute a distributed signing protocol
to collectively generate a single Schnorr signature for the block.  Crucially,
the signing protocol will succeed only if at least _X%_ of the reward slots are
accounted for in the aggregate signature.  This proposal calls for a 70% signing
threshold -- at least 70% of the reward slots (by proxy, 70% of the stacked STX)
must sign a block in order to append it to the Stacks blockchain.

This SIP calls for using the WSTS protocol with the FIRE extension [2], which
admits a distributed key generation and signature generation algorithm pair
whose CPU and network bandwidth complexity grows with the number of _distinct_
Stackers.  The FIRE extension enables WSTS to tolerate byzantine Stackers.

## Chain Structure

The Nakamoto Stacks chain is a linearized history of blocks without forks.
Miners create blocks at a fast cadence (e.g. once every five seconds), they send
them to Stackers for validation and signing, and if Stackers reach at least 70%
quorum on the block, the block is replicated to the rest of the peer network.
The process repeats until the next cryptographic sortition chooses a different
miner to produce blocks (Figure 1).

As with the system today, miners submit their candidacy to produce blocks by
sending `block-commit` transactions on the Bitcoin chain.  This proposal calls
for altering the semantics of the `block-commit` in one key way: the
`block_header_hash` field is no longer the hash of a proposed Stacks block (i.e.
its `BlockHeaderHash`), but instead is the index block hash (i.e.
`StacksBlockId`) of the _previous_ miner's first-ever produced block.

![Untitled presentation
(12)](https://github.com/stacks-network/stacks-blockchain/assets/459947/fb669bc7-3d61-4154-a941-0e22beb73ad0)

<em>Figure 1: Overview of the relationship between Bitcoin blocks (and
sortitions), Stacks blocks, and the inventory bitmaps exchanged by Stacks nodes.
Each winning block-commit's <code>BlockHeaderHash</code> field no longer refers
to a new Stacks block to be appended, but instead contains the hash of the very
first Stacks block in the previous tenure.  These tenure start blocks each
contain a <code>TenureChange</code> transaction (not shown), which, among other
things, identifies the number of Stacks blocks produced since the last valid
start block (numbers in dark orange circles).</em>

The reason for this change is to both preserve Bitcoin finality and to
facilitate initial block downloads without significantly altering the inventory
state synchronization and block downloader state machines.  Bitcoin finality is
preserved because at every Bitcoin block _N+1_, the state of the Stacks chain as
of the start of tenure _N_ is written to Bitcoin.  Even if at a future date all
of the former Stackers' signing keys were compromised, they would be unable to
rewrite Stacks history for tenure N without rewriting Bitcoin history back to
sortition _N+1_.

## Chain Synchronization

This chain structure is similar enough to the current system that the inter-node
synchronization procedure remains roughly the same as it is today, meaning all
the lessons learned in building out inter-node synchronization still mostly
apply.  At a high-level, nodes would do the following when they have all of the
Stacks chain state up to reward cycle _R_:

1. **Download and process all sortitions in reward cycle _R+1_**.  This happens
largely the same way here as it does today -- the node downloads the Bitcoin
blocks, identifies the valid block-commits within them, and runs sortition on
each Bitcoin block's block-commits to choose a winner.  It does this on a
reward-cycle by reward-cycle basis, since it must first process the PoX anchor
block for the next reward cycle before it can validate the next reward cycle's
block-commits.

2. **For each sortition _N+1_, go and fetch the start block of tenure _N_ if
sortition _N+1_ has a valid block-commit and the inventory bit for tenure _N_ is
1.** This requires minimal changes to the block inventory and block downloader
state-machines.  Each neighbor node serves the node an inventory bitmap of all
tenure start blocks they have available, which enables the node to identify
neighbors that have the blocks they need.  Unlike today, only the inventory
bitmap of tenure start blocks is needed; there is no longer a need for a PoX
anchor block bitmap nor a microblock bitmap.

3. **For each start block of tenure _N_, identify the number of blocks** between
this start block and the last prior tenure committed to by a winning
block-commit (note that this may not always be tenure _N-1_, per figure 1).
This information is identified by a special `TenureChange` transaction that must
be included in each tenure start block (see next section).  So, the act of
fetching the tenure-start blocks in step 2 is the act of obtaining these
`TenureChange` transactions.

4. **Download and validate the continuity of each block sequence between
consecutive block commits**.  Now that the node knows the number of blocks
between two consecutive winning block-commits, as well as the hashes of the
first and last block in this sequence, the node can do this in a bound amount of
space and time.  There is no risk of a malicious node serving an endless stream
of well-formed but invalid blocks to a booting-up node, because the booting-up
node knows exactly how many blocks to expect and knows what hashes they must
have.

5. **Concurrently processes newly-downloaded blocks in reward cycle _R+1_** to
build up its tenure of the blockchain.

6. **Repeat once the PoX anchor block for R+2 has been downloaded and
processed**

This bootup procedure is amenable to activating this proposal from Stacks 2.x,
as long as it happens on a reward cycle boundary.

When the node has synchronized to the latest reward cycle, it would run this
algorithm to discover new tenures within the current reward cycle until it
reaches the chain tip.  Once it has processed all blocks as of the last
sortition, it continues to keep pace with the current miner by receiving new
blocks broadcasted through the peer network by Stackers once they accept the
next Stacks block.

## Block Structure

Nakamoto Stacks blocks will have a different wire format than Stacks blocks and
microblocks today.  In particular, the header will contain:

* A version number (1 byte)
* The length of the chain as of this tip (8 bytes, big-endian)
* The total BTC spent producing this tip (8 bytes, big-endian)
* The `StacksBlockId` of the parent Stacks block (32 bytes)
* The Bitcoin block hash of the Bitcoin block that triggered the start of the
  tenure in which they were mined (32 bytes)
* A recoverable ECDSA signature from the tenure's miner (65 bytes)
* The root of a SHA512/256 Merkle tree constructed over all of its contained
  transactions (32 bytes)
* The SHA512/256 root hash of the MARF once all of the contained transactions
  are processed (32 bytes)
* A Schnorr signature collectively generated by the set of Stackers over this
  block (65 bytes)

As before, the Stacks blockchain will continue to calculate a consensus hash for
each sortition.  The `StacksBlockId` of a Stacks block would simply be the
SHA512/256 of the block's associated sortition's consensus hash and the hash of
the block header.

Absent from this header is the VRF proof, because it only needs to be included
once per tenure.  Instead, this information will be put into the Nakamoto
`Coinbase` transaction, which has a different wire format than the current
`Coinbase` transaction.

All existing Stacks transactions, with the exception of `PoisonMicroblock`
transactions and the current `Coinbase` transaction, will continue to be
supported.  However, the anchor mode byte will be ignored.

### Tenure Changes

A _tenure change_ is an event in the Stacks blockchain when one miner assumes
responsibility for confirming transactions from another miner.  The miner's
_tenure_ lasts until the next cryptographic sortition.  Today, a tenure change
in Stacks occurs when a Stacks block is discovered from a cryptographic
sortition.

In this proposal, the Stackers themselves carry out a tenure change by creating
a specially-crafted `TenureChange` transaction which a miner must include in its
first-produced block.  The cryptographic sortition prompts Stackers to begin
creating the `TenureChange` for the next miner, and the next miner's tenure
begins only once they produce a block with the `TenureChange` transaction.

The act of producing a `TenureChange` transaction is also the act of Stackers
agreeing to no longer sign the current miner's blocks.  Thus, the act of
producing a `TenureChange` is the act of _atomically_ transferring
block-production responsibilities from one miner to another.  In doing so, the
new miner cannot orphan recently-confirmed transactions from the old miner
(something that is possible today with microblocks, and one of the reasons why
they are not adequate for addressing this proposal's concerns).

![Untitled presentation
(11)](https://github.com/stacks-network/stacks-blockchain/assets/459947/98381aa0-f8ff-4842-b15b-881f4c4424ab)

<em>Figure 2: Tenure change overview.  When a new Bitcoin block arrives,
Stackers begin the process of deciding the last block they will sign from miner
N.  When they reach quorum, they make this data available for download by
miners, and wrap it in a WSTS-signed specially-crafted data payload.  This
information serves as a record of the tenure change, and must be incorporated in
miner N+1's tenure-start block.  In other words, miner N+1 cannot begin
producing Stacks blocks until Stackers inform it of block X -- the block from
miner N that it must build atop.  Stacks-on-Bitcoin transactions are applied by
miner N+1 for all Bitcoin blocks in sortitions N and earlier when its tenure
begins.</em>

The `TenureChange` transaction encodes the following data:

* The `StacksBlockId` of the last block from miner _N_ that they will have
  processed (this is _X_ in figure 2)
* The number of blocks produced by miner _N_ and prior miners, back to the last
  non-empty sortition (required by the chain bootup algorithm).
* A flag to indicate which of the following triggered the tenure change
    * A valid winning block-commit
    * No `block-commit` transactions were present
    * No miner won sortition
* The ECDSA public key hash of miner _N+1's_ block-signing key
* An aggregate WSTS Schnorr signature from the Stackers
* A bitmap of which Stackers contributed to the WSTS Schnorr signature

When produced, the `TenureChange` transaction will be made available to miners
for download, so that miners can include it in their first block.  Miners _N_
and _N+1_ will both monitor the availability of this data in order to determine
when the former must stop producing blocks and the latter may begin producing
blocks.  Once miner _N+1_ receives this data, it begins its tenure by doing the
following:

1. It processes any currently-unprocessed Stacks-on-Bitcoin transactions up to
(but excluding) the Bitcoin block which contains its sortition (so, up to
sortition _N_).
2. It produces its tenure-start block, which contains the `TenureChange`
transaction as its first transaction.
3. It begins mining transactions out of the mempool to produce Stacks blocks.

If miner _N_ cannott obtain or observe the `TenureChange` transaction, then it
will keep producing blocks.  However, Stackers will not sign them, so as far as
the rest of the network is concerned, these blocks never materialized.  If miner
_N+1_ does not see the `TenureChange` transaction, it does not start mining; a
delay in obtaining the `TenureChange` transaction can lead to a period of chain
inactivity.  This can be mitigated by the fact that the miner can learn the set
of Stackers' IP addresses in advance, can directly query them for the data.

The Nakamoto Stacks blockchain has exactly one `TenureChange` transaction for
each and every tenure, even if the tenure is empty.

### Empty Tenures

Sometimes, a tenure can be empty.  The miner and Stackers may fail to sign any
Stacks block.  This can happen for banal reasons, such as (but not limited to):

* The next Bitcoin block arrived before the miner could produce a block (e.g. a
  flash block occurred)
* The miner crashed before it could mine a block, and remained offline for the
  duration of its tenure
* The miner never produced a valid block

In all cases, the tenure would be empty (Figure 3).

![Untitled presentation
(13)](https://github.com/stacks-network/stacks-blockchain/assets/459947/4f971f6b-e1a7-4994-8fca-cb82d70764e4)


<em>Figure 3: Tenures N+1 and N+2 are empty.  Stackers recover from this by
requiring the next non-empty tenure to include the empty tenures'
<code>TenureChange</code> transactions, to prove that these tenures were in fact
empty and no blocks were signed for them.  Because the tenures are empty, the
inventory bitmap would mark them as 0s -- there is no block data to fetch.</em>

To recover from this, Stackers would still produce `TenureChange` transactions
for the empty tenures, and require the start block of the first non-empty tenure
to include them.  In other words, Stackers _always_ produce a `TenureChange`
transaction for each tenure; it just might not be included by the tenure's
sortition-selected miner.

### Stacker Turnover

A miner tenure change happens every Bitcoin block.  In addition, there are
Stacker tenure changes, which happen once every 2100 Bitcoin blocks (one reward
cycle).  In a Stacker tenure change, a new set of Stackers are selected by the
PoX anchor block (see SIP-007).

Because Stacks no longer forks, the PoX anchor block is always known 100 Bitcoin
blocks prior to the start of the next reward cycle:  it is simply the the start
block of the 2000th tenure in the current reward cycle.

The PoX anchor block identifies the next Stackers.  They have 100 Bitcoin blocks
to prepare for signing Stacks blocks.  Within this amount of time, the new
Stackers would complete a WSTS DKG for signing blocks (among other things, such
as the sBTC peg wallet hand-off).  The PoX contract will require Stackers to
register their block-signing keys when they stack or delegate-stack STX, so the
entire network knows enough information to validate their WSTS Schnorr
signatures on blocks.

### PoX Failure

In the event that PoX does not activate, the chain halts.  If there are no
Stackers, then block production cannot happen.

### Changes to PoX

To support tenure changes, this proposal calls for a new PoX contract, `.pox-4`.
The `.pox-4` contract would be altered over the current PoX contract (`.pox-3`)
to meet the following requirements:

* Stackers register a WSTS signing key when they call `stack-stx` and optionally
  `delegate-stx`.
    * In `delegate-stx`, Stackers may instead elect for the delegate to supply
      the signing key.  In this case, the delegate carries out the Stacker's
responsibility for signing blocks.
* The stacking minimum is abolished.  If there is at least one stacker that is
  able to claim one reward slot, then PoX activates.
* The `.pox-4` contract will expose each reward cycle's full reward set,
  including the signing keys for each stacker, via a public function.
Internally, the Stacks node will call a _private_ function to load the reward
set into the `.pox-4` data space after it identifies the PoX anchor block.  This
is required for other dependent SIPs, such as the sBTC SIP.

## Dynamic Runtime Budgets

The time between cryptographic sortitions (and thus tenure changes) depends on
the time between two consecutive burnchain blocks.  This can be highly variable,
which complicates the task of sustaining a predictable transaction confirmation
latency while also preventing a malicious miner from spamming the network with
too many high-resource transactions.

Today, each miner receives a tenure block budget, which places hard limits on
how much CPU, RAM, and I/O their block can consume when evaluated.  In this
proposal, each miner begins its tenure with a fixed budget, but Stackers may opt
to increase that budget through a vote.  This is done to enable the miner to
continue to produce blocks if the next burnchain block is late.

To achieve this, Stackers each keep track of the elapsed wall-clock time since
the start of the tenure.  Once the expected tenure time has passed (e.g. 10
minutes), they vote to grant the miner an additional tenure execution budget.
This is achieved by having Stackers collectively produce a `TenureExtension`
Stacks transaction, which the miner would include into one of their blocks.
Once this transaction has been processed, the tenure block budget expands.

## Support for WSTS Schnorr Signatures

This proposal calls for adding support for WSTS Schnorr signatures as a
transaction authorization mode to Stacks.  This enables Stackers to collectively
sign a Stacks transaction.  The specification for the transaction authorization
is as follows:

* The spending condition's hash mode must be **0x04**.
* An additional spending condition variant specific to single-key Schnorr
  signatures, which can only be used if the hash mode is 0x04.  The spending
condition variant is encoded as follows:
  * A 65-byte **Schnorr signature**, consisting of:
    * The 33-byte signed x-coordinate of the signature curve point
    * The 32-byte scalar derived from the hash of the generator raised to the
      _k_th power and the message
  * A 33-byte **compressed secp256k1 public key**, consisting of its signed
    x-coordinate

To verify the transaction signature, the node both verifies that the public
key's hash160 is equal to the spending condition's 20-byte hash, and verifies
that the Schnorr signature over the `presign-sighash` value of the transaction
was generated by corresponding private key.

The address of a principal who signs a transaction with the WSTS Schnorr
signature algorithm is identical to that of a single-sig ECDSA signer.  They
have the same address versions -- i.e. on mainnet, the address starts with `SP`,
and on testnet, it starts with `ST`.

## New Block Validation Rules

In this proposal, a block is valid if and only if the following are true:

* The block is well-formed
    * It has the correct version and mainnet/testnet flag
    * **(NEW)** Its header contains the same Bitcoin block hash as the Bitcoin
      block that contains its tenure's block-commit transaction
    * The transaction Merkle tree root is consistent with the transactions
    * The state root hash matches the MARF tip root hash once all transactions
      are applied
    * **(NEW)** the block header has a valid ECDSA signature from the miner
    * **(NEW)** the block header has a valid WSTS Schnorr signature from the set
      of Stackers
* **(NEW)** All Bitcoin transactions since the last valid sortition up to (but
  not including) this tenure's block-commit'ss Bitcoin block have been applied
to the Stacks chain state
* In the case of a tenure start block:
    * **(NEW)** The first transactions are the `TenureChange` transactions for
      any tenures not represented by Bitcoin block-commits, and they are present
in order by sortition.
    * **(NEW)** The first non-`TenureChange` transaction is a `Coinbase`.
* All transactions either run to completion, or fail due to runtime errors.
  That is:
    * The transaction is well-formed
    * All transactions' senders and sponsors are able to pay the transaction fee
    * The runtime budget for the tenure is not exceeded
        * **(NEW)** The total runtime budget is equal to the runtime budget for
          one tenure, multiplied by the number of valid `TenureExtension`
transactions mined in this tenure.
    * No expression exceeds the maximum nesting depth
    * No supertype is too large
    * **(NEW)** The `PoisonMicroblock` transaction variant is not supported
      anymore
    * **(NEW)** The current `Coinbase` transaction variant is not supported
      anymore

In addition to the new `TenureChange` and `TenureExtension` transactions, this
proposal calls for a new coinbase transaction called the `NakamotoCoinbase`.
This transaction contains the same data as the `Coinbase` transaction does
today, as well as a VRF proof for this tenure.

## Block Reward Distribution and MEV

The Nakamoto system will use a variation of the Assumed Total Commitment with
Carryforward (ATC-C) MEV mitigation strategy described in [this
document](https://forum.stacks.org/uploads/short-url/bqIX4EQ5Wgf2PH4UtiZHZBqJvYE.pdf)
to allocate block rewards to miners.  Unlike Stacks today, there is no 40/60 fee
split between two consecutive miners.  Each miner nominally receives the entire
coinbase and transaction fees before the MEV mitigation is applied.

In the ATC-C algorithm, Nakamoto would use the document's recommended assumed
total commitment function: the median total PoX spend across all miners for the
past ten Bitcoin blocks.  It would additionally use the document's recommended
carryforward function for missed sortitions' coinbases:  the coinbase for a
Bitcoin block without a sortition would be available to winning miners across
the next ten tenures.  That is, if a miner whose tenure begins during the next
ten tenure-changes manages to produce a Stacks block with a `Coinbase`, then
they receive a 20% of the coinbase that was lost.

The reason ATC (and ATC-C) were not considered as viable anti-MEV strategies
before is because a decrease in the PoX total spend can lead to a Bitcoin block
with no sortition. This is a deliberate design choice in ATC-C, because it has
the effect of lowering the expected return of MEV mining.  In ATC-C, the
probability of a miner winning a sortition is _equal to_ (i.e. no longer
proportional to) the miner's BTC spend, divided by the maximum of either the
assumed total commit (median total BTC spend in the last 5 blocks) or the total
BTC spend in this Bitcoin block.  This means that the sum of each miners'
winning probabilities is not guaranteed to be 1.  The system deals with this by
creating a virtual "nul" miner that participates in each sortition, such that
its probability of the null miner winning is _1 -
sum(probabilities-of-all-other-miners)_.  If the null miner wins, then the
sortition is treated as empty.

While the existence of a null miner was a liveness concern in Stacks today, it
is not a concern in this proposal.  If the null miner wins tenure _N_, then the
last non-null miner continues to produce blocks in tenure _N_.  They receive
transaction fees, but no coinbase for tenure _N_.

This proposal advocates for one additional change to ATC-C as described in the
above report:  if a miner does not mine in at least five of the ten prior
Bitcoin blocks, it has zero chance of winning.  This requires a Bitcoin MEV
miner to participate as an honest miner for the majority of blocks it produces,
such that even if they pay a _de minimis_ PoX payout each time, they are still
paying Bitcoin transaction fees to other miners.

### Example

The need for this additional tweak becomes apparent when considering the
consequences for a real Bitcoin MEV miner who is active on the Stacks network
today: F2Pool.

Consider what happens to F2Pool, who spends 200 sats on PoX and zero sats on
transaction fees for their block-commit. Suppose the median total BTC spend over
the last ten Bitcoin blocks was 500,000 sats (about what it is right now).  With
ATC-C alone, their probability of winning sortition would be 200 / max(500,000,
200), or about 0.04% chance. The miner would need to send 2,500 such
block-commits before winning a Stacks coinbase (worth about 500 USD). F2Pool had
13.89% of Bitcoin's mining power over the past three months, so it would take
them about 4 months to win a single STX coinbase (which is a very long time
horizon). Right now, it costs 22 sats/vbyte to get a Bitcoin transaction mined
in the next Bitcoin block; this is what Stacks miners pay. A block-commit tx is
about 250 vbytes, so that's 5500 sats, or about 1.41 USD with today's BTC price.
So, F2Pool would lose money by MEV mining at their current rate if prices stay
the same over those 4 months -- they'd forfeit about 3,525 USD in Bitcoin
transaction fees (lost by excluding other Bitcoin transactions in order to
include their block-commit) for a Stacks coinbase worth 500 USD. They'd have to
pay about 1410 sats per block-commit just to break even, and they'd only recoup
their investment on average once every 4 months.

This by itself is not a significant improvement -- F2Pool would be required to
go from paying 200 sats to 1410 sats.  However, with this proposal's tweek,
F2Pool would be required to _additionally_ win five Bitcoin blocks in a row in
order to mine this cheaply.  Given that they have 13.89% of the mining power
today, the odds of this happening by chance are only 0.005%.  Since this is
unlikely -- about once every 20,000 Bitcoin blocks (once every 138.9 days) --
F2Pool would instead be required to send legitimate `block-commit` transactions
in at least 50% of the Bitcoin blocks.  In 87.11% of those, they would be paying
the same transaction fees as every other Stacks miner.  This alone would cost
them $106.13 USD/day.  With the additional _de minimis_ PoX payout, this rises
to $212.25 USD/day.  In other words, they would expect to pay $29,481.51 USD
just to be able to mine one Stacks block for a _de minimis_ PoX payout.  This is
more expensive than mining honestly!

If the largest Bitcoin mining pool -- Foundry USA, at 30% of the Bitcoin mining
power -- wanted to become a Bitcoin MEV miner on Stacks, then the given
parameter choice still renders this unprofitable.  There is a 0.243% chance that
they win five blocks in a row, and can thus mine a _de-minimis_ `block-commit`
and be guaranteed to win.  This happens about once every 2.85 days (every 411.5
Bitcoin blocks), so they'd be spending about $604.91 USD just to mine one Stacks
block for free (which is not profitable either).

## Financial Incentives and Security Budgets

Miners remain incentivized to mine blocks because they earn STX by spending BTC.
This dynamic is not affected by this change.

Stackers have the new-found power to sign blocks in order to append them to the
Stacks chain.  However, some of them could refuse to sign, and ensure that no
block ever reaches the 70% signature threshold.  While this can happen by
accident, this is not economically rational behavior -- if they stall the chain
for too long, their STX lose their value, and furthermore, they cannot re-stack
or liquidate their STX or activate PoX to earn BTC.

Stackers may refuse to sign blocks that contain transactions they do not like,
for various reasons.  In the case of `stack-stx`, `delegate-stx`, and
`transfer-stx`, users have the option to _force_ Stackers to accept the block by
sending these transactions as Bitcoin transactions.  Then, all
subsequently-mined blocks _must_ include these transactions in order to be
valid.  This forces Stackers to choose between signing the block and stalling
the network forever.

Stackers who do not wish to be in this position should evaluate whether or not
to continue Stacking.  Furthermore, Stackers may delegate their signing
authority to a third party if they feel that they cannot participate directly in
block signing.

That all said, the security budget of the chain is considerably larger in this
proposal than before.  In order to reorg the Stacks chain, someone must take
control of at least 70% of the STX that are currently Stacked.  If acquired at
market prices, then at the time of this writing, that amounts to spending about
$191 million USD.  By contrast, Stacks miners today spend a few hundred USD per
Bitcoin block to mine a Stacks block.  Reaching the same economic resistence to
reorgs provided by a signature from 70% of all stacked STX would take
considerably longer.

## Future Work: Transaction Replay on Bitcoin Forks

The Bitcoin chain can fork.  This can be a problem, because Stacks transactions
can be causally dependent on the now-orphaned Bitcoin state.  For example, any
Stacks transaction that uses `(get-burn-block-info?)` may have a different
execution outcome if evaluated after the Bitcoin block state from which it was
mined no longer exists.

To recover from Bitcoin forks, and the loss of data that may result, this
proposal calls for dropping any previously-mined but now-invalid Stacks
transactions from the Stacks chain history, but re-mining the set of Stacks
transactions which remain valid across the Bitcoin fork in the same order in
which they were previously mined.  That is, **transactions that were _not_
causally dependent on lost Bitcoin state would remain confirmed on Stacks, in
the same (relative) order in which they were previously mined.**

To do so, Stackers would first observe that a Bitcoin fork has occurred, and
vote on which Bitcoin block(s) were orphaned (even if it means sending the
orphaned data to each other, since not all Stacks nodes may have seen it).  Once
Stackers agree on the sequence of orphaned Bitcoin blocks, they identify which
Stacks blocks would be affected.  From there, they each replay the affected
Stacks blocks' transactions in the same order, and in doing so, identify which
transactions are now invalid and which ones remain valid.  Once they have this
subsequence of still-valid transactions, they advertise it to miners, and only
sign off on Stacks blocks that include a prefix of this subsequence that has not
yet been re-mined (ignoring `Coinbase`, `TenureChange`, and `TenureExtension`
transactions).  This way, the Stacks miners are compelled to replay the
still-valid Stacks transactions in their same relative order, thereby meeting
this guarantee.

Importantly, this transaction replay feature is directed exclusively by Stacker
and miner policy logic.  It is not consensus-critical, and in fact cannot be
because not all miners or Stackers may have even seen the orphaned Bitcoin state
(which precludes them from independently identifying replay transactions; they
must instead _work together_ to do so off-chain).  Therefore, this feature's
implementation can be deferred until after this SIP is ratified.

# Backwards Compatibility

This proposal is a breaking change.  However, all smart contracts published
prior to this proposal's activation will be usable after this proposal
activates.  Of particular note is that the `block-height` Clarity variable will
increment at a much faster pace, since blocks will be produced much more
quickly.

A separate SIP will be written to describe any changes to Clarity that may take
effect with the activation of this SIP.

Some design decisions of this SIP were undertaken to support sBTC, which is
described in a separate SIP.  In particular, the sBTC system requires a notion
of finality be present in Stacks -- an sBTC peg-in or peg-out is not truly
settled until it is impossible for a chain reorg to remove it from the Stacks
history.

# Related Work

This new system bears superficial similarity to proof-of-stake (PoS) systems.
However, there are several crucial differences that place the Nakamoto Stacks
system in a separate category of blockchains from PoS:

* Anyone can produce blocks in Stacks by pending BTC.  How they get their BTC is
  not important; all that matters is that they spend it  This is not true in PoS
systems -- users must stake existing tokens to have a say in block production,
which means that they must acquire them from existing stakers.  This _de facto_
means that producing blocks in PoS systems requires the permission of at least
one staker -- they have to sell you some tokens.  However, because BTC is
produced via proof-of-work, no such permission is needed to produce Stacks
blocks.

* Stackers do not earn the native STX tokens for signing off on blocks.
  Instead, they receive PoX payouts and their stacked STX tokens eventually
unlock.  By contrast, stakers earn the native token by signing off on blocks.

* Because anyone can mine STX, anyone can become a Stacker.  There is no way for
  existing Stackers to "close ranks" and prevent someone from joining -- if
Stackers refuse to sign a block with a `stack-stx` contract call, then a
would-be Stacker would issue a `stack-stx` call via a Stacks-on-Bitcoin
transaction.  This forces all subsequent miners to produce blocks which
materialize this `stack-stx` call, thereby forcing Stackers to choose between
admitting the new Stacker or halting the chain forever.  By contrast, there is
no penalty for "closing ranks" on new stakers in PoS systems.

# Activation

There are different rules for activating this SIP based on whether or not the
user has stacked their STX, and how they have done so.

## For Stackers

In order for this SIP to activate, the following criteria must be met by the set
of Stacked STX:

* At least 80 million Stacked STX must vote _at all_ to activate this SIP.  This
  number is chosen because it is more than double the amount of STX locked by
the largest Stacker at the time of this writing (reward cycle 69).

* Of the Stacked STX that vote, at least 80% of them must vote "yes."

The act of not voting is the act of siding with the outcome, whatever it may be.
We believe that these thresholds are sufficient to demonstrate interest from
Stackers -- Stacks users who have a long-term interest in the Stacks
blockchain's succesful operation -- in performing this upgrade.

### How To Vote

If a user is Stacking, then their STX can be used to vote in one of two ways,
depending on whether or not they are solo-stacking or stacking through a
delegate.

The user must be Stacking in any cycle up to and including cycle 75.  Their vote
contribution will be the number of STX they have locked.

#### Solo Stacking

The user must send a minimal amount of BTC from their PoX reward address to one
of the following Bitcoin addresses:

* For **"yes"**, the address is `11111111111111X6zHB1bPW6NJxw6`.  This is the
  base58check encoding of the hash in the Bitcoin script `OP_DUP OP_HASH160
000000000000000000000000007965732d332e30 OP_EQUALVERIFY OP_CHECKSIG`.  The value
`000000000000000000000000007965732d332e30` encodes "yes-3.0" in ASCII, with
0-padding.

* For **"no"**, the address is `1111111111111117Crbcbt8W5dSU7`.  This is the
  base58check encoding of the hash in the Bitcoin script `OP_DUP OP_HASH160
00000000000000000000000000006e6f2d332e30 OP_EQUALVERIFY OP_CHECKSIG`.  The value
`00000000000000000000000000006e6f2d332e30` encodes "no-3.0" in ASCII, with
0-padding.

From there, the vote tabulation software will track the Bitcoin transaction back
to the PoX address in the `.pox-3` contract that sent it, and identify the
quantity of STX it represents.  The STX will count towards a "yes" or "no" based
on the Bitcoin address the PoX address sends to.

If the PoX address holder votes for both "yes" and "no" by the end of the vote,
the vote will be discarded.

Note that this voting procedure does _not_ apply to Stacking pool operators.
Stacking pool operator votes will not be considered.

#### Pooled Stacking

If the user is stacking in a pool, then they must send a minimal amount of STX
from their Stacking address to one of the following Stacks addresses to commit
their STX to a vote:

* For **"yes"**, the address is `SP00000000000003SCNSJTCSE62ZF4MSE`.  This is
  the c32check-encoded Bitcoin address for "yes"
(`11111111111111X6zHB1bPW6NJxw6`) above.

* For **"no"**, the address is `SP00000000000000DSQJTCSE63RMXHDP`.  This is the
  c32check-encoded Bitcoin address for "no" (`1111111111111117Crbcbt8W5dSU7`)
above.

From there, the vote tabulation software will track the STX back to the sender,
and verify that the sender also has STX stacked in a pool.  The Stacked STX will
be tabulated as a "yes" or "no" depending on which of the above two addresses
receive a minimal amount of STX.

If the Stacks address holder votes for both "yes" and "no" by the end of the
vote period, the vote will be discarded.

## For Miners

There is only one criterion for miners to activate this SIP: they must mine the
Stacks blockchain up to and past the end of the voting period.  In all reward
cycles between cycle 75 and the end of the voting period, PoX must activate.

## Examples

### Voting "yes" as a solo Stacker

Suppose Alice has stacked 100,000 STX to `1LP3pniXxjSMqyLmrKHpdmoYfsDvwMMSxJ`
during at least one of the voting period's reward cycles.  To vote, she sends
5500 satoshis for **yes** to `11111111111111X6zHB1bPW6NJxw6`.  Then, her 100,000
STX are tabulated as "yes".

### Voting "no" as a pool Stacker

Suppose Bob has Stacked 1,000 STX in a Stacking pool and wants to vote "no", and
suppose it remains locked in PoX during at least one reward cycle in the voting
period.  Suppose his Stacks address is
`SP2REA2WBSD3XMVMYS48NJKS3WB22JTQNB101XRRZ`.  To vote, he sends 1 uSTX from
`SP2REA2WBSD3XMVMYS48NJKS3WB22JTQNB101XRRZ` for **no** to
`SP00000000000000DSQJTCSE63RMXHDP`. Then, his 1,000 STX are tabulated as "no."

# Reference Implementation

The reference implementation can be found at
https://github.com/stacks-network/stacks-blockchain.

## Stacker Responsibilities

The act of Stacking requires the Stacker to be online 24/7 to sign blocks.  To
facilitate this, the implementation comes with a Stacker signer daemon, which
runs as an event observer to the Stacks node.

The Stacker signer daemon receives notifications from the Stacks node when a new
block arrives.  On receipt of the block, the daemon instigates a WSTS signing
round with other signer daemons to generate an aggregate Schnorr signature.

The Stacker signer daemons communicate with one another through a network
overlay within the Stacks peer-to-peer network called a _StackerDB_.  The
StackerDB system allows nodes to replicate an array of fixed-sized chunks of
arbitrary data, which must be signed by principals identified by a smart
contract.

## StackerDB

StackerDB is a feature that will ship prior to this SIP's activation.  It allows
users to store data within the Stacks peer-to-peer network by means of a
specially-crafted smart contract, and a connected overlay network.  The smart
contract describes the parameters of the data (e.g. who can write to it; how
much data can be stored; and so on); the data itself is stored off-chain.  A
StackerDB-aware node maintains connections to other StackerDB-aware nodes who
replicate the same StackerDBs as itself.

The StackerDB data schema is an array of fixed-sized chunks.  Each chunk has an
slot index, a monotonically-increasing version, and a signer (e.g. a Stacks
address).  A user writes a chunk by POST-ing new chunk data for the slot, as
well as a new version number and a signature over both the data and the version.
If the chunk is newer than the chunk already stored (as identified by version
number), then the node stores the chunk and replicates it to other nodes
subscribed to the same StackerDB instance.

Stacks nodes announce which StackerDB replicas they subscribe to when they
handshake with one another.  If both the handshaker and its peer support the
StackerDB protocol, they exchange the list of replicas that they maintain.  In
doing so, StackerDB-aware nodes eventually learn about all reachable nodes'
StackerDB replicas as they walk the peer graph.

StackerDB-aware nodes set up overlay networks on top of the Stacks peer-to-peer
network to replicate StackerDB chunks.  Nodes that replicate a particular
StackerDB will periodically exchange version vectors for the list of chunks in
the replica.  If one node discovers that another node has a newer version of the
chunk, it will download it and forward it to other StackerDB-aware nodes in the
overlay that also need it.  In doing so, every StackerDB-aware node in the
overlay eventually receives an up-to-date replica of the StackerDB chunks.

## DKG and Signing Rounds

The WSTS system requires all signing parties to exchange cryptographic data with
all other signing parties.  The reference implementation's Stacker signer daemon
does this via a StackerDB instance tied to the `.pox-4` smart contract.  The
`.pox-4` smart contract exposes the signing keys for each Stacker, and the
StackerDB contract accesses this information to implement the StackerDB trait,
thereby creating a StackerDB into which only Stackers can write chunks of data.

The StackerDB used by Stackers will be used to carry out distributed key
generation, to run signing rounds, and to publish `TenureChange` and
`TenureExtend` transactions.

## Stacker Transaction Inclusion

Some transactions, like `TenureChange` and `TenureExtend`, are generated by
Stackers for inclusion in the blockchain.  These transactions would have a 0-STX
fee, so that Stackers are not in a position of needing to pay STX to do their
jobs.  They _compel_ miners to include them in their blocks by keeping track of
any such pending transactions in their StackerDB, and refusing to sign blocks
unless the miner includes them.

The miner obtains these transactions by querying the StackerDB instance used by
Stackers.  Miners' nodes may subscribe to the StackerDB instance in order to
maintain an up-to-date replica.

## Future Work: Guaranteed Transaction Replay

In the event of a Bitcoin fork, Stackers would maintain the list of transactions
which miners _must_ reply in their StackerDB as well.  The miner would read this
information from the Stackers' StackerDB in order to re-mine them into new
Stacks blocks after the Bitcoin fork resolves.

## Signer Delegation

Users who Stack may not want to run a 24/7 signing daemon. If not, then they can
simply report some other signer's public key when calling `stack-stx` or
`delegate-stack-stx`.  Then, this other entity would run the signing daemon on
their behalf.

While this does induce some consolidation pressure, we believe it is the
least-bad option.  Some users will inevitably want to outsource the signing
responsibility to a third party.  However, trying to _prevent_ this
programmatically would only encourage users to find work-arounds that are even
more risky.  For example, requiring users to sign with the same key that owns
their STX would simply encourage them to trust a 3rd party to both hold and
stack their STX on their behalf, which is _worse_ than just outsourcing the
signing responsibility.

# References

- [1] https://eprint.iacr.org/2020/852.pdf
- [2] https://trust-machines.github.io/wsts/wsts.pdf


[SIP-001-LINK]:
https://github.com/stacksgov/sips/blob/main/sips/sip-001/sip-001-burn-election.md
[SIP-007-LINK]:
https://github.com/stacksgov/sips/blob/main/sips/sip-007/sip-007-stacking-consensus.md
[HOW-STACKING-HELPS-THE-NETWORK-GIST]:
https://gist.github.com/jcnelson/802d25994721d88ab7c7991bde88b0a9
