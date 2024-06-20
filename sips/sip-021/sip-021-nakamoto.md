# Preamble

SIP Number: 021

Title: Fast and Reliable Blocks through PoX-assisted Block Propagation

Authors:

* Aaron Blankstein <aaron@hiro.so>
* Charlie Cantoni <charlie@hiro.so>
* Brice Dobry <brice@hiro.so>
* Jacinta Ferrent <jacinta@trustmachines.co>
* Diwaker Gupta <diwaker@hiro.so>
* Marvin Janssen <marvin@ryder.id>
* Jesus Najera <jnajera1917@gmail.com>
* Jude Nelson <jude@stacks.org>
* Ashton Stephens <ashton@trustmachines.co>
* Joey Yandle <joey@trustmachines.co>

Consideration: Governance, Technical, Economics

Type: Consensus

Status: Accepted

Created: 2023-09-28

License: BSD 2-Clause

Sign-off: Rafael Cárdenas <rafael@hiro.so> (SIP Editor), Brice Dobry <brice@hiro.so> (Technical CAB)

# Abstract
This document describes a consensus-breaking change to the Stacks blockchain that would enable faster and more reliable Stacks blocks.

In this proposal, Stacks block production would no longer be tied to miner elections. Instead, miners produce blocks at a fixed cadence, and the set of PoX Stackers rely on the miner elections to determine when the current miner should stop producing blocks and a new miner should start. This blockchain will only fork if 70% of Stackers approve the fork, and chain reorganization will be as difficult as reorganizing Bitcoin.

This proposal, dubbed the "Nakamoto" release, represents a substantial architectural change to the current Stacks blockchain. If adopted, the Stacks major version would be bumped from 2 to 3. The first Nakamoto release would be 3.0.0.0.0.

# Addendum
_The following was added after this SIP was accepted, where some clarification about Clarity specifications were necessary. The following section addresses these changes **without** changing the ratified text_

The introduction of Fast Blocks and of the new Clarity variables `tenure-height` and `stacks-block-height` in this SIP requires that the existing Clarity function `get-block-info?` is changed. This function should be removed in Clarity 3, replaced with two new functions to retrieve data for Stacks blocks and tenures:
* `(get-stacks-block-info? property-name block-height)`, where `property-name` is one of:
  * `id-header-hash`: equivalent to Clarity 2's `(get-block-info? id-header-hash block-height)`
  * `header-hash`: equivalent to Clarity 2's `(get-block-info? header-hash block-height)`
  * `time`: **new** in Clarity 3, this property returns a `uint` value matching the time field in the Stacks block header
* `(get-tenure-info? property-name block-height)`, where `property-name` is one of:
  * `burnchain-header-hash`: equivalent to Clarity 2's `(get-block-info? burnchain-header-hash block-height)`
  * `miner-address`: equivalent to Clarity 2's `(get-block-info? miner-address block-height)`
  * `time`: equivalent to Clarity 2's `(get-block-info? time block-height)`, returns the value of the burn chain block header time field of the tenure block
  * `block-reward`: equivalent to Clarity 2's `(get-block-info? time block-height)`
  * `miner-spend-total`: equivalent to Clarity 2's `(get-block-info? miner-spend-total block-height)`
  * `miner-spend-winner`: equivalent to Clarity 2's `(get-block-info? miner-spend-winner block-height)`
  * `vrf-seed`: equivalent to Clarity 2's `(get-block-info? vrf-seed block-height)`

# Introduction

## Glossary

### Existing Terminology
|Term|Definition|
|-|-|
|burnchain|The chain that a stacks blockchain follows in the PoX protocol. The prefix “burn” is a vestige of  [SIP-001][SIP-001-link]’s terminology where a fungible token would be burned on a chain to determine a miner’s chance of being elected leader / miner of the next block. After the activation of  [SIP-007][SIP-007-link], burnchain tokens are no longer burned; they are transferred to stackers. <br><br> The most popular and relevant instance of the Stacks blockchain utilizes Bitcoin as its burnchain. Where previous SIPs have defined behavior relative to a nameless burnchain, this SIP will simply assume that the burnchain in use is Bitcoin for ease of reading.|
|cryptographic sortition|A process of randomly selecting one or more entities from a set using cryptography. This is a decentralized and verifiable way to select participants for a variety of tasks, such as consensus protocols, lotteries, and auctions.|
|miner selection (aka. sortition)|Also known as “leader selection,” “miner election” or simply “sortition,” miner selection is the weighted cryptographic sortition process by which a miner candidate is selected as the next miner (leader). Details of this process are in [SIP-001][SIP-001-link] with mechanism alterations in [SIP-007][SIP-007-link].<br><br>Within this SIP, we will refer to the miner selection process as simply “the sortition.”|
|(Stacks) miner candidate|Someone that has thrown their hat in the ring to produce the next stacks block by sending some amount of Bitcoin to specific registered stackers and committing to a stacks chain tip via a block-commit transaction. The normalized quantity of Bitcoin spent in honor of a candidate is equivalent to the probability that this candidate wins. The election procedure is defined in [SIP-001][SIP-001-link] and is modified in the SIP below.|
|Stacks miner|A miner candidate who won the sortition process and can produce the next Stacks block in return for STX tokens and the transaction fees of all transactions that it includes within its mined block.
|Stacker|Someone who locks up their STX tokens in order to support the network and earn Bitcoin rewards. Read more about how stacking helps the network.<br><br>Where Stackers would once only put STX to the side and receive a Bitcoin payout every sortition, the Stackers will now be fully responsible for voting via threshold signature to accept or reject blocks proposed by miners|
|PoX anchor block|Not to be confused with the anchored block. For the duration of a reward cycle, mining any descendant forks of the anchor block requires transferring mining funds to the appropriate reward addresses. The PoX anchor is selected at most once per reward cycle (approximately 2100 Bitcoin Blocks), and determines the set of Stackers for that reward cycle|
|anchored block|Not to be confused with the PoX anchor block, this is the Stacks block that ties its creation directly to the sortition on the Bitcoin blockchain that instilled the current miner with the power to create this Stacks block and any subsequent microblocks. This block has the potential to be the only block within the current miner’s tenure. Including all transactions within the anchored block is called “batching”.<br><br>Details in [SIP-001][SIP-001-link] and [SIP-005][SIP-005-link].<br><br>***This concept does not apply post Nakamoto.***|
|microblock|A block from the current miner that follows the anchored block. The aim of microblocks is to improve transaction inclusion time on the chain (though this did not work in practice).<br><br>Details in [SIP-001][SIP-001-link] and [SIP-005][SIP-005-link].<br><br>***This concept does not apply post Nakamoto.***|
|PoX|**Proof of Transfer:** Miners commit Bitcoin to the Stacks network in order to be eligible to mine blocks. The more Bitcoin a miner commits, the higher their chances of winning the block lottery selected via cryptographic sortition. If a miner wins the sortition, they are awarded the chance to create a Stacks block (or blocks under Nakamoto) which in turn creates STX tokens as a reward. Further details are in [SIP-007][SIP-007-link].|
|coinbase|The newly-minted tokens for a block that is rewarded to the miner who mined the block.|
|MEV|**Miner Extractable Value:** Any extra amount of value that a miner can extract from the network by deviating from expected behavior such as including, excluding, or reordering transactions in a block. In our case, some Bitcoin miners will exclude all candidate transactions except that of their own STX miner so that they win the STX block.|

