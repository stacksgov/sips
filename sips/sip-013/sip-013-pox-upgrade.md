# Preamble

SIP Number: 013

Title: Upgrading Proof-of-Transfer Consensus

Author:
    Aaron Blankstein <aaron@hiro.so>,
    Jude Nelson <jude@stacks.org>

Consideration: Technical

Type: Consensus

Status: Draft

Created: 1 December 2021

License: BSD 2-Clause

Sign-off:

Discussions-To: https://github.com/stacksgov/sips

# Abstract

This SIP proposes a set of updates to Stacking, the Proof-of-Transfer
(PoX) consensus algorithm as implemented in the Stacks chain and
originally proposed in [SIP-007](./sip-007-stacking-consensus.md).
These updates improve the user and developer experience of
participating in Stacking, add support for new behaviors in the
Stacking smart contract, and address potential consensus challenges
for PoX related chain reorganizations. In addition to proposing these
changes, this SIP also outlines an approach for implementing these
changes in the Stacks blockchain.

# Introduction

The current PoX implementation in the Stacks blockchain has several
shortcomings for developers and users:

1. After unlocking, Stackers **must** wait one cycle before Stacking
   again. This is an implementation consequence, not a requirement of
   the algorithm itself.
2. If users fail to qualify during a cycle, their funds remain locked
   for the cycle regardless.
3. PoX cannot support advanced behaviors that could be used for
   different kinds of smart contracts: changing the PoX reward
   address, increasing or decreasing lock amounts, etc. These features
   would enable new kinds of applications that build on top of PoX.

Furthermore, Stacking as proposed in SIP-007 has a design flaw: If it
is ever the case that a PoX anchor block is missing, and yet somehow
manages to achieve 80% or more confirmations during the prepare phase,
then the subsequent arrival of that anchor block will cause a deep
chain reorganization. It does not matter how many future blocks get
mined--- if the anchor block is later revealed, it will invalidate all
of the blocks that did not build on it. While mining and confirming a
hidden anchor block is very costly, it is possible.

# Specification

Upgrading Stacking in the Stacks blockchain requires a
consensus-breaking network upgrade, in this case, a hard fork. Like
other such changes, this will require a new Stacks epoch. In this SIP,
we will refer to this new epoch as Stacks 2.1.

At the onset of Stacks 2.1, a new `pox-2` contract will be published
by the boot address. The `stacks-node` will use the new `pox-2`
contract for determining PoX reward sets and governing PoX
locks.

The new PoX contract operates exclusively with PoX state that was
created in the new contract. It will not "import" state from the
original PoX contract. In order to allow for this, a particular reward
cycle `N` is chosen as the "Last PoX-1" reward cycle, and then the
"First PoX-2" reward cycle is the subsequent cycle (`N+1`).

This defines three periods of PoX operation:

Period 1 | Period 2 | Period 3
-- | -- | --
2.0 Consensus Rules in Effect | 2.1 Consensus Rules enacted, but first PoX-2 reward cycle has not begun | First PoX-2 reward cycle has begun
_This is the period of time before the 2.1 fork._ | _This is after the 2.1 fork, but before cycle (N+1)._ | _This is after cycle (N+1) has begun. Original PoX contract state will no longer have any impact on reward sets, account lock status, etc._

- Every account that is locked by the original contract for cycle `N`
  and beyond is unlocked at the end of Cycle `N`.
- Every account that is locked (whether by PoX-1 or PoX-2) is eligible
  for a call to `pox-2.lock-extend`, which allows an account to
  re-lock for some subsequent number of reward cycles while still
  being locked.
    - This would also be true for `pox-2.delegate-lock-extend`
- Calls to PoX 2 which would attempt to create state for a cycle
  _before_ `(N+1)` will fail
- Calls to the original PoX contract which would attempt to create
  state for a cycle `>= N+1` will be made to fail and any state after
  `N+1` is ignored.  This requires interposing on contract-calls
  during period 2 and checking the reward cycles arguments: the
  relevant functions are `stack-stx`, `delegate-stack-stx`,
  `stack-aggregation-commit`, and `reject-pox`.

# Improving PoX with Forkable PoX Anchor Blocks

This SIP proposes addressing challenges in Proof-of-Transfer by making
the history of PoX anchor blocks itself forkable, and by implementing
Nakamoto consensus on the anchor block history forks so that there
will always be a canonical anchor block history. In doing so, the
Stacks blockchain now has three levels of forks: the Bitcoin chain,
the history of PoX anchor blocks, and the history of Stacks
blocks. The canonical Stacks fork is the longest history of Stacks
blocks that passes through the canonical history of anchor blocks
which resides on the canonical Bitcoin chain.

