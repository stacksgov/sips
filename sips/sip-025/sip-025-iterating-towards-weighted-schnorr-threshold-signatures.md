# Preamble

SIP Number: 025

Title: Iterating towards Weighted Schnorr Threshold Signatures

Authors:

* Aaron Blankstein (aaron@hiro.so)
* Brice Dobry (brice@hiro.so)
* Crypt0jan (jan@alumlabs.io)
* Jacinta Ferrant (jacinta@trustmachines.co)
* Jude Nelson (jude@stacks.org)
* Hank Stoever (hank@trustmachines.co)
* Joey Yandle (joey@trustmachines.co)

Consideration: Technical

Type: Consensus

Status: Draft

Created: 14 May 2024

License: BSD 2-Clause

Sign-off:

Discussions-To:

# Abstract

SIP-021 defines a threshold signature scheme called Weighted Schnorr Threshold
Signatures (WSTS), a Schnorr signature scheme based on FROST whereby a set of
mutually-distrustful parties produce a single Schnorr signature from shares of a
private key.  No party knows the private key; a signature can only be produced
if a threshold of parties agree to produce a signature.

WSTS is used in SIP-021 to provide a means for Stackers to collectively append
blocks to the Stacks blockchain in a way that achieves Bitcoin finality for
Stacks.  Because a block can only be attached if a large fraction of the stacked
STX votes for the block, the Stacks blockchain will not fork on its own as long
as at least 30% of STX votes are honest.  In the absence of network partitions,
Stackers always see the same Stacks chain tip and thus can compel Stacks miners
to build atop it (and refuse to sign blocks from miners that do not do this).

This SIP describes an incremental approach to achieving this end (Bitcoin
finality) via a simpler, but less efficient means:  have each Stacker append a
signature to the block, and do not aggregate them.  This approach makes blocks
bigger (but tolerably so), and does not meaningfully slow down validation.  By
implementing this means first, before WSTS is ready, SIP-021 can be ratified
sooner than later.

# Introduction

WSTS, being a variant of FROST, requires that signers designate a particular
signer as a coordinator to facilitate both the _distributed key generation_ (DKG)
and _signing round_ steps of the protocol.  But because signers are distributed
and mutually distrustful, the setting for WSTS coordinator selection is
fundamentally a Byzantine setting.  Not only can individual signers be faulty,
but also the coordinator may be faulty.  This necessitates a Byzantine
fault-tolerant (BFT) protocol for making forward progress on DKG and signing
rounds (something that the FROST authors leave as an exercise to the
implementer), in which faulty signers and coordinators can be identified by a
BFT majority and excised from the next round of the protocol.

Excluding a Byzantine signer from WSTS is trivial if the coordinator is honest:
the coordinator restarts the protocol without including the Byzantine signer.
Other signers do not communicate with the Byzantine signer, because the
coordinator has not designated that signer as part of the signer set.

But what happens when the coordinator is faulty?  To oust a Byzantine
coordinator, signers must execute a BFT protocol amongst themselves to select a
new coordinator.  But in order to deal with this problem, coordinator selection
will:

* be a best-effort process that could result in an unrecoverable signer split
  (and subsequently a chain stall),
* implement leader election with BFT Paxos (or something equivalent), or 
* implement some "in between" solution. 

The first option is a non-starter, because signers work in a Byzantine setting.

The third option is a false option.  The history of distributed systems should
teach us that any such half solution is either broken, or eventually becomes a
(bad) implementation of BFT Paxos anyways.

Of these options, it should be clear that the second option is the best -- it
applies a well-known protocol to solve the exact kinds of problems it was
designed to solve. However, implementing BFT Paxos is a serious undertaking, and
applicable libraries are not readily available.

Why propose this SIP at all, then, if the only path to a viable WSTS
implementation is to implement coordinator selection via BFT Paxos?  The reason
is that WSTS is not an end but a _means_ of achieving Bitcoin finality.  There are
other, simpler means to achieving this in a Byzantine setting that are less
efficient, but simpler to implement and more robust to failure than WSTS which
can be used to implement the goals of SIP-021 while a complete WSTS with
BFT-Paxos implementation is developed.

To achieve this, we propose an iterative approach to signer-set signatures in
Nakamoto, spread across two hard forks:  one to implement a simpler but
less-efficient signer-set signature which can be delivered sooner, and one to
implement the complete WSTS scheme with BFT Paxos coordinator selection.

# Specification

Nakamoto signer-sets would be implemented in two iterations, where each
iteration takes effect with a hard fork.  The first iteration would activate
with SIP-021 if this SIP is ratified before SIP-021 activates.

## Iteration 1 

In Epoch 3.0, the signer set does not use WSTS to aggregate a signature, but
instead simply provides a concatenation of signatures (like Bitcoin's P2SH
multisig). Each signer binary listens to their paired Stacks node for block
proposals, and individually computes a signature over the block if they approve
it. This signature is sent to the miner via StackerDB, which gathers and
includes the signatures in their block. Each 3.0 block header includes all of
the signatures required to reach the signer set approval threshold (as discussed
in SIP-021). Apart from the signature scheme, the rest of Nakamoto's consensus
rules would be identical. This allows for a simpler signature scheme to
implement the rest of the Nakamoto system. 

## Iteration 2

Once iteration 1 is stable and SIP-021 activates, WSTS will be used to improve
the efficiency of the system. Leader election with BTF Paxos will be implemented
during this iteration.  This iteration will require some significant design
work, and will be fully specified in a future SIP which describes the hard fork
in total.

Figure 1: Nakamoto Block Header in Iterations 1 and 2