### Nakamoto Terminology
|Term|Definition|
|-|-|
|tenure|The sequence of blocks that a miner produces from a winning sortition.  A tenure can last for the duration of one or more burnchain blocks, and may be extended by Stackers.  As such, every tenure corresponds to exactly one cryptographic sortition with a winning miner.|
|Stacker / Signer|An entity that receives PoX payouts for stacking their STX tokens and actively participating in the Stacks protocol by signing mined blocks. The voting power that a Stacker has in signing Stacks blocks is directly proportional to the amount they have stacked.|
|stacks miner|The role of a miner changes in this SIP. Instead of being responsible for a single stacks block after winning a miner election, they are responsible for block production during a tenure validated by the stacks signers.|
|Bitcoin finality|The level of difficulty inherent to reversing a confirmed Bitcoin transaction by means of producing a Bitcoin fork with a higher total chainwork which excludes said transaction.|

## Current Design
The Stacks blockchain today produces blocks in accordance with the algorithms described in [SIP-001][SIP-001-link] and [SIP-007][SIP-007-link], and [SIP-015][SIP-015-link]. Miners compete to append a block to the blockchain through the miner selection process facilitated by a VRF backed sortition process. Miners submit a block-commit transaction to Bitcoin, which commits to the hash of the block the miner intends to append. The sortition process selects at most one block-commit in the subsequent Bitcoin block, which entitles the submitter to propagate their block and earn a block reward.

## Problem Statement
Over the last three years the Stacks community has identified several issues with the current system design:
1. **Slow Bitcoin blocks, Stacks forks, and missed sortitions are disruptive to on-chain applications.** The act of waiting to produce a new block until after a sortition elects a valid miner ties best-case Stacks block production rate to the block production rate of Bitcoin, leading to very high transaction confirmation latency.
2. **Microblocks are not effective in speeding up transaction confirmation time.** While microblocks have the potential to mitigate missed sortitions and improve transaction inclusion time, they do not work in practice because the protocol cannot ensure that microblocks will be confirmed until the next sortition happens. Additionally, new miners will often orphan recently-confirmed transactions from the old miner that were included in microblocks because there is no consensus-critical procedure that forces the next miner to build upon the latest microblock.
3. **Stacks forks are not tied to Bitcoin forks, allowing cheap reorgs** The cost to reorg the last N blocks in the Stacks blockchain is the cost to produce the next N + 1 Stacks blocks (i.e. by spending BTC), which is cheap compared to the cost of reorging the Bitcoin blockchain. This SIP describes an opportunity to tie the canonical Stacks fork to the Bitcoin blockchain such that the act of reorging Stacks chain history requires the Stacks miner to produce the fork with 70% of stacker sign-off.
4. **Stacks forks arise due to poorly-connected miners.** If a set of miners has a hard time learning the canonical Stacks chain tip when they submit block-commits, then they will collectively orphan other miners who are better-connected. This has happened in practice.
5. **Some Bitcoin miners run their own Stacks miners and deliberately exclude other Stacks miners' `block-commits` from their Bitcoin blocks.** Once the STX block reward became sufficiently large this allowed them to pay a trivial PoX payout while guaranteeing that they would win the cryptographic sortition in their Bitcoin block. This was anticipated in the original design but the regularity with which it happens today is greater than the original protocol accounted for, and thus must be addressed now.

## Proposed Solution
To address these shortcomings, this proposal calls for three fundamental changes to the way Stacks works.
- **Fast blocks:** The time taken for a user-submitted transaction to be mined within a block (and thus confirmed) will now take on the order of seconds, instead of tens of minutes. This is achieved by separating block production from cryptographic sortitions -- a winning miner may produce many blocks between two subsequent sortitions.
- **Bitcoin finality\*:** Once a transaction is confirmed, reversing it is at least as hard as reversing a Bitcoin transaction. The Stacks blockchain no longer forks on its own.
- **Bitcoin Miner MEV Resistance:** This proposal alters the sortition algorithm to ensure that Bitcoin miners do not have an advantage as Stacks miners. They must spend competitive amounts of Bitcoin currency to have a chance of earning STX.

\* In the protocol described in this SIP, a transaction on the Stacks blockchain has Bitcoin finality (that is, it is anchored to a Bitcoin block) after two tenure changes build upon the tenure that produced a block containing that transaction. The wall-clock time between a transaction being included in the Stacks blockchain and achieving Bitcoin finality is strictly less than it takes on the Bitcoin blockchain because a Stacks transaction can be broadcast and included within the duration of a single tenure but a Bitcoin transaction can only be included within a single block and must be broadcast before that block is produced.

## Design
To achieve these goals this proposal makes the following changes to the Stacks protocol:
1. **Decouple Stacks tenure changes from Bitcoin block arrivals.** In both today's system and this proposal, miners take turns appending blocks to the Stacks blockchain -- the next miner is selected by cryptographic sortition, and the miner has the duration of the Bitcoin block (its tenure) to announce a new block state. This proposal calls for allowing a miner to produce many Stacks blocks per Bitcoin block instead of one, and requiring the next miner to confirm all of them. There are no more microblocks or Bitcoin-anchored blocks; instead, there are only Nakamoto Stacks blocks. This will achieve fast block times.
2. **Require stackers to collaborate before the next block can be produced.** Stackers will need to collectively validate, store, sign, and propagate each Nakamoto Stacks block the miner produces before the next block can be produced. Stackers must do this in order to earn their PoX payouts and unlock their STX (i.e. PoX is now treated as compensation from the miner for playing this essential role). In the proposed system, a sortition only selects a new miner; it does not give the miner the power to unilaterally orphan confirmed transactions as it does today. This will ensure that miners do not produce forks and are able to confirm all prior Stacks blocks prior to selection.
3. **Use stackers to police miner behavior.** A sortition causes the Stackers to carry out a tenure change by (a) agreeing on a "last-signed" block from the current miner, and (b) agreeing to only sign blocks from the new miner which descend from this last-signed block. Thus, Stackers police miner behavior -- Stackers prevent miners from mining forks during their tenure, and ensure that they begin their tenures by building atop the canonical chain tip. The new miner cannot orphan recently-confirmed transactions from the old miner because the signers who approved the tenure change are necessarily aware of all Stacks blocks that came before it. This **further prevents miners from forking the Stacks blockchain.**
4. **Require Stacks miners to commit the indexed block hash of the first block produced by the last Stacks miner in their block-commit transactions on the Bitcoin blockchain.** This is the SHA512/256 hash of both the consensus hash of all previously-accepted Bitcoin transactions that Stacks recognizes, as well as the hash of the block itself (a block-commit today only contains the hash of the Stacks block). This will anchor the Stacks chain history to the Bitcoin chain, up to the start of the previous miner's tenure, as well as all causally-dependent Bitcoin state that Stacks has processed. This **ensures Bitcoin finality and resolves miner connectivity issues** by putting fork prevention on Stackers.
5. **Adopt a Bitcoin MEV solution which punishes block-commit censorship.** The probability a stacks miner wins a sortition should be altered such that omitting block commits of honest Stacks miners is not profitable to Bitcoin miners. The mechanics of this are outlined below.

