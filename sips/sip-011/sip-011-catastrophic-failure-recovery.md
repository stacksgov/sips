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

### Example Application: Recover from a Network-wide Crash

Suppose that the Stacks blockchain software had a bug that caused all nodes to
crash when processing the same Stacks block.  If this happened, the Stacks
blockchain developers would coordinate with the Foundation to
promptly identify and create a fixed version of the
node software, and verify that it could correctly process the full Stacks
chainstate including the fault-inducing block.
They would then follow this procedure to roll out the new,
fixed version of the software.

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

### Example Application: Preemptively Fix a STX Minting Bug

Suppose that it was discovered that there existed a way to change the rate at
which new STX were minted.  If this bug had never been exploited to mint new
STX, the Stacks Core Developers would coordinate with the Foundation to quietly
release a patched version of the node software to miners, so that they could
prevent the bug from being exploited (and avoid mining transactions that could
lead to its exploitation on a fork).  Once sufficiently many miners had
upgraded, the Foundation would follow this procedure to announce the new node
software, and eventually, announce the vulnerability it patched.

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

### Example: Recover from a Network-wide DoS Vulnerability

Suppose a bug was discovered that could cause Stacks nodes to unintentionally
crash each other via certain kinds of network messages.  In this case,
the Stacks Core Developers would coordinate with the Foundation to
make a release of the node software that intentinally NACK'ed the problematic
messages, and would proceed to spin up public nodes with the new NACK'ing behavior.
These new public nodes would then be used to help the mainnet repair itself.
This effectively causes the mainnet to operate in a partially-degraded state for
the time being -- whatever feature was enabled by the now-NACK'ed messages will
no longer be functioning.  This has already happened once with the transaction
data attachment protocol.

