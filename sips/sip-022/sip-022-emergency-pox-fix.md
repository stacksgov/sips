# Preamble

SIP Number: 022

Title: Emergency Fix to PoX Stacking Increases

Authors:
    Aaron Blankstein <aaron@hiro.so>,
    Jude Nelson <jude@stacks.org>

Consideration: Technical, Governance

Type: Consensus

Status: Draft

Created: 19 April 2023

License: BSD 2-Clause

Sign-off: 

Discussions-To: https://github.com/stacksgov/sips

# Abstract

On 19 April 2023, it was discovered that there was a bug in the PoX smart
contract which would allow a user to claim that they have stacked far, far more
STX than they had locked.  Exploiting this bug both allows the user to increase
their PoX reward slot allotment, while also driving up the stacking minimum.
Furthermore, it creates the conditions for a network-wide crash:  if the total
amount of STX stacked as reported by the PoX smart contract were to ever exceed
the total amount of liquid STX, then the node would crash into an irrecoverable
state.  This bug has already been triggered in the wild.

This SIP proposes **two immediate consensus-breaking changes** that both prevents this bug
from being triggered in subsequent reward cycles, and replaces the current PoX
implementation with a new PoX implementation without the bug.  If ratified, this
SIP would activate two hard forks 200 Bitcoin blocks prior to the start of
reward cycles #58 and #59.

This SIP would constitute two consensus-rules version bumps.  During cycle #58, the system 
version would be Stacks 2.2.  During and after cycle #59, the system would be
Stacks 2.3.

# Introduction

[SIP-015](./sips/sip-015/sip-015-network-upgrade.md) proposed a new PoX smart
contract, `pox-2`, which included a new public function `stack-increase`.  This
function allows a user to increase the amount of STX locked for PoX while the
account has locked STX.  The `stack-increase` function calls an internal function
`increase-reward-cycle-entry` to update the PoX contract's data space to record
the increase.

The `increase-reward-cycle-entry` function has a bug in this code path.  The bug
itself is annotated with a comment lines starting with "(BUG)".

```clarity
(let ((existing-entry (unwrap-panic (map-get? reward-cycle-pox-address-list { reward-cycle: reward-cycle, index: reward-cycle-index })))
      (existing-total (unwrap-panic (map-get? reward-cycle-total-stacked { reward-cycle: reward-cycle })))
      (total-ustx (+ (get total-ustx existing-total) (get add-amount data))))
    ;; stacker must match
    (asserts! (is-eq (get stacker existing-entry) (some (get stacker data))) none)
    ;; update the pox-address list
    (map-set reward-cycle-pox-address-list
             { reward-cycle: reward-cycle, index: reward-cycle-index }
             { pox-addr: (get pox-addr existing-entry),
               ;; (BUG) ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
               ;; (BUG) `total-ustx` is the amount of uSTX locked in this cycle, not
               ;; (BUG) the stacker's total amount of uSTX. This value ought to be
               ;; (BUG) `(+ (get total-ustx existing-entry) (get add-amount data))`
               ;; (BUG) ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
               total-ustx: total-ustx,
               stacker: (some (get stacker data)) })
    ;; update the total
    (map-set reward-cycle-total-stacked
             { reward-cycle: reward-cycle }
             { total-ustx: total-ustx })
    (some { first-cycle: first-cycle,
            reward-cycle: (+ u1 reward-cycle),
            stacker: (get stacker data),
            add-amount: (get add-amount data) })))))
```

The bug is reachable by any solo Stacker who calls `stack-increase`.  Any solo
Stacker who increases their total STX locked will erroneously set the amount of
uSTX backing their PoX address to be equal to the current total number of uSTX
locked in this cycle (the value `total-ustx`), instead of the sum of their
current locked uSTX amount and their added amount.  The act of triggering this
bug is an unavoidable consequence of calling the `stack-increase` function --
individuals who call `stack-increase` are not thought to be deliberately
exploiting the system.

This bug was first triggered in the wild by Stacks transaction
`20e708e250bad3fb5d5ab84a70365c3c1cf0520c7a9f67cd5ff6b9fa94335ea5`.

The immediate consequences for PoX of this bug being triggered are as follows:

