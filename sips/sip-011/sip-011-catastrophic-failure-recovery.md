# Preamble

SIP Number: 011

Title: Catastrophic Blockchain Failures and Recovery

Author: Jude Nelson <jude@stacks.org>

Consideration: Governance

Type: Meta

Status: Draft

Created: 8 February 2021

License: BSD 2-Clause

Sign-off:

Discussions-To: https://github.com/stacksgov/sips

# Abstract

This SIP describes the sanctioned procedures for recovering the state of the
Stacks blockchain in the event of a _catastrophic_ failure.  A failure qualifies
as a _catastrophic_ failure if and only if there is no conceivable way for the
correct nodes in the network to make progress and preserve safety without human
intervention.

This document describes how to identify a catastrophic failure, and how the
various parties in the Stacks ecosystem should work together to resuscitate the
blockchain.  Importantly, these procedures seek to minimize the degree of human
intervention and code change whenever possible.  Blockchains represent a social
contract between the people who run the nodes (see SIP-000), so care must be
taken to preserve the blockchain's expected SIP-described rules and behaviors
above all else.

# License and Copyright

This SIP is made available under the terms of the BSD-2-Clause license,
available at https://opensource.org/licenses/BSD-2-Clause.  This SIP’s copyright
is held by the Stacks Open Internet Foundation.

# Introduction

What does it mean for a blockchain to fail?  They are designed to be resilient
to node churn, individual node crashes, and (short-lived) network partitions,
but two broad categories of bugs can cause the whole blockchain network to enter
an irrecoverable state in which human intervention becomes necessary to recover.
This document qualifies these failure modes, and describes various procedures
for recovering from them.

The first class of bugs are _liveness failures_.  These are bugs that prevent
the blockchain from making progress.  For example, a bug that causes all nodes
in the network to simultaneously crash is a liveness failure.  As another
example, a bug that causes all nodes in the network to become unable to respond
to network requests is a liveness failure.

The second class of bugs are _safety failures_.  These are bugs in which the
blockchain itself permits state-transitions that are undesirable and
inconsistent with the design of the system.  For example, a bug that would let
anyone move anyone else's STX tokens would be a safety failure.  As another
example, a bug in which some Clarity code's execution led to the wrong result
(but consistent across the network) would be a safety failure.

This document describes the ways in which Stacks ecosystem participants can
coordinate to recover from various instances of these failure modes, and when it
is appropriate to use them.  These procedures include:

* Announcing a new point-release of the Stacks Open Internet Foundation's reference implementation of
  the Stacks node software
* Covertly fixing systemically-important nodes to fix security-sensitive bugs
* Altering or extending the p2p network protocol
* Soft forks, which constrain what kinds of transactions may be mined on the
  canonical fork
* Hard forks, which are backwards-incompatible upgrades

## A Note on Scope

The absence of a feature is not a catastrophic failure.  The blockchain behaving
consistently with the SIPs that describe its design is not a catastrophic
failure, even if the behavior is not desired.  This SIP does not describe how to
remedy these situations; it is only concerned with manual recovery procedures
and guidelines for restoring the network after a network-wide safety or liveness
failure is discovered.

## Terminology

In the remainder of this document, the following words refer to the following
things:

* "Foundation" refers to the Stacks Open Internet Foundation unless otherwise specified.
* "Stacks Core Developers" refers to the set of blockchain developers who are
  largely responsible for maintaining the Stacks blockchain reference
implementation.  A list of these developers can be found in the supplemental
file `SIP-011-001.txt` that comes with this SIP.  This list will be 
maintained by the SIP Steering Committee, its superiors, or its successors.

# Specification

The following catastrophic failure recovery procedures are presented in order
from least-disruptive to most-disruptive.  When choosing the recovery procedure
to execute, ecosystem participants should err on choosing the least disruptive
procedure that will fix the problem at hand.  A recovery procedure should only
be taken only once all less-disruptive recovery procedures have been considered
or tried.

## Procedure for Pushing out a Critical Bugfix Point-Release

