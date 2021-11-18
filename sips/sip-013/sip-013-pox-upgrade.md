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

## New native support methods for PoX-2

### 1. `stx-account`

## Changes to existing PoX methods in PoX-2

### 1. Fix expiration of `contract-caller` allowances

### 2. Add optional `amount` argument to `agg-commit`

## Use cases and examples

### Stacking again without cooldown cycle

#### Direct stackers

Direct stackers wishing to repeatedly stack without cooldown may
issue a simple contract-call transaction, invoking:

     SP000000000000000000002Q6VF78.pox stack-extend

If the user wishes to *increase* the amount that they have stacked
in addition to repeating the stacking lockup, they can separately issue
a contract-call transaction to:

     SP000000000000000000002Q6VF78.pox stack-increase

Users can launch a utility smart-contract to execute both of these
contract-calls atomically, but they must remember to invoke the
contract caller allowance for that utility contract.

#### Delegated stackers

Delegation operators wishing to repeatedly stack with a given user
without cooldown may do the following:

1. Issue a contract-call on behalf of the delegated stacker they wish
   to re-stack:
   
```
   (contract-call SP000000000000000000002Q6VF78.pox delegate-stack-extend
     ...)
```

2. That contract-call *locks but does not commit* the user's funds. In
   order for the delegation operator to register the reward address for
   those funds, they must invoke the aggregation commit function (just as
   when they invoke `delegate-stack-stx`):

```
   (contract-call SP000000000000000000002Q6VF78.pox stack-aggregation-commit
     ...)
```

If the delegator wishes to *increase* the amount that the user has
stacked, they must separately issue a `delegate-stack-increase` call
which locks but does not commit the increased funds.

### Changing the reward address after stacking, before expiration

### Assigning multiple reward addresses from a single stacker

### Allow "early" unlock if threshold missed

### Allow unlock beginning at next cycle