# The PoX-2 Contract

This section of the SIP specifies the new and changed behaviors of the
PoX-2 contract and also provides new use cases that demonstrate how
the new PoX-2 contract could be used.

## New methods in PoX-2

### 1. `stack-extend`

This method allows direct stackers to re-lock their funds for an additional
12 cycles *before* their current lock has expired. The target use case for
this is to allow users to repeatedly stack without cooldowns.

This method checks that the stacker is still allowed to stack, that
the stacker has not delegated to an operator, and that their funds are
currently stacked. The caller may supply a new reward address for the
extension.

The special case handler for the PoX contract in the Clarity VM will
check this method's return value and set the stacker's STX account to
"auto-unlock" at the end of the last extended-to reward cycle.

### 2. `delegate-stack-extend`

This method allows operators to re-lock the funds of one of their
delegation participants for additional cycles *before* that participants
lock has expired. The target use case for this is to allow delegation
operators to repeatedly stack on behalf of their users without cooldowns.

This method checks that the delegator is still authorized on behalf of
the given stacker (and remains authorized until the end of the
locked-for period) and that the funds are currently stacked.

Note that, just as with the existing `delegate-stack-stx` function,
this method locks *but does not commit* the user's STX. The delegation
operator must invoke `stack-aggregation-commit` to set a reward address
for the locked funds.

The special case handler for the PoX contract in the Clarity VM will
check this method's return value and set the stacker's STX account to
"auto-unlock" at the end of the last extended-to reward cycle.

### 3. `stack-increase`

This method allows direct stackers to lock additional funds for
the remaining cycles on their current lock.

This method checks that the stacker is still allowed to stack, that
the stacker has not delegated to an operator, that their funds are
currently stacked, and that they have enough unlocked funds to cover
the increase. The caller may *not* supply a new reward address for the
increase.

The special case handler for the PoX contract in the Clarity VM will
check this method's return value and set the locked amount in the
stacker's STX account to correspond to the increased amount.

### 4. `delegate-stack-increase`

This method allows operators to lock additional funds for one of their
delegation participants for the remaining cycles on that user's
current lock.

This method checks that the delegator is still authorized on behalf of
the given stacker (and remains authorized until the end of the
locked-for period), that the increased amount remains less than the
delegation's `amount-ustx` field, that the user is currently locked,
and that the user has enough unlocked funds to cover the increase.

Note that, just as with the existing `delegate-stack-stx` function,
this method locks *but does not commit* the user's STX. The delegation
operator must invoke `stack-aggregation-commit` to set a reward address
for the newly locked funds.

The special case handler for the PoX contract in the Clarity VM will
check this method's return value and set the locked amount in the
stacker's STX account to correspond to the increased amount.

### 5. `stack-unlock`

This method allows direct stackers (not delegation participants) to
unlock their funds *after* the active reward cycle: removing the
account from all future reward sets.

The special case handler for the PoX contract in the Clarity VM will
check this method's return value and set the stacker's STX account to
"auto-unlock" at the start of the next reward cycle (i.e., the user
account will behave as if the current cycle is their last active
cycle).

### 6. `stack-unlock-early`

This method allows direct stackers (not delegation participants) to unlock
their funds during the *current* reward cycle if, and only if, the user's
stacked amount was not sufficient to obtain a rewards slot.

This method will behave similarly to `stack-unlock`, removing the account
from all future reward sets. The special case handler for the PoX contract
in the Clarity VM will check this method's return value and set the stacker's
STX account to "auto-unlock" at the _next_ Stacks block height.

### 7. `delegator-stack-unlock`

This method allows a user who delegated their PoX functionality
to an operator to unlock a locked _but not committed_ amount from their
account. The reason that the amount cannot have been committed yet is that
the operator and the PoX contract cannot distinguish between which accounts
have been used during a given cycle's commitment-- and allowing users to
"uncommit" from the operator's pool would introduce denial-of-service vectors
to the pool.

### 8. `stack-aggregation-rollback`

This method allows operators to rollback an aggregation commit.
It does not unlock the associated user funds (that would need to be
performed via `delegator-stack-unlock`), rather it just removes the
associated entry from a future reward set. The rolled back entry
*must* be in a future reward cycle. In addition to removing the
entry from the reward set, this method increments the delegator's
partially stacked funds with the rolled back funds.

