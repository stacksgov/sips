# Preamble

**SIP Number:** XXX

**Title:** Improved Stacking Protocol

**Authors:**

- Friedger Müffke ([friedger@ryder.id](mailto:friedger@ryder.id))

**Consideration:** Technical

**Type:** Consensus

**Status:** Draft

**Created:** 2025-04-01

**License:** BSD 2-Clause

**Sign-off:**

**Discussions-To:**

- [Stacks Forum Discussions](https://forum.stacks.org/t/remove-cool-down-cycle-in-stacking/17899)

# Abstract

This SIP proposes a change to the different phases of the stacking process so that stackers can change
their stacking settings without the so-called cooldown cycle. Furthermore, the relationship between stackers
and signers is strengthened and stacking overall is simplified.

The specification defines that

- the beginning of the prepare phase is moved by 90 Bitcoin blocks towards the end of the cycle.
- the length of the prepare phase is reduced to 10 Bitcoin blocks.
- locked Stacks token ready for unlocking are unlocked at 90 blocks before the beginning of the prepare phase.
- delegated stacking tokens are locked immediately.
- stacking rewards are received by the Bitcoin address specified by the signer.
- solo stackers and delegating stackers have to follow the same flow.

# Introduction

## Glossary

| Term               | Definition                                                                                                                                               |
| ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Cooldown Cycle** | The period of 1 stacking cycle where stackers cannot stack their STX tokens because their tokens are unlocked only at the beginning of a stacking cycle. |
| **Signer**         |                                                                                                                                                          |
| **Delegation**     |                                                                                                                                                          |
| **PoX Contract**   |                                                                                                                                                          |

## Problem Statement

The current stacking process has two different paths, one for solo stackers, one for delegated stackers,
resulting in a more complex user experience and more complex code. Furthermore, users cannot change their
stacking settings (decrease amount, change PoX reward address, etc.) without an unlocked cycle where users cannot earn
stacking rewards.

The process is defined by a prepare phase of 100 bitcoin blocks that is used to find an anchor block
for the next stacking cycle. Stackers must lock
their Stacks tokens before the
preapre phase, i.e. before the 2000th block of the current stacking cycle. Furthermore, Stacks
tokens are locked for a locking period that always end at the beginning of a cycle, i.e. after the
prepare phase. Therefore, the current implementation of Stacking includes a period where Stacks
tokens are unlocked and cannot earn stacking rewards (Cooldown Cycle).

The current PoX contract allows users to lock Stacks tokens during the prepare phase. This is too late for the next cycle
and the tokens are locked without earning stacking rewards for one cycle.

The cooldown cycle for unstacking from a pool presents a problem for network decentralization.
As a stacker, when I delegate to a signer and that signer does not perform and gets low yield,
I get penalized for switching. In today's model with cooldown cycles, users get double penalized
if a validator does not perform. Even if there are penalties for signers not performing / being down,
the switching costs are too high for users to switch (2 weeks worth of yield).

## Proposed Solution

This SIP proposes a new Proof of Transfer (PoX) contract without
the flow for solo stacking and moves responsibilities from pool operators to signers. It also
defines the end of the locking period to be before the start of the stacking cycle.

The user will be able to switch from one signer to another with a single contract call and without a cool down period.

# Specification

Applying these upgrades to the Stacks blockchain requires a consensus-breaking network upgrade,
in this case, a hard fork. Like other such changes, this will require a new Stacks epoch.
In this SIP, we will refer to this new epoch as Stacks 3.2.

## Delegated Stacking only

The following PoX contract functions shall be removed

- stack-stx
- stack-increase
- stack-extend

## Locking period

Stacking transactions shall result in locking periods that end 100 blocks before the beginning of a stacking period. This includes

- delegate-stack-stx
- delegate-stack-extend

The PoX contract has to be changed and return the unlock height as previous unlock height minus 100 blocks for mainnet. E.g.

```
(new-unlock-ht (- (reward-cycle-to-burn-height (+ u1 last-extend-cycle)) u100))
```

The unlocking process of the stacks node needs to be adapted accordingly.

## Prepare phase

The prepare phase shall start 10 blocks before the beginning of the stacking cycle and last for 10 blocks.

The prepare cycle length defined in PoX contract has be changed to

```
(define-constant PREPARE_CYCLE_LENGTH (if is-in-mainnet u10 u5))
```

## Relationship Between Stackers and Signers

The signature provided by signers to stackers shall use one of the following topics

- delegate
- delegate-increase
- delegate-extend
- agg-commit
- agg-increase

## Transition to PoX-5

A new PoX contract requires that all stacked Stacks tokens are unlocked and Stackers need to lock their Stacks token again using the new PoX-5 contract. The process shall be similar to the previous upgrades of the PoX contract. PoX-4 contract shall be deactivated and PoX-5 contract shall be activated at the beginning of epoch 3.2 All locked Stacks tokens shall be unlocked automatically 1 block after the beginning of epoch 3.2.

# Related Work

The previous PoX process is described in [SIP 007](https://github.com/stacksgov/sips/blob/main/sips/sip-007/sip-007-stacking-consensus.md).

# Activation

This SIP requires a hard fork and shall be activated on Stacks 3.2 as defined by the SIP for epoch 3.2.

## Appendix

[1] https://github.com/stacks-network/stacks-core/issues/4912
