# Preamble

SIP Number: 015

Title: Stacks Upgrade of Proof-of-Transfer and Clarity

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
originally proposed in [SIP-007](./sip-007-stacking-consensus.md) and
to the Clarity language supported on the Stacks blockchain. These
updates improve the user and developer experience of participating in
Stacking, add support for new behaviors in the Stacking smart
contract, address potential consensus challenges for PoX related
chain reorganizations, and improve Clarity's support for interacting
with the Bitcoin network. In addition to proposing these changes, this
SIP also outlines an approach for implementing these changes in the
Stacks blockchain.

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

Finally, a year of active development of smart contracts on the Stacks
blockchain highlighted areas for improved support in the Clarity smart
contracting language. These areas include increasing the visibility of
burnchain operations (on the Stacks chain, these are *Bitcoin
operations*) and general improvements to the Clarity programming
language.

# Specification

Upgrading Stacking in the Stacks blockchain requires a
consensus-breaking network upgrade, in this case, a hard fork. Like
other such changes, this will require a new Stacks epoch. In this SIP,
we will refer to this new epoch as Stacks 2.1.

At the onset of Stacks 2.1, the Clarity VM will begin to support
"Clarity Version 2". This version will include support for the new
native methods proposed in this SIP (and therefore include new
*keywords* which cannot be used for method names or variable names).
New contracts launched in Stacks 2.1 will _default_ to Clarity 2, but
contract authors will be able to use a special pragma in their
contracts to indicate if a contract should specifically launch using
Clarity 1 or Clarity 2. Additionally, a new `pox-2` contract will be
published by the boot address. The `stacks-node` will use the new
`pox-2` contract for determining PoX reward sets and governing PoX
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

# Clarity Version 2

## New native methods

### 1. `stx-account`

This method returns the status of STX account: the account's
current STX balance, the amount of STX that is currently locked,
the unlock height for the account, and whether or not the account
qualifies for an early unlock.

This method will be used by the `pox-2` contract to validate
various contract-calls: implementing early unlocks, lock extensions,
lock increases, etc.

### 2. `parse-principal`

* **Input Signature:** `(principal-parse (principal-address principal))`
* **Output Signature:** `(response { hash-bytes (buff 20), version (buff 1) } { hash-bytes (buff 20), version (buff 1) })`

A principal value is a concatenation of two components: a `(buff 1)`
*version byte*, indicating the type of account and the type of network
that this principal can spend tokens on, and a `(buff 20)` *public key hash*,
indicating the principal's unique identity.

`principal-parse` will decompose a principal into its component parts,
`{version-byte, hash-bytes}`.

This method returns a `Response` that wraps this pair as a Clarity tuple.

If the version byte of `principal-address` matches the network (see
`is-standard`), then this method returns the pair as its `ok` value.

If the version byte of `principal-address` does not match the network,
then this method returns the pair as its `err` value.

Examples:

```
(principal-parse 'STB44HYPYAT2BB2QE513NSP81HTMYWBJP02HPGK6) ;; Returns (ok (tuple (hash-bytes 0x164247d6f2b425ac5771423ae6c80c754f7172b0) (version 0x1a)))
(principal-parse 'SP3X6QWWETNBZWGBK6DRGTR1KX50S74D3433WDGJY) ;; Returns (err (tuple (hash-bytes 0xfa6bf38ed557fe417333710d6033e9419391a320) (version 0x16)))
```

### 3. `assemble-principal`

* **Input Signature:** `(principal-parse (version-byte (buff 1)) (hash-bytes (buff 20)))`
* **Output Signature:** `(response principal uint)`

`principal-construct` takes as input such a `(buff 1)` `version-byte`
and a `(buff 20)` `hash-bytes`, and returns a principal.

This function returns a `Response`. On success, the `ok` value is a `Principal`.

The `err` value is a value tuple with the form `{err_int:UInt,value:Option<Principal>}`.

If the single-byte `version-byte` is in the valid range `0x00` to
`0x1f`, but is not an appropriate version byte for the current
network, then the error will be `u0`, and `value` will contain
`Some<Principal>`, where the wrapped value is the principal.

If the `version-byte` is a `buff` of length 0, if the single-byte
`version-byte` is a value greater than `0x1f`, or the `hash-bytes` is
a `buff` of length less than 20, then `err_int` will be `u1` and
`value` will be `None`.

Examples:

```
(principal-construct 0x1a 0xfa6bf38ed557fe417333710d6033e9419391a320) ;; Returns (ok ST3X6QWWETNBZWGBK6DRGTR1KX50S74D3425Q1TPK)
(principal-construct 0x16 0xfa6bf38ed557fe417333710d6033e9419391a320) ;; Returns (err (tuple (error_int u0) (value (some SP3X6QWWETNBZWGBK6DRGTR1KX50S74D3433WDGJY))))
(principal-construct 0x20 0xfa6bf38ed557fe417333710d6033e9419391a320) ;; Returns (err (tuple (error_int u1) (value none)))
```

### 4. `get-burn-block-info?`

* **Input Signature:** `(get-burn-block-info? (prop-name BurnBlockPropertyName) (block-height uint))`
* **Output Signature:** `(optional buff)`

The `get-burn-block-info?` function fetches data for a block of the
given *burnchain* block height. The value and type returned are
determined by the specified `BlockInfoPropertyName`. If the provided
`block-height` does not correspond to an block that is both 1) prior
to the current block, and 2) since the start of the Stacks chain, the
function returns `None`. The only available property name so far is
`header-hash`.

The `header-hash` property returns a 32-byte integer representing the
header hash of the burnchain block at burnchain height `block-height`.

Example:

```
(get-burn-block-info? header-hash u677050) ;; Returns (some 0xe67141016c88a7f1203eca0b4312f2ed141531f59303a1c267d7d83ab6b977d8)
```

### 5. `slice`

* **Input Signature:** `(slice (sequence sequence_A) (left uint) (right uint))`
* **Output Signature:** `(optional sequence_A)`

The `slice` function attempts to return a sub-sequence of that starts
at `left-position` (inclusive), and ends at `right-position`
(non-inclusive).

If `left_position`==`right_position`, the function returns an empty
sequence.

If either `left_position` or `right_position` are out of bounds OR if
`right_position` is less than `left_position`, the function returns
`none`.

Examples:

```
(slice \"blockstack\" u5 u10) ;; Returns (some \"stack\")
(slice (list 1 2 3 4 5) u5 u9) ;; Returns none
(slice (list 1 2 3 4 5) u3 u4) ;; Returns (some (4))
(slice \"abcd\" u1 u3) ;; Returns (some \"bc\")
(slice \"abcd\" u2 u2) ;; Returns (some \"\")
(slice \"abcd\" u3 u1) ;; Returns none
```

### 6. `string-to-int`

* **Input Signature:** `(string-to-int (input (string-ascii|string-utf8)))`
* **Output Signature:** `(optional int)`

Converts a string, either `string-ascii` or `string-utf8`, to an
optional-wrapped signed integer.  If the input string does not
represent a valid integer, then the function returns `none`. Otherwise
it returns an `int` wrapped in `some`.

Examples:

```
(string-to-int "1") ;; Returns (some 1)
(string-to-int u"-1") ;; Returns (some -1)
(string-to-int "a") ;; Returns none
```

### 7. `string-to-uint`

* **Input Signature:** `(string-to-uint (input (string-ascii|string-utf8)))`
* **Output Signature:** `(optional uint)`

Converts a string, either `string-ascii` or `string-utf8`, to an
optional-wrapped `uint`.  If the input string does not represent a
valid non-negative integer, then the function returns
`none`. Otherwise it returns an `uint` wrapped in `some`.

Examples:

```
(string-to-uint "1") ;; Returns (some u1)
(string-to-uint u"1") ;; Returns (some u1)
(string-to-uint "a") ;; Returns none
```

### 8. `int-to-ascii`

* **Input Signature:** `(int-to-ascii (input (int|uint)))`
* **Output Signature:** `string-ascii`

Converts  an integer,  either  `int` or  `uint`,  to a  `string-ascii`
string-value representation.

Examples:

```
(int-to-ascii 1) ;; Returns "1"
(int-to-ascii u1) ;; Returns "1"
(int-to-ascii -1) ;; Returns "-1"
```

### 9. `int-to-utf8`

* **Input Signature:** `(int-to-utf8 (input (int|uint)))`
* **Output Signature:** `string-utf8`

Converts an integer, either `int` or `uint`, to a `string-utf8`
string-value representation.

Examples:

```
(int-to-utf8 1) ;; Returns u"1"
(int-to-utf8 u1) ;; Returns u"1"
(int-to-utf8 -1) ;; Returns u"-1"
```

### 10. `buff-to-int-le`

* **Input Signature:** `(buff-to-int-le (input (buff 16)))`
* **Output Signature:** `int`

Converts a byte buffer to a signed integer use a little-endian
encoding.  The byte buffer can be up to 16 bytes in length. If there
are fewer than 16 bytes, as this function uses a little-endian
encoding, the input behaves as if it is zero-padded on the _right_.