```diff
--- a/stackslib/src/chainstate/nakamoto/mod.rs
+++ b/stackslib/src/chainstate/nakamoto/mod.rs
@@ -305,8 +305,8 @@ pub struct NakamotoBlockHeader {
     pub state_index_root: TrieHash,
     /// Recoverable ECDSA signature from the tenure's miner.
     pub miner_signature: MessageSignature,
-    /// Schnorr signature over the block header from the signer set active during the tenure.
-    pub signer_signature: ThresholdSignature,
+    /// The set of recoverable ECDSA signatures over
+    ///   the block header from the signer set active during the tenure.
+    ///   (ordered by reward set order)
+    pub signer_signature: Vec<MessageSignature>,
     /// A bitvec which represents the signers that participated in this block signature.
     /// The maximum number of entries in the bitvec is 4000.  The ith bit represents
     /// the participation of the ith signer, in reward set order.
     pub signer_bitvec: BitVec<4000>,
```

The primary impact on the Stacks protocol is in the block header (Figure 1). The
Nakamoto block header must include a vector of recoverable ECDSA signatures.
This is variable length, depending on the number of signers who participated in
the block's construction. Validation of a Nakamoto block header requires
validating each of these signatures against the reward cycle's signing set,
summing their weights until the threshold is reached. If any signature in the
header is invalid, the block is invalid; if there are duplicate signatures in
the header, the block is invalid; if the total weight of the signatures is not
greater than or equal to the signing threshold, the block is invalid.

## Impact on Chainstate

Each signature will occupy 65 bytes of the block header. This is a small, but
decidedly not negligible overhead in the block header. In the worst case
scenario (i.e., there are 4000 distinct signers in the set), this would be 182
KB. Depending on the size of each block in the network, this could represent an
overhead of 5%-50% in terms of network bandwidth. However, if the signer set
distribution is similar to stacker set distributions in pre-3.0 epochs, we
expect around 100 distinct signers, meaning an overhead of ~4.5KB (the most
distinct PoX addresses in a reward set was 270, but fewer signatures than 270 is
required to clear the threshold). This is still not an ideal block header size:
WSTS is still an important feature for Nakamoto, however, concatenated
signatures is a worthwhile step along the way.

## Benchmarks

To confirm that this change does not meaningfully impact chain validation, one
of the authors tested an implementation of Iteration 1 block header.  In this
experiment, it took about 12.38ms to verify 300 signatures sequentially.  For
1400 signatures -- 70% of 2000, the maximum possible number of signatures --
the time to validate is 58.62ms.  Thus, validation time is not a concern.


## Stacks Signer Binary

The stacks signer binary is still responsible for signing block proposals. It
does not need to perform the WSTS DKG protocol for generating the signer set's
aggregate public key, but it still needs to perform Stacks and Bitcoin state
tracking in order to monitor correct miner behavior and prevent any
miner-initiated forking. Because the signer binary no longer needs to perform
DKG or distributed signing, coordinator selection is no longer necessary.
Practically speaking, this also obviates the need for signers to vote for an
aggregate public key in the prepare phase (which eliminates the failure
conditions arising from a vote failure), and it obviates the need for signers to
send Stacks transactions and spend STX (or require the signer to compel miners
to admit these transactions for free).

While signers and miners continue to operate in a Byzantine setting, the
consequences of Byzantine activity remain as they are in SIP-021:

| Condition             | Honest miner                      | Faulty miner |
| --------------------- | --------------------------------- | -----------  |
| >= 70% honest signers | Liveness and safety are preserved | Safety is preserved, but not liveness |
| >= 30% honest signers, but less than 70% | Safety is preserved, but not liveness | Safety is preserved, but not liveness |
| < 30% honest signers | Safety is preserved, but not liveness | Catastrophic failure (see SIP-011) |

# Related Work

The signature scheme presented in iteration 1 is
essentially the same as a Bitcoin p2sh script.  The signers each produce a
signature over a _sighash_ -- a hash over the block header besides the
signatures.  Signers can sign in any order.

BFT Paxos is a well-understood and widely-used BFT agreement protocol.  This SIP
proposes (but does not specify in detail) that it be used for WSTS coordinator
selection in iteration 2 of the Nakamoto signer-set signature.

# Backwards Compatibility

This change does not alter the goals of SIP-021, but it does alter
the means.  However, SIP-021 is not activated, so there is no consideration for
backward compatibility above and beyond that prescribed in SIP-021.

# Activation

This SIP is only meaningful if SIP-021 activates, and only
meaningfully affects the workloads of Stackers.  As such, this SIP activates if
(1) SIP-021 activates, and (2) the Stackers demonstrate that they agree with
these changes.

To demonstrate signer agreement, it is sufficient for signers to produce a
SIP-018 signed structure data payload indicating a yes or no vote.  The domain
tuple shall be

```clarity
{
   "name": "SIP-025",
   "version": "1",
   "chain-id": u1
}
```

The structured data to sign will either be the ASCII string `yes` (for a
yes-vote) or `no` (for a no-vote).


Signer agreement will be demonstrated if and only if there exists a reward cycle
N between the current one (cycle 84) and the second-to-last cycle of Stacks 2.5,
such that:

* at least 70% of the signers vote "yes" (as weighted by STX) in cycle N
* fewer than 30% of the signers vote "no" (as weighted by STX) in cycle N+1

This scheme allows signers who feel strongly against this SIP to reject it in
cycle N+1, even if they are not stacked in cycle N.

# Reference Implementation

This SIP is implemented in the Stacks blockchain repository, available at
https://github.com/stacks-network/stacks-core. 