In the event that a safety or liveness failure can be readily addressed in
public _without_ altering the blockchain's social contract (i.e. no changes to
the networking protocols, mining protocols, or chainstate validation protocols),
the following procedure will be carried out:

1. The code for the fix will be written and pushed to a Github branch prefixed
with `fix/` to the Stacks Blockchain reference implementation, hosted at
https://github.com/blockstack/stacks-blockchain.
2. The branch will be submitted as a pull-request to the `master` branch, and
will be reviewed and approved by at least two members of the Stacks Core
Developers group.
3. If warranted, an unofficial announcement will be made to various public
avenues where Stacks miners are known to gather, such as the Stacks Discord
server or the Stacks forum (https://forum.stacks.org), in order to inform them
that the source code to the fix is available to be inspected, built, and tested.
4. A build process will be triggered to produce pre-built binaries for users to
download.
5. Once the binaries are available, a cryptographically-signed email will be
sent from announce@stacks.org with the cryptographic digests of the binaries and
download links to them.  The email will detail any special considerations and
instructions for recovering from the bug.

Anyone can subscribe to receive critical bugfix emails by sending an email to
announce+subscribe@stacks.org.  Critical bugfix announcements will also be
posted to the Stacks forum (https://forum.stacks.org).

This procedure is further incorporated into procedures described below, and is
referenced as the "critical bugfix point-release procedure."

## Procedure for Pushing out Sensitive Bugfixes

Depending on the severity of the bug, it may be necessary for ecosystem
participants to quietly fix and/or reboot their nodes with a bugfix before
making any announcement.  For example, if the bug is an as-of-yet-unexploited
safety failure that could lead to loss or theft of digital assets, it may be
more prudent to silently upgrade vulnerable nodes before announcing the
vulnerability.

If it is necessary to do this, then the Foundation or an agent of its choosing
will reach out to vulnerable ecosystem participants with instructions on how to
proceed.  In order to minimize the chance that the details of an unexploited but
critical bug will be leaked, the Foundation (or its agent) may take any means
necessary to ensure its secrecy in order to protect unknowingly-vulnerable
users.  This may include, but is not limited to, requiring ecosystem
participants so contacted to sign a legally-binding non-disclosure agreement.

Once the vulnerability no longer poses a systemic threat to the Stacks ecosystem
(or once the bug gets exposed, whichever happens first), the procedure for
pushing out a critical bugfix point-release will be followed.

To encourage users who discover such sensitive blockchain bugs to report them
while keeping them secret, the Stacks Foundation will start a bug-bounty program that
will be set up once this SIP activates.

## Procedure for Altering Network Protocols

If a catastrophic failure can be traced to a bug in the Stacks blockchain's
network protocols (see SIP-003), and if it can be fixed without changing the
protocol(s) in an incompatible way, then it will be fixed through the critical
bugfix point-release procedure above.

The Stacks network protocols offer nodes a lot of leeway in how they are allowed
to behave, so it is unlikely that the protocol itself will need to be altered in
an incompatible way in order to recover from a catastrophic failure.  But that
does not by itself preclude the possibility of a catastrophic failure
originating from the network's design and/or implementation.  In all likelihood,
failures in the network protocol will be liveness failures.

Broadly speaking, a critical bugfix to the network protocols can take one or
both of the following two forms:

* Adding _new_ network messages whose handling does not interfere or interact
  with code for handling existing messages.
* Making an incompatible change to how the system handles _existing_ messages.

### Adding New Network Messages

If the catastrophic failure can be remedied by adding a new type of network
message which old nodes will ignore, then the procedure for rolling out the
bugfix is as follows:

1. If the message types are part of the p2p network protocol, a new bit pattern
must be defined the `services` bitfield in the p2p message preamble that
distinguishes nodes with the fix applied from nodes that do not have the fix.
This, in turn, will allow the fixed nodes to know when it is appropriate to use
the new message types.
2. The Foundation and other ecosystem entities will deploy new versions of their
nodes, which use the new `services` bitfield.
3. Once the Foundation believes that there are enough publicly-routable nodes
with the fix applied, it will begin executing the critical bugfix rollout
procedure per above.

In this procedure, the network versioning information is preserved.  Therefore,
this procedure is only appropriate if backwards-compatibility with other nodes
and downstream clients can be preserved.

This procedure should be executed instead of changing the networking protocol if
at all possible.

### Changing Existing Network Messages

If the catastrophic failure can only be remedied by changing the way nodes
handle an existing message, such that the change renders the node incompatible
with the network (i.e. unable to effectively participate in block
synchronization, relaying, and/or mining), then the bugfix will require rolling
out two concurrent versions of the network that share the same chainstate for a
time in order to allow people running old nodes a chance to upgrade.  The
deadline to upgrade (and the deadline at which the old, buggy code-paths will
cease to be supported) will be enforced programmatically by new nodes, and will
be measured in burnchain block heights.

This bugfix procedure consists of the following steps.

1. If at all possible, a version of the node software with the buggy code paths
disabled will be released in order to provide partially-degraded service while
booting up the new, incompatible version of the network with the fix applied.
This release may have certain features intentionally disabled, or may introduce
performance regressions, as long as doing so does not introduce any other
liveness or safety failures.
2. The Foundation and other ecosystem entities will run versions of the degraded
but functional node software from step 1, if applicable.  If a pre-built binary
needs to be generated to encourage its mass deployment, then it will be
announced via a signed email from announce@stacks.org as a critical bug-fix
point release, with instructions on how to proceed in the coming network
upgrade.
3. Once the immediate liveness or safety bug no longer manifests (even if it
means operating the blockchain in a degraded state), the Foundation will procure
a _testnet_ release of the node software with the incompatible fix applied.
Power users and ecosystem entities are encouraged to run this testnet release in
order to verify that it solves the problem and works correctly.
4. Once the Foundation and the participating ecosystem entities from step 2
are satisfied that the new network version solves the problem, the Foundation
will execute a second critical bugfix point-release for mainnet.  To the greatest extent
possible, the new networking code will remain compatible with the old but broken
network's message formats and interfaces.  The Foundation will provide a
detailed explanation of how old nodes will interact with new nodes as part of
this release's email from announce@stacks.org.
5. Once the new version of the network is running, each ecosystem entity,
including the Foundation, may independently decide when to shut down their
degraded nodes in favor of their new incompatible nodes.  It is highly
recommended that both versions are kept alive for as long as possible, so that
the blockchain can be resuscitated with the new network version while providing
service to downstream dependencies that are not yet compatible with the new
version.
6. The new software release in step 5 will set a reasonable deadline, measured
in burnchain block heights, at which point any legacy support for the old,
replaced networking code paths will be dropped.  This deadline will be no longer
than six months into the future.  The exact block height is chosen at the
discretion of the Foundation, with advice from affected ecosystem entities.

The Foundation will keep its old nodes online as long as it believes that there
is a systemic risk to shutting them down, and will send an email to
announce@stacks.org to indicate when support for the old network version will be
terminated.  This deadline may exceed the built-in deadline, at the Foundation's
discretion.

Note that if this procedure is used, ecosystem participants should expect no
fewer than three separate emails from announce@stacks.org -- one in step 2, one
in step 4, and one in step 5.  The email in step 5 will list the burnchain block
height at which support for any legacy, broken networking code will be dropped
(if applicable).

The developers who procure the new incompatible network version should take steps
to retain backwards-compatibility with old clients and old nodes to the greatest
extent possible until the upgrade deadline passes.  This is because at a
minimum, the new incompatible node code will need to boot off of an old node's
chainstate.

The incompatible node implementation must change any network version signaling
information (e.g. HTTP prefixes, p2p preamble version bytes, etc.) so that old
versions of the network do not attempt to contact it.

## Procedure for Soft Forks

A _soft fork_ is a backwards-compatible change to the blockchain's consensus
rules.  Soft forks work by constraining the set of state-transitions that may be
applied to the canonical chain tip.  Old nodes will remain capable of validating
the Stacks blockchain data without the new rules applied, and will still be able
to calculate the same canonical fork.

Soft forks are a potentially-contentious form of upgrade, and should be avoided
in favor of any of the above procedures if at all possible.  Therefore,
executing a soft fork necessarily requires a high degree of cooperation between
ecosystem participants in order to make sure a significant majority are onboard
with the changes.

A soft fork may be an appropriate course of action if healing a catastrophic
failure requires the following kinds of changes, among others (this list is
exemplary, and not exhaustive):

* Adding supplementary block data (and validation rules for it) that gets
  considered and stored "outside of" blocks, but which correct miners must
nevertheless produce in order to mine a valid block on the canonical fork.  For
example, a soft fork might require miners to include network routing state
alongside their blocks in order for their blocks to be considered valid.
* Denying or limiting access to a particular smart contract or address by not
  mining transactions that interact with it on the canonical fork.  For example,
a soft fork can be used to prevent miners from allowing an attacker to withdraw
digital assets from a popular but buggy smart contract.
* Preventing or constraining the blockchain from mining particular types of
  transactions that may be mined on the canonical fork.  For example, if a
partial cryptographic break is discovered for the Stacks blockchain's
key-signing algorithm that enables hackers to calculate some private keys from
on-chain data, a soft fork could prevent any transactions signed with vulnerable
keys from being mined until the true owner can authenticate themselves to the
miners through some other channel.
* Declaring a "flag day" for a subsequent hard fork, by declaring that the
  current node software will reach end-of-life status by a certain burnchain
block height.  This may be appropriate if the bugfix for the catastrophic
failure is temporary (e.g. if the design of concensus-critical code-paths in the
blockchain are at fault, and preclude a permanent fix).

There are multiple different ways to execute a soft fork.  This document only
discusses procedures for a _miner-actived_ soft fork whose goal is to address a
liveness or safety failure.  A subsequent SIP may codify other types of soft
forks and their applications in different contexts.  Due to the comparatively
low barrier-to-entry for mining on the Stacks chain, miner-activated soft forks
are expected to offer an acceptable measurement of the ecosystem's sentiments on
a pending soft fork.

A miner-activated soft fork procedure for healing a catastrophic failure works
as follows:

1. A majority of the Stacks Core Developers group will approve and
sign a Stacks node software release that implements the soft fork rules.  This
is the first step in this process because this new node software must address
whatever catastrophic bug that led to the need to follow this procedure.  The
remainder of this procedure is focused on codifying the new rules via the SIP
process in order to require them in future node software releases.  The act of
releasing this new node software will follow the critical bugfix point-release
procedure, but with an additional warning from the announcement email that this
new release is the beginning of a soft-fork roll-out.
2. Once the catastrophic bug has been addressed, and a reliable majority of
blocks on the canonical fork are produced by miners running the new software, a
SIP describing the soft fork will be written and published describing the new
rules and why they are necessary.  This SIP must then be advanced in the SIP
process to "activation-in-progress" status by the relevant advisory boards and
technical steering committee.  Among other things, this SIP's activation
criteria must require the following:

   * At least 80% of all mined blocks must _explicitly and continuously vote to
     accept_ the soft fork rules for at least _two consecutive_ whole PoX reward
cycles. Additional, stricter criteria are permitted.
   * An _activation window_, defined by a _start activation height_ and an _end
     activation height_, represented as burnchain block heights, must be
stipulated in the activation criteria.  The aforementioned miner vote must take
place and run to completion in-between these two block heights.  The block
heights _must_ correspond to the beginnings of PoX reward cycles, and must be
between 14 reward cycles (1 maximum Stacking period plus two reward cycles) and
25 reward cycles (about 1 year) apart.
   * A soft-fork-specific bit pattern must be specificied, which miners _must_
     include in their coinbase transactions in order to indicate unambiguous
support for activating the new rules.

3. Once a release with the soft fork voting rules and activation window is
written and adequately tested (possibly including rolling it out to one or more
public testnets first), it will be announced via a signed email from
announce@stacks.org.  This release announcement must occur before the activation
window begins.
4. If at least 80% of all blocks produced in two consecutive, whole reward
   cycles vote to accept the soft fork rules within the activation window, then the new
rules will take effect starting in the next whole reward cycle.  All new
releases of the Stacks node will adhere to the soft fork rules, since they are
now part of the block validation rules.
5. A signed email from announce@stacks.org will be sent once the new rules take
effect, urging all network participants to upgrade to a node that applies the
new rules.

Note that in this procedure, at least three emails from announce@stacks.org will
be sent -- one in step 1, one in step 3, and one in step 5.

Multiple soft forks may be processed in parallel, as long as their activations
do not conflict or depend on one another.

## Procedure for Hard Forks

A hard fork is backwards-incompatible blockchain upgrade.  They are to be
avoided if at all possible, because they are tantamount to making an entirely
new version of the blockchain that, if executed poorly, threatens to split the
ecosystem into two or more parts.  A hard fork is a fundamental re-working of
the social contract that the Stacks blockchain represents, and a successful hard
fork requires near-unanimous agreement on the new rules from all ecosystem
participants.

A hard fork is only necessary for repairing catastrophic failures if all other
procedures prove inadequate.  It is not to be used in any other circumstance.
Therefore, the kinds of catastrophic failures that necessitate hard forks are
artifacts of a design bug in the Stacks blockchain that renders it unsustainable
or unable to operate as intended.

Some examples of when a hard fork is the appropriate course of action include,
but are not limited to:

* The underlying burnchain is crashing or is rendered insufficiently reliable
  for the Stacks blockchain to keep making progress.
* The discovery of a cryptographic break in the signing/verifying algorithms
  used by the Stacks blockchain makes all funds vulnerable to theft.
* A severe bug in the consensus-critical code-paths leads to an irreconcilable
  chain split, where it is ambiguous as to which tip is the "true" tip.

Importantly, the following problems are _not_ worthy of a hard fork:

* Theft of funds due to buggy but correctly-executed Clarity code.
* Loss or theft of funds due to user error.
* Different opinions on the design of the Stacks blockchain.
* Different opinions on the design of an already-deployed smart contract.

Depending on the severity of the underlying bug, the procedure for executing a
hard fork presented here should be considered preliminary and incomplete.  At a
minimum, the following steps will be followed:

1. An announcement describing the situation will be sent via signed email from
announce@stacks.org
2. If at all possible, one of the above procedures will be executed to bring the
blockchain network back online in a degraded state at the latest point of
execution before where it had failed (as measured by burnchain block height).
3. If mining can be resumed, the soft fork procedure will be executed to vote
for a "flag day" that will cause this version of the blockchain to crash
permanently at the end of the voting period.  If mining cannot be resumed, then
this step is skipped.
4. A new version of the node software will be released via the critical bugfix
point-release procedure.  The node software will resume from the old chainstate
at the last block mined before the catastrophic failure was manifested (as
determined by the burnchain block height).

Step 3 should be executed if possible, because it gives the network a chance to
vote on the new rules.

Note that in this procedure, at least two emails from announce@stacks.org will
be sent -- one in step 1 and one in step 4.  However, given the severity of any
bug that can only be resolved with a hard fork, there may be many more
communications sent.

# Related Work

This section is a work in process.

Bitcoin has a codified process for soft fork votes.  It should be cited here.

Tezos has an even more extreme version of soft-forking than we support, but it's
still a related concept to be cited.

Ethereum is a good example of how _not_ to do hard forks -- they just happen
willy-nilly once enough "core developers" are on board.

# Activation

This SIP codifies the behaviors of the Stacks Core Developers and the Stacks
Open Internet Foundation in the event of a catastrophic blockchain failure.  It
also serves to inform all ecosystem participants on what to expect should such a
failure occur, and how it will be handled.

Because this SIP cannot be legally or programmatically enforced, a legal or
programmatic ratification process would be meaningless.  Therefore, it is
sufficient that the two affected parties -- the Stacks Open Internet Foundation
and teh Stacks Core Developers -- both unanimously approve this SIP by
cryptographically signing it an attaching their signatures as supplementary
files (in `SIP-011-001.txt`).  This must be carried out on or before 31 December 2021
at 23:59:59 UTC.

# Reference Implementation

Not Applicable