All together these changes will achieve the goals outlined, resolving key areas of improvement for the Stacks protocol.

# Specification
## Overview
Stackers subsume an essential role in the Nakamoto system that had previously been the responsibility of miners. Before, miners both decided the contents of blocks, and decided whether or not to include them in the chain (i.e. by deciding whether or not to confirm them). In this system each actor has the following responsibilities necessary to make the system function reliably without forks:

- **Miners** decide the contents of blocks.
- **Stackers** decide whether or not the block is included in the chain.

The bulk of the complexity of the proposed changes is in separating these two concerns while ensuring that both mining and Stacking remain open-membership processes. Crucially, anyone can become a miner and anyone can become a Stacker, just as before. The most substantial changes are in getting miners and Stackers to work together in their new roles to achieve this proposal's goals.

The key idea is that Stackers are required to acknowledge and validate a miner's block before it can be appended to the chain. To do so, Stackers must first agree on the canonical chain tip, and then apply (and roll back) the block on this chain tip to determine its validity. Once Stackers agree that the block is both canonical and valid, they collectively sign it and replicate it to the rest of the Stacks peer network. Only at this point do nodes append the block to their chain histories.

This new behavior prevents forks from arising. If a miner builds a block atop a stale tip, Stackers will refuse to sign the block. If Stackers cannot agree on the canonical Stacks tip, then no block will be appended in the first place. While this behavior creates a new failure mode for Stacks -- namely, the chain can halt indefinitely if Stackers cannot agree on the chain tip -- this is mitigated by having a large and diverse body of Stackers such that enough of them are online at all times to meet quorum and incentivising them via PoX rewards to act as such.

## Stacker Signing

The means by which Stackers agree on the canonical chain tip and agree to append blocks is tied to PoX. In each reward cycle, a Stacker clinches one or more reward slots; there are at most 4,000 reward slots per reward cycle. Stackers vote to accept blocks by producing a weighted threshold signature over the block. The signature must represent a substantial fraction of the total STX locked in PoX (the threshold), and each Stacker's share of the signature (its weight) is proportional to the fraction of locked STX it owns.

The weighted threshold signature is a Schnorr signature generated through a variation of the FROST protocol [1]. Each Stacker generates a signing key pair, and the Stackers collectively generate an aggregate public key for nodes to use to verify signatures computed through a distributed signing protocol. This signing protocol allocates shares of the associated aggregate private key to Stackers proportional to the number of reward slots they clinch. No Stacker learns the aggregate private key; Stackers instead compute shares of the private key and use them to compute shares of a signature, which can be combined into a single Schnorr signature.

When a miner produces a block, Stackers execute a distributed signing protocol to collectively generate a single Schnorr signature for the block. Crucially, the signing protocol will succeed only if at least 70% of the assigned reward slots are accounted for in the aggregate signature. This means that at least 70% of the assigned reward slots (and by proxy, 70% of the stacked STX) must sign a block in order to append it to the Stacks blockchain.

This SIP calls for using the WSTS protocol with the FIRE extension [2], which admits a distributed key generation and signature generation algorithm pair whose CPU and network bandwidth complexity grows with the number of distinct Stackers. The FIRE extension enables WSTS to tolerate byzantine Stackers.

## Chain Structure
The Nakamoto Stacks chain is a linearized history of blocks without forks. Miners create blocks at a fast cadence (on the order of seconds), they send them to signers for validation, and if signers reach at least 70% quorum on the block, then the block is replicated to the rest of the peer network. The process repeats until the next cryptographic sortition chooses a different miner to produce blocks (Figure 1).

As with the system today, miners submit their candidacy to produce blocks by sending a block-commit transaction on the Bitcoin chain. This proposal calls for altering the semantics of the block-commit in one key way: the block_header_hash field is no longer the hash of a proposed Stacks block (i.e. its BlockHeaderHash), but instead is the index block hash (i.e. StacksBlockId) of the previous miner's first-ever produced block.

By altering the block-commit to expect the first block from the previous tenure, we make the system resilient to high network latency. Miner candidates will have approximately the time between Bitcoin blocks to obtain and process the previous miner’s blocks and submit a valid block-commit for the current Stacks tip.

![Figure 1][figure-1-asset]

*Figure 1: Overview of the relationship between Bitcoin blocks (and sortitions), Stacks blocks, and the inventory bitmaps exchanged by Stacks nodes. Each winning block-commit's BlockHeaderHash field no longer refers to a new Stacks block to be appended, but instead contains the index block hash of the very first Stacks block in the previous tenure. Signers force the miner to build upon the last signed Stacks block in the previous tenure by refusing to sign blocks that don’t build upon the most recently signed block. These tenure start blocks each contain a TenureChange transaction (not shown), which, among other things, identifies the number of Stacks blocks produced since the last valid start block (numbers in dark orange circles).*


The reason for this change is to both preserve Bitcoin finality and to facilitate initial block downloads without significantly altering the inventory state synchronization and block downloader state machines. Bitcoin finality is preserved because at every Bitcoin block N+1, the state of the Stacks chain as of the start of tenure N is written to Bitcoin. Even if at a future date all of the former Stackers' signing keys were compromised, they would be unable to rewrite Stacks history for tenure N without rewriting Bitcoin history back to sortition N+1.

## Chain Synchronization

This chain structure is similar enough to the current system that the inter-node synchronization procedure remains roughly the same as it is today, meaning all the lessons learned in building out inter-node synchronization still mostly apply. At a high-level, nodes would do the following when they have all of the Stacks chain state up to reward cycle R:
1. **Download and process all sortitions in reward cycle R+1.** This happens largely the same way here as it does today -- the node downloads the Bitcoin blocks, identifies the valid block-commits within them, and runs sortition on each Bitcoin block's block-commits to choose a winner. It does this on a reward-cycle by reward-cycle basis, since it must first process the PoX anchor block for the next reward cycle before it can validate the next reward cycle's block-commits.
2. **For each sortition N+1, go and fetch the start block of tenure N if sortition N+1 has a valid block-commit and the inventory bit for tenure N is 1.** This requires minimal changes to the block inventory and block downloader state-machines. Each neighbor node serves the node an inventory bitmap of all tenure start blocks they have available, which enables the node to identify neighbors that have the blocks they need. Unlike today, only the inventory bitmap of tenure start blocks is needed; there is no longer a need for a PoX anchor block bitmap nor a microblock bitmap.
3. **For each start block of tenure N, identify the number of blocks** between this start block and the last prior tenure committed to by a winning block-commit (note that this may not always be tenure N-1, per figure 1). This information is identified by a special TenureChange transaction that must be included in each tenure start block (see next section). So, the act of fetching the tenure-start blocks in step 2 is the act of obtaining these TenureChange transactions.
4. **Download and validate the continuity of each block sequence between consecutive block commits.** Now that the node knows the number of blocks between two consecutive winning block-commits, as well as the hashes of the first and last block in this sequence, the node can do this in a bounded amount of space and time. There is no risk of a malicious node serving an endless stream of well-formed but invalid blocks to a booting-up node, because the booting-up node knows exactly how many blocks to expect and knows what hashes they must have.
5. **Concurrently processes newly-downloaded blocks in reward cycle R+1** to build up its tenure of the blockchain.
6. **Repeat once the PoX anchor block for R+2 has been downloaded and processed**

