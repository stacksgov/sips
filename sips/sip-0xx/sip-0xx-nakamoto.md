# Preamble

SIP Number: XX

Title: Collaborative Mining and Stacker Availability Signing

Authors:  Aaron Blankstean <aaron@hiro.so>, Brice Dobry <brice@hiro.so>, Jude
Nelson <jude@stacks.org>

Considerations: Technical, Governance, Economics

Type: Consensus

License: BSD 2-Clause

Sign-Off: 

Discussions-To: 

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
proposed, it is transmitted to all PoX stackers.

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
history, regardless of the future valuation of STX and regardless of the
intentions of miners and stackers.

With these principal changes, Stacks block production is no longer inherently tied to
Bitcoin block production.  As described in more detail below, miners no longer commit
to each block they produce via Bitcoin transactions,
but instead submit Bitcoin transactions only to join a _producer set_ of miners
and to periodically snapshot the chain state.
Block production now happens via a dedicated peer network maintained by the producer set.

In this proposed system, transaction confirmation latency now depends on
how quickly a Stacks block that contains it
can be produced and accepted -- this takes on the order of seconds, instead of hours.
In addition, the security budget of a transaction confirmed this way is substantially higher
than it is today -- due to BFT agreement in steps 1 and 2, the budget is equal to the sum of 67% of the
miners' Bitcoin spends for that block plus 67% of the worth of the stackers'
locked STX.  At the time of this writing (1 STX = $0.63 USD, 1 BTC = $29,747 USD,
Stacks reward cycle 63), this represents a security budget increase from $234.18 USD per block (cumulative)
to $213,908,185.70 per block -- nearly 6 orders of magnitude higher!  The
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

## Consensus Properties and Goals

This SIP proposes a set of changes to the Stacks blockchain's consensus protocol
in order to achieve the following high level properties:

1. Increased transaction throughput over the Stacks 2.4 protocol through
   collaborative mining.
2. Low latency transactions in the absence of bitcoin forks. Without waiting for
   announcement on the bitcoin chain, transactions which are accepted by miners
   confirm much more rapidly.
3. Elimination of coinbase reward incentives for intentional miner crowding and
   bitcoin transaction censorship.
4. Bitcoin-finality for transactions: once a block containing a transaction has
   been announced to the bitcoin chain, that transaction may only be reorged if
   the bitcoin chain reorgs.
5. Maintenance of Stacks 2.4's expected coinbase reward schedule and
   proof-of-transfer rewards.

## Producer Set Terms and Block Production

Rather than competition among miners to mine blocks, each block is mined by a
single, globally visible, producer set. A producer set collaborates to mine
blocks during fixed length _terms_. For a given term, every Stacks block is
assembled and signed by a Byzantine fault-tolerant majority of that term's producer set.

The producer set is a collection of weighted public keys. Each member of the
producer set is associated with a public key and is assigned a weight according
to the proportion of Bitcoin committed during the term's selection (see
[Producer Set Selection](#producer-set-selection)).

For a block to be validated, it must be signed by over `67%` of the producer set
by weight. The signature scheme will use a weighted extension of FROST group
signatures. In this extension, in addition to each Stacks block including a
normal FROST signature, it would include a bit vector conveying which public
keys signed the block. Validators would use this information in order to:

1. Confirm that indeed each of those public keys participated in the group
   signature.
2. Sum over the weights of those signing keys and confirm that they meet the
   required threshold.

### Block Production during a Term

Each producer set term is 10 bitcoin blocks in length. Stacks cost limits are
applied to the term as a whole rather than individual Stacks blocks, and each
term's cost limit is 10x the Stacks 2.4 single block limit (or the single block
limit after improvements to the Clarity runtime and improved benchmark results).

