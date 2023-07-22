# Preamble

SIP Number: XX

Title: Collaborative Mining and Stacker Availability Signing

Authors:  Aaron Blankstean <aaron@hiro.so>, Brice Dobry <brice@hiro.so>, Jude
Nelson <jude@stacks.org>

Considerations: Technical, Governance, Economics

Type: Consensus

License: BSD 2-Clause

Sign-Off: 

Discussions-To: https://github.com/stacksgov/sips/pull/148 

Supersedes: SIP-001, SIP-007, SIP-021

# Abstract

This SIP describes a new consensus protocol for the Stacks blockchain,
superseding the competative mining protocol described in SIP-001 and SIP-007.
In this proposed system, both miners and PoX stackers _cooperate_ through Byzantine fault-tolerant
agreement to produce a linearized stream of confirmed transactions, in which the
materialized view of the chainstate is periodically recorded to the Bitcoin
blockchain.  This new arrangement allows for a significantly lower transaction
confirmation latency time (on the order of seconds instead of hours),
while also increasing the security budget of the chain from 51% of the miners'
Bitcoin spends to _at least_ the sum of 67% of the miners' Bitcoin spends plus 67% of the
total STX stacked.  The chain's security budget reaches 51% of Bitcoin's
mining power through periodic chainstate snapshots written to the Bitcoin chain
by block producers and stackers, which are confirmed by the Bitcoin network as
regular transactions.  Once a Stacks chainstate snapshot is confirmed by the Bitcoin
network, no subsequent Stacks fork can revert it -- any Stacks chain
reorganization requires a Bitcoin chain reorganization.

# Introduction

The Stacks network has been in continuous operation since January 2021.  Per
SIP-001, block production in Stacks executes through a single-leader process:
in each Bitcoin block, several miners compete to win the right to append a block to the Stacks
blockchain through a cryptographic sortition process.  While this has served to
keep the network running, it has several limitations:

* High transaction latency: Transactions are confirmed at the same rate as
  the underlying Bitcoin transaction -- that is, on the order of hours.  Even
then, there is no true finality, since like Bitcoin, Stacks employs Nakamoto
consensus to achieve only a probabilistic agreement on whether or not a
transaction was accepted by the network.

* Independent security budget:  Because the Stacks blockchain can fork -- a consequence of its
  single-leader block production rules -- the cost to remove a transaction from
the canonical fork is proportional to the amount of Bitcoin that miners have
spent building atop it.  The amount of Bitcoin is, in turn, proportional to the
value of the STX coinbase, which is worth substantially less than the Bitcoin
coinbase.  Therefore, the cost to reorganize the Stacks blockchain to orphan a
given transaction is substantially lower than the cost to do the same for a
Bitcoin transaction (but in no case can a malicious party _hide_ their behavior
without attacking Bitcoin, which mitigates the damage they can cause in practice).

* Miner-extractable value (MEV):  Because Bitcoin miners may also be Stacks miners, a
  Bitcoin miner can guarantee that they win a Stacks block by excluding other
miners' Bitcoin transactions from the Bitcoin blocks they produce.  This has
already happened with some F2Pool blocks, for example.  Doing so is more
profitable than mining honestly, because the Bitcoin miner can realize an
arbitrarily high profit margin by tailoring their
block-commit transaction to pay almost zero BTC to PoX recipients and omit a
transaction fee.

* Unequitable mining rewards:  Because the Stacks blockchain can fork, a
  majoritarian mining coalition can deliberately exclude the minority's blocks
from the canonical fork.  More banally, if a majority of Stacks miners (by
Bitcoin spend) are not well-connected to the minority, they can accidentally
exclude the minority's blocks simply because they do not arrive on their nodes
in time to build atop them.  At least one of these phenomena has been witnessed
in practice.  In either case, the minority does not receive any reward for
their work.

Each of these problems arises from the fact that Stacks is a single-leader
blockchain.  In order to tolerate the failure of single leader to replicate a block 
or even produce a valid block, the Stacks chain must support blockchain forks in
order to permit other miners to repair the canonical fork and "work around"
missing or invalid block data.  This forking behavior combined with
single-leader block production creates an independent security budget, and
permits Bitcoin miners to extract value from Stacks by preventing other Stacks
miners from competing.  The forking behavior prevents equitable mining rewards
from being materialized for honest but minoritarian miners: the system _cannot_
reward minoritarian miners who produce non-canonical blocks lest it create incentives
to selfish-mine or deliberately mine orphans.  Without extra cooperation between miners, the
current system forces Stacks transaction confirmation latency to be no lower than
the underlying burnchain (Bitcoin) -- the best-effort nature of single-leader
mining precludes requiring other miners to agree on the same chain tip before
mining.

This SIP proposes a substantially different consensus protocol whereby miners and PoX
stackers _cooperate_ to produce a linearized transaction history.  In the
proposed system, block production is a three-step procedure, whereby block
_production_, block _acceptance_, and block _finalization_ are treated
separately:

1. Miners coordinate to create and propose new blocks from pending transactions.
   A block is proposed if at least 67% of miners agree on the same block, as
measured by the Bitcoin spent by the miners to produce it.  Once a block is
proposed, it is transmitted to all PoX stackers in the current reward cycle.

2. Stackers not only validate each proposed block, but also verify that it builds
   atop the current Stacks chain tip and faithfully applies any on-Bitcoin
Stacks transactions.  If at least 67% of Stackers agree to accept a proposed
block, then it is added to the Stacks blockchain and replicated to all other
Stacks nodes.  Subsequent blocks must be built atop it -- Stacks forks are no
longer permitted.

3. Every so often, Stackers and miners must collectively produce a Bitcoin
   transaction that commits to the state of the Stacks chain in order to continue
to receive block rewards.  Any Stacks block must descend from the chain state this snapshot represents.
This _finalizes_ all blocks represented by the snapshot, such that retroactively
changing Stacks chain history will be as expensive as retroactivelly changing Bitcoin
history, regardless of the future valuation and distribution of STX and regardless of the
intentions of future miners and stackers.

With these principal changes, Stacks block production is no longer inherently tied to
Bitcoin block production.  As described in more detail below, miners no longer commit
to each block they produce via Bitcoin transactions,
but instead submit Bitcoin transactions only to join a _producer set_ of miners
and to periodically snapshot the chain state.
Block production now happens via a dedicated peer network maintained by the producer set
and stackers.

In this proposed system, transaction confirmation latency now depends on
how quickly a Stacks block that contains it
can be produced and accepted.  This takes on the order of seconds, instead of hours.
In addition, the security budget of a transaction confirmed this way is substantially higher
than it is today -- due to BFT agreement in steps 1 and 2, the cost to remove 
an already-confirmed but not-yet-finalized transaction is equal to the sum of 67% of the
miners' Bitcoin spends since the last snapshot, plus 67% of the worth of the stackers'
locked STX.  At the time of this writing (1 STX = $0.63 USD, 1 BTC = $29,747 USD,
Stacks reward cycle 63), this represents a security budget increase from $234.18 USD per block
($4,680.36 before a snapshot is expected to occur) to $213,908,185.70 -- five orders of magnitude higher!  The
requirement for miners and stackers to periodically snapshot the Stacks chain
state further increases this budget to that of Bitcoin's security budget,
regardless of how cheap or easy it may be in the future to monopolize subsequent
Stacks block production.