This bootup procedure is amenable to activating this proposal from Stacks 2.x, as long as it happens on a reward cycle boundary.
When the node has synchronized to the latest reward cycle, it would run this algorithm to discover new tenures within the current reward cycle until it reaches the chain tip. Once it has processed all blocks as of the last sortition, it continues to keep pace with the current miner by receiving new blocks broadcasted through the peer network by Stackers once they accept the next Stacks block.

## Mining Protocol

![Figure 2][figure-2-asset]

*Figure 2: The mining run-loop. Mining has two phases; sortition and block creation. To attempt to win a sortition a miner will submit a block-commit and monitor the Bitcoin blockchain to determine if it has won. Once a miner has won the current tenure the miner will proceed to submit new blocks to the Stackers for approval, which will be incorporated into the chain if the block is successfully signed by the Stackers.*

## Block Structure
### Block Header
Amongst other things, the original Stacks header is designed to:

1. Tie a single Stacks block to a single Bitcoin block with the sortition that chose the current miner.
2. Handle appending the next Stacks blocks to a microblock.

The Nakamoto proposal changes the functionality of the Stacks Blockchain to utilize tenure changes as a  consensus critical artifact that links sortitions to the chosen miner as well as removes the support for microblocks. As such, the following is the updated block header to support the features in this proposal and remove support for those being deprecated:

The Nakamoto block header wire format  is as follows.
|Name|Description|Representation|
|-|-|-|
|version|Version number to describe how to validate the block.|1 byte|
|chain length|The total number of StacksBlock and NakamotoBlocks preceding this block in this block's history.|8 bytes, big-endian|
|burn spent|Total amount of BTC spent producing the sortition that selected the miner whose tenure produced this block.|8 bytes, big-endian|
|consensus hash|The consensus hash of the burnchain block that selected this tenure.  The consensus hash uniquely identifies this tenure, including across all Bitcoin forks.|20 bytes|
|parent block ID|The index block hash of the immediate parent of this block. This is the hash of the parent block's hash and consensus hash.|32 bytes|
|transaction Merkle root|The SHA512/256 root hash of the binary Merkle tree calculated over the sequence of transactions in this block.|32 bytes|
|state index Merkle root|The SHA512/256 root hash of the MARF once all of the contained transactions are processed.|32 bytes|
|miner signature|Recoverable ECDSA signature from the tenure's miner.|65 bytes|
|stacker signature|A Schnorr signature collectively generated by the set of Stackers over this block|65 bytes|

**Total bytes:** 263

Absent from this header is the VRF proof, because it only needs to be included once per tenure. Instead, this information will be put into the updated Nakamoto Coinbase transaction, which has a different wire format than the current Coinbase transaction.