During a term, there is no distinction between Stacks blocks and microblocks:
there are only blocks. Terms are not limited to 10 blocks (i.e., there may be
more than one Stacks block produced during a given bitcoin block), but rather
the only limit applied to the term is the overall cost limit (which may be
increased through application of a VDF, see
[Extension: Overdue Term](#overdue-terms)).

The first block of a term always builds off the last-known block of
the prior term, which itself is a descendant of the last on-Bitcoin snapshot.
Producers may not choose to reorganize a prior term, but any
unannounced blocks from the prior term are dropped.

### Producer Set Collaboration

While this proposal specifies how blocks mined by a producer set are validated,
it leaves open the question of exactly how producer sets collaborate to assemble
blocks. This is intentional: the validation of blocks is consensus-critical, but
exactly how a valid block gets mined is not. However, the Stacks blockchain
codebase will need to supply a default method for this assembly.

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

Producer set enrollments have the same constraints on the Bitcoin transaction's
inputs as PoX leader block commitments. Specifically, the first input of this
Bitcoin operation must originate from the same address as the second output of
the
[VRF key registration](https://github.com/stacksgov/sips/blob/main/sips/sip-001/sip-001-burn-election.md#leader-vrf-key-registrations).
The first output of a producer set enrollment must be an `OP_RETURN` with the
following data:

```
            0      2  3     7     9    13    15           48            80
            |------|--|-----|-----|-----|-----|------------|-------------|
             magic  op set   set   key   key     signing      padding
                       block txoff block txoff   pubkey          
```

Where `op = @` and:

- `set_block` is the burn block height of the final block announced in the
  previous term, N-3. This ensures that the enrollment is only accepted if it is
  processed during the correct term.
- `set_txoff` is the vtxindex for the final block announced in the previous
  term, N-3.
- `key_block` is the burn block height of this producer's VRF key registration
- `key_txoff` is the vtxindex for this producer's VRF key registration
- `signing_pubkey` is the compressed secp256k1 public key used by this producer
  to sign FROST signature-generation messages to be consumed by other
producers.

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
number of outputs: one `OP_RETURN`, twenty stacker rewards, and one change
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
open a new DoS vector. This cap will also prevent the block-signing process from
becoming too expensive. To this end, the total amount of BTC spent in the
outputs described in "Producer Set Enrollments" is used to select the producer
set. Would-be producers are ranked by these BTC expenditures, and the top 100
will be selected for the producer set.

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
in which _M_ out of _N_ signers cooperate to produce
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
the Stacks peer-to-peer network over time.

#### Stacker DBs

To facilitate FROST key and signature generation for producers and stackers,
the Stacks peer network will be extended to support Stacker DBs.  A _Stacker DB_
is an eventually-consistent replicated array of bound-sized data chunks,
administrated by a smart contract.

The data schema for a Stacker DB is very simple.  Each key is an unsigned
128-bit integer, and each value is a byte buffer with a fixed length.  Keys act
like array indexes -- the first key/value pair has key `u0`, the second has key
`u1`, and so on.  The smart contract determines the total number of key/value
pairs the DB can contain, and it determines the maximum length of a value.

Stacks nodes exchange a list of up to 256 Stacker DBs to which they are
subscribed when they exchange peer-to-peer handshake messages (see SIP-003).
Each Stacks node maintains a vector clock for each Stacker DB replica it hosts,
which it exchanges with peer Stacks nodes that host replicas of the same DB.
Nodes exchange chunk data with one another such that eventually, in the absence
of in-flight writes, all replicas will contain the same state.  Values with old
version numbers are discarded by the node, and never replicated again once a new
version is discovered.

Chunk values for the DB can be both written and queried via the node's RPC interface.
Newly-written values will be asynchronously replicated to peer nodes
via the above best-effort algorithm.  Clients may query a node's
peer's last-seen vector clocks for a Stacker DB in order to assess the node's
progress on replicating a written chunk.

A "read" to the Stacker DB occurs through an RPC endpoint.  The "read" endpoint
returns the chunk data, the chunk version (as a Clarity value), and the chunk signer's
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
updates the DB's vector clock, and announces it to its peer nodes which
replicate the Stacker DB.  If authentication fails, or if the version is less than
the last-seen version, or if the version is equal to the last-seen version and
the hash of the new chunk has less than or equal leading 0-bits in its hash,
 then the Stacks node NACKs the RPC request with an HTTP 403 response.

The reason for accepting chunks with the same version but lesser hashes is to
allow the system to both heal from and throttle writers that equivocate.  Automatically
resolving conflicts that arise from equivocation keeps all Stacker DB replicas consistent,
regardless of the schedule by which the equivocated writes are replicated.  The use of the chunk hash
to resolve equivocation conflicts makes it increasingly difficult
for the writer to continue equivocating about the chunk for this version -- the
act of replacing a chunk with version _V_ for _K_ times requires _O(2**K)_
computing work in expectation.  This, in turn, severely limits the amount of excess disk-writes the
a Stacks node can be made to perform by the equivocating writer, and severely limits
the number of distinct states that this version of the chunk can be in.

To support equivocation throttling in this manner, the vector clock for the
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
(henceforth referred to as `.pox-4`).

Like with the PoX contract, the data spaces for these two contracts are
controlled directly by the Stacks node.  In particular, the data space for
`.block-producers` is populated at the start of each term with the public keys
of the tenure's block producers that will be used to validate DB chunks for the coming
tenure.  These keys are obtained from the enrollment transaction on Bitcoin.

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
transaction IDs in lexographic order, and shuffling them using a ChaCha12
pseudorandom function seeded from the on-chain VRF state sampled tenure N-1's last Bitcoin block.

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
to the 20% producer, slot 202 to the 30% producer, and slot 203 to th3 40%
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
the block is acceptable, then stackers execute the FROST signature algorithm to
produce the signature by storing their signature shares to their allotted signature slots.  Once enough
signature slots have been acknowledged and filled for this block, then the block and both
producer and stacker signatures are replicated to the broader peer network.

Because the block production algorithm is implementation-defined for producers,
it is possible that the producer set creates two or more blocks that are signed
by at least 67% of the producer signers.  To resolve this conflict, the stackers
collectively choose the block whose header's SHA512/256 hash is the numerically
smallest of all candidates.  Stackers execute multiple rounds of
signature-generation if need be in the event that two or more blocks are
discovered; each subsequent round commits the Stacker to a block whose hash is
numerically smaller than the prior block's hash.  Signing stops once _any_
block's stacker signature reaches at least 67% of the stacker signers, even if a
produced block at the same height is later discovered with a lower hash.

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

Crafting and sending this transaction is not free.  To ensure that it gets
mined on-time, producer block reward disbursal for tenure N will not happen until a snapshot for
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

### Chain Consensus Rules

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
the caveat that any resulting state is _tainted_.  Tainted state, including
account balances, may be rolled back by the network if a Bitcoin fork occurs
(i.e. because it is not yet finalized).  Tainted state becomes untainted once a
subsequent state snapshot finalizes it.

The Clarity VM would be instrumented to track tainted state.  Any
transactions that causally depend on tainted state would also be tainted.  While
on-chain smart contracts may interact with tainted state, systems that use the
blockchain to carry out off-chain tasks (like exchanges and bridges) would only
act on untainted state.  The Stacks blockchain would report whether or not a
particular piece of state is tainted, and report when the taint is expected to
disappear.

To reduce the quantity of transactions that can be tainted through causal
dependency, this SIP requires that producers apply on-Bitcoin transactions at
the end of their blocks, instead of the beginning.

### Recovery from Bitcoin Forks

In the event that a Bitcoin fork arises and invalidates tainted state, the
Stacks blockchain would guarantee that _untainted_ transactions would remain
linearized.  Producer sets and stackers would reproduce the Stacks block history
from only untainted transactions, such that each untainted transaction is
mined in the same order as before and appears in the same Stacks block height.

Stackers in particular are responsible for ensuring that they only sign
reproduced blocks that contain exactly the same sequence of untainted transactions.
They only sign replacement blocks which contain the same untainted transactions
as before the Bitcoin fork.

Old Stacks blocks that contain potentially-invalid state are discarded.

### Bitcoin Forks and sBTC

The sBTC wallet operations already require sufficient Bitcoin confirmations that
it is effectively guaranteed that they will never be orphaned by the time the
producer set processes them.  As such, sBTC by itself is not treated as tainted
-- it can only materialize once its deposit transaction is sufficiently
confirmed, and it can only be destroyed once its withdrawal transaction is
sufficiently confirmed.  Consequently, sBTC transfers are not inherently
tainted either (anymore than any other Stacks transaction).

## Extension: Overdue Term

Naively, the execution budget available to block producers can be treated as
equal to the number of Stacks blocks' budgets today, multipled by the tenure
length.  Ideally, block producers would produce blocks at a rate such that under
network congestion, the tenure budget is completely consumed just as the tenure
ends.

It is very difficult in practice to realize this idealized block production
schedule, because the length of a tenure has very high variance.  If the block
producers reach their tenure budget before the tenure is over, then the Stacks
network stalls, which significantly increases transaction latency.

To eliminate these periods of idle time, this SIP proposes implementing a
replicated verifiable delay function (VDF) which block producers individually
run in order to prove that a tenure is taking too long.  If enough block
producers can submit VDF proofs that indicate that they have waited for the
expected tenure length, then if the tenure is still ongoing, their tenure's
execution budget grows by one additional tenure.  The process repeats forever --
as long as block producers can submit VDF proofs, they earn more execution
budget until their tenure ends.

TODO: finish

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

# Appendix A: Stacker DB Specification

TBD

## Peer Network Wire Formats

TBD

## Smart Contract Traits

TBD

## RPC Endpoints

TBD