* The total STX locked to the PoX address owned by the caller of `stack-increase`
  will be potentially higher than the amount of STX that the caller possesses.
The caller will receive PoX payouts _as if_ they had locked that much STX.  So,
the caller receives undue BTC.

* The stacking threshold is raised to account for the PoX contract's reported
  increase in STX locked.

Furthermore, if this bug is triggered enough times, the Stacks network will crash.  This is
because of a runtime assertion in the PoX reward set calculation logic that
verifies that the total locked STX does not exceed the total liquid STX.  This
would no longer be true due to this bug.  The offending assertion is detailed
below:

```rust
pub fn get_reward_threshold_and_participation(
    pox_settings: &PoxConstants,
    addresses: &[RawRewardSetEntry],
    liquid_ustx: u128,
) -> (u128, u128) {
    let participation = addresses
        .iter()
        .fold(0, |agg, entry| agg + entry.amount_stacked);

    assert!(
        participation <= liquid_ustx,
        "CORRUPTION: More stacking participation than liquid STX"
    );
```

The `RawRewardSetEntry` data are pulled directly from the
`reward-cycle-pox-address-list` data map, and the `.amount_stacked` field is
equal to the `total-ustx` field that was erroneously set in `stack-increase`.

Considering these consequences with respect to the [draft blockchain catastrophic
failure and recovery guidelines](https://github.com/stacksgov/sips/pull/10),
this bug would be categorized as requiring an _immediate_ hard fork to rectify.
The network has not yet crashed, but it is in imminent danger of crashing and
there is insufficient time to execute a Stacker-based SIP vote as has been customary for
past hard forks.  This SIP instead proposes that this hard fork activate at the
start of the next reward cycle (#58) at the time of this writing.

There is less than one reward cycle remaining to fix this
problem, and yet a Stacker vote would require at least one complete reward cycle
to carry out vote (not accounting for any additional time required for
sending out adequate public communications and tabulating the vote afterwards).
A subsequent hard fork to re-enable PoX would have the effect of restoring
Stacker voting.

# Specification

Given the lack of time to conduct a Stacker vote to activate this SIP, the
proposed fix in this SIP is as parsimonious and discreet as possible.  It will
execute as a set of **two hard forks**.

The first hard fork, which activates at the start of reward cycle #58 will disable PoX.
This hard fork would do the following:

* Prevent all stacking functions from being called in `pox-2`.  The `pox-2`
  contract would be considered defunct, like the `pox` contract is now.

* Set the minimum required block-commit memo bits to `0x07`.  All block-commits
  after the Bitcoin block activation height must have a memo value of at least
`0x07`.  This ensures that miners that do not upgrade from Stacks 2.1 will not
be able to mine in Stacks 2.2.

* Set the mainnet peer network version bits to `0x18000007`.  This ensures that follower
  nodes that do not upgrade to Stacks 2.2 will not be able to talk to Stacks
2.2 nodes.

The second hard fork will deactivate `pox-2` and instantiate a new PoX
implementation `pox-3`.  The `pox-3` contract code will:

* Fix the aforementioned `stacks-increase` bug.

* Add a `delegated-to` field in the `stacking-state` data map, so that the
  `stacking-state` entry for a PoX user will indicate the principal to which
their STX are delegated (if they are using delegated stacking).

* Add checks to the delegated stacking public functions that validate the
  `delegated-to` field in the Stacker's `stacking-state` map entry.

* Set the minimum required block-commit memo bits to `0x08`.  All block-commits
  after the Bitcoin block activation height must have a memo value of at least
`0x08`.  This ensures that miners that do not upgrade from Stacks 2.2 will not
be able to mine in Stacks 2.3.

* Set the mainnet peer network version bits to `0x18000008`.  This ensures that follower
  nodes that do not upgrade to Stacks 2.3 will not be able to talk to Stacks
2.3 nodes.

## Alternative Approaches Considered

It is unusual that this SIP proposes two hard forks in rapid succession without 
a Stacker-based vote for activating the new rules.  The
reason for this is because PoX must first be disabled prior to the start of
reward cycle #58 in order to avert a network-wide
crash.  This cannot be delayed, but there is insufficient time to prepare `pox-3`
or even execute a Stacker-based vote before this bug must be addressed.
Therefore, the first hard fork must happen immediately.

A second hard fork is necessary to instantiate `pox-3`, which must also happen
as soon as possible (no more than one reward cycle later) in order to restore
critical functionality to the Stacks blockchain.  Because PoX would be disabled
before `pox-3` would activate, there would not exist a means of carrying out a
Stacker-based vote to upgrade the system (as had been the case in all prior
hard forks).  Beyond receiving a BTC yield, **the lack of a functioning PoX contract
prevents consensus-level SIPs from being voted upon**, which necessitates an
expedient restoration.

A less-disruptive alternative approach of repairing the
`reward-cycle-pox-address-list` data map was considered.  This would have only
required a single hard fork, and no disruption of PoX payouts (however,
`stack-extend` would have been disabled).  This approach was ultimately dropped
because of the interactions between delegated stacking and solo stacking -- it
would not be possible to retroactively compute the correct values for the
`reward-cycle-pox-address-list` data map.  This, in turn, meant that any repair
tactic would require the node to calculate the correct values for
`reward-cycle-pox-address-list` as the blocks in reward cycle #57 were
processed, which in turn meant that nodes would need to boot from genesis to
derive the correct data with which to repair the data map at the start of reward
cycle #58.  There is insufficient time to implement, test, and deploy this
approach.

# Related Work

Consensus bugs requiring immediate attention such as this
have been detected and fixed in other blockchains.  In the
absence of a means of gathering user comments on proposed fixes, the task of
activating these bugfixes has fallen to miners, exchanges, and node runners.  As
long as sufficiently many participating entities upgrade, then a chain split is
avoided and the fixed blockchain survives.  A prominent example was Bitcoin
[CVE-2010-5139](https://www.cvedetails.com/cve/CVE-2010-5139/), in which a
specially-crafted Bitcoin transaction could mint arbitrarily many BTC well above
the 21 million cap.  The [developer
response](https://bitcointalk.org/index.php?topic=823.0) was to quickly release
a patched version of Bitcoin and rally enough miners and users to upgrade.  In a
matter of hours, the canonical Bitcoin chain ceased to include any transactions
that minted too much BTC.

# Backwards Compatibility

There are no changes to the chainstate database schemas in this SIP.  Everyone
who runs a Stacks 2.1 node today will be able to run a Stacks 2.2 node off of
their existing chainstates at the start of reward cycle #58,
as well as a Stacks 2.3 node off of a Stacks 2.2 chainstate at the start of
reward cycle #59.

Stacks 2.2 nodes will not interact with Stacks 2.1 nodes on the peer network
after the Bitcoin block activation height passes.  In addition, Stacks 2.2 nodes
will ignore block-commits from Stacks 2.1 nodes.  Similar changes were made for
Stacks 2.05 and Stacks 2.1 to ensure that the new network cleanly separates from
stragglers still following the old rules.  This also applies to Stacks 2.3 nodes
and Stacks 2.2 nodes.

# Activation

This SIP shall be considered Activated if the Stacks 2.3 network is live at the
start of reward cycle #59.

The Bitcoin block activation height for the first hard fork will need to pass prior to the selection of
the PoX anchor block for reward cycle #58 (Bitcoin block height 787851).  This
SIP proposes Bitcoin block height 787651, which is 200 Bitcoin blocks prior.  In
other words, the Bitcoin block that is mined 100 blocks prior to the start of
the prepare phase for reward cycle #58 shall be the activation height.

The second hard fork will take effect 200 Bitcoin blocks prior to the start of reward cycle #59,
which is Bitcoin block height 789751.

The node software for Stacks 2.2 and 2.3 shall be merged to the `master` branch of the
reference implementation no later than three days prior to the activation
height.  This means that everyone shall have at least three days to upgrade
their Stacks 2.1 nodes to Stacks 2.2, and at least three days to upgrade from
2.2 to 2.3.

# Reference Implementation

The reference implementation of this SIP can be found in the
`feat/address-pox-increase` branch of
the Stacks blockchain reference implementation.  It is available at
https://github.com/stacks-network/stacks-blockchain.