### Transactions
#### Existing Transactions
All existing Stacks transactions, with the following exceptions will continue to be supported:
- `PoisonMicroblock`` transaction
- Current `Coinbase` transaction (Details on a replacement below)
Additionally, the anchor mode byte which once differentiated whether the transaction should be mined in an anchor block or a microblock will now be ignored.

### New Transactions
#### Tenure Change

A tenure change is an event in the existing Stacks blockchain when one miner assumes responsibility for creating new stacks blocks from another miner. Currently, the miner's tenure lasts until the next cryptographic sortition, over which time it has the option to create a single Stacks block and  stream microblocks until the next sortition ends its tenure. A change in tenure occurs when a Stacks block is discovered from a cryptographic sortition.

In this proposal, the Stackers themselves carry out a tenure change by creating a specially-crafted `TenureChange` transaction to serve as a consensus critical artifact stored on the Stacks blockchain which ties the selection of a new miner to the sortition that selected it. Miners must include this artifact as the first transaction  in the first block it produces in its new tenure. The sortition prompts Stackers to begin creating the `TenureChange` for the next miner, and the next miner's tenure begins only once the newly selected miner produces a block with the `TenureChange` transaction.

In the act of producing a `TenureChange` transaction, the Stackers also internally agree to no longer sign the current miner's blocks. Thus, the act of producing a `TenureChange` atomically transfers block-production responsibilities from one miner to another. The new miner cannot orphan recently-confirmed blocks from the old miner because the `TenureChange` transaction contains within it the most recently confirmed blockId as identified by the same Stackers that produced the `TenureChange`.  As a result, any new blocks that fail to build upon the latest Stacks block identified by the Signers will be verifiably invalid.

![Figure 3][figure-3-asset]

*Figure 3: Tenure change overview. When a new Bitcoin block arrives, Stackers begin the process of deciding the last block they will sign from miner N. When they reach quorum, they make this data available for download by miners, and wrap it in a WSTS-signed specially-crafted data payload. This information serves as a record of the tenure change, and must be incorporated in miner N+1's tenure-start block. In other words, miner N+1 cannot begin producing Stacks blocks until Stackers inform it of block X -- the block from miner N that it must build atop. Stacks-on-Bitcoin transactions are applied by miner N+1 for all Bitcoin blocks in sortitions N and earlier when its tenure begins.*

The `TenureChange` transaction encodes the following data:

|Name|Description|Representation|
|-|-|-|
|tenure consensus hash|Consensus hash of this tenure.  Corresponds to the sortition in which the miner of this block was chosen.  It may be the case that this miner's tenure gets extended across subsequent sortitions; if this happens, then this `consensus hash` value remains the same as the sortition in which the winning block-commit was mined.|20 bytes|
|previous tenure consensus hash|Consensus hash of the previous tenure.  Corresponds to the sortition of the previous winning block-commit.|20 bytes|
|burn view consensus hash|Current consensus hash on the underlying burnchain.  Corresponds to the last-seen sortition.|20 bytes|
|previous tenure end|The index block hash of the last Stacks block from the previous tenure.|32 bytes|
|previous tenure blocks|The number of blocks produced since the last sortition-linked tenure.|4 bytes, big-endian|
|cause|A flag to indicate the cause of this tenure change<br>- `0x00` indicates that a sortition occurred, and a new miner should begin producing blocks.<br>- `0x01` indicates that the current miner should continue producing blocks. The current miner’s tenure execution budget is reset upon processing this transaction.|1 byte|
|pubkey hash|The ECDSA public key hash of the current tenure.|20 bytes|
|signature|The Stacker signature.|65 bytes|
|signers|A bitmap of which Stackers signed. The ith bit refers to the ith Stacker in the order in which the principals are stacked.|4 bytes big-endian length + ceil(num_stackers /8)|

#### TenureChange-BlockFound

***A `TenureChange-BlockFound` transaction is induced by a winning sortition. This causes the new miner to start producing blocks, and stops the current miner from producing more blocks.***

When produced, the `TenureChange-BlockFound` transaction will be made available to miners for download, so that miners can include it in their first block. Miners N and N+1 will both monitor the availability of this data in order to determine when the former must stop producing blocks and the latter may begin producing blocks. Once miner N+1 receives this data, it begins its tenure by doing the following:

1. It processes any currently-unprocessed Stacks-on-Bitcoin transactions up to (but excluding) the Bitcoin block which contains its sortition (so, up to sortition N).
2. It produces its tenure-start block, which contains the `TenureChange-BlockFound` transaction as its first transaction.
3. It begins mining transactions out of the mempool to produce Stacks blocks.

If miner N cannot obtain or observe the `TenureChange-BlockFound` transaction, then it will keep producing blocks. However, Stackers will not sign them, so as far as the rest of the network is concerned, these blocks never materialized. If miner N+1 does not see the `TenureChange-BlockFound` transaction, it does not start mining; a delay in obtaining the `TenureChange-BlockFound` transaction can lead to a period of chain inactivity. This can be mitigated by the fact that the miner can learn the set of Stackers' IP addresses in advance, and can directly query them for the data.

#### TenureChange-Extend

***A `TenureChange-Extend`, which is induced by Stackers, resets the current tenure's ongoing execution budget, thereby allowing the miner to continue producing blocks.***

The time between cryptographic sortitions (and thus tenure changes) depends on the time between two consecutive Bitcoin blocks. This can be highly variable, which complicates the task of sustaining a predictable transaction confirmation latency while also preventing a malicious miner from spamming the network with too many high-resource transactions.

Today, each miner receives a tenure block budget, which places hard limits on how much CPU, RAM, and I/O their block can consume when evaluated. In this proposal, each miner begins its tenure with a fixed budget, but Stackers may opt to increase that budget through a vote. This is done to enable the miner to continue to produce blocks if the next Bitcoin block is late.

Ultimately the cadence and decision making around when to initiate, approve, and execute a TenureChange-Extend is at the discretion of the Stackers. To achieve a regular cadence, Stackers are recommended to keep track of the elapsed wall-clock time since the start of the tenure. Once the expected tenure time has passed (e.g. 10 minutes), they can vote to grant the miner an additional tenure execution budget.

Stackers can produce as many TenureChange-Extend transactions as they like to extend a miner’s tenure.  This offers a forward-compatibility path for increasing the blockchain’s throughput to take advantage of future optimizations to the chain’s performance.  Also, it allows Stackers to keep the last-winning miner online in order to tolerate empty sortitions, which may arise from misconfigured miners as well as the Bitcoin MEV miner solution (described below).

### Stacker Turnover

A miner tenure change happens every time the Signers collectively issue a `TenureChange-BlockFound` transaction in response to a sortition on the burn chain selecting a valid miner.

Additionally, there are Stacker cycles, which happen once every 2100 Bitcoin blocks (one reward cycle) in which a new set of Stackers are selected by the PoX anchor block (see [SIP-007][SIP-007-link]).

Because Stacks will no longer fork, the PoX anchor block is always known 100 Bitcoin blocks before the start of the next reward cycle. It is the last tenure-start block that precedes prepare-phase.

The PoX anchor block identifies the next Stackers. They have 100 Bitcoin blocks to prepare for signing Stacks blocks. Within this amount of time, the new Stackers would complete a WSTS DKG for signing blocks. The PoX contract will require Stackers to register their block-signing keys when they stack or delegate-stack STX, so the entire network knows enough information to validate their WSTS Schnorr signatures on blocks.

### Pox Contract
#### PoX Failure
In the event that PoX does not activate, the chain halts. If there are no Stackers, then block production cannot happen.

#### Changes to PoX
To support tenure changes, this proposal calls for a new PoX contract, `.pox-4`. The `.pox-4` contract would be altered over the current PoX contract (`.pox-3`) to meet the following requirements:
- Stackers register a WSTS signing key when they call `stack-stx` or a delegate provides the signing key with `stack-aggregation-commit-indexed`.
In addition, a `.signers` & `.signers-voting` boot contracts will be created which carry out the following tasks:
- The `.signers` contract will expose each reward cycle's full reward set, including the signing keys for each stacker, via a public function. Internally, the Stacks node will call a private function to load the next reward set into the `.signers` data space after it identifies the PoX anchor block. This is required for some future Stacks features that have been discussed.
  - `stackerdb-set-signer-slots`: will update the reward set for the following reward cycle. It will take in a list of at maximum size 4000 of signer principals & reward-slots allocated.
- The `.signers-voting` contract will expose a function to vote on the aggregate public key used by the Stackers to sign new blocks in the current tenure.
  - `vote-for-aggregate-public-key` takes the key of the signer calling the contract, the reward cycle number, and the round number. An aggregate public key candidate must reach the same consensus threshold met for signing blocks (70%) for the system to continue.

## Changes to Clarity

The protocol described in this document would have Stacks blocks occur at a much greater frequency than in the past. Many contracts rely on the `block-height` primitive to approximate a time assuming that a block takes, on average, 10 minutes. To release faster blocks while preserving the functionality of existing contracts that make this block frequency assumption, this proposal calls for a new version of Clarity, version 3, which includes the following changes.

1. A new Clarity global variable `stacks-block-height` will be introduced, which evaluates to the Stacks block height.
2. A new Clarity global variable `tenure-height` will be introduced, which evaluates to the number of tenures that have passed. When the Nakamoto block-processing starts, this will be equal to the chain length.
3. The Clarity global variable `block-height` will continue to be supported in existing Clarity 1 and Clarity 2 contracts by returning the same value as `tenure-height`. Usage of `block-height` in a Clarity 3+ contract will trigger an analysis error.

## New Block Validation Rules
In this proposal, a block is valid if and only if the following are true:
- The block is well-formed
  - It has the correct version and mainnet/testnet flag
  - **(NEW)** Its header contains the right number of Stacks blocks preceding this one.
  - **(NEW)** Its header contains the correct total Bitcoin spent in the sortition that elected the current tenure.
  - **(NEW)** Its header contains the same Bitcoin block hash as the Bitcoin block that contains its tenure's block-commit transaction
  - Its header contains the correct parent block ID of the immediate parent of this block.
  - The transaction Merkle tree root is consistent with the transactions
  - The state root hash matches the MARF tip root hash once all transactions are applied
  - **(NEW)** The block header has a valid ECDSA signature from the miner.
  - **(NEW)** The block header has a valid WSTS Schnorr signature from the set of Stackers.
- **(NEW)** All Bitcoin transactions since the last valid sortition up to (but not including) this tenure's block-commit’s Bitcoin block have been applied to the Stacks chain state
- In the case of a tenure start block:
  - **(NEW)** The first transaction is the `TenureChange` transaction.
  - **(NEW)** The first transaction after the `TenureChange` transaction is a `Coinbase`.
- All transactions either run to completion, or fail due to runtime errors. That is:
  - The transaction is well-formed
  - All transactions' senders and sponsors are able to pay the transaction fee
  - The runtime budget for the tenure is not exceeded
  - **(NEW)** The total runtime budget is equal to the runtime budget for one tenure, multiplied by the number of valid `TenureExtension` transactions mined in this tenure.
  - No expression exceeds the maximum nesting depth
  - No supertype is too large
  - **(NEW)** The `PoisonMicroblock` transaction variant is no longer supported
  - **(NEW)** The current `Coinbase` transaction variant is no longer supported

In addition to the new `TenureChange` transaction, this proposal changes coinbase transactions to include VRF proof for the current tenure. As stated above, the existing Coinbase transaction variant is no longer supported.

### Miner Signature Validation

Validating a miner's ECDSA signature is performed by:
1. Looking up the winning block-commit on the Bitcoin block that selected this tenure (or, if a TenureChange occurred due to an empty sortition, the most-recent non-empty sortition).
2. Find the associated `key-register` operation with that block-commit (see [SIP-001][SIP-001-link] block-commit and vrf-register).
3. Interpret the first 20-bytes of the `key-register` operation's memo field as a Hash160 of the miner's public key.

Note that the extension of the `key-register` operation operation makes that operation's wire format the following:

Leader VRF key registrations require at least two Bitcoin outputs. The first output is an `OP_RETURN` with the following data:

```txt
        0      2  3              23                       55                 75       80
        |------|--|---------------|-----------------------|------------------|--------|
         magic  op consensus hash    proving public key     hash160(miner pk)   memo