Because this method does not perform any unlocking, it does not
require a special case handler in the Clarity VM.

## New native support methods for PoX-2

### 1. `stx-account`

This method returns the status of STX account: the account's
current STX balance, the amount of STX that is currently locked,
the unlock height for the account, and whether or not the account
qualifies for an early unlock.

This method will be used by the `pox-2` contract to validate
various contract-calls: implementing early unlocks, lock extensions,
lock increases, etc.

## Changes to existing PoX methods in PoX-2

### 1. Fix expiration of `contract-caller` allowances

The `pox` contract's implementation of contract-caller allowance
expirations is broken. `pox-2` should fix this behavior.

### 2. Add optional `amount` argument to `stack-aggregation-commit`

A new optional `amount` argument in the `stack-aggregation-commit` public
function will allow pool operators or other users of the delegation interface
to only commit a subset of the locked funds. This is useful if the operator
wants to commit to multiple PoX reward addresses in a given cycle.

## Use cases and examples

### Stacking again without cooldown cycle

#### Direct stackers

Direct stackers wishing to repeatedly stack without cooldown may
issue a simple contract-call transaction, invoking:

     SP000000000000000000002Q6VF78.pox-2 stack-extend

If the user wishes to *increase* the amount that they have stacked
in addition to repeating the stacking lockup, they can separately issue
a contract-call transaction to:

     SP000000000000000000002Q6VF78.pox-2 stack-increase

Users can launch a utility smart-contract to execute both of these
contract-calls atomically, but they must remember to invoke the
contract caller allowance for that utility contract.

#### Delegated stackers

Delegation operators wishing to repeatedly stack with a given user
without cooldown may do the following:

1. Issue a contract-call on behalf of the delegated stacker they wish
   to re-stack:
   
```
   (contract-call SP000000000000000000002Q6VF78.pox-2 delegate-stack-extend
     ...)
```

2. That contract-call *locks but does not commit* the user's funds. In
   order for the delegation operator to register the reward address for
   those funds, they must invoke the aggregation commit function (just as
   when they invoke `delegate-stack-stx`):

```
   (contract-call SP000000000000000000002Q6VF78.pox-2 stack-aggregation-commit
     ...)
```

If the delegator wishes to *increase* the amount that the user has
stacked, they must separately issue a `delegate-stack-increase` call
which locks but does not commit the increased funds.

### Changing the reward address after stacking, before expiration

#### Direct stackers

Stackers wishing to alter their PoX reward address before their lock
expires can issue two contract-calls to change their reward address:

```
(contract-call SP000000000000000000002Q6VF78.pox-2 stack-unlock ...)
(contract-call SP000000000000000000002Q6VF78.pox-2 stack-extend ...)
```

The first contract call will unlock the stacker's funds at the start
of the next reward cycle -- allowing the user to re-stack those funds
with a different reward address. Because the funds are still locked,
the user can invoke `stack-extend` to re-stack those funds, setting
a new reward address.

Users can launch a utility smart-contract to execute both of these
contract-calls atomically, but they must remember to invoke the
contract caller allowance for that utility contract.

#### Delegated stackers

Delegation operators wishing to change a reward address after issuing
an `stack-aggregation-commit` but before that reward cycle begins can
issue two contract-calls to change the reward address:

```
(contract-call SP000000000000000000002Q6VF78.pox-2 stack-aggregation-rollback ...)
(contract-call SP000000000000000000002Q6VF78.pox-2 stack-aggregation-commit ...)
```

These contract calls simply undo the already issued commit, allowing
the operator to issue the aggregation commit with the new reward address.

### Assigning multiple reward addresses from a single stacker

#### Direct stackers

Direct stackers cannot use multiple reward address for the same Stacking
address. This is because the direct stacking interface does not support
partial stacking operations (i.e., separating the locking operation from
the stacking operation), which are necessary for supporting this use case.
Users who wish to do this should use the delegation interfaces.

#### Delegated stackers

Even in PoX-1, delegation operators are capable of assigning multiple
reward addresses for funds that they manage: each invocation of
`delegate-stack-stx` can use a different PoX reward address. However,
if operators wished to split the same _account's_ lockups across
multiple addresses, this would not be possible.

In PoX-2, however, delegation operators can use
`delegate-stack-increase` to achieve this. This method allows the
delegation operator to set a new PoX address to receive the
"partially stacked" funds from the increase. Once called, the operator
can use `stack-aggregation-commit` to commit to each PoX reward
address separately.