Requiring miners and Stackers to cooperate to produce blocks mitigates the
impact of Bitcoin miner MEV and allows for equitable coinbase reward distribution.
Would-be Stacks miners have a reasonably long
window of time (measured by Bitcoin blocks) to join a producer set, meaning that Bitcoin
MEV miner would need to mine _every_ Bitcoin block in this window to monopolize
Stacks mining.  The requirement that miners collectively produce a block
weighted by Bitcoin spends enables the Stacks blockchain consensus rules to
distribute the STX coinbase _pro-rata_ to each miner in the producer set, and
distribute the transaction fees _pro-rata_ to each miner who actively worked to
approve the block.  This ensures that honest minoritarian miners
receive STX for their BTC while retaining an incentive for miners to pack as
many high-value transactions into a block as possible.

# Specification

## Producer Set Terms and Block Production

Rather than requiring competition among miners to mine blocks, each block is mined by a
single, globally visible, producer set. A _producer set_ collaborates to mine
blocks during fixed length _terms_. For a given term, every Stacks block is
assembled and signed by a Byzantine fault-tolerant majority of that term's producer set.

The producer set is a collection of weighted public keys. Each member of the
producer set is associated with a public key and is assigned a weight according
to the proportion of Bitcoin committed during the term's selection (see
[Producer Set Selection](#producer-set-selection)).

For a block to be validated, it must be signed by over 67% of the producer set
by weight. The signature scheme uses a weighted extension of FROST threshold
signatures, described in [Signature Generation](#signature-generation).  A valid
signature can be created if and only if this 67% threshold is achieved.

### Block Production during a Term

Each producer set term is 10 Bitcoin blocks in length. Stacks cost limits are
applied to the term as a whole rather than individual Stacks blocks, and each
term's cost limit is 10x the Stacks 2.4 single block limit (or the single block
limit after improvements to the Clarity runtime and improved benchmark results).

During a term, there is no distinction between Stacks blocks and microblocks:
there are only blocks. Terms are not limited to 10 Stacks blocks (i.e., there may be
more than one Stacks block produced during a given Bitcoin block), but rather
the only limit applied to the term is the overall cost limit (which may be
increased through application of a VDF to accomodate an unusually long term
length; see [Extension: Overdue Term](#overdue-terms)).

The first block of a term always builds off the last block stackers accepted
from the prior term, which itself is a descendant of the last on-Bitcoin snapshot.
Producers may not choose to reorganize a prior term, nor may they reorganize any
stacker-accepted blocks.  But, any unannounced or not-yet-accepted
blocks from the prior term are dropped.

### Producer Set Collaboration

While this proposal specifies how blocks mined by a producer set are validated,
it leaves open the question of exactly how producer sets collaborate to assemble
blocks. This is intentional: the validation of blocks is consensus-critical, but
exactly how a valid block gets mined is not. However, the Stacks blockchain
codebase will need to supply a default method for this assembly.  There are,
however, two requirements that producer set must adhere to:

* A proposed block must be signed by at least 67% of the producer set, measured
  by BTC spend.

* There exists at most one proposed block at a given height with respect to a
  given Bitcoin fork.

If either requirement is not met, then stackers halt block acceptance for the
remainder of the term.

This SIP proposes that producer sets undergo a leader election once the producer
set is chosen (or the current leader becomes inactive). Leader elections proceed
in rounds until a leader is chosen by 67% of the weighted producer set. At the
start of a round, each node in the producer set waits a random amount of time.
If it does not receive a request for a leadership vote before that timeout, it
puts itself forward for leadership, and submits a vote request to every other
participant. If a node receives a vote request and it has not already voted in
that round or submitted its own leadership request, it signs the vote request.

The leader is responsible for assembling a block and sending it to each producer
set participant to collect the threshold signatures. There are many possible
extensions and variations to this protocol. For example, each participant could
have some heuristic about the best transaction ordering for a block, and if the
proposal deviates too much, the node could opt not to sign, or try to trigger a
leadership change.

## Producer Set Selection

The producer set selection for term _N_ occurs during term _N-2_. Similar to the
leader block commitments used in the current miner selection process, as defined
in
[SIP-001](https://github.com/stacksgov/sips/blob/main/sips/sip-001/sip-001-burn-election.md)
and amended in
[SIP-007](https://github.com/stacksgov/sips/blob/main/sips/sip-007/sip-007-stacking-consensus.md),
would-be producers issue a Bitcoin transaction known as a producer set
enrollment.

### Producer Set Enrollments

As it is today, this SIP requires block producers to register a VRF public key
on the Bitcoin chain prior to enrolling in a producer set.  The process and
wire-formats are the same as in SIP-001; see 
[VRF key registration](https://github.com/stacksgov/sips/blob/main/sips/sip-001/sip-001-burn-election.md#leader-vrf-key-registrations).

Producer set enrollments have the same constraints on the Bitcoin transaction's
inputs as PoX leader block commitments. Specifically, the first input of this
Bitcoin operation must originate from the same address as the second output of
the VRF public key registration transaction.
The first output of a producer set enrollment must be an `OP_RETURN` with the
following data:

```
            0      2  3      7     11   13            46      50       52       80
            |------|--|------|-----|-----|------------|-------|--------|--------|
             magic  op tenure  key   key     signing   snapshot snapshot padding
                       number  block txoff   pubkey    block    txoff
```

Where `op = @` and:

- `tenure_number` is the target tenure for this producer, which should be `N`
- `key_block` is the Bitcoin block height of this producer's VRF key registration
- `key_txoff` is the transaction index for this producer's VRF key registration
- `signing_pubkey` is the compressed secp256k1 public key used by this producer
  to sign FROST signature-generation messages to be consumed by other
producers.
- `snapshot_block` is the Bitcoin block height of the last valid snapshot
  transaction this producer has seen up to tenure `N-2`.
- `snapshot_txoff` is the transaction index of this snapshot transaction.

The subsequent output(s) in this transaction are the PoX outputs:

1. If the producer set enrollment is in a reward phase, then outputs 1 through
   20 must go to the chosen PoX recipients.
   - Recipients are chosen as described in "Stacking Consensus Algorithm" in
     SIP-007, using the final block announcement of term N-3 as the source:
     addresses are chosen without replacement, by using the sortition hash,
     mixed with the burn header hash of the final block announcement from term
     N-3 as the seed for the ChaCha12 pseudorandom function to select 20
     addresses. Since a producer set term lasts 10 Bitcoin blocks, there are 20
     PoX recipients, 2 per Bitcoin block, to maintain the same number of reward
     slots and payment frequency.
   - The order of these outputs does not matter.
   - Each of these outputs must receive the same amount of BTC.
   - If the number of remaining addresses in the reward set, N, is less than 20,
     then the producer set enrollment must burn BTC by including (20-N) burn
     outputs
2. Otherwise, the second output must be a burn address (i.e. the enrollment
   falls into a prepare phase).

During a reward cycle, this enrollment transaction will include a somewhat large
number of outputs: one `OP_RETURN`, 20 stacker rewards, and one change
address, totaling 22 outputs. While this might seem like a substantial
transaction, it effectively replaces ten separate transactions under the SIP-007
leader block commit scheme, each of which would have four outputs (one
`OP_RETURN`, two stacker rewards, and one change address). Furthermore, the
enrollment window's duration of ten blocks potentially allows would-be producers
to take advantage of lower transaction fees during one of those blocks. Despite
the higher fee for this larger transaction, the cost can be spread out or
amortized across the ten blocks of the set, resulting in a lower overall cost
compared to the previous system.

### Enrollment Censorship Resistance

The producer set enrollments for set _N_ can be included in any of the 10
Bitcoin blocks in producer set _N-2_. This makes it extremely difficult for a
Bitcoin miner to censor these transactions, since to do so, they would need to
control all 10 Bitcoin blocks in that term.

### Selecting Producers

Would-be producers with valid producer set enrollments in term _N-2_ are
eligible to be included in the producer set for term _N_. The total number of
producers in a set needs to be limited to prevent coinbase payouts from
including too many accounts, as this could slow down event processing and even
open a DoS vector. This cap will also prevent the block-signing process from
becoming too CPU- and bandwidth-intensive. To this end, the total amount of BTC spent in the
outputs described in "Producer Set Enrollments" is used to select the producer
set. Any would-be producer that spends at least 1% of the total will be included
in the set. This naturally limits the total number of producers to 100.

## Producer Rewards

During a term, producers in the set are eligible to receive a portion of the
coinbase rewards and transaction fees for blocks they produce. Since a term is
defined as 10 Bitcoin blocks, the coinbase reward is equal to 10 times the
coinbase as defined in **_<which SIP defines this?>_**. This amount is
distributed to all producers in the set proportionally, based on the percentage
of the total BTC spent in the producer set enrollments. All producers receive
their portion of the coinbase, regardless of whether or not they signed the
blocks produced by the set. The coinbase transaction should be the first
transaction in a term.

The producer set is then incentivized to continue producing blocks throughout
the term by the transaction fees. Transaction fees are paid only to producer set
participants who signed the blocks produced. For each block, _B_, the total BTC
spent by all signers block _B_ is computed, then the transaction fees for all
transactions in block _B_ are distributed proportionally based on BTC spent by
each signer in their producer set enrollment.

## Blockchain Structure 

Because Stacks block production is no longer tied to Bitcoin block production,
producers and stackers must explicitly determine the earliest Stacks block
at which newly-discovered Bitcoin state can be queried.  To achieve this,
producers propose a special-purpose _checkpoint transaction_ for each new Bitcoin
block they see that does not already have one.

A checkpoint transaction serves to identify the new Bitcoin block header and serve as a 
synchronization hint for Stacks nodes.  When they see a block with a checkpoint transaction,
Stacks nodes pause Stacks block-processing in order to ensure that they have
first processed the identified Bitcoin block.  Once they have done so, they
can proceed to process this block and its descendants.

Checkpoint transactions are necessary to ensure that Stacks transactions which
are causally-dependent on Bitcoin state are only processed once the referenced
Bitcoin block has been processed.  Checkpoint transactions also ensure that bootstrapping
Stacks nodes validate Bitcoin-dependent Stacks transactions only once they have
obtained the relevant Bitcoin state to do so.  As such, there must exist one
checkpoint transaction for each Bitcoin block, and they must be in the same
order in the Stacks transaction history as the Bitcoin blocks they reference.

The Stacks blockchain is thus composed of long swaths of regular transactions
punctuated by checkpoint transactions.  If a block contains a checkpoint
transaction, it must be the first transaction in that block.  A block containing
a checkpoint transaction is a _checkpoint block_.

Only the producer set can create a checkpoint transaction.  This is enforced via
the consensus rules, instead of via a transaction authorization structure.  The contents
of the transaction authorization structure for a checkpoint transaction are
undefined -- it can contain any valid structure (i.e. the producer who proposed
the block could simply sign it).

### Block Structure

This SIP proposes that the structure of a Stacks block now contains the following:

* A header:

   * A version byte

   * A 2-byte sequence number

   * The SHA512/256 hash of its parent block

   * The SHA512/256 hash of a Merkle tree containing the block's transactions

   * A FROST Schnorr signature from the current producer set

   * A bitmap of which producers contributed to the signature (used for
     determining transaction fee distribution)

* A body:

   * A 4-byte big-endian number, equal to the number of transactions the block
     contains

   * The sequence of encoded Stacks transactions

### Checkpoint Transaction Structure

The checkpoint transaction contains information that today is found in anchored
Stacks blocks (see SIP-005).  At a high level, the payload for a checkpoint transaction contains:

* The total number of Stacks blocks so far

* The total amount of BTC spent to produce this chain as of the parent of this
  Bitcoin block

* A VRF proof

* The Stacks chainstate root hash as of the end of processing this block and all
  of its ancestors.

* The Bitcoin block header

* The consensus hash of the Bitcoin block

* VDF calibration data (see [Extension: Overdue Term](#extension-overdue-term))

* The location of the last-seen snapshot transaction in the Bitcoin chain

The wire formats for this new transaction can be found in Appendix B.

### Block Validation

As before, transactions are processed in order within their blocks, and
blocks are processed in order by parent/child linkage.  Block-processing
continues until a checkpoint block is reached, at which the node must proceed to
process the associated Bitcoin block.  After the Bitcoin block has been
processed, the node compares the Stacks chainstate root hash
hash to the checkpoint transaction's root hash.  If they do not match, then the
checkpoint block is treated as invalid (and producers should try again to
produce a checkpoint block for the given Bitcoin block).  If they do match, then
the next stream of regular blocks may be processed.

Each time a block is processed, the Stacks chainstate MARF index commits to
the block's index hash and height, as well as its parent's index hash and height.
The index hash is the SHA512/256 hash of the concatenation of the consensus hash
of the last-processed Bitcoin block (i.e. this is committed to by the last
checkpoint transaction), and the hash of the regular block's header.
Previously, this commitment only occurred when processing anchored Stacks
blocks, and not microblocks.  This step is required for Clarity functions like
`get-block-info?` to work correctly.

Because non-checkpoint Stacks blocks do not contain a new VRF proof, the VRF seed for
each block is calculated as the SHA512/256 hash of the parent block's encoded
header and the parent block's VRF seed.  This value is returned by the `get-block-info?`
function in Clarity for a given Stacks block.

### Checkpoint Block Validation

When processing a Stacks block with a checkpoint transaction, the node must
ensure that there is exactly one checkpoint transaction, and it is the first
transaction in the block.

The VRF proof generation and validation logic differs from the system today,
because the VRF seed is no longer updated only once per Bitcoin block (but
instead once per Stacks block).  When a block producer proposes a checkpoint block, they
calculate their VRF proof over the hash of the parent block's VRF seed concatenated with
the new Bitcoin block's header hash.  Nodes verify this proof as part of
validating the checkpoint block.

### Checkpoint Block Production

Producers must create checkpoint transactions for each Bitcoin block in their tenure,
as well as for any Bitcoin blocks in any prior tenures that have not yet
received them (back to the last chain state snapshot transaction).  This
behavior is enforced by the consensus rules; each Stacks node independently
watches the Bitcoin blockchain for new Bitcoin
blocks, and will only accept a Stacks blockchain history with the appropriate
checkpoint blocks in the right order.

When a producer sees a Bitcoin block, one of two things happen, depending on
whether or not it sees a new Bitcoin block before its checkpoint block, or vice
versa:

* If the producer sees a new Bitcoin block but not a checkpoint block for it,
the producer immediately creates a checkpoint block for it and attempts to get other producers to sign it.

* If the producer sees a checkpoint block, it will immediately attempt to
  synchronize its view of the Bitcoin blockchain.  If the checkpoint block
corresponds to a newly-discovered Bitcoin block, and this Bitcoin block the
_lowest_ such block without a checkpoint block, then it will immediately sign it.

Because Bitcoin block propagation is not inherently reliable, it is
possible that other block producers are unable to validate it because they
either have not seen the Bitcoin block, or have seen a sibling Bitcoin block on
their view of the canonical Bitcoin fork.  To overcome these inconsistencies,
producers will continuously retry creating checkpoint
blocks if they do not observe any other producers acting on an in-flight
checkpoint block after a timeout passes.

In the event that a tenure ends before checkpoint blocks can be created for all
of its Bitcoin blocks, the producer set in the subsequent tenure(s) must
backfill the Stacks chain with missing checkpoint blocks.

In the event that a reward cycle change-over happens before all checkpoint
blocks can be signed for the prior tenure, the new stackers may sign the
checkpoint blocks from the old producers if they are available.  Otherwise,
the new producers will need to recreate them for the new stackers to sign (note
that a reward cycle change-over is also the start of a new tenure).

## Block Signing and Announcement

Creating a new block requires two parties to sign it: the current tenure's
producers, and the current reward cycle's stackers.  The reasons for involving
the stackers in this process are two-fold:

* **Block availability**.  By requiring stackers to sign the block, the
  producers are compelled to divulge the blocks they produce.  They cannot work
on a hidden fork, nor can they build atop blocks that are not readiliy available
to the peer network.

* **Transaction linearizability**.  Stackers will only accept blocks that constitute a
  linearized transaction history.  Even if producers create multiple conflicting
blocks, at most one block will be appended to the Stacks chain.  Moreover, if
a Bitcoin fork arises that invalidates some Bitcoin-dependent transactions,
Stackers ensure that any non-Bitcoin-dependent transactions that were previously
accepted remain accepted (see "Extension: Fixed Transaction Orders").

### Facilities for Signature Generation

For each Bitcoin block, it is unambiguous as to which producer set and
stacker set are active.  All Stacks nodes which share the same view of the
Bitcoin and Stacks chains can independently determine which tenure and reward
cycle are active, and as such, can determine the public key(s) and
Bitcoin spends of each producer, and the public key(s) and STX holdings of each stacker.

Producers and stackers use this information to bootstrap two FROST-generated public keys:
one that represents the producers, and one that represents the stackers.  A
block is only appended to the Stacks chain if it contains two Schnorr
signatures -- one from the producers and one from the stackers -- which are
valid with respect to these two public keys.

The reader will recall that FROST is a threshold signature scheme
in which _M_ out of _N_ (where _0 < M <= N_) signers cooperate to produce
a single Schnorr signature.  If all signers faithfully cooperate, they can
generate signatures with a single round of communication per signature.
However, this requires a pre-computation protocol to be executed by the signers
beforehand.

In the pre-computation step, each signer must generate and share _N - 1_ encrypted
messages with each other signer.  When there are hundreds of signers, as will be 
the case for this proposal, the size of the digital representation of this data will
be on the order of megabytes.  Moreover, the pre-computation step must be re-executed each
time the set of signers change, or if at least one signer misbehaved.

In order to employ FROST signing for block producers and stackers,
this SIP defines a standard communication medium by which hundreds of
signers can readily carry out the pre-computation step, accommodating even the
degenerate case of having to perform it _N - M_ times in order to exclude
the maximum number of _N - M - 1_ malicious signers that the protocol can
tolerate while maintaining safety.  The communication medium, called a _Stacker
DB_ (described below), leverages every connected Stacks node to store and replicate the
FROST pre-computation state, as well as store and forward signature generation messages.

By leveraging Stacks network infrastructure via Stacker DBs,
producer and stacker signer implementations do not need to concern themselves
with implementing durable data storage and highly-available communication.
Instead, it is sufficient for these signer processes to contact a trusted Stacks node
to send, store, and receive this data on its behalf.  This significantly reduces
the trusted computing base for producer and stacker signer implementations, and
allows the block production process to benefit from independent improvements to
the Stacks peer-to-peer network over time.  Furthermore, it allows all Stacks
nodes to monitor the behavior of block producers and signers, so they can detect
and handle network partitions (see below).

#### Stacker DBs

To facilitate FROST key and signature generation for producers and stackers,
the Stacks peer network will be extended to support Stacker DBs.  A _Stacker DB_
is an eventually-consistent replicated shared memory system, comprised of an array
of bound-length slots into which authorized writers may store a single chunk of data
that fits into the slot's maximum size.

Stacks nodes exchange a list of up to 256 Stacker DBs to which they are
subscribed when they exchange peer-to-peer handshake messages (see SIP-003).
Each Stacks node maintains an ordered list of Lamport clocks, called a 
_chunk inventory_, for each slot in each Stacker DB replica it hosts,
which it exchanges with peer Stacks nodes that host replicas of the same DB
(note that this is _not_ a vector clock; write causality is _not_ preserved).
Nodes exchange chunk data with one another such that eventually, in the absence
of in-flight writes and network partitions, all replicas will contain the
same state.  Chunks with old version numbers are discarded by the node, and
never replicated again once a new version is discovered.

Chunks are replicated asynchronously through the Stacks p2p network through
gossipping.  A Stacks node will periodically query neighbors
who replicate the same Stacker DB for their replicas' chunk inventories, as 
well as the number of inbound and outbound neighbor connections this node
currently has.  If any slots are discovered that contain "later" versions
than the local slot, the node will fetch that slot's chunk, authenticate it
(see below), and store it along with an updated version.  In addition, if the
node discovers that it has the latest version of a chunk out of all neighbors
and it discovers a neighbor with an older chunk, it will push its local chunk
to the neighbor with probability inversely proportional to either the neighbor's
reported number of total neighbors (if the local node treats this neighbor as
an outbound neighbor), or to the reported number of outbound neighbors (if the
local node treats this neighbor as an inbound neighbor).

Stacker DB clients (i.e. producers and stackers) read and write chunks via the
node's RPC interface.  The Stacker DB "read" endpoint returns the chunk data, the chunk version (as a Clarity value), and the chunk signer's
compressed secp256k1 public key as a JSON struct, conforming to the following specification:

```json
{
   "chunk": {
      "type": "string",
      "pattern": "^[0-9a-fA-F]*$"
   },
   "version": {
      "type": "string",
      "pattern": "^(0x)?00[0-9a-fA-F]{16}$"
   },
   "public_key": {
      "type": "string",
      "pattern": "^[0-9a-fA-F]{33}$"
   }
}
```

Note that chunk versions are serialized Clarity unsigned integers.

A chunk with version `0x000000000000000000` is always an empty chunk, and has 
a `chunk` field with zero length.  It is used to represent a chunk that has not been written.
The content of the `public_key` field in this case is undefined. 

A "write" to the Stacker DB occurs through an RPC endpoint.  The "write"
consists of the array index, the chunk version, the chunk data, and a
recoverable secp256k1 signature over the aforementioned data.  The node
leverages the Stacker DB's smart contract to authenticate the write by passing
it the array index, chunk version, chunk hash (SHA512/256), and signature via a read-only
function called `stackerdb-auth-write`, whose signature is produced below:

```clarity
(define-read-only (stackerdb-auth-write
                     (chunk-idx uint)
                     (chunk-version uint)
                     (chunk-hash (buff 32))
                     (chunk-sig (buff 65))))
```

The `auth-write` function evaluates to `true` if the write is allowed, or
`false` if not.  If `true`, then the Stacks node verifies that the version is
equal to or greater than the last-seen version for this chunk.  If it is equal,
but the chunk is different, then the write will be accepted only if the hash of
the chunk has strictly more leading 0's than the current chunk.  If this is the
case, or if the version is strictly greater than the last-seen version of this
chunk, then the node stores the chunk locally,
updates the DB's chunk inventory, and announces it to its peer nodes which
replicate the Stacker DB.  If authentication fails, or if the version is less than
the last-seen version, or if the version is equal to the last-seen version and
the hash of the new chunk has less than or equal leading 0-bits in its hash,
 then the Stacks node NACKs the RPC request with an HTTP 403 response.

The reason for accepting chunks with the same version but lesser hashes is to
allow the system to both recover from and throttle nodes that equivocate.  Automatically
resolving conflicts that arise from equivocation keeps all Stacker DB replicas consistent,
regardless of the schedule by which the equivocated writes are replicated.  The use of the chunk hash
to resolve equivocation conflicts makes it increasingly difficult
for the writer to continue equivocating about the chunk for this version -- the
act of replacing a chunk with version _V_ for _K_ times requires _O(2**K)_
computing work in expectation.  This, in turn, severely limits the amount of excess disk-writes the
a Stacks node can be made to perform by the equivocating writer, and severely limits
the number of distinct states that this version of the chunk can be in.

To support equivocation throttling in this manner, the chunk inventory for the
Stacker DB encodes both the version and the number of leading 0-bits in the
chunk's hash.

The node will periodically query the smart contract in a read-only fashion to determine if any
chunks may be evicted.  To determine the periodicity, the node queries the
smart contract in a read-only fashion via its
`stackerdb-garbage-collect?` function once per Bitcoin block processed:

```clarity
(define-read-only (stackerdb-garbage-collect?))
```

This function evaluates to `true` if the node should begin garbage-collection
for this DB, and `false` if not.

If the node should garbage-collect the DB, it will determine which chunks are
garbage via the smart contract's `stackerdb-is-garbage?`
function, whose signature is produced below:

```clarity
(define-read-only (stackerdb-is-garbage?
                     (chunk-idx uint)
                     (chunk-version uint)
                     (chunk-hash (buff 32))
                     (chunk-sig (buff 65))))
```

If this function evaluates to `true`, then the chunk will be deleted and its
version reset to `u0`.  If `false`, then the chunk will be retained.

Further details of the Stacker DB wire formats, controlling smart contracts, and RPC
endpoints can be found in Appendix A.

#### Boot Contracts

Each Stacks node must subscribe to two Stacker DB instances -- one for
producers, and one for stackers -- in order to ensure that each producer and
stacker can reliably participate in FROST signature generation.  The producer
Stacker DB contract is controlled through
`SP000000000000000000002Q6VF78.block-producers` (henceforth referred to as
`.block-producers` for brevity), and the Stacker DB contract for
stackers is controlled through a new PoX contract `SP000000000000000000002Q6VF78.pox-4`
(henceforth referred to as `.pox-4`).  Only nodes that act as producers and/or
stackers need to subscribe to these Stacker DBs; however, each producer and each
stacker will need to subscribe to both.

Like with the PoX contract, the data spaces for these two contracts are
controlled directly by the Stacks node.  In particular, the data space for
`.block-producers` is populated at the start of each term with the public keys
of the tenure's block producers that will be used to validate DB chunks for the coming
tenure, as well as data about the highest-known on-Bitcoin state snapshot.
The public keys are obtained from the enrollment transactions on Bitcoin for
this tenure.

The `.pox-4` contract will become the current PoX contract if this SIP
activates.  This PoX implementation behaves identically to the current version,
except in two ways.  First, the signatures of
the `stack-stx` and `delegate-stx` functions in `.pox-4` are
modified to accept an additional `(buff 33)` argument, which encodes a
compressed secp256k1 public key.  This effectively requires stackers to supply a
chunk-signing key when they stack.  Second, this state is stored in a new data
map within `.pox-4`, which will be queried by the Stacker DB interface to
authenticate chunk writes.

Both contracts will have read-only getter functions so that other smart
contracts can query the chunk-signing keys for their own purposes.

### Signature Generation

In both `.block-producers` and `.pox-4`, the concept of "signature weight" is
embodied by the number of signers that each producer or stacker represents.  A
_signer_ in this context refers to a fixed-sized portion of the threshold
signature.  For block production, there are 100 signers, and at least 67 of them
must participate to produce a valid block signature.  For stacker signing, there
are up to 4,000 signers (one for each claimed reward slot), of which 67% must
participate (up to 2,680 signers).

#### Producer DB Setup

The `.block-producers` contract defines a Stacker DB with 300 slots.  The first
100 slots store the pre-computed FROST state for each signer, slots 100-199 are used
to store in-flight signature generation state for FROST, and slots 200-299 store proposed
block data.  The signers are assigned to a tenure's producers in quantities proportional to their share of Bitcoin spent.
At the start of tenure N, it evicts all signing state for tenure N-1 by
garbage-collecting each chunk.  It then determines how many slots to allot each producer by distributing them in a
round-robin fashion from smallest producer by Bitcoin spend to largest producer by
Bitcoin spend.  It breaks ties by sorting each tied producers' last enrollment
transaction IDs in lexographic order.

The number of DB signer slots are assigned to a producer represents the weight of the
producer's signature.  For example, if four producers each registered for tenure
N, and each spent 10%, 20%, 30%, and 40% of the BTC, then the 10% producer would
receive 10 slots, the 20% producer would receive 20 slots, the 30% 30 slots, and
the 40% 40 slots.  The 10% producer receives DB slots 0, 10, 20, 30, 40, 50, 60,
70, 80, ... 180, and 190; the 20% producer receives DB slots 1, 2, 11, 12, 21, 22, ...,
191, and 192; the 30% producer receives DB slots 3, 4, 5, 13, 14, 15, 23, 24, 25, ...,
193, 194, and 195; the 40% producer receives DB slots 6, 7, 8, 9, 16, 17, 18, 19, ...,
196, 197, 198, and 199.  The `.block-producers` contract's `stackerdb-auth-write`
function ensures that each producer can only write to their assigned slots; the
requisite state for doing so is directly written into the contract's data space
at the start of each tenure, which this function queries.

The proposed block slots are alloted to producers in ascending order by BTC
weight.  In the above example, slot 200 is alloted to the 10% producer, slot 201
to the 20% producer, slot 202 to the 30% producer, and slot 203 to the 40%
producer.  If there are fewer than 100 producers, then the remaining slots are
unused.

#### Producer Signing Protocol

When the FROST pre-computation step is executed, each producer generates their
signers' data and uploads them to their assigned slots.  The producer then
fetches and decrypts the messages from the other producers' signers in order to
obtain the necessary FROST state required to produce signatures.

When proposing blocks, each block producer may submit a candidate assembled block
to their assigned block slots (i.e. slots 200-299) for other producers to see.
Producers then collectively decide on which candidate block to sign.  The protocol
for agreeing on the block is implementation-defined and not consensus-critical,
but this SIP requires the implementation to provide a necessary ingredient
to Byzantine fault-tolerant implementations: each block must be signed by at
least 67% of the producers' signers.

The signed block is automatically propagated to stackers via the
`.block-producer` Stacker DB.

#### Stacker Signer DB Setup

Like the `.block-producers` contract, the `.pox-4` contract maintains a set of
DB slots for storing FROST pre-computed data and signature data.  The stacker
signer DB has 8,000 slots.  The first 4,000 are allotted to stackers based on
how many reward slots they earn.  These slots are assigned to stackers
in contiguous ranges, based on the order in which their STX were stacked for this reward
cycle (i.e. as determined by the `.pox-4` contract's
`reward-cycle-pox-address-list` map), and are used to hold each stackers'
signers' FROST pre-computation state.  The last 4,000 are similarly alloted to
stackers, but are used to contain in-flight signature metadata regarding the
proposed block.

#### Stacker Signing Protocol

Stacker signers monitor the producer Stacker DB to watch for a completed, valid,
sufficiently-signed producer-proposed block.  If such a block is created, then
each stacker attempts to append the block to its local node's chainstate.  If
the block is acceptable, then stackers execute the distributed FROST signature algorithm to
produce the signature by storing their signature shares to their allotted signature slots.  Once enough
signature slots have been acknowledged and filled for this block, then the block and both
producer and stacker signatures are replicated to the broader peer network.
Note that block replication can happen independent of signature replication;
future work may leverage this property to implement an optimistic eager block
replication strategy and a fast _post-hoc_ signature-replication strategy to
speed the delivery of blocks from producers to the rest of the network.

Because the block production algorithm is implementation-defined, stackers must
take the utmost care in choosing whether or not to append a produced block to
the blockchain.  The produced block must meet the following criteria:

* It must be valid under the consensus rules

* At least 67% of producers' signers have signed the block

* There must not exist another block at the same height on the same Bitcoin fork

If producers equivocate and create two valid but different blocks for the same
Stacks height, then stackers should not only refuse to sign it, but also stackers
should refuse to sign any further blocks from that tenure.

If the underlying Bitcoin chain forks, then stackers may need to sign a producer
block with the same Stacks block height as an existing Stacks block but happens
to be evaluated against a different Bitcoin fork.  Stackers determine which
Bitcoin fork by examining the sequence of checkpoint transactions in the
ancestors of the block.

### State Snapshots

Once per tenure, stackers and the producer set create a "snapshot" Bitcoin transaction that
contains a recent digest of the Stacks chain history.  Specifically, the
stackers and producer set who are active in tenure N must send a snapshot
transaction that contains the hash of the last block produced in tenure N-2
(i.e. the block that all blocks in tenure N-1 build upon, which has subsequently
received at least 10 Bitcoin confirmations).  The presence of this
transaction in the Bitcoin chain prevents any future set of producers and
stackers from producing a conflicting chain history.  All blocks represented by
the snapshot transaction are treated as finalized -- the act of creating
an alternative transaction history is tantamount to reorganizing the Bitcoin
chain to remove conflicting snapshot transactions.

Crafting and sending this transaction is not free, so its creation must be
incentivized by the consensus rules.  To ensure that it gets created and
mined on-time, the producer block reward disbursal for tenure N will not happen until a snapshot for
tenure N-2 _or later_ is mined on Bitcoin.  To similarly incentivize stackers to cooperate
with producers to create the snapshot, PoX payouts during subsequent tenures are
diverted to a Bitcoin burn address and their STX are indefinitely locked
until the snapshot for tenure N-2 (or later)
is mined on Bitcoin.  In other words, producers and stackers can only get paid
if they create and broadcast the snapshot on Bitcoin in a timely fashion.  To
avoid missed payments, stackers and producers are encouraged to produce the
snapshot for tenure N-2 at the start of tenure N.

The wire format for a snapshot transaction's `OP_RETURN` payload is as follows:

```
            0      2  3     7                 39                         80
            |------|--|-----|------------------|-------------------------|
             magic  op tenure   block hash       padding
                       id
```

Where `op = 0x73` (ASCII `s`) and:

- `tenure_id` is the tenure number (i.e. N-2)
- `block_hash` is the SHA512/256 hash of the last block in the identified tenure

In addition, the snapshot transaction must contain at least two inputs:  a FROST-generated Schnorr
signature from the producer set in tenure N, and a FROST-generated Schnorr
signature from the stackers in the current reward cycle.  The producer set funds
the transaction fee; the stackers sign the transaction with
`SIGHASH_ANYONECANPAY`.

### Liveness Incentives

The producer set is incentivized to produce blocks and snapshot transactions
because if either process stops, then the STX coinbase and transaction fees also
stop.

The stackers are incentivized to sign snapshot transactions, but what
incentivizes them to validate and sign producer blocks?  The answer is sBTC (see
SIP-021).  Stackers are already incentivized to accept blocks that materialize sBTC from
deposits and dematerialize sBTC from withdrawals.  If they do not complete these
tasks in a timely fashion, then their PoX rewards are diverted to a burn address
and their STX are indefinitely locked until all unfulfilled sBTC deposits and
withdrawals are handled.  In addition, stackers are incentivized to sign blocks
that contain their own stacking operations, so that they can continue to receive
PoX rewards.  

This is enough to drive stacker liveness.  In order to process a stacking or
sBTC (de)materialization operation in Stacks block _N_, the stacker must
process and accept all blocks prior to _N_.  Therefore, stackers will
continuously accept valid blocks from producers so that they will be able to
complete these actions on-time.

## sBTC Concerns

This SIP proposes incorporating the sBTC system described in SIP-021, but with
the following changes.

### sBTC Wallet Operations

The act of sending BTC to the stacker-controlled Bitcoin wallet would not
materialize sBTC until the Bitcoin transaction had received at least one tenure
of Bitcoin confirmations.  Similarly, withdrawing BTC for sBTC would require at least one
tenure of Bitcoin confirmations before its effects materialized on Stacks,
as would transferring the wallet's BTC from one set of stackers
to the next.  Because there are no longer any Stacks forks, a BTC withdrawal would no longer
require 150 Bitcoin confirmations.

### sBTC Transfers

Because Stacks no longer forks, sBTC transfers would be treated as any other
SIP-010 token transfer.  They can be mined as quickly as any other Stacks
transaction, and do not need to be materialized on the Bitcoin chain.

### sBTC Consensus Rules

Because Stacks no longer forks, there is no longer a need for the system to
identify blocks as unconfirmed or frozen.  Also, there is no longer a need for
stacker blessings.  Instead, this SIP makes it so that the concerns these
protocols were meant to address no longer arise. 

## Extension: Fixed Transaction Orders

This SIP proposes that Stacks continue to support on-Bitcoin transactions for `stack-stx`,
`transfer-stx`, and `delegate-stx`.  However, the absence of Stacks forks makes
it possible for non-finalized Stacks chain state to become inconsistent with the
Bitcoin chain.  For example, if Alice send 10 STX to Bob via a `stack-stx`, but
the `stack-stx` is mined in a Bitcoin block that later gets orphaned, then
Alice's and Bob's new balances are inconsistent with Bitcoin -- a node
attempting to bootstrap from the Bitcoin and Stacks chains would not process the
now-missing `stack-stx` transaction, and would be unable to authenticate the
Stacks blocks against subsequent state snapshots (and thus be unable to finish
booting).

Bitcoin forks are rare events, and forks lasting longer than six blocks are
extremely unlikely.  This SIP proposes that a Bitcoin transaction which receives
at least one tenure of Bitcoin confirmations (i.e. at least 10 Bitcoin
confirmations) is sufficiently confirmed that it can be assumed that it will
remain confirmed forever.

Nevertheless, short-lived Bitcoin forks arise often.
A naive stawman way of dealing with Stacks chain state inconsistency created by
these short-lived forks is presented below for illustrative purposes:

* Process all on-Bitcoin transactions at the end of the block, instead of the
  beginning (as it is done today).  Then, the transactions in the block that are
not on-Bitcoin are at least not causally-dependent on the on-Bitcoin
transactions.

* Do not process on-Bitcoin transactions that arise in tenure N until the state
  snapshot for tenure N is mined.  This all but guarantees that these on-Bitcoin
transactions will never be orphaned.

* Report only Bitcoin data as of the last state snapshot via Clarity functions.
  For example, `get-burn-block-info?` would only report Bitcoin state up to the
Bitcoin block which contained the last state snapshot.

While this naive approach would work, the problem is that the second and third requirements introduce a
very high transaction confirmation latency for Bitcoin-dependent transactions -- users
would need to wait for over two tenures (over 20 Bitcoin blocks) before their
Bitcoin-dependent transactions could be processed.

Because Bitcoin forks are rare, this SIP proposes a form of speculative execution whereby 
Bitcoin-dependent transactions are processed as soon as they are available (and
Bitcoin-dependent information exposed to Clarity as soon as available), but with
the caveat that unfinalized transactions may be discarded if a fork arises.  To
minimize the disruption this would cause, stackers require that producers 

### Recovery from Bitcoin Forks

In the event that a Bitcoin fork arises and invalidates transactions, the
Stacks blockchain would guarantee that all Stacks transactions (but not
on-Bitcoin transactions) are reprocessed in the same order that they were
initially accepted.  Stackers will only sign produced blocks that contain the
same Stacks transactions as before.  However, it is possible that not all Stacks
transactions will be valid, since they may be causally dependent on Bitcoin
state that is no longer canonical.  For this reason, transactions no longer
invalidate Stacks blocks; the inclusion of an invalid transaction is treated as
a runtime error in all cases.

Old Stacks blocks that contain potentially-invalid state are discarded.

### Bitcoin Forks and sBTC

The sBTC wallet operations already require sufficient Bitcoin confirmations that
it is effectively guaranteed that they will never be orphaned by the time the
producer set processes them.  As such, sBTC by itself is not speculatively
instantiated or destroyed -- it can only materialize or dematerialize
once its deposit and withdraw transactions are sufficiently
confirmed, Consequently, sBTC transfers will remain valid even when Stacks
transactions are replayed to recover from Bitcoin forks.

### Future Work: Taint Tracking

A future SIP may propose that the Clarity VM performs taint-tracking on state
that may still be volatile.  This information is not consensus-critical, so this
SIP does not propose it.  However, this information would be useful to off-chain
services who need to determine whether or not state they intend to act upon is
sufficiently confirmed by Bitcoin.

## Extension: Overdue Term

Naively, the execution budget available to block producers can be treated as
equal to the number of Stacks blocks' budgets today, multipled by the tenure
length.  Ideally, block producers would produce blocks at a rate such that under
network congestion, the tenure budget is completely consumed just as the tenure
ends.

It is very difficult in practice to realize this idealized block production
schedule, because the length of a tenure has very high variance and is not known
in advance.  If the block producers reach their tenure budget before the
tenure is over, then the Stacks network stalls, which significantly increases
transaction latency and degrades the user experience.

To eliminate these periods of idle time, this SIP proposes implementing a
replicated verifiable delay function (VDF) which block producers individually
run in order to prove that a tenure is taking too long.  If enough block
producers can submit VDF proofs that indicate that they have waited for the
expected tenure length, then if the tenure is still ongoing, their tenure's
execution budget is increased for an additional tenure.  The process repeats indefinitely --
as long as block producers can submit VDF proofs, they earn more execution
budget until their tenure is terminated by the arrival of the first Bitcoin
block of the next tenure.

### VDF Execution 

Concurrent with producing blocks, members of the producer set continuously
evaluate a VDF for a protocol-defined number of "ticks" (i.e. one pass of the
VDF's sequential proof-generation algorithm).  The VDF proof must
show that the producer evaluated the VDF for at least as many ticks.

Producers are incentivized to evaluate their local VDFs as quickly as possible,
because gaining additional tenure execution budget means more transaction fees
are available to them.  Each time they can create a VDF proof, they submit it as
a transaction to the mempool.  Because the tenure execution budget grows only
once at least 67% of producers (weighted by BTC spend) submit a VDF proof, each
producer is incentivized to confirm a new VDF proof transaction as soon as
possible by including it in the next block they propose.

Once enough valid VDF proofs have materialized in the blockchain, the tenure's
budget expands.

### VDF Calibration

The consensus rules for checkpoint blocks require that the first checkpoint
block in a tenure reports an adjusted number of ticks required to produce a valid
VDF proof in this tenure.  The tick count is adjusted over many tenures
such that a producer running the VDF as fast as they
can in the current tenure would complete a VDF proof in the expected duration of 
the tenure (i.e. 100 minutes).  The number of ticks can be adjusted up or down, depending
on historical tenure data.

To calculate the minimum number of ticks for tenure N, a node will load
the following data for the past 15 tenures (about 25 hours of data):

* The wall-clock time of the tenure, calculated as the difference in the UNIX
  epoch timestamps between the last and first Bitcoin blocks in the tenure
(as an array `TIMES`).
* The consumed execution budget for the tenure (as an array `EXECUTION`).
* The minimum number of ticks for the tenure (as an array `TICKS`).
* The integer number of times the execution budget was increased in the tenure
  (as an array `EXCEEDED`).

The node then calculates the scaled average number of times the tenure budget
was exceeded as:

```
s = (sum(TIMES) / 1500) * (sum(EXCEEDED) / 15)
```

If `s >= 0.5`, then it means that in the average tenure in this sample,
producers were able to earn expanded tenures with over 50% probability.
This indicates that the tick count needs to be increased, because producers
were able to regularly evaluate the VDF faster than the tenures completed.
In this case, it is multiplicatively incrased by a factor of `min(2.0, s / 0.5)`, and rounded
down to the nearest integer.

If `s < 0.5`, then in the average tenure, producers did not expand the budget
over 50% of the time.  This could be due to any of three reasons:

* The average tenure length was less than 10 minutes, so the budget was never
  exceeded and no VDF proofs were produced

* There was no network congestion, so producers simply didn't need to submit any VDF
  proofs

* There was network congestion, but the minimum tick count was so high that
  producers were unable to earn more budget to address it


We are interested in distinguishing that last case from the others, which do not
warrant a minimum tick decrease.  To do so, the node examines each consumed
budget in `EXECUTION[i]` where `TIMES[i] > 6000`.  If the majority of each such
`EXECUTION[i]` contains a cost parameter that is over 95% of the allotted budget,
we can infer that the network was congested but producers were unable to ask for
more budget (i.e. Bitcoin didn't terminate their tenure early).  In this case, 
the minimum tick count is multiplicatively decreased by a factor of `min(2.0,
a)` where `a` is an adjusted scale factor, calculated to only consider tenures
where producers really did need to increase the budget:

```
n = len(EXCEEDED[i] where TIMES[i] > 6000 and EXECUTION[i] has a near-full cost parameter)
a = (sum(TIMES) / 1500) * (sum(EXCEEDED) / n)
```

The final tick count reported in the checkpoint block can be as low as 1, or as
high as `u128::MAX`.  The initial tick count will be calculated once a VDF
implementation is written and tested.

The initial tick count is unconditionally used for the first 15 tenures.

### VDF On-Chain State

Each checkpoint block will contain a special-purpose transaction from the producers which
contains the new tick count.  Each Stacks node independently performs the VDF
calibration above; the VDF calibration transaction merely announces it.

The VDF tick counts are recorded to a boot code contract `SP000000000000000000002Q6VF78.vdf`, 
and exposed via read-only functions so that Clarity contracts can act on them.

# Activation

This SIP activates concurrently or before SIP-021.  Before this SIP can
activate, the following additional tasks must be performed:

* SIP-021 must be updated to depend on this SIP.

* A VDF implementation must be written, so as to calculate the initial VDF tick
  count

* A stacker vote must take place, by which at least 67% of STX holders vote in
  one reward cycle (TBD) to ratify this SIP.  This must occur before or during
the early implementation of this SIP -- stackers will be voting to authorize
this change, instead of rubber-stamping a ready-to-go implementation.

# Related Work

## Rollups

The proposed consensus protocol makes Stacks superficially similar to optimistic
rollups.  The producer set can be thought of as a replicated BFT block
sequencer in rollup parlance; the key difference between Stacks and existing
rollups is that the sequencer implementation is designed from the get-go to
operate as an open-membership BFT replicated state-machine.

Like rollups, Stacks produces a linearized transaction history that is
periodically snapshotted to the underlying L1 blockchain.  However, due to
Bitcoin's limited block space and limited scripting language, Stacks does not
rely on Bitcoin to store its transaction state nor does it rely on Bitcoin
script to validate them.  Instead, this responsibility is outsourced to the
stackers, who are chiefly responsible for keeping transaction data available and
determining the validity of blocks prior to their acceptance into the Stacks
chainstate.  Stackers and the producer set record digests of the Stacks chain
state to Bitcoin once per tenure in order to ensure that no alternative Stacks
chain history can be produced up until that snapshot without first reorganizing
the Bitcoin chain.

On-Bitcoin transactions in Stacks are analogous to forced transactions in
rollups -- the producer set must incorporate them into their blocks in order for
their blocks to be valid.  Unlike rollups, Stacks applies on-Bitcoin transactions (with the
exception of sBTC peg-in and peg-out transactions) immediately via speculative
execution; they are only rolled back in the event that the Bitcoin block
containing them is orphaned.

## Proof-of-Stake

This proposal bears some superficial similarity to proof-of-stake (PoS) systems in that
it now requires stackers to accept a block.  However, there are two significant
differences between this SIP and PoS that render it decidedly _not_ PoS:

* **Block production and acceptance are decoupled**.  Block production only
  requires spending BTC; block producers do not need to hold or stake STX.  This
means that anyone who can acquire BTC can be a block producer; stackers cannot
influence this by controlling the liquid supply of STX.  This ensures that
block production remains an open-membership protocol.  By contrast, PoS
systems require block producres to hold and stake the system's native token,
whose availability is subject to sales by the existing block producers.

* **Block finalization and acceptance are decoupled**.  While stackers determine
  which blocks get accepted to the chain, they are not responsible for
finalizing the chain state.  This is instead achieved through state snapshots to
Bitcoin.  This way, the cost to produce multiple alternative histories of the
Stacks chain is at least as costly as producing multiple alternative histories
of Bitcoin.  By contrast, nothing stops PoS systems' block producers from
crafting multiple chain histories, since the cost to doing so is negligeable.
The only thing that prevents this in PoS is that the block producers would
potentially lose their staked tokens (provided that proofs of equivocation could
be accepted into all equivocated histories).  In this proposal, generating
alternative histories is as difficult as reorganizing the Bitcoin chain _even
if_ 100% of block producers and stackers were determined to do so.

# Appendix A: Stacker DB Specification

TBD

## Peer Network Wire Formats

TBD

## Smart Contract Traits

TBD

## RPC Endpoints

TBD

# Appendix B: New System Transactions

## VDF Calibration