```

Where op = `^` and:
- `consensus_hash` is the current consensus hash for Bitcoin state of the Stacks blockchain
- `proving_public_key `is the 32-byte public key used in the miner's VRF proof
- `hash160(miner_pk)` is the 20-byte `hash_160` of the miner's ECDSA public key
- `memo` is a field for including a miner memo

The second output is the address that must be used as an input in any of the miner's block commits.

## New Stacks-on-Chain Rules
The `stack-stx` Stacks-on-Chain transaction will be extended to include the Stacker’s signing key, as follows:
```txt
        0      2  3              19           20           53
        |------|--|---------------|-----------|------------|
         magic  op  uSTX to lock    num-cycles  signing key
```

The new field, `signing key`, will contain the compressed secp256k1 ECDSA public key for the stacker.

In addition, the following two new Stacks-on-Chain transactions are added:

### Delegate-Stack-STX
In Nakamoto, it will now be possible for a stacking delegate to lock up their delegated STX via a Bitcoin transaction.  It shall contain an OP_RETURN with the following payload:

```txt
        0      2  3              19           20             21        25
        |------|--|---------------|-----------|--------------|----------|
         magic  op  uSTX to lock    num-cycles  has-pox-addr?  index
```

Where `op` = `+`, `uSTX to lock` is the number of microSTX to lock up, `num-cycles` is the number of reward cycles to lock for.  The field `has-pox-addr?` can be `0x00` or `0x01`. If it is `0x01`, then `index` is treated as a 4-byte big-endian integer, and is used as an index into the transaction outputs to identify the PoX address the delegate must use.  The value `0` refers to the first output after the OP_RETURN.  The output’s `scriptPubKey` is then decoded and converted to the PoX address.  If `index` points to a nonexistent transaction output or if `scriptPubKey` cannot be decoded into a PoX address, then this transaction is treated as invalid and has no effect.
If `has-pox-addr?` is `0x00` instead, then index is not decoded and the delegate may choose the PoX address.

#### Stack-Aggregation-Commit
In Nakamoto, it will now be possible for a stacking delegate to commit delegated STX behind a PoX address.  It shall contain an OP_RETURN with the following payload:

```txt
        0      2  3       7           11
        |------|--|-------|-----------|
         magic  op  index  reward cycle