At the same time, the Stacks Core Developers would work with the Foundation to
procure a new version of the node software with the _upgraded_ network protocol,
and deploy it to the Xenon testnet (a Stacks testnet that operates on top of
Bitcoin's `testnet3`).  Once they were satisifed that the new design and
implementation behaved as expected, they would coordinate the new release for
mainnet.

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
cycle prepare phases. Additional, stricter criteria are permitted.
   * An _activation window_, defined by a _start activation height_ and an _end
     activation height_, represented as burnchain block heights, must be
stipulated in the activation criteria.  The aforementioned miner vote must take
place and run to completion in-between these two block heights.  The block
heights _must_ correspond to the beginnings of PoX prepare phases, and must be
between 14 reward cycles (1 maximum Stacking period plus two reward cycles) and
25 reward cycles (about 1 year) apart.
   * A soft-fork-specific bit pattern must be specificied, which miners _must_
     include in the unused `memo` bits in their block-commit transactions on the
burnchain in order to unambiguously signal support for activating the new rules.
Different soft forks may (re)use the same bit pattern only if they have
non-overlapping activation windows.

3. Once a release with the soft fork voting rules and activation window is
written and adequately tested (possibly including rolling it out to one or more
public testnets first), it will be announced via a signed email from
announce@stacks.org.  This release announcement must occur before the activation
window begins.
4. If at least 80% of all sortitions in two consecutive, whole PoX prepare
   phases vote to accept the soft fork rules within the activation window, then the new
rules will take effect starting in the next whole reward cycle (i.e. right after
the second prepare phase finishes).  All new releases of the Stacks node will
adhere to the soft fork rules, since they are now part of the block validation rules.
5. A signed email from announce@stacks.org will be sent once the new rules take
effect, urging all network participants to upgrade to a node that applies the
new rules.

Note that in this procedure, at least three emails from announce@stacks.org will
be sent -- one in step 1, one in step 3, and one in step 5.

Multiple soft forks may be processed in parallel, as long as their activations
do not conflict or depend on one another.

### Example Application: Require PoX Anchor Block Confirmations

Suppose that a PoX anchor block was mined, but was never propagated.  This poses
an existential danger to the network, because the arrival of the anchor block at
a later date would trigger a deep chain reorganization.

To prevent this, miners could execute a soft-fork to require that a PoX
anchor block will be ignored if the majority of descendant PoX anchor blocks 
do _not_ confirm it.  To do so, Stacks Core Developers would coordinate to produce a
version of the node software that set a particular bit in the `memo` field to `1`
if the miner agrees with this new rule, and `0` if not.  The software would
start to enforce this rule once two consecutive PoX reward cycles' prepare
phases had 80% of their winning sortitions set this bit (if the sortition was
empty, it counts as a `0`).

Miners do not need to wait until the soft fork rules activate to begin to
enforce this rule -- in this particular case, the Stacks Core Developers would code
the new node software so the rule was already activated by default (but such
that the miner could opt out).  If the soft fork activates, however, then the
rule becomes part of the consensus rules, and cannot be reverted.

### Example Application: Replace the PoX Smart Contract

Not all soft forks can be deployed incrementally; some will require that the
network enforces them all at once.

Suppose a bug is discovered in the PoX smart contract that prevents it from
paying every Stacker their due burnchain tokens.  Because the bug occurs on the
PoX path, not the PoB path, it could be replaced with a new PoX smart contract.
To do this, the Stacks Core Developers
would publish the new PoX smart contract, and miners would
execute a soft fork to ensure that a Stacks block would only be considered valid
if it adhered to both the old and new PoX smart contracts' rules.  The new PoX
smart contract would choose the reward set and control Stacking, but the old
smart contract (and associated block-commit validation logic) would continue to
be used to choose winning blocks.

To achieve this, the Stacks Core Developers would release a version of the mining
software that simply ignored all `stack-stx` contract-call transactions
to the old PoX smart contract, effectively forcing it to operate in PoB-only mode.
The developers would also alter the block-commit transaction structure on the
burnchain such that in addition to producing the PoB burn, miners would create two
more payments whose combined value was a constant multiple of the burn output.
For example, if the multipler was 3 and the miner burnt 0.001 BTC, then the
miner's block-commit would contain two additional payments of 0.001 BTC, each
destined to new reward addresses chosen by the new PoX smart contract.  This
constraint ensures that miners continue to be obliged to pay Stackers more burnchain 
tokens in order to increase their chances of winning the block sortition.

Both the old and new validation rules for block-commits will only consider 
the PoB outputs to calculate the block winner.  But, the new PoX smart
contract, and its new rules for selecting reward address recipients, would
be used to determine which reward addresses will be paid in the block-commit's
new payment outputs.  In addition, the new PoX smart contract would
have its own rules for determining the reward set, thereby fixing the bug.
Once the new rules take effect, miners would
ignore all Stacks blocks that were mined using the old block-commit format --
they would then be treated as missing.

Because this soft fork would change how the reward address set is calculated,
and change how much (and to whom) the miners must pay, miners will need to
activate the new PoX contract on a "flag day."  To pick this flag day, the
miners voting in favor would set a particular bit in their block-commits' `memo`
fields to `1` to indicate support, and if over 80% of the sortitions in any two
consecutive PoX prepare phases vote in favor, then the new block-commit
validation rules would take effect at a predetermined block-height after the
activation, to be stipulated in the soft fork implementation
(e.g. perhaps 2100 burnchain blocks later).

Old nodes would be able to continue to validate and process the blockchain, even
if they were not aware of the new soft-fork rules.  This is because they do not
validate the new block-commit payment outputs; they only pay attention to the
PoB output and the old Stacking implementation (which both the old and new rules
continue to use for selecting block winners).  To these nodes, it appears as if
the Stacks blockchain has switched to operating in PoB mode indefinitely.
Therefore, it would not be a safety violation of the protocol to carry out this
soft fork.

### Example Application: Fix a Bug in Smart Contract Processing

Suppose a bug is discovered in the Clarity VM that permits anyone to take anyone
else's STX.  This bug would affect every smart contract, since it affects the VM
itself.  Suppose that the bug could only be triggerred by running Clarity code
-- i.e. other transaction variants like STX-transfers or Coinbases did not
trigger the problem.  Also, suppose that this bug is public knowledge, meaning
that exploits are occuring in the wild.

To recover from this bug, the Stacks Core Developers would release a version of the
mining software that both rejected smart contract and contract-call
transactions, in order to prevent future theft of STX.  In addition, the fix
would cause miners to generate blocks that descend from the highest Stacks block
_before_ the first instance of the exploit.  In doing so, miners running the new
software would work on a set of forks in which no subsequent smart contracts and
contract-calls execute.

In addition, the Stacks Core Developers would coordinate with the Foundation to
release a version of the node software that included a fix for the bug, as well
as code to re-activate smart contracts under the condition that
the vast majority of miners have _rejected_ all the forks in
which this bug's exploits have occurred.  In other words, smart contracts would
only re-activate if a fork that does _not_ descend from any block in which an
exploit occurs becomes the dominant fork.

In order to activate this soft fork, the vast majority of miners would first need
to download and run the modified mining software which prevents smart contracts
from running.  This version would set a bit in the block-commit `memo` field to
`1` to indicate that this particular soft fork is in the process of activating.
Once there has been sufficient network support -- namely, at least 80% support
from at least two PoX prepare phases -- then it would indicate that the miners
have applied the fix to the Clarity VM and all blocks in which STX were stolen
were orphaned.  At this point, it would be safe to re-activate smart contracts.

Fixing this problem can be done as a soft fork because changing the VM to consider a block
to be valid but orphaned, whereas older VM versions would accept it as valid, is a
backwards-compatible change.  Old nodes would not notice any deviation from
the original protocol; instead, they would switch from tracking a fork in
which the exploits occured to a fork in which they did not.  New nodes would
still process blocks with the exploit, but they would not relay them or (if
mining) build on them.

Like the "change the PoX smart contract" example, this soft fork would be
executed as a "flag day" change.  At a pre-determined block height after
activation, all new Stacks nodes would cease to recognize blocks with the
exploit behavior as valid.  They would still permit Stacks miners to mine these
blocks, and they would appear as valid to old nodes, but new nodes would never
relay or confirm them.

### Example Application: Preemptive Upgrade to a New Signature Algorithm

Suppose that the ECDSA design needs to be updated (e.g. suppose the availability of 
general quantum computers is imminent).  If so, then the network can
preemptively migrate to a post-quantum signature scheme via a soft-fork.

To do so, the Stacks Core Developers will use the `additional_data` field in a Stacks
P2P message structure (see SIP-003) to allow a transaction's sender to broadcast ancillary
post-quantum signature data along with the transaction.  This extra information
will be stored alongside the block data, and validated _in addition to_ the
ECDSA signatures.  A transaction will only be considered valid if both the ECDSA
signature validates and the post-quantum signature validates.  Blocks that
contain transactions in which the ECDSA signature validates, but the
post-quantum signature does _not_ validate (or is absent) will be accepted but
orphaned and not relayed.

This soft fork can be rolled out incrementally by miners who want to test out
the post-quantum signature validation code themselves, but the block orphaning
behavior will need to take effect via a "flag day."  Before the flag day, miners
can make their own decisions as to which blocks to build on and which to
consider absent.  After the flag day passes (executed via a soft fork), then
all miners must orphan blocks without valid post-quantum signature data.

Old nodes will continue to operate as before, because they only validate the
ECDSA signature data.  Even if quantum computers become available at a later
date, the fact that the vast majority of the mining power uses a post-quantum
signature scheme will ensure that the longest Stacks fork will, in expectation,
be composed of unforged transactions.  Even if a malicious miner uses a quantum
computer to mine a block with forged transaction data, the honest
miners will never build on top of it.

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

### Example: Bitcoin Changes `OP_RETURN`

Right now, the reference implementation of Stacks relies on embedding 80 bytes
of data within a Bitcoin transaction's `OP_RETURN` output.  The ability to do so
was not native to Bitcoin; it was added in October 2013 as 80 bytes [1], then
reduced to 40 bytes in February 2014 [2], and then restored to 80 bytes again in 
February 2015 [3].

It is entirely possible that the Bitcoin network opts to change or remove
`OP_RETURN` outputs altogether, or take other steps to remove functionality that
the Stacks blockchain depends on.  These sorts of changes will necessitate a
hard fork of the Stacks chain, because it will be rendered unable to function
without a breaking change to the way it processes its block-commits and VRF key
registrations.  A soft fork cannot address this problem.

If this does happen, the Stacks Core Developers will release a new version of the
node software as quickly as practical via the above procedure.  It will resume
mining from the state of the network as it was at the height of the last Bitcoin
block that permitted 80-byte `OP_RETURN` outputs.

[1] https://github.com/bitcoin/bitcoin/pull/2738

[2] https://github.com/bitcoin/bitcoin/pull/3737

[3] https://github.com/bitcoin/bitcoin/pull/5286

### Example: A SHA512/256 Break is Found in the Wild

Suppose that the SHA512/256 hash algorithm is broken, making it tractable for
attackers to generate two or more valid Stacks blocks with the same hashes.
While unlikely, this would be justification for a hard fork that changed the
hash function the software used internally for block hashes and state roots (see
SIP-004).

This would mean that it would be ambiguous as to which chain tip is the true
chain tip.  Supposing that the date of the exploit's first appearance on the
world stage could be found, the most likely outcome would be that the Stacks
developers would release a version of the software that only permitted mining
off of the Stacks blocks that were mined before this date.  In the mean time,
they would release a version of the software that permitted miners to only
mine empty blocks and permitted them to _kill_ the current chain, and to 
vote to confirm the final valid Stacks block (by building PoB block-commits
on it).  The Stacks Core Developers would encourage miners to use this degraded
version for the time being, so they can vote to activate a _completely new_
version of the node software that used a different hash function.

This new version would be incompatible with the old version, and would be
designed to simply use a particular chainstate as its genesis state.  All prior
blocks would need to be discarded.  The chainstate it would use would be voted
upon by miners -- for example, the chainstate corresponding to the first Stacks
block to receive 2100 confirmations from empty block commits produced by the
degraded software would be selected as the new genesis chainstate.  The degraded
software would be written so that it simply stopped processing new Bitcoin
blocks once the 2100 confirmation threshold was reached, necessitating a
migration to the new Stacks node with the voted-upon chainstate as its genesis
state.

# Related Work

Bitcoin has a codified process for soft forks in BIP 009 [1].  The soft-fork
procedure described here represents a similar effort by representing soft fork
signals as bit patterns in block header information over time, but is tailored
specifically to the unique properties of the Stacks blockchain.  In addition,
this SIP only proposes soft forks of this nature as a catastrophic recovery
tool, such as when the contents of Stacks blocks themselves may not be available
or reliable.

Tezos has an in-band procedure for changing the consensus rules directly [2] via
an amendment process.  While superficially similar in spirit to this SIP, this
SIP is only concerned with altering the Stacks blockchain consensus rules in
order to recover from failures.  A separate SIP may be written later to provide
a way to carry out non-breaking consensus changes for other purposes (and may
opt to re-use the procedures described in this SIP if appropriate).

Ethereum famously does _not_ rely on any sort of in-band signaling for changing
consensus rules [3], and instead relies on both ratification from an "All
Core Devs" meeting and individual miners' and clients' choices to upgrade.
This SIP takes the position that such a procedure would be inappropriate
for changing the Stacks blockchain's consensus rules, even in
the narrow sense of recovering from a catastrophic failure.  This is because the
Stacks blockchain uniquely (1) permits Stacks miners to identify and avoid
problematic transations (a property bequeathed to them by Clarity's decidability),
and (2) permits in-band signaling between miners through a
_separate blockchain_ via block-commit transactions, thereby obviating the need
to decide when changes happen out-of-band.  It is the opinion of this SIP's authors
that the approach of using Stacks block-commit transactions, as opposed to
having in-person meetings, makes the Stacks blockchain _more receptive_ to
users' needs and _less reliant upon_ a specific set of people to meet them,
because sending burnchain transactions has a lower barrier to entry for
participation.

[1] https://github.com/bitcoin/bips/blob/master/bip-0009.mediawiki

[2] https://tezos.com/static/white_paper-2dc8c02267a8fb86bd67a108199441bf.pdf

[3] https://eth.wiki/en/governance/governance-compendium

# Activation

This SIP codifies the behaviors of the Stacks Core Developers and the Stacks
Open Internet Foundation in the event of a catastrophic blockchain failure.  It
also serves to inform all ecosystem participants on what to expect should such a
failure occur, and how it will be handled.

Because this SIP cannot be legally or programmatically enforced, a legal or
programmatic ratification process would be meaningless.  Therefore, it is
sufficient that the two affected parties -- the Stacks Open Internet Foundation
and the Stacks Core Developers -- both unanimously approve this SIP by
cryptographically signing it an attaching their signatures as supplementary
files (in `SIP-011-001.txt`).  This must be carried out on or before 31 December 2021
at 23:59:59 UTC.

# Reference Implementation

The soft-fork activation logic, as well as logic for helping miners disable
transactions by variant and opt to mine off of (or not mine off of) particular
blocks will be implemented in the reference Stacks blockchain, available at
https://github.com/blockstack/stacks-blockchain.