Examples:

```
(buff-to-int-le 0x01) ;; Returns 1
(buff-to-int-le 0x01000000000000000000000000000000) ;; Returns 1
(buff-to-int-le 0xffffffffffffffffffffffffffffffff) ;; Returns -1
(buff-to-int-le 0x) ;; Returns 0
```

### 11. `buff-to-uint-le`

* **Input Signature:** `(buff-to-uint-le (input (buff 16)))`
* **Output Signature:** `uint`

Converts a byte buffer to an unsigned integer use a little-endian
encoding..  The byte buffer can be up to 16 bytes in length. If there
are fewer than 16 bytes, as this function uses a little-endian
encoding, the input behaves as if it is zero-padded on the _right_.

Examples:

```
(buff-to-uint-le 0x01) ;; Returns u1
(buff-to-uint-le 0x01000000000000000000000000000000) ;; Returns u1
(buff-to-uint-le 0xffffffffffffffffffffffffffffffff) ;; Returns u340282366920938463463374607431768211455
(buff-to-uint-le 0x) ;; Returns u0
```

### 12. `buff-to-int-be`

* **Input Signature:** `(buff-to-int-be (input (buff 16)))`
* **Output Signature:** `int`

Converts a byte buffer to a signed integer use a big-endian encoding.
The byte buffer can be up to 16 bytes in length. If there are fewer
than 16 bytes, as this function uses a big-endian encoding, the input
behaves as if it is zero-padded on the _left_.

Examples:

```
(buff-to-int-be 0x01) ;; Returns 1
(buff-to-int-be 0x00000000000000000000000000000001) ;; Returns 1
(buff-to-int-be 0xffffffffffffffffffffffffffffffff) ;; Returns -1
(buff-to-int-be 0x) ;; Returns 0
```

### 13. `buff-to-uint-be`

* **Input Signature:** `(buff-to-uint-be (input (buff 16)))`
* **Output Signature:** `uint`

Converts a byte buffer to an unsigned integer use a big-endian
encoding.  The byte buffer can be up to 16 bytes in length. If there
are fewer than 16 bytes, as this function uses a big-endian encoding,
the input behaves as if it is zero-padded on the _left_.

Examples:

```
(buff-to-uint-be 0x01) ;; Returns u1
(buff-to-uint-be 0x00000000000000000000000000000001) ;; Returns u1
(buff-to-uint-be 0xffffffffffffffffffffffffffffffff) ;; Returns u340282366920938463463374607431768211455
(buff-to-uint-be 0x) ;; Returns u0
```

### 14. `stx-transfer-memo?`

* **Input Signature:** `(stx-transfer? (amount uint) (sender principal) (recipient principal) (memo buff))`
* **Output Signature:** `(response bool uint)`

`stx-transfer-memo?` is similar to `stx-transfer?`, except that it
adds a `memo` field.

This function returns `(ok true)` if the transfer
is successful, or, on an error, returns the same codes as
`stx-transfer?`.

Examples:

```
(as-contract
  (stx-transfer? u50 'SZ2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKQ9H6DPR tx-sender 0x00)) ;; Returns (err u4)
(stx-transfer-memo? u60 tx-sender 'SZ2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKQ9H6DPR 0x010203)) ;; Returns (ok true)
```

## New native variables

### 1. `tx-sponsor?`

* **Type:** `(optional principal)`

Returns the fee-sponsoring principal of the current transaction (if there is such a principal).

## Altered native methods

### 1. `principal-of?`

The `principal-of?` function returns the principal derived from the
provided public key.

If the `public-key` is invalid, it will return the error code `(err u1).`.

Before Stacks 2.1, this function has a bug, in that the principal
returned would always be a testnet single-signature principal, even if
the function were run on the mainnet. In Clarity version 2, this bug
is fixed, so that this function will return a principal suited to the
network it is called on. In particular, if this is called on the
mainnet, it will return a single-signature mainnet principal.


### 2. Comparators `>`, `>=`, `<=`, `<`

In Clarity version 2, these binary comparators will be extended to support
comparison of `string-ascii`, `string-utf8` and `buff`.

These comparisons are done using a lexicographical comparison. 

Examples:
```
(>= "baa" "aaa") ;; Returns true
(>= "aaa" "aa") ;; Returns true
(>= 0x02 0x01) ;; Returns true
(> "baa" "aaa") ;; Returns true
(> "aaa" "aa") ;; Returns true
(> 0x02 0x01) ;; Returns true
(< "aaa" "baa") ;; Returns true
(< "aa" "aaa") ;; Returns true
(< 0x01 0x02) ;; Returns true
```