```

Where `op` = `*`, and as with `delegate-stack-stx` above, `index` is a big-endian 4-byte integer which points to a transaction output whose `scriptPubKey` must decode to a supported PoX address.  The `reward cycle` field is a 4 byte big-endian integer which identifies the `reward cycle` for which to aggregate the stacked STX.

## Financial Incentives and Security Budgets

Miners remain incentivized to mine blocks because they earn STX by spending BTC. This dynamic is not affected by this change.

Stackers have the new-found power to sign blocks in order to append them to the Stacks chain. However, some of them could refuse to sign, and ensure that no block ever reaches the 70% signature threshold. While this can happen by accident, this is not economically rational behavior -- if they stall the chain for too long, their STX loses their value, and furthermore, they cannot re-stack or liquidate their STX or activate PoX to earn BTC.  Also, miners will stop mining if no blocks are getting confirmed, which eliminates their ongoing PoX payouts.

Stackers may refuse to sign blocks that contain transactions they do not like, for various reasons. In the case of `stack-stx`, `delegate-stx`, and `transfer-stx`, users have the option to *force* Stackers to accept the transactions by sending them as Bitcoin transactions. Then, all subsequently-mined blocks must include these transactions in order to be valid. This forces Stackers to choose between signing the block and stalling the network forever.

Stackers who do not wish to be in this position should evaluate whether or not to continue Stacking. Furthermore, Stackers may delegate their signing authority to a third party if they feel that they cannot participate directly in block signing.

That all said, the security budget of the chain is considerably larger in this proposal than before. In order to reorg the Stacks chain, someone must take control of at least 70% of the STX that are currently Stacked. If acquired at market prices, then at the time of this writing, that amounts to spending about $191 million USD. By contrast, Stacks miners today spend a few hundred USD per Bitcoin block to mine a Stacks block. Reaching the same economic resistance to reorgs provided by a signature from 70% of all stacked STX would take considerably longer.

## Future Work
### Transaction Replay on Bitcoin Forks

Bitcoin can fork. This can be a problem, because Stacks transactions can be causally dependent on the now-orphaned Bitcoin state. For example, any Stacks transaction that uses `(get-burn-block-info?)` may have a different execution outcome if evaluated after the Bitcoin block state from which it was originally mined no longer exists.

To recover from Bitcoin forks, and the loss of data that may result, this proposal calls for dropping any previously-mined but now-invalid Stacks transactions from the Stacks chain history, but re-mining the set of Stacks transactions which remain valid across the Bitcoin fork in the same order in which they were previously mined. That is, **transactions that were not causally dependent on lost Bitcoin state would remain confirmed on Stacks, in the same (relative) order in which they were previously mined.**

To do so, Stackers would first observe that a Bitcoin fork has occurred, and vote on which Bitcoin block(s) were orphaned (even if it means sending the orphaned data to each other, since not all Stacks nodes may have seen it). Once Stackers agree on the sequence of orphaned Bitcoin blocks, they identify which Stacks blocks would be affected. From there, they each replay the affected Stacks blocks' transactions in the same order, and in doing so, identify which transactions are now invalid and which ones remain valid. Once they have this subsequence of still-valid transactions, they advertise it to miners, and only sign off on Stacks blocks that include a prefix of this subsequence that has not yet been re-mined (ignoring `Coinbase`, `TenureChange`, and `TenureExtension` transactions). This way, the Stacks miners are compelled to replay the still-valid Stacks transactions in their same relative order, thereby meeting this guarantee.

Importantly, this transaction replay feature is directed exclusively by Stacker and miner policy logic. It is not consensus-critical, and in fact cannot be because not all miners or Stackers may have even seen the orphaned Bitcoin state (which precludes them from independently identifying replay transactions; they must instead work together to do so off-chain). Therefore, this feature's implementation can be deferred until after this SIP is ratified.

# Backwards Compatibility

This proposal is a breaking change. However, all smart contracts published prior to this proposal's activation will be usable after this proposal activates.

# Related Work

This new system bears superficial similarity to proof-of-stake (PoS) systems. However, there are several crucial differences that place the Nakamoto Stacks system in a separate category of blockchains from PoS:

- Anyone can produce blocks in Stacks by spending BTC. How they get their BTC is not important; all that matters is that they spend it. This is not true in PoS systems -- users must stake existing tokens to have a say in block production, which means that they must acquire them from existing stakers. This de facto means that producing blocks in PoS systems requires the permission of at least one staker -- they have to sell you some tokens. However, because BTC is produced via proof-of-work, no such permission is needed to produce Stacks blocks.
- Stackers do not earn the native STX tokens for signing off on blocks. Instead, they receive PoX payouts and their stacked STX tokens eventually unlock. By contrast, stakers earn the native token by signing off on blocks.
- Because anyone can mine STX, anyone can become a Stacker. There is no way for existing Stackers to "close ranks" and prevent someone from joining -- if Stackers refuse to sign a block with a stack-stx contract call, then a would-be Stacker would issue a stack-stx call via a Stacks-on-Bitcoin transaction. This forces all subsequent miners to produce blocks which materialize this stack-stx call, thereby forcing Stackers to choose between admitting the new Stacker or halting the chain forever. By contrast, there is no penalty for "closing ranks" on new stakers in PoS systems.

# Activation

## Determinations Prior to SIP Activation

Some aspects of this proposal are best decided after a reference implementation approaches code completion. The following will be solidified at a later date but will strictly remain within the bounds described below.

### Block Reward Distribution and MEV

The Nakamoto system will use a variation of the Assumed Total Commitment with Carryforward (ATC-C) MEV mitigation strategy described in [this document][MEV-analysis-link] to allocate block rewards to miners. The probability a miner will win the sortition and be granted the current tenure will be based on a function that accounts for the total block commit spend on the blocks leading up to the current sortition.

An example ATC solution may rely on the max of the median and current total block commit spend as the denominator and the median commit of the last several blocks as the numerator for calculating the probability that a given miner wins a sortition.

Any ATC solution included in Nakamoto will leave the option for a sortition to have no valid winner. The TenureChange-Extend transaction mitigates the majority of adverse effects caused by a missed sortition.

### Timing of Release from 2.5 to 3.0

Activating Nakamoto will include two epochs:

- **Epoch 2.5:** Pox-4 contract is booted up but no Nakamoto consensus rules take effect.
- **Epoch 3:** Nakamoto consensus rules take effect.

There will be at least one reward cycle between the initiation of Epoch 2.5 and Epoch 3, but the exact duration will need to be determined prior to activation.

### Updated Block Limits

Block limits in the initial system described in [SIP-001][SIP-001-link] were designed conservatively such that a low compute threshold was required to run a functional node. These cost limits have been updated twice before, as improvements have been made to the stacks-node. This SIP calls for another block limit update to reflect several changes from both this SIP and improvements to reference implementation of the Clarity virtual machine, and to accomodate the new block mining mechanism in Nakamoto, in which a miner is no longer racing against the next Bitcoin block.

1. Contract calls are less computationally expensive due to practical optimizations in the Clarity virtual machine.
2. Mining a Stacks block is no longer a race against the next Bitcoin block.
3. The block limit is now spread over multiple Stacks blocks within a miner's tenure.

A new block limit will be set based on benchmarks of the reference implementation such that a tenure can have its entirety executed over the course of some period less than 10 minutes on reasonable hardware.

### Signer Liveness Enforcement

Once epoch 3.0 goes live, Stackers will be required to actively participate in the system by signing and rejecting valid blocks from the currently tenured miner. This will be enforced by the withholding of PoX payouts from inactive Stackers during the periods in which they are inactive. In this way Stackers cannot benefit from the system without participating.

The exact liveness thresholds required of stackers before PoX payouts cease will be informed by practical observations of a test version system with a best-effort from participants. The expectation will be that if a Stacker is not live for some n of the last m blocks the Stacker's PoX payouts will be disabled by removing the Stacker addresses from the pool of valid PoX targets. Their BTC will instead be burnt.  The exact number will be chosen such that it enforces signer activeness while not punishing a signer for restart. The current expectation is that this will be 5 Bitcoin blocks. Should a signer come back online, then after being online for 5 consecutive Bitcoin blocks, they will again become eligible to receive PoX payouts.

## Process of Activation

There are different rules for activating this SIP based on whether or not the user has stacked their STX, and how they have done so.

### For Stackers

In order for this SIP to activate, the following criteria must be met by the set of Stacked STX:
- At least double the amount of Stacked STX locked by the largest Stacker in the cycle preceding the vote must vote at all to activate this SIP.
- Of the Stacked STX that vote, at least 80% of them must vote "yes."

The act of not voting is the act of siding with the outcome, whatever it may be. We believe that these thresholds are sufficient to demonstrate interest from Stackers -- Stacks users who have a long-term interest in the Stacks blockchain's successful operation -- in performing this upgrade.

### How To Vote
If a user is Stacking, then their STX can be used to vote in one of two ways, depending on whether or not they are solo-stacking or stacking through a delegate.

The user must be Stacking in any cycle up to and including a cycle to be determined that is no later than cycle 81. Their vote contribution will be the number of STX they have locked.

#### Solo Stacking

The user must send a minimal amount of BTC from their PoX reward address to one of the following Bitcoin addresses:

- For **"yes"**, the address is `11111111111111X6zHB1bPW6NJxw6`. This is the base58check encoding of the hash in the Bitcoin script `OP_DUP` `OP_HASH160` `000000000000000000000000007965732d332e30` `OP_EQUALVERIFY` `OP_CHECKSIG`. The value `000000000000000000000000007965732d332e30` encodes "yes-3.0" in ASCII, with 0-padding.

For **"no"**, the address is `1111111111111117Crbcbt8W5dSU7`. This is the base58check encoding of the hash in the Bitcoin script OP_DUP OP_HASH160 `00000000000000000000000000006e6f2d332e30` `OP_EQUALVERIFY` `OP_CHECKSIG`. The value `00000000000000000000000000006e6f2d332e30` encodes "no-3.0" in ASCII, with 0-padding.

From there, the vote tabulation software will track the Bitcoin transaction back to the PoX address in the .pox-3 contract that sent it, and identify the quantity of STX it represents. The STX will count towards a "yes" or "no" based on the Bitcoin address to which the PoX address sends.

If the PoX address holder votes for both "yes" and "no" by the end of the vote, the vote will be discarded.

Note that this voting procedure does not apply to Stacking pool operators. Stacking pool operator votes will not be considered.

#### Pooled Stacking

If the user is stacking in a pool, then they must send a minimal amount of STX from their Stacking address to one of the following Stacks addresses to commit their STX to a vote:

- For **"yes"**, the address is `SP00000000000003SCNSJTCSE62ZF4MSE`. This is the c32check-encoded Bitcoin address for "yes" (`11111111111111X6zHB1bPW6NJxw6`) above.
- For **"no"**, the address is `SP00000000000000DSQJTCSE63RMXHDP`. This is the c32check-encoded Bitcoin address for "no" (`1111111111111117Crbcbt8W5dSU7`) above.

From there, the vote tabulation software will track the STX back to the sender, and verify that the sender also has STX stacked in a pool. The Stacked STX will be tabulated as a "yes" or "no" depending on which of the above two addresses receive a minimal amount of STX.

If the Stacks address holder votes for both "yes" and "no" by the end of the vote period, the vote will be discarded.

## For Non-Stackers

Users with liquid STX can vote on proposals using the [Ecosystem DAO](https://stx.eco).
Liquid STX is the users balance, less any STX they have locked in PoX stacking protocol,
at the block height at which the voting started (preventing the same STX from being transferred between accounts and used to effectively double vote).
This is referred to generally as "snapshot" voting.

For SIP 21 Nakamoto Upgrade to pass 66% of all liquid STX committed by voting
must in favour of the proposal.

### For Miners
There is only one criterion for miners to activate this SIP: they must mine the Stacks blockchain up to and past the end of the voting period. In all reward cycles between cycle 75 and the end of the voting period, PoX must activate.

### Examples

#### Voting "yes" as a solo Stacker

Suppose Alice has stacked 100,000 STX to `1LP3pniXxjSMqyLmrKHpdmoYfsDvwMMSxJ` during at least one of the voting period's reward cycles. To vote, she sends 5500 satoshis for **yes** to `11111111111111X6zHB1bPW6NJxw6`. Then, her 100,000 STX are tabulated as "yes".

#### Voting "no" as a pool Stacker

Suppose Bob has Stacked 1,000 STX in a Stacking pool and wants to vote "no", and suppose it remains locked in PoX during at least one reward cycle in the voting period. Suppose his Stacks address is `SP2REA2WBSD3XMVMYS48NJKS3WB22JTQNB101XRRZ`. To vote, he sends 1 uSTX from `SP2REA2WBSD3XMVMYS48NJKS3WB22JTQNB101XRRZ` for no to `SP00000000000000DSQJTCSE63RMXHDP`. Then, his 1,000 STX are tabulated as "no."

# Reference Implementation

The reference implementation can be found at https://github.com/stacks-network/stacks-core.

## Stacker Responsibilities

The act of Stacking requires the Stacker to be online 24/7 to sign blocks. To facilitate this, the implementation comes with a Stacker signer daemon, which runs as an event observer to the Stacks node.

The Stacker signer daemon receives notifications from the Stacks node when a new block arrives. On receipt of the block, the daemon instigates a WSTS signing round with other signer daemons to generate an aggregate Schnorr signature.

The Stacker signer daemons communicate with one another through a network overlay within the Stacks peer-to-peer network called a StackerDB. The StackerDB system allows nodes to replicate an array of fixed-sized chunks of arbitrary data, which must be signed by principals identified by a smart contract.

## StackerDB

StackerDB is a feature that will ship prior to this SIP's activation. It allows users to store data within the Stacks peer-to-peer network by means of a specially-crafted smart contract, and a connected overlay network. The smart contract describes the parameters of the data (e.g. who can write to it; how much data can be stored; and so on); the data itself is stored off-chain. A StackerDB-aware node maintains connections to other StackerDB-aware nodes who replicate the same StackerDBs as itself.

The StackerDB data schema is an array of fixed-sized chunks. Each chunk has a slot index, a monotonically-increasing version, and a signer (e.g. a Stacks address). A user writes a chunk by POSTing new chunk data for the slot, as well as a new version number and a signature over both the data and the version. If the chunk is newer than the chunk already stored (as identified by version number), then the node stores the chunk and replicates it to other nodes subscribed to the same StackerDB instance.

Stacks nodes announce which StackerDB replicas they subscribe to when they handshake with one another. If both the handshaker and its peer support the StackerDB protocol, they exchange the list of replicas that they maintain. In doing so, StackerDB-aware nodes eventually learn about all reachable nodes' StackerDB replicas as they walk the peer graph.

StackerDB-aware nodes set up overlay networks on top of the Stacks peer-to-peer network to replicate StackerDB chunks. Nodes that replicate a particular StackerDB will periodically exchange version vectors for the list of chunks in the replica. If one node discovers that another node has a newer version of the chunk, it will download it and forward it to other StackerDB-aware nodes in the overlay that also need it. In doing so, every StackerDB-aware node in the overlay eventually receives an up-to-date replica of the StackerDB chunks.

The Stacks node re-evaluates the StackerDB's controlling smart contract each time it processes a new Bitcoin block in order to determine who is allowed to write to which chunks. At each such reconfiguration, a slot's data whose signer changes will be evicted from the replica. Data for slots whose signers do not change is preserved.

## DKG and Signing Rounds

The WSTS system requires all signing parties to exchange cryptographic data with all other signing parties. The reference implementation's Stacker signer daemon does this via a StackerDB instance tied to the `.pox-4` smart contract. The `.pox-4` smart contract exposes the signing keys for each Stacker, and the StackerDB contract accesses this information to implement the StackerDB trait, thereby creating a StackerDB into which only Stackers can write chunks of data.

The StackerDB used by Stackers will be used to carry out distributed key generation, to run signing rounds, and to publish `TenureChange` and `TenureExtend` transactions.

## Stacker Transaction Inclusion

Some transactions, like `TenureChange`, are generated by Stackers for inclusion in the blockchain. These transactions will have a 0-STX fee, so that Stackers are not in a position of needing to pay STX to do their jobs. They compel miners to include them in their blocks by keeping track of any such pending transactions in their StackerDB, and refusing to sign blocks unless the miner includes them.

The miner obtains these transactions by querying the StackerDB instance used by Stackers. Miners' nodes may subscribe to the StackerDB instance in order to maintain an up-to-date replica.

## Future Work: Guaranteed Transaction Replay

In the event of a Bitcoin fork, Stackers would maintain the list of transactions which miners must replay to in their StackerDB as well. The miner would read this information from the Stackers' StackerDB in order to re-mine them into new Stacks blocks after the Bitcoin fork resolves.

## Signer Delegation

Users who Stack may not want to run a 24/7 signing daemon. If not, then they can simply report some other signer's public key when calling `stack-stx` or `delegate-stack-stx`. Then, this other entity would run the signing daemon on their behalf.

While this does induce some consolidation pressure, we believe it is the least-bad option. Some users will inevitably want to outsource the signing responsibility to a third party. However, trying to prevent this programmatically would only encourage users to find work-arounds that are even more risky. For example, requiring users to sign with the same key that owns their STX would simply encourage them to trust a 3rd party to both hold and stack their STX on their behalf, which is worse than just outsourcing the signing responsibility.

# References

- [1] Komlo C, Goldberg I (2020) FROST: Flexible Round-Optimized Schnorr Threshold Signatures. Available at https://eprint.iacr.org/2020/852.pdf and [locally][local-FROST-paper-copy] [Verified 2 February 2024]
- [2] Yandle J (2023) Weighted Schnorr Threshold Signatures. Available at https://trust-machines.github.io/wsts/wsts.pdf and [locally][local-WSTS-paper-copy] [Verified 2 February 2024]

[SIP-001-link]: https://github.com/stacksgov/sips/blob/main/sips/sip-001/sip-001-burn-election.md
[SIP-005-link]: https://github.com/stacksgov/sips/blob/main/sips/sip-005/sip-005-blocks-and-transactions.md
[SIP-007-link]: https://github.com/stacksgov/sips/blob/main/sips/sip-007/sip-007-stacking-consensus.md
[SIP-015-link]: https://github.com/stacksgov/sips/blob/main/sips/sip-015/sip-015-network-upgrade.md
[MEV-analysis-link]: ./MEV-Report.pdf

[local-WSTS-paper-copy]: ./Weighted-Schnorr-Threshold-Signatures.pdf
[local-FROST-paper-copy]: ./FROST-Flexible-Round-Optimized-Schnorr-Threshold-Signatures.pdf

[figure-1-asset]: ./sortition-stacksblock-relationship.png
[figure-2-asset]: ./miner-protocol.svg
[figure-3-asset]: ./tenure-change-overview.png
