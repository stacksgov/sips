# Preamble

SIP Number: 015

Title: Stacks Upgrade of Proof-of-Transfer and Clarity

Authors:
    Aaron Blankstein <aaron@hiro.so>,
    Mike Cohen <mjoecohen@gmail.com>,
    Greg Coppola <greg@hiro.so>,
    Brice Dobry <brice@hiro.so>,
    Hero Gamer <herogamerthesht572@gmail.com>
    Matthew Little <matthew@blockstack.com>,
    Jenny Mith <jenny@stacks.org>,
    Jude Nelson <jude@stacks.org>,
    Pavitthra Pandurangan <pavitthra@hiro.so>,
    Rena Shah <rena@trustmachines.co>,
    Hank Stoever <hank@mechanism.so>,
    Igor Sylvester <igor@trustmachines.co>,
    Jesse Wiley <jw@stacks.org>,

Consideration: Technical, Governance, Economics

Type: Consensus

Status: Draft

Created: 1 December 2021

License: BSD 2-Clause

Sign-off:

Discussions-To: https://github.com/stacksgov/sips

# Abstract

This SIP proposes a set of updates to three major areas of the Stacks blockchain:

* **Stacking**, the Proof-of-Transfer (PoX) consensus algorithm as implemented
in the Stacks chain and originally proposed in [SIP-007](./sip-007-stacking-consensus.md). 
The proposed changes improve the user and developer experience of participating
in Stacking, and add support for new behaviors and PoX reward address types.

* **Clarity**, the smart contract language supported on the Stacks blockchain.
The proposed changes fix bugs and add new native functions and global variables
that improve its support for interacting with off-chain services and
blockchains, especially Bitcoin.

* **Block Validation**, the procedure by which blocks are determined to be acceptable to the Stacks
  blockchain.  The proposed changes address bugs in the implementation that are
not specified by any prior SIP, but which cannot be changed without a
coordinated network-wide upgrade.  In addition, the proposed changes address
potential consensus challenges for PoX-related chain reorganizations which were
not known at the time SIP-007 was written.  Finally, new variations of existing
transactions are proposed to better support Stacking, to support
multiple Clarity versions, and to support decentralized mining pools.

In addition to proposing these changes, this SIP also outlines an approach for
implementing these changes in the Stacks blockchain.

Because this is a breaking change, there must be a vote from the relevant
stakeholders to activate this SIP.  This vote is slated to take place
during reward cycles 46 and 47.  This
window is estimated to begin **starting November 10, 2022** and **ending
December 8, 2022**.

# Introduction

This SIP condenses lessons learned from running the Stacks blockchain in
production to date.  Since the system was launched in January 2021, several
shortcomings have been discovered which can only be addressed through a
coordinated, backwards-compatible network upgrade.  This SIP enumerates these
shortcomings and proposes solutions.

Broadly speaking, the shortcomings of the system fall into one of three
categories: Stacking, the Clarity language, and block validation.

Concerning Stacking, the current PoX implementation in the Stacks blockchain has several
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

4. PoX will automatically sunset after a pre-defined number of Bitcoin blocks
   pass, regardless of how popular or useful it is.

This SIP proposes the creation of a new `pox-2` smart contract to implement
Stacking which addresses the above problems.  A migration procedure is presented
for transitioning the system from `pox` to `pox-2`.

At the same time, it was discovered over the lifetime of the Stacks blockchain
that there are a few shortcomings in the block validation logic that
negatively impact the user experience and miner experience.  In particular:

1. Stacking as proposed in SIP-007 has a design flaw: If it
is ever the case that a PoX anchor block is missing, and yet somehow
manages to achieve 80% or more confirmations during the prepare phase,
then the subsequent arrival of that anchor block will cause a deep
chain reorganization. It does not matter how many future blocks get
mined--- if the anchor block is later revealed, it will invalidate all
of the blocks that did not build on it. While mining and confirming a
hidden anchor block is very costly, it is possible.

2. An on-burnchain transaction mined in Bitcoin block `N` will only be mined 
in the Stacks blockchain if Bitcoin block `N+1` selects a Stacks block.
Even then, the transaction only materializes in Stacks forks which include this
Stacks block.  This is brittle in the face of both orphan Stacks blocks (which
will never be canonical) and "flash blocks" -- quickly-mined
Bitcoin blocks that contain no block-commits.

3. The Stacks blockchain calculates the probability of a miner winning a block race as
   proportional to the minimum of their last block-commit's Bitcoin spend, and
the median of their last six block-commits' spends.  The last six block-commits
today only include block-commits that arrived in their intended Bitcoin blocks.
This unfairly punishes miners whose block-commits, through no fault of the
miner's, are late to be mined on the Bitcoin chain.

4. Today, there are multiple ways for a Stacks miner to process a transaction
   but be forced to drop it from the block they are building because its
inclusion would invalidate the block.  While the current implementation employs
various measures to mitigate the impact of this shortcoming, a "proper" solution
would be to make it so that this simply never happens -- miners should get paid
for _all_ of the work they do, _even if_ the transaction is invalid.

This SIP proposes fixing these four problems.  Regarding the first, the SIP proposes organizing 
PoX anchor blocks into a forkable history, whose canonical fork is determined
via Nakamoto consensus.  The canonical Stacks fork must contain all canonical
PoX anchor blocks.  Regarding the second, an on-burnchain transaction
will be considered in each Stacks block to be mined in the subsequent six
burnchain blocks, instead of the next.  Regarding the third, the median Bitcoin spend of the
miner's last six block-commits will include _late_ block-commits.  Regarding the
fourth, the SIP proposes changing a few rules for transaction-processing that
would permit the miner to include transactions in blocks that it cannot include today.

Finally, a year of active development of smart contracts on the Stacks
blockchain highlighted areas for improved support in the Clarity smart
contracting language. These areas include increasing the visibility of
burnchain operations (on the Stacks chain, these are *Bitcoin
operations*) and general improvements to the Clarity programming
language.

## How to Read this SIP

This SIP specification is structured like a changelog.  Proposed changes to each of these
areas of the system are described in order of new features, changed features,
and fixed features.  A rationale is provided for each proposed modification to
Stacks.

# Specification

Applying these upgrades to the Stacks blockchain requires a
consensus-breaking network upgrade, in this case, a hard fork. Like
other such changes, this will require a new Stacks epoch. In this SIP,
we will refer to this new epoch as Stacks 2.1.

At the onset of Stacks 2.1, the Clarity VM will begin to support
"Clarity Version 2". This version will include support for the new
native methods proposed in this SIP (and therefore include new
*keywords* which cannot be used for method names or variable names).
New contracts launched in Stacks 2.1 will _default_ to Clarity 2, but
contract authors will be able to use a new contract-publish transaction type to
indicate if a contract should specifically launch using
Clarity 1 or Clarity 2.

Additionally, a new `pox-2` contract will be
published by the boot address. The `stacks-node` will use the new
`pox-2` contract for determining PoX reward sets and governing PoX
locks.  Similarly, new rules for block validation take effect at the onset of Stacks
2.1.

## Stacking

This section of the SIP specifies the new and changed behaviors of the
PoX-2 contract and also provides new use cases that demonstrate how
the new PoX-2 contract could be used.

### Overview

The new PoX contract operates exclusively with PoX state that was
created in the new contract. It will not "import" state from the
original PoX contract. In order to allow for this, a particular reward
cycle `N` is chosen as the "Last PoX-1" reward cycle, and then the
"First PoX-2" reward cycle is the subsequent cycle (`N+1`).

This defines three periods of PoX operation:

Period 1 | Period 2 | Period 3
-- | -- | --
2.0 Consensus Rules in Effect | 2.1 Consensus Rules enacted, but first PoX-2 reward cycle has not begun | First PoX-2 reward cycle has begun
_This is the period of time before the 2.1 fork._ | _This is after the 2.1 fork in cycle N, but before cycle (N+1)._ | _This is the start of cycle (N+1), and all cycles afterward.  The original PoX contract state will no longer have any impact on reward sets, account lock status, etc._

- Every account that is locked by the original contract for cycle `N`
  and beyond is unlocked at the end of Cycle `N`.
- Every account that is locked (whether by PoX-1 or PoX-2) is eligible
  for a call to `pox-2.stack-extend`, which allows an account to
  re-lock for some subsequent number of reward cycles while still
  being locked.
    - This would also be true for `pox-2.delegate-stack-extend`
- Calls to PoX 2 which would attempt to create state for a cycle
  _before_ `(N+1)` will fail
- Calls to the original PoX contract which would attempt to create
  state for a cycle `>= N+1` will be made to fail and any state after
  `N+1` is ignored.  This requires interposing on contract-calls
  during period 2 and checking the reward cycles arguments: the
  relevant functions are `stack-stx`, `delegate-stack-stx`,
  `stack-aggregation-commit`, and `reject-pox`.

### New method: `stack-extend`

This method allows direct stackers to re-lock their funds for up to an additional
12 cycles *before* their current lock has expired. The target use case for
this is to allow users to repeatedly stack without a cooldown phase.

This method checks that the stacker is still allowed to stack, that
the stacker has not delegated to an operator, and that their funds are
currently stacked. The caller may supply a new reward address for the
extension.

The special case handler for the PoX contract in the Clarity VM will
check this method's return value and set the stacker's STX account to
"auto-unlock" at the end of the last extended-to reward cycle.

### New method: `delegate-stack-extend`

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

### New method: `stack-increase`

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

### New method: `delegate-stack-increase`

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

### Changed: `delegate-stx`

This method has been changed so that the user can call it even while their STX
are locked.  This is meant to enable the user to increase their STX allowance to
their delegator can lock up for them while their STX are locked.  In such cases,
the user would call `revoke-delegate-stx` and then `delegate-stx` with their
higher STX allowance, and the delegator would subsequently call
`delegate-stack-increase` and `stack-aggregation-commit` to increase the user's 
locked-and-committed STX.

### Changed: Auto-Unlock

This SIP proposes that if the user's STX do not earn a single
reward slot in a reward cycle, then the user's STX are _automatically unlocked_
at the start of the reward cycle.  The user's STX would remain unlocked even if
they had locked them for subsequent reward cycles.

If a user has amassed more STX, or believes that they can acquire a reward slot
in a subsequent cycle, then they can re-stack their STX.

The current system behavior is to keep the user's STX locked for the duration of
their specified lock-up period, even if they are not earning them any reward
slots.

### Changed: Automatic PoX Sunset Removed

This SIP proposes removing the automatic PoX sunset that is currently slated to
activate in the current system.  The rationale for the PoX sunset was to address
an incentive problem with PoX: if miners acquire enough STX, they can mine at a
discount because the burnchain tokens they pay will be paid back to themselves.
While the existence of Stacking pools means this can't be avoided at any scale,
it is particularly bad for the chain if miners have so many STX Stacked that
they can control the _median_ mining commitment value in the sortition weight
calculation.  If they can do this, then they can spend as many burnchain tokens
as they want since they will get them back right away.  The effect of this
behavior is that miners who can discount-mine will eventually price out all
other miners, leading to a chain where only large STX-holders can effectively mine.

The PoX sunset fixes this incentive problem by capping any gains such a miner
could ever make over the system's lifetime.  Even if a miner did this, it would
lead to a temporary gain in their mining power.  However, Stacking has proven
successful and popular, and we believe that stopping its operation on an
automated schedule has the potential to harm the Stacks blockchain ecosystem.

As an alternative, we recommend that discount-mining behavior be policed by
vigilent users.  In the system today, 25% of the liquid STX can vote to stop PoX
payouts for the next reward cycle.  If discount-mining behavior becomes the
dominant strategy in Stacks, then users already have the power to fix the
miner incentives _if it becomes a problem_.  We do not know when, or if, it ever
will, but we believe that the mechanism(s) for determining when or if PoX
deactivates to counter discount-mining must be (1) adaptive in the face of an
ever-shifting set of discount-mining strategies and the strategies for
countering them, and (2) under the control of users, not Stacks blockchain developers.
The PoX sunset has neither of these properties.

A future SIP may propose an alternative mechanism for empowering users to
collectively address discount-mining in the event that either
a better strategy be discovered, the Stacks blockchain incentives
get altered to render this impractical.

### Changed: Support Segwit PoX Payout Addresses

The type of a PoX address is now `(tuple (hashbytes (buff 32)) (version (buff
1)))`.  This is to accomodate pay-to-witness-script-hash (p2wsh) and taproot (p2tr) scriptPubKeys on Bitcoin.  In
addition, new values for `version` are supported to represent these encodings:

   * `0x04` means this is a pay-to-witness-public-key-hash (p2wpkh) address, and `hashbytes` is the 20-byte hash160 of the witness script
   * `0x05` means this is a pay-to-witness-script-hash (p2wsh) address, and `hashbytes` is the 32-byte sha256 of the witness script
   * `0x06` means this is a pay-to-taproot (p2tr) address, and `hashbytes` is the 32-byte sha256 of the witness script

### Fixed: Expiration of `contract-caller` Allowances

The `pox` contract's implementation of contract-caller allowance
expirations is broken. `pox-2` should fix this behavior.

This behavior is not explicitly specified in SIP-007, but is a behavior present
in the reference implementation which enables users to allow other principals
(e.g. smart contracts) to Stack their STX on their behalf.  In the `pox`
contracts, users can set the principal allowed to do this at any time, and
specify the maximum burnchain height for which the authorization will be valid
(once this burnchain height passes, the allowance is automatically revoked).

### Usecase: Stacking without a Cooldown Cycle

#### Direct stackers

Direct stackers wishing to repeatedly stack without cooldown may
issue a simple contract-call transaction, invoking:

     `SP000000000000000000002Q6VF78.pox-2 stack-extend`

If the user wishes to *increase* the amount that they have stacked
in addition to repeating the stacking lockup, they can separately issue
a contract-call transaction to:

     `SP000000000000000000002Q6VF78.pox-2 stack-increase`

Users can launch a utility smart-contract to execute both of these
contract-calls atomically, but they must remember to invoke the
contract caller allowance for that utility contract.

#### Delegated stackers

Delegation operators wishing to repeatedly stack with a given user
without cooldown may do the following:

1. Issue a contract-call on behalf of the delegated stacker they wish
   to re-stack:
   
```clarity
   (contract-call SP000000000000000000002Q6VF78.pox-2 delegate-stack-extend
     ...)
```

2. If the user wishes to *increase* the amount of STX they have stacked, then
   the user must first reset their delegated STX allowance:

```clarity
   (contract-call SP000000000000000000002Q6VF78.pox-2 revoke-delegate-stx
      ...)
   (contract-call SP000000000000000000002Q6VF78.pox-2 delegate-stx
      ...)
```

   Then, the delegator must separately issue a `delegate-stack-increase` call
   which locks but does not commit the increased funds.


3. The aforementioned contract-calls *lock but do not commit* the user's funds. In
   order for the delegation operator to register the reward address for
   those funds, they must invoke the aggregation commit function (just as
   when they invoke `delegate-stack-stx`):

```clarity
   (contract-call SP000000000000000000002Q6VF78.pox-2 stack-aggregation-commit
     ...)
```

### Usecase: Stacking with Multiple PoX Addresses

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

## Clarity

If this SIP is ratified, then at the time of the
Stacks 2.1 network upgrade, the Clarity smart
contract language will be expanded with new features and some new
behaviors for existing native methods. In order to support these
changes, this SIP proposes to introduce *Clarity versioning for smart
contracts*. In this scheme, each smart contract will be associated
with a particular Clarity version. The execution environment will
track the current version for a given execution (in the
implementation, this will be via the `ContractContext`), and use that
to select which features are available, and which native method
implementations will be used. Clarity 2 contracts can invoke Clarity 1
contracts (and vice-versa), but particular care will need to be taken
if a new native keyword is used in the Clarity 1 contract's API.

For example:

```
Contract A (Clarity 1 Contract):
  (define-public (stx-account) ...)
  
Contract B (Clarity 2 Contract):
  (contract-call contract-A stx-account)
```

In such cases, the new keyword (in the above example, the keyword is
`stx-account`) *cannot* be used by the Clarity 2 contract, and
therefore invoking the public method of Contract A from Contract B is
not allowed. To address these cases, contract authors must launch a
Clarity 1 contract that interposes on Contract A, providing a Clarity
2 compatible interface.

Existing, pre-2.1 contracts will all be Clarity 1. New contracts will
default to Clarity 2, and a new Stacks transaction wire format for publishing
smart contracts will allow contract publishers to choose the version that
their contract should use.

Note that the act of adding, changing, or removing a native Clarity function or native
Clarity global variable (including comparators and operators, which are
themselves native functions) necessitates the creation of a new version of the
Clarity language, and must be treated as a breaking change.
This is because adding, changing, or removing either of these
things alters the rules for block validation, which makes these 
consensus-level changes.  This SIP proposes introducing a new version of Clarity
(Clarity 2) _while also_ preserving the current version of Clarity (Clarity 1).  This
shall not be construed as setting a precedent -- a future SIP may remove the
ability to publish new smart contracts with older versions of Clarity.

### New method: `stx-account`

* **Input Signature:** `(stx-account (principal-address principal))`
* **Output Signature:** `{ locked: uint, unlock-height: uint, unlocked: uint }`

This method returns the status of STX account: the account's
current STX balance, the amount of STX that is currently locked,
and the unlock height for the account.

**Rationale:**  This method will be used by the `pox-2` contract to validate
various contract-calls: implementing early unlocks, lock extensions,
lock increases, etc.  It exposes PoX lock state to smart contracts, which is not
entirely visible even in `pox` or `pox-2`.

**Examples:**

```clarity
(stx-account 'SZ2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKQ9H6DPR) ;; Returns (tuple (locked u0) (unlock-height u0) (unlocked u0))
(stx-account (as-contract tx-sender)) ;; Returns (tuple (locked u0) (unlock-height u0) (unlocked u1000))
```

### New method: `principal-destruct`

* **Input Signature:** `(principal-destruct (principal-address principal))`
* **Output Signature:** `(response { hash-bytes: (buff 20), name: (optional (string-ascii 40)), version: (buff 1) } { hash-bytes: (buff 20), name: (optional (string-ascii 40)), version: (buff 1) })`

A principal value represents either a set of keys, or a smart contract.
The former, called a _standard principal_,
is encoded as a `(buff 1)` *version byte*, indicating the type of account
and the type of network that this principal can spend tokens on,
and a `(buff 20)` *public key hash*, characterizing the principal's unique identity.
The latter, a _contract principal_, is encoded as a standard principal concatenated with
a `(string-ascii 40)` *contract name* that identifies the code body.

`principal-destruct` will decompose a principal into its component parts.  Standard principals will 
be decomposed into a tuple containing the **version byte** and **public key
hash**.  Decomposed contract principals contain the same data as standard
principals, as well as a **name** element that contains the human-readable
contract name part of the contract address.

This method returns a `Response` that wraps this data as a tuple.

If the version byte of `principal-address` matches the network (see `is-standard`), then this method
returns the pair as its `ok` value.

If the version byte of `principal-address` does not match the network, then this method
returns the pair as its `err` value.

In both cases, the value itself is a tuple containing three fields: a `version` value as a `(buff 1)`,
a `hash-bytes` value as a `(buff 20)`, and a `name` value as an `(optional (string-ascii 40))`.  The `name`
field will only be `(some ..)` if the principal is a contract principal.

**Rationale:** This method is meant to help smart contracts integrate with
Bitcoin addresses and with other Stacks network instances' addresses.  Legacy
Bitcoin addresses can already be converted to Stacks addresses; the ability to
decode them in Clarity empowers developers to do things like verify that a
Bitcoin owner signed some data, or also controlled some Stacks data.

**Examples:**

```clarity
(principal-destruct 'STB44HYPYAT2BB2QE513NSP81HTMYWBJP02HPGK6) ;; Returns (ok (tuple (hash-bytes 0x164247d6f2b425ac5771423ae6c80c754f7172b0) (name none) (version 0x1a)))
(principal-destruct 'STB44HYPYAT2BB2QE513NSP81HTMYWBJP02HPGK6.foo) ;; Returns (ok (tuple (hash-bytes 0x164247d6f2b425ac5771423ae6c80c754f7172b0) (name (some "foo")) (version 0x1a)))
(principal-destruct 'SP3X6QWWETNBZWGBK6DRGTR1KX50S74D3433WDGJY) ;; Returns (err (tuple (hash-bytes 0xfa6bf38ed557fe417333710d6033e9419391a320) (name none) (version 0x16)))
(principal-destruct 'SP3X6QWWETNBZWGBK6DRGTR1KX50S74D3433WDGJY.foo) ;; Returns (err (tuple (hash-bytes 0xfa6bf38ed557fe417333710d6033e9419391a320) (name (some "foo")) (version 0x16)))
```

### New method: `principal-construct`

* **Input Signatures:**
   * `(principal-construct (buff 1) (buff 20))`
   * `(principal-construct (buff 1) (buff 20) (string-ascii 40))`
* **Output Signature:** `(response principal { error_code: uint, value: (optional principal) })`

A principal value represents either a set of keys, or a smart contract.
The former, called a _standard principal_,
is encoded as a `(buff 1)` *version byte*, indicating the type of account
and the type of network that this principal can spend tokens on,
and a `(buff 20)` *public key hash*, characterizing the principal's unique identity.
The latter, a _contract principal_, is encoded as a standard principal concatenated with
a `(string-ascii 40)` *contract name* that identifies the code body.

The `principal-construct` function allows users to create either standard or contract principals,
depending on which form is used.  To create a standard principal, 
`principal-construct` would be called with two arguments: it
takes as input a `(buff 1)` which encodes the principal address's
`version-byte`, a `(buff 20)` which encodes the principal address's `hash-bytes`.

To create a contract principal, `principal-construct` would be called with
three arguments: the `(buff 1)` and `(buff 20)` to represent the standard principal
that created the contract, and a `(string-ascii 40)` which encodes the contract's name.
On success, this function returns either a standard principal or contract principal, 
depending on whether or not the third `(string-ascii 40)` argument is given.

This function returns a `Response`. On success, the `ok` value is a `Principal`.
The `err` value is a value tuple with the form `{ error_code: uint, value: (optional principal) }`.

If the single-byte `version-byte` is in the valid range `0x00` to `0x1f`, but is not an appropriate
version byte for the current network, then the error will be `u0`, and `value` will contain
`(some principal)`, where the wrapped value is the principal.  If the `version-byte` is not in this range, 
however, then the `value` will be `none`.

If the `version-byte` is a `buff` of length 0, if the single-byte `version-byte` is a
value greater than `0x1f`, or the `hash-bytes` is a `buff` of length not equal to 20, then `error_code`
will be `u1` and `value` will be `None`.

If a name is given, and the name is either an empty string or contains ASCII characters
that are not allowed in contract names, then `error_code` will be `u2`.

**Rationale:** This method empowers developers to convert between Bitcoin and
Stacks addresses, and between Stacks addresses and subnet addresses (with
applications to enabling users to prove control of assets on different chains
within a smart contract).  In addition, it provides introspection for smart
contract addresses.

**Examples:**

```clarity
(principal-construct 0x1a 0xfa6bf38ed557fe417333710d6033e9419391a320) ;; Returns (ok ST3X6QWWETNBZWGBK6DRGTR1KX50S74D3425Q1TPK)
(principal-construct 0x1a 0xfa6bf38ed557fe417333710d6033e9419391a320 "foo") ;; Returns (ok ST3X6QWWETNBZWGBK6DRGTR1KX50S74D3425Q1TPK.foo)
(principal-construct 0x16 0xfa6bf38ed557fe417333710d6033e9419391a320) ;; Returns (err (tuple (error_code u0) (value (some SP3X6QWWETNBZWGBK6DRGTR1KX50S74D3433WDGJY))))
(principal-construct 0x16 0xfa6bf38ed557fe417333710d6033e9419391a320 "foo") ;; Returns (err (tuple (error_code u0) (value (some SP3X6QWWETNBZWGBK6DRGTR1KX50S74D3433WDGJY.foo))))
(principal-construct 0x   0xfa6bf38ed557fe417333710d6033e9419391a320) ;; Returns (err (tuple (error_code u1) (value none)))
(principal-construct 0x16 0xfa6bf38ed557fe417333710d6033e9419391a3)   ;; Returns (err (tuple (error_code u1) (value none)))
(principal-construct 0x20 0xfa6bf38ed557fe417333710d6033e9419391a320) ;; Returns (err (tuple (error_code u1) (value none)))
(principal-construct 0x1a 0xfa6bf38ed557fe417333710d6033e9419391a320 "") ;; Returns (err (tuple (error_code u2) (value none)))
(principal-construct 0x1a 0xfa6bf38ed557fe417333710d6033e9419391a320 "foo[") ;; Returns (err (tuple (error_code u2) (value none)))
```

### New method: `get-burn-block-info?`

* **Input Signature:** `(get-burn-block-info? (prop-name BurnBlockPropertyName) (block-height uint))`
* **Output Signature:** `(optional buff) | (optional (tuple (addrs (list 2 (tuple (hashbytes (buff 32)) (version (buff 1))))) (payout uint)))`

The `get-burn-block-info?` function fetches data for a block of the given *burnchain* block height. The
value and type returned are determined by the specified `BlockInfoPropertyName`.  Valid values for `block-height` only
include heights between the burnchain height at the time the Stacks chain was launched, and the last-processed burnchain
block.  If the `block-height` argument falls outside of this range, then `none` shall be returned.

The following `BurnBlockInfoPropertyName` values are defined:

* The `header-hash` property returns a 32-byte buffer representing the header hash of the burnchain block at
burnchain height `block-height`.

* The `pox-addrs` property returns a tuple with two items: a list of up to two PoX addresses that received a PoX payout at that block height, and the amount of burnchain
tokens paid to each address (note that per the blockchain consensus rules, each PoX payout will be the same for each address in the block-commit transaction).
The list will include burn addresses -- that is, the unspendable addresses that miners pay to when there are no PoX addresses left to be paid.  During the prepare phase,
there will be exactly one burn address reported. During the reward phase, up to two burn addresses may be reported in the event that some PoX reward slots are not claimed.

The `addrs` list contains the same PoX address values passed into the PoX smart contract:
   * They each have type signature `(tuple (hashbytes (buff 32)) (version (buff 1)))`
   * The `version` field can be any of the following:
      * `0x00` means this is a pay-to-public-key-hash (p2pkh) address, and `hashbytes` is the 20-byte hash160 of a single public key
      * `0x01` means this is a pay-to-script-hash (p2sh) address, and `hashbytes` is the 20-byte hash160 of a redeemScript script
      * `0x02` means this is a pay-to-witness-public-key-hash-over-pay-to-script-hash (p2wpkh-p2sh) address, and `hashbytes` is the 20-byte hash160 of a p2wpkh witness script
      * `0x03` means this is a pay-to-witness-script-hash-over-pay-to-script-hash (p2wsh-p2sh) address, and `hashbytes` is the 20-byte hash160 of a p2wsh witness script
      * `0x04` means this is a pay-to-witness-public-key-hash (p2wpkh) address, and `hashbytes` is the 20-byte hash160 of the witness script
      * `0x05` means this is a pay-to-witness-script-hash (p2wsh) address, and `hashbytes` is the 32-byte sha256 of the witness script
      * `0x06` means this is a pay-to-taproot (p2tr) address, and `hashbytes` is the 32-byte sha256 of the witness script

**Rationale:**  This method empowers developers to query Bitcoin state.  Stacks
2.1 adds the ability for smart contracts to query PoX payouts directly, with applications
for Stacking pools and other Stacking-centric programs.

**Examples:**

```clarity
(get-burn-block-info? header-hash u677050) ;; Returns (some 0xe67141016c88a7f1203eca0b4312f2ed141531f59303a1c267d7d83ab6b977d8)
(get-burn-block-info? pox-addrs u677050) ;; Returns (some (tuple (addrs ((tuple (hashbytes 0x395f3643cea07ec4eec73b4d9a973dcce56b9bf1) (version 0x00)) (tuple (hashbytes 0x7c6775e20e3e938d2d7e9d79ac310108ba501ddb) (version 0x01)))) (payout u123)))
```

### New method: `slice`

* **Input Signature:** `(slice (sequence sequence_A) (left-position uint) (right-position uint))`
* **Output Signature:** `(optional sequence_A)`

The `slice` function attempts to return a sub-sequence of `sequence_A` that starts
at `left-position` (inclusive), and ends at `right-position`
(non-inclusive).

If `left-position`==`right-position`, the function returns an empty
sequence.

If either `left-position` or `right-position` are out of bounds OR if
`right-position` is less than `left-position`, the function returns
`none`.

Values in `sequence_A` are zero-based.  That is, the first item in `sequence_A`
is at index 0. 

**Rationale:** This method facilitates parsing user-supplied encoded data, such
as data from oracles and other off-chain services.  While a variant of `slice`
could be implemented entirely in Clarity, it would be much slower and much more
expensive than supplying a native method.

**Examples:**

```clarity
(slice "blockstack" u5 u10) ;; Returns (some "stack")
(slice (list 1 2 3 4 5) u5 u9) ;; Returns none
(slice (list 1 2 3 4 5) u3 u4) ;; Returns (some (4))
(slice "abcd" u0 u2) ;; Returns (some "ab")
(slice "abcd" u1 u3) ;; Returns (some "bc")
(slice "abcd" u2 u2) ;; Returns (some "")
(slice "abcd" u3 u1) ;; Returns none
```

### New method: `string-to-int`

* **Input Signature:** `(string-to-int (input (string-ascii|string-utf8)))`
* **Output Signature:** `(optional int)`

Converts a string, either `string-ascii` or `string-utf8`, to an
optional-wrapped signed integer.  If the input string does not
represent a valid integer in decimal format, then the function returns `none`. Otherwise
it returns an `int` wrapped in `some`.

**Rationale:** This method facilitates parsing user-supplied encoded data from
text.  While this functionality could have been implemented in Clarity, it would
have been much more expensive to use.

**Examples:**

```clarity
(string-to-int "1") ;; Returns (some 1)
(string-to-int u"-1") ;; Returns (some -1)
(string-to-int "a") ;; Returns none
```

### New method: `string-to-uint`

* **Input Signature:** `(string-to-uint (input (string-ascii|string-utf8)))`
* **Output Signature:** `(optional uint)`

Converts a string, either `string-ascii` or `string-utf8`, to an
optional-wrapped `uint`.  If the input string does not represent a
valid non-negative integer in decimal format, then the function returns
`none`. Otherwise it returns an `uint` wrapped in `some`.

**Rationale:** This method facilitates parsing user-supplied encoded data from
text.  While this functionality could have been implemented in Clarity, it would
have been much more expensive to use.

**Examples:**

```clarity
(string-to-uint "1") ;; Returns (some u1)
(string-to-uint u"1") ;; Returns (some u1)
(string-to-uint "a") ;; Returns none
```

### New method: `int-to-ascii`

* **Input Signature:** `(int-to-ascii (input (int|uint)))`
* **Output Signature:** `string-ascii`

Converts  an integer,  either  `int` or  `uint`,  to a  `string-ascii`
string-value representation in decimal format.

**Rationale:** This method facilitates parsing user-supplied encoded data from
text.  While this functionality could have been implemented in Clarity, it would
have been much more expensive to use.

**Examples:**

```clarity
(int-to-ascii 1) ;; Returns "1"
(int-to-ascii u1) ;; Returns "1"
(int-to-ascii -1) ;; Returns "-1"
```

### New method: `int-to-utf8`

* **Input Signature:** `(int-to-utf8 (input (int|uint)))`
* **Output Signature:** `string-utf8`

Converts an integer, either `int` or `uint`, to a `string-utf8`
string-value representation in decimal format.

**Rationale:** This method facilitates parsing user-supplied encoded data from
text.  While this functionality could have been implemented in Clarity, it would
have been much more expensive to use.

**Examples:**

```clarity
(int-to-utf8 1) ;; Returns u"1"
(int-to-utf8 u1) ;; Returns u"1"
(int-to-utf8 -1) ;; Returns u"-1"
```

### New method: `buff-to-int-le`

* **Input Signature:** `(buff-to-int-le (input (buff 16)))`
* **Output Signature:** `int`

Converts a byte buffer to a signed integer use a little-endian
encoding.  The byte buffer can be up to 16 bytes in length. If there
are fewer than 16 bytes, as this function uses a little-endian
encoding, the input behaves as if it is zero-padded on the _right_.

**Rationale:** This method facilitates parsing user-supplied encoded data, or
data available on-chain that is currently represented as a `buff`.
While this functionality could have been implemented in Clarity, it would
have been much more expensive to use.

**Examples:**

```clarity
(buff-to-int-le 0x01) ;; Returns 1
(buff-to-int-le 0x01000000000000000000000000000000) ;; Returns 1
(buff-to-int-le 0xffffffffffffffffffffffffffffffff) ;; Returns -1
(buff-to-int-le 0x) ;; Returns 0
```

### New method: `buff-to-uint-le`

* **Input Signature:** `(buff-to-uint-le (input (buff 16)))`
* **Output Signature:** `uint`

Converts a byte buffer to an unsigned integer use a little-endian
encoding..  The byte buffer can be up to 16 bytes in length. If there
are fewer than 16 bytes, as this function uses a little-endian
encoding, the input behaves as if it is zero-padded on the _right_.

**Rationale:** This method facilitates parsing user-supplied encoded data, or
data available on-chain that is currently represented as a `buff`.
While this functionality could have been implemented in Clarity, it would
have been much more expensive to use.

**Examples:**

```clarity
(buff-to-uint-le 0x01) ;; Returns u1
(buff-to-uint-le 0x01000000000000000000000000000000) ;; Returns u1
(buff-to-uint-le 0xffffffffffffffffffffffffffffffff) ;; Returns u340282366920938463463374607431768211455
(buff-to-uint-le 0x) ;; Returns u0
```

### New method: `buff-to-int-be`

* **Input Signature:** `(buff-to-int-be (input (buff 16)))`
* **Output Signature:** `int`

Converts a byte buffer to a signed integer use a big-endian encoding.
The byte buffer can be up to 16 bytes in length. If there are fewer
than 16 bytes, as this function uses a big-endian encoding, the input
behaves as if it is zero-padded on the _left_.

**Rationale:** This method facilitates parsing user-supplied encoded data, or
data available on-chain that is currently represented as a `buff`.
While this functionality could have been implemented in Clarity, it would
have been much more expensive to use.

**Examples:**

```clarity
(buff-to-int-be 0x01) ;; Returns 1
(buff-to-int-be 0x00000000000000000000000000000001) ;; Returns 1
(buff-to-int-be 0xffffffffffffffffffffffffffffffff) ;; Returns -1
(buff-to-int-be 0x) ;; Returns 0
```

### New method: `buff-to-uint-be`

* **Input Signature:** `(buff-to-uint-be (input (buff 16)))`
* **Output Signature:** `uint`

Converts a byte buffer to an unsigned integer use a big-endian
encoding.  The byte buffer can be up to 16 bytes in length. If there
are fewer than 16 bytes, as this function uses a big-endian encoding,
the input behaves as if it is zero-padded on the _left_.

**Rationale:** This method facilitates parsing user-supplied encoded data, or
data available on-chain that is currently represented as a `buff`.
While this functionality could have been implemented in Clarity, it would
have been much more expensive to use.

**Examples:**

```clarity
(buff-to-uint-be 0x01) ;; Returns u1
(buff-to-uint-be 0x00000000000000000000000000000001) ;; Returns u1
(buff-to-uint-be 0xffffffffffffffffffffffffffffffff) ;; Returns u340282366920938463463374607431768211455
(buff-to-uint-be 0x) ;; Returns u0
```

### New method: `stx-transfer-memo?`

* **Input Signature:** `(stx-transfer? (amount uint) (sender principal) (recipient principal) (memo (buff 34)))`
* **Output Signature:** `(response bool uint)`

`stx-transfer-memo?` is similar to `stx-transfer?`, except that it
adds a `memo` field.

This function returns `(ok true)` if the transfer
is successful, or, on an error, returns the same codes as
`stx-transfer?`.

**Rationale:** This method facilitates integration with exchanges.  Exchanges
often require a memo field for transferring funds into and out of their wallets,
often for the purposes of multiplexing one address into many user accounts.
Adding a native `stx-transfer-memo?` function makes it easy for smart contracts
to interact with exchanges that follow this convention.

**Examples:**

```clarity
(as-contract
  (stx-transfer? u50 'SP3X6QWWETNBZWGBK6DRGTR1KX50S74D3433WDGJY tx-sender 0x00)) ;; Returns (err u4)
(stx-transfer-memo? u60 tx-sender 'SP3X6QWWETNBZWGBK6DRGTR1KX50S74D3433WDGJY 0x010203) ;; Returns (ok true)
```

### New method: `is-standard`

* **Input Signature:** `(is-standard (standard-or-contract principal))`
* **Output Signature:** `bool`

Tests whether `standard-or-contract` _matches_ the current network
type, and therefore represents a principal that can spend tokens on the current
network type. That is, the network is either of type `mainnet`, or `testnet`.
Only `SPxxxx` and `SMxxxx` _c32check form_ addresses can spend tokens on
a mainnet, whereas only `STxxxx` and `SNxxxx` _c32check forms_ addresses can spend
tokens on a testnet. All addresses can _receive_ tokens, but only principal
_c32check form_ addresses that match the network type can _spend_ tokens on the
network.  This method will return `true` if and only if the principal matches
the network type, and false otherwise.

**Rationale:** This method facilitates authenticating principal types supplied
by contract-calls or from decoded data.  Because principals must have the
correct version byte in order to spend tokens, ensuring contracts can perform
this check is of paramount importance to avoid loss-of-funds.

**Examples:**

```clarity
(is-standard 'STB44HYPYAT2BB2QE513NSP81HTMYWBJP02HPGK6) ;; returns true on testnet and false on mainnet
(is-standard 'STB44HYPYAT2BB2QE513NSP81HTMYWBJP02HPGK6.foo) ;; returns true on testnet and false on mainnet
(is-standard 'SP3X6QWWETNBZWGBK6DRGTR1KX50S74D3433WDGJY) ;; returns true on mainnet and false on testnet
(is-standard 'SP3X6QWWETNBZWGBK6DRGTR1KX50S74D3433WDGJY.foo) ;; returns true on mainnet and false on testnet
(is-standard 'SZ2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKQ9H6DPR) ;; returns false on both mainnet and testnet
```

### New method: `to-consensus-buff`

* **Input Signature:** `(to-consensus-buff x)`
* **Output Signature:** `(optional buff))`

The `to-consensus-buff` function is a special function that will serialize any
Clarity value into a buffer, using the SIP-005 serialization of the
Clarity value. Not all values can be serialized: some value's
consensus serialization is too large to fit in a Clarity buffer (this
is because of the type prefix in the consensus serialization).

If the value cannot fit as serialized into the maximum buffer size (1 MB),
this returns `none`, otherwise, it will be
`(some consensus-serialized-buffer)`. During type checking, the
analyzed type of the result of this method will be the maximum possible
consensus buffer length based on the inferred type of the supplied value.
Note that it is possible to construct a valid Clarity value whose buffer
serialization exceeds 1 MB; however, this is highly unlikely to happen by
accident.

**Rationale:** This method is used to facilitate interactions with off-chain
services, and to export data from a smart contract that can be consumed
off-chain.

**Examples:**

```clarity
(to-consensus-buff 1) ;; Returns (some 0x0000000000000000000000000000000001)
(to-consensus-buff u1) ;; Returns (some 0x0100000000000000000000000000000001)
(to-consensus-buff true) ;; Returns (some 0x03)
(to-consensus-buff false) ;; Returns (some 0x04)
(to-consensus-buff none) ;; Returns (some 0x09)
(to-consensus-buff 'SZ2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKQ9H6DPR) ;; Returns (some 0x051fa46ff88886c2ef9762d970b4d2c63678835bd39d)
(to-consensus-buff { abc: 3, def: 4 }) ;; Returns (some 0x0c00000002036162630000000000000000000000000000000003036465660000000000000000000000000000000004)
```

### New method: `from-consensus-buff`

* **Input Signature:** `(from-consensus-buff type-signature buff)`
* **Output Signature:** `(optional t)`

The `from-consensus-buff` function is a special function that will deserialize a
buffer into a Clarity value, using the SIP-005 serialization of the
Clarity value. The type that `from-consensus-buff` tries to deserialize
into is provided by `type-signature`. If it fails
to deserialize the `buff` argument to this type, the method returns `none`.
Note that the given `buff` argument cannot represent more than 1 MB of data.

**Rationale:** This method is used to facilitate interactions with off-chain
services, and to implement "transaction-less transactions.""  The ability to
both verify the signature on a buffer and decode the buffer into a Clarity
value is a basic building block for bridges and oracles.  In addition, it is a
basic building block for smart contracts where users are not expected to send
transactions (e.g. because they lack a wallet, or because the transaction volume
would be too high).  Instead, they can send signed Clarity values to someone willing to
package them into transactions at a later time (possibly as a batch), and
send them to the smart contract on their behalf.

**Examples:**

```clarity
(from-consensus-buff int 0x0000000000000000000000000000000001) ;; Returns (some 1)
(from-consensus-buff uint 0x0000000000000000000000000000000001) ;; Returns none
(from-consensus-buff uint 0x0100000000000000000000000000000001) ;; Returns (some u1)
(from-consensus-buff bool 0x0000000000000000000000000000000001) ;; Returns none
(from-consensus-buff bool 0x03) ;; Returns (some true)
(from-consensus-buff bool 0x04) ;; Returns (some false)
(from-consensus-buff principal 0x051fa46ff88886c2ef9762d970b4d2c63678835bd39d) ;; Returns (some SZ2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKQ9H6DPR)
(from-consensus-buff { abc: int, def: int } 0x0c00000002036162630000000000000000000000000000000003036465660000000000000000000000000000000004) ;; Returns (some (tuple (abc 3) (def 4)))
```

### New method: `replace-at`

* **Input Signature:** `(replace-at (x (sequence Y)) (i uint) (value Y))`
* **Output Signature:** `(optional (sequence Y))`

The `replace-at` function takes in a sequence, an index, and an element, 
and returns a new sequence with the data at the index position replaced with the given element. 

The supported sequence types are `string-ascii`, `string-utf8`, `buff`, and
`list`.

* If `(sequence Y)` is either `(string-ascii ...)` or `(string-utf8...)`, then `(value Y)`
must be a `(string-ascii 1)` or a `(string-utf8 1)`, respectively.

* If `(sequence Y)` is `(buff ...)`, then `(value Y)` must be a `(buff 1)`.

* If `(sequence Y)` is a `(list Y ...)` (i.e. a list of values of type `Y`), then `(value Y)` 
must be a value of type `Y`.

If the provided index is out of bounds, this functions returns `none`.

Note that sequences are zero-indexed.  The first item in `x` is at index 0.

**Rationale:** This method makes it possible to set values of a sequence type
without incurring the costs of splitting the sequence into subsequences,
and concatenating them back together with the new value.  This operation is also
a common facility in many other languages, so supporting it in Clarity would
make Clarity more approachable to new developers.

**Examples:**

```clarity
(replace-at u"ab" u1 u"c") ;; Returns (some u"ac")
(replace-at 0x00112233 u2 0x44) ;; Returns (some 0x00114433)
(replace-at "abcd" u3 "e") ;; Returns (some "abce")
(replace-at (list 1) u0 10) ;; Returns (some (10))
(replace-at (list (list 1) (list 2)) u0 (list 33)) ;; Returns (some ((33) (2)))
(replace-at (list 1 2) u3 4) ;; Returns none
```

### New global: `tx-sponsor?`

* **Type:** `(optional principal)`

This global variable evaluates to the fee-sponsoring principal of the current transaction (if there is such a principal).

**Rationale:** Stacks already exposes the origin address as `tx-sender`, and
exposing this data would make it possible to build smart contracts where only
certain entities could relay transactions on behalf of users (such as entities
with which the user has an off-chain business relationship).

### New global: `chain-id`

* **Type:** `uint`

This global variable evaluates to a 32-bit chain ID that identifies this
instance of the Stacks blockchain.  The purpose of this global variable is to
give contract developers a way to determine which instance of Stacks their code
runs on, in order to execute instance-specific logic or integrate with
instance-specific off-chain services.

The following values are reported:

* `u1`:  This is the Stacks mainnet chain (this is `0x00000001`).

* `u2147483648`:  This is the Stacks testnet chain (this is `0x80000000`).

Other values may be used for other deployments of Stacks, such as (but not
limited to) subnets.

**Rationale**: Stacks already has two instances (testnet and mainnet), and
subnets are instances of Stacks.  Enabling smart contracts to differentiate
between which environments they run in would empower developers to add
(or rely on) chain-specific features.

### New feature: Faster Clarity Parser

This SIP proposes a new Clarity lexer and parser implementation that will be
specific to Clarity 2.  Current benchmarks indicate that the reference
implementation of this new lexer and parser it is around 3x faster than the
reference implementation of the chain today.

The reason for proposing this as a breaking change is to de-risk the possibility
that the new lexer and parser are not "bug-for-bug" compatible with the current
parser.  Tying the release of this new lexer and parser with a breaking change,
while keeping the old parser for processing all blocks prior to the change,
ensures that any new behaviors introduced will only apply to transactions after
the change takes effect.

### New feature: New Trait Semantics

Over the lifetime of Clarity 1, it was discovered that there are a few
surprising behaviors of the current trait semantics.  Clarity 2 proposes the
following new trait semantics:

* **Traits are real types.** The Clarity 2 type system will analyze and propagate
  the type of a trait value in the same ways that it does with other types. This
means that in Clarity 2, trait values can be embedded into complex types (lists,
tuples, optionals, and responses) and maintain their ability to enable dynamic
dispatch. The only limitation on the trait type is that trait values may not be
persisted (e.g. in a data-var or map). Persisting a trait value, and maintaining
the ability to perform dynamic dispatch would inhibit static analysis of a
contract.

* **Trait values may be coerced into compatible trait types.**  When type
  checking a trait value against another trait type, the expected trait type
need not be the identical trait type of the value; instead, the trait value is
checked for compatibility with the expected type, meaning that if the expected
trait type is a subset of the trait value's type, then the coercion is legal.
See below for an example.

* **Trait values may be locally bound.** A trait value can be bound in a local
  scope and maintain its trait type and dynamic dispatch functionality. Binding
in a local scope includes `let` expressions and `match` expressions.

* **Traits may not be defined with duplicate function names.**  In Clarity 1 a
  trait could be defined with duplicated function names in its signature. This
resulted in only the last instance (in program order) being kept as part of the
trait's definition. In Clarity 2, a trait defined with a duplicate function name
will trigger an analysis error, preventing it from being mined in a block.

* **Contract principals stored in constants are callable.**  Clarity 2 allows a
  constant contract principal (defined with a `define-constant`) to be callable --
used to make static dispatch contract calls, or coerced into a trait type.

* **Imported trait name conflicts.** In Clarity 1, there is surprising behavior
  relating to the names of imported traits (from `use-trait`). The name of a local
trait will conflict with the trait name of the imported trait. For example, in
`(use-trait a-alias .a-trait.a)` if a local trait is defined with the name `a`, then
uses of `a-alias` will refer to the local trait, `a`, instead of the imported trait.
In Clarity 2, the imported trait can always be referenced by its alias and the
imported trait name will not conflict with local traits.

Clarity 1 trait semantics are preserved in Clarity 1 code.

#### Examples

```clarity
;; use trait in optional
(define-public (execute (job (optional <job-trait>))) (match job j (contract-call? j fn) (default-job)))

;; use of compatible traits, e.g. marketplace commissions
(define-trait t1 ((fn (response uint bool)))) 
(define-trait t2 ((fn (response uint bool)))) 
```

```clarity
;; --- contract 1
(impl-trait .contract.t1)
;; ...
```

```clarity
;; -- contract 2
(impl-trait .contract.t2)
;; ...
```

```clarity
;; -- contract 3
(use-trait t contract.t1)
;; can be called with contract 1 and contract 2 because of compatible traits
(define-public (meta-fn (ctr <t>)...)
```

### Changed: Comparators `>`, `>=`, `<=`, `<`

In Clarity version 2, these binary comparators will be extended to support
comparison of `string-ascii`, `string-utf8` and `buff`.

These comparisons are executed as follows:

* For `buff` and `string-ascii`, comparison is done on a byte-by-byte basis
  until a difference is found, or until the end of one sequence is reached.  In
  the first case, the differing bytes are compared with the comparator.  In the
  second case, the shorter of the two sequences is considered to be "less than"
  the other.

* For `string-utf8`, comparison is done on a codepoint-by-codepoint basis.
  Each codepoint occupies between 1 and 4 bytes.  Comparing two codepoints is
  the act of comparing them on a byte-by-byte basis, just as if they were `(buff 4)`s.
  Comparison proceeds until either a difference is found, or until the end of
  one sequence is reached. In the first case, the differing codepoints are
  compared with the comparator. In the second case, the shorter of the two
  sequences (as measured by number of codepoints) is considered to be "less than"
  the other.

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
(< 0x01 0x0100) ;; Returns true
(< 0x01ff 0x01) ;; Returns false
(> 0x01ff 0x01) ;; Returns true
(< 0x01ff 0x02) ;; Returns true
(< u"\u{0380}" u"Z") ;; Returns false
(< u"\u{5a}" u"\u{5b}") ;; Returns true
(<= u"\u{5a}" u"Z") ;; Returns true
(>= u"\u{5a}" u"Z") ;; Returns true
(< u"stacks" u"st\u{c3a4}cks") ;; Returns true
```

### Changed: `get-block-info?`

The following new properties are proposed to be added `get-block-info?`:

* `block-reward`: This property returns a `uint` value for the total block reward of the indicated Stacks block.  This value is only available once the reward for 
the block matures.  That is, the latest `block-reward` value available is at least 101 Stacks blocks in the past (on mainnet).  The reward includes the coinbase,
the anchored block's transaction fees, and the shares of the confirmed and produced microblock transaction fees earned by this block's miner.  Note that this value may 
be smaller than the Stacks coinbase at this height, because the miner may have been punished with a valid `PoisonMicroblock` transaction in the event that the miner
published two or more microblock stream forks.

* `miner-spend-total`: This property returns a `uint` value for the total number of burnchain tokens (i.e. satoshis) spent by all miners trying to win this block.  This does _not_ 
include burnchain transaction fees.

* `miner-spend-winner`: This property returns a `uint` value for the number of burnchain tokens (i.e. satoshis) spent by the winning miner for this Stacks block.  Note that
this value is less than or equal to the value for `miner-spend-total` at the same block height.  This does _not_ include burnchain transaction fees.

**Rationale**: These changes to `get-block-info?` empower developers to
determine how many burnchain tokens (e.g. satoshis) are spent for STX on a
block-by-block basis, without having to rely on an off-chain oracle.

### Fixed: `principal-of?`

The `principal-of?` function returns the principal derived from the
provided public key.

If the `public-key` is invalid, it will return the error code `(err u1).`.

Before Stacks 2.1, this function has a bug, in that the principal
returned would always be a testnet single-signature principal, even if
the function were run on the mainnet. In Clarity version 2, this bug
is fixed, so that this function will return a principal suited to the
network it is called on. In particular, if this is called on the
mainnet, it will return a single-signature mainnet principal.

## Block Validation

### New Transaction: Alternative Coinbase Recipient

To enable miners to pay their block rewards to a cold wallet address, and to
enable mining pools to pay block rewards to a custodian smart contract address,
the Coinbase transaction payload is altered to include an alternative address to
which the block reward will materialize.  Its encoding is described as follows:

* **Payload Type ID**: 0x05
* **Payload**:
   * **Coinbase Memo**: 32 bytes
   * **Recipient Address**: variable bytes
      * This is an encoded Clarity `principal` value.  See SIP-005 for details.

### New Transaction: Versioned Smart Contract 

To support offering developers a choice to use Clarity 1 or Clarity 2, this SIP
proposes a new Stacks transaction payload variant for deploying a **versioned
smart contract**.  Its encoding is described as follows:

* **Payload Type ID**: 0x06
* **Payload**:
   * **Clarity Version**: 1 byte
      * 0x01: this is a Clarity 1 contract
      * 0x02: this is a Clarity 2 contract
   * **Smart-contract Payload**: variable bytes
      * This is identical to the smart-contract payload definition in SIP-005.
        It contains a length-prefixed name and a length-prefixed code body.  See
        SIP-005 for details.

## New Burnchain Transaction: `delegate-stx`

This SIP proposes adding support for issuing a `delegate-stx` call to PoX
from the burnchain, similar to how `stx-transfer?` and `stack-stx` are supported
as burnchain-hosted transactions in SIP-007.  The rationale for this is that
users may wish to maintain ownership of their STX tokens via burnchain
addresses, but permit Stacking them via Stacks addresses.  This way, the Stacks
blockchain will be better able to accommodate users who already have set up
and secured burnchain wallets to hold their STX.

The burnchain wire format is as follows:

* For the Bitcoin chain:
   (TODO; PR still in review) 

### Changed: PoX with Forkable PoX Anchor Blocks

This SIP proposes making the history of PoX anchor blocks itself forkable, and by implementing
Nakamoto consensus on the PoX anchor block history forks so that there
will always be a canonical PoX anchor block history. In doing so, the
Stacks blockchain now has three levels of forks: the Bitcoin chain,
the history of PoX anchor blocks, and the history of Stacks
blocks. The canonical Stacks fork is the longest history of Stacks
blocks that passes through the canonical history of anchor blocks
which resides on the canonical Bitcoin chain.

To enable this, this SIP proposes a couple additional requirements for PoX anchor block
selection over those in SIP-007.  The rationale for these changes is to make
it possible to identify the PoX anchor block's block-commit _without having the Stacks chain state._
The reason this is important is because it allows the honest miners of the
network to identify _and ignore_ a hidden PoX anchor block that is no longer on the
canonical Stacks fork (should it be found later), which in turn prevents a hidden PoX anchor block's
arrival from triggering a deep chain reorganization.  The two additional
requirements for PoX anchor blocks are:

* **Heaviest block-commit**.  The PoX anchor block _must_ be mined in a
block-commit whose descendant block-commits in the prepare phase collectively represent
the most burnchain tokens (i.e. satoshis) burnt, out of all candidates.
This will statistically almost always be the case if there
is no or little contention between miners, but in the event that two or more
histories of block-commits arise which both (a) span at least 80 Bitcoin blocks
and (b) descend from conflicting PoX anchor blocks, then this rule is used to
break ties.  In the event that two such histories arise that burn an equal
amount of BTC, the PoX anchor block-commit which occurs _higher_ in the
burnchain is selected.  Note that at most one of these block-commit histories
will correspond to valid Stacks blocks, since each Bitcoin block in a prepare
phase chooses at most one block-commit as corresponding to a Stacks block in _any_
Stacks fork.

* **A block can be a PoX anchor block at most once.**  Today, miners can select
  the same Stacks block as the PoX anchor block over and over.  This SIP
proposes removing this possibility.

When these two changes are applied, it becomes possible for nodes to inspect
the burnchain transactions and determine the degree of _affirmation_ each PoX
anchor block selection has received by the network in subsequent prepare phases.  
The miners implicitly affirm the block's presence or absence when they make the
choice as to whether or not to mine off of a descendant.  With these changes, a
node can determine which block-commits correspond to PoX anchor blocks, and
from there, determine how many _subsequent_ PoX anchor blocks have built on a
previous PoX anchor block.

With this knowledge, the node can partition the set of Stacks forks that could
exist (based on the block-commits) into disjoint fork sets, where two forks are in
the same set if they contain the same sequence of PoX anchor blocks.  The
canonical fork _must_ contain the highest possible number of PoX anchor blocks;
all forks that contain fewer than this _must_ be non-canonical.  The node then
proceeds to ignore (i.e. store but not process) PoX anchor blocks for
forks classified as non-canonical in this manner.

The node only processes a deep reorganization -- i.e. switching its view of the
canonical Stacks fork to a Stacks fork that contains a _different_ set of PoX
anchor blocks -- once there exists a Stacks fork with _more_ PoX anchor blocks
than the one it currently treats as canonical.  This would only happen if the
miners of the network had mined sufficiently many PoX anchor blocks in
subsequent prepare phases to have made canonical a fork from a different fork set.
The barrier to entry for miners doing this is quite high: they must
_repeatedly_ select PoX anchor blocks in _multiple_ prepare phases -- more than 
those which have affirmed the current canonical fork -- and they must do so
without 20% or more opposition _each time_.  This makes executing a deep reorg
much harder to do for a malicious miner than it is today, because the malicious
miner must _repeatedly_ out-mine the defenders in each subsequent reward cycle
(and must consistently do so at a level of 80% or higher).  This is what we mean
when we say that PoX anchor blocks are now forkable, and follow Nakamoto
consensus.

In the event that two fork sets represent different PoX anchor blocks, but
represent the same _number_ of PoX anchor blocks, the canonical fork will reside
in the fork set whose PoX anchor block was mined last.

Details on how this feature works can be found in [6] and [7].

## Changed: Burnchain Transaction Grace Period

To address the usability limitations of on-burnchain Stacks operations, this SIP proposes allowing
these transactions to be processed in _all_ Stacks forks built upon within the _six_
Bitcoin blocks mined after such a transaction is mined.  Today, SIP-007
only requires that they are considered in the Stacks block mined in the
subsequent burnchain block (if one exists at all).

The reason for this change is because the existence of orphaned Stacks blocks
and burnchain blocks with no sortition (i.e. "flashblocks") are the root cause
of the poor user experience for on-burnchain transactions.
Today, if a burnchain operation is mined in
burnchain block N, and burnchain block N+1 either has no Stacks block selected
or selects an orphaned Stacks block, then the on-burnchain operation does not
take effect in the canonical Stacks fork.  The user will have wasted their time
and burnchain tokens (i.e. satoshis) attempting to use this facility, and will be forced to
retry the operation.

This proposal increases the period for which an on-burnchain operation will be
considered.  Instead of considering them for the Stacks block mined in
burnchain block N+1, they will be considered in all Stacks blocks mined in
burnchain blocks N+1 through N+6, inclusive.

When mining a block, miners track the on-burnchain transactions from the last 6
burnchain blocks and determine whether or not they have been applied to an
ancestor of the block they are mining.  If not, then they are applied to this
block.  Miners will not apply the on-burnchain operations on subsequent Stacks
blocks built off this block.

### Changed: Pay Transaction Fee before Processing

Prior to 2.1, the transaction-processing logic followed this procedure:

1. Verify that the spending account has enough balance to pay the fee
2. Run the transaction
3. Debit the fee from the spending account

The benefits of this approach are two-fold.  First, a transaction can earn the
paying account the requisite STX to pay its fee in step 3, so a too-low balance is not
necessarily a barrier-to-entry for new users.  Second, a user will not be
penalized in a contract-call or contract-publish transaction if the act of
running the transaction spends more STX than they anticipated.

The problem with this approach in practice is that it creates too much work for
miners.  If the account did not have enough STX left over at the end of step 2,
then step 3 could not complete, and the transaction could not be mined.  This
creates a problem for miners, who are obliged to process the transaction in
step 2 without knowing if an insufficient balance condition could arise in step
3.  Miners are not compensated for this work.  The reference implementation
addresses this problem by never re-considering
such transactions if they are detected, and never propagating them.

In 2.1, this problem is addressed by an alternative processing procedure:

1. Verify that the spending account has enough balance to pay the fee
2. Debit the fee from the spending account
3. Run the transaction

While this means that the benefits of the old approach are lost, it is the
authors' opinion that the upside of ensuring miners get paid for processing
transactions more than make up for this.  Specifically, this change means that
a user's pending transactions cannot be blocked by a dependent transaction in
the mempool which is unmineable simply because the balance was ultimately too
low.  Eliminating this class of errors with this alternative processing
procedure is deemed to itself be beneficial to the user experience above and
beyond what the original benefits offerred.  Furthermore, both the newly-added
`to-consensus-buff` and `from-consensus-buff` Clarity functions and the
existence of sposnored transactions already enable users to send signed Clarity
data to the Stacks blockchain without possessing any STX of their own.

### Changed: Analysis Errors are Runtime Errors

When processing a transaction, a transaction can fail for one of the following two
reasons:

* A **runtime error** can occur, in which the transaction attempts to do
  something the VM prohibits.  For example, divide-by-0 is a runtime error, as
is spending tokens that the caller does not possess.  Today, a transaction that
encounters a runtime error can be included in a block without invalidating the
block.

* A **check error** can occur, in which the transaction attempts to do something
  prohibited by the Clarity language itself.  For example, a transaction
can use `(at-block 0xabc)` to attempt to call a smart contract method in a trait
implementation which was instantiated _after_ the block `0xabc` was mined.
Attempting to call a function in a contract that does not exist is prohibited by
the Clarity language -- such an action cannot be expressed in Clarity.  Today,
a transaction that encounters a check error _cannot_ be included in a valid block.

Most check errors can be caught in the analysis pass of publishing a smart
contract, which would then prohibit them from being published.  However, there
are some classes of check errors (such as the one described above) where this is
infeasible.

This SIP proposes treating all check errors that arise during
transaction-processing as runtime errors.  Transactions that encounter check
errors would be mined, and their fees would be collected, but the transaction's
payload would never be applied to the chainstate.

This change benefits both miners and users.  With this change, miners will get paid for
processing a transaction regardless of how it would fail when executed.  Notably, this change
does _not_ prevent the user's wallet from executing a more-rigorous analysis
pass on any transactions the user sends.

This change also helps users because it means that transactions that encounter
check errors will get cleared from the mempool without any further action on
their parts.  Today, users must replace-by-fee (RBF) the problematic
transaction.

### Changed: Default Clarity Version

The behavior of the Smart-contract Payload transaction payload variant (see
SIP-005) is changed such that the Clarity version used to evaluate a new
contract shall be determined by the current system epoch.  Right now, the system
epoch is 2.05, in which case, a new smart contract instantiated this way shall
be processed with Clarity 1 rules.  In epoch 2.1, a new smart contract instantiated this
way shall be processed with Clarity 2 rules.  Users who wish to publish Clarity
1 contracts in epoch 2.1 can use the versioned smart contract payload described
above.

# Related Work

Most blockchains regularly execute coordinated breaking changes
to add new features or behaviors.  Prominent examples include Ethereum [2] and
Tezos [3].  Indeed, Stacks has already gone through one breaking change [4] via
its SIP process.

Stacks strikes a balance between developer-coordinated breaking changes (like
Ethereum) and self-amending ledgers (like Tezos).  Like Ethereum, changes in
Stacks are sufficiently disruptive that for now, upgrades must be coordinated
out-of-band and are led by developers.  But unlike Ethereum, the Stacks SIP
process [5] has well-defined constraints on developers' ability to effect
changes unilaterally -- in particular, Stacks' governance system requires
independent reviewers to authorize breaking changes, and in the case of breaking
changes, requires (through precedent) users to explicitly consent to them
in-band through coin votes.

# Backwards Compatibility

This SIP retains full backwards-compatibility with the Stacks 2.05 chainstate.
All Clarity features that are supported today will continue to be supported.
However, developers publishing new Clarity 1 contracts will need to use the new
contract-publish transaction and explicitly indicate that they want to use
Clarity 1.  All smart contracts published with the standard contract-publish
transaction will default to using Clarity 2 rules.

Due to the introduction of new reserved keywords in Clarity 2, it will not be
possible to publish an already-written contract as a Clarity 2 contract if it
uses these reserved words for any other purpose.  However, already-deployed
contracts are not affected -- they were published under Clarity 1 rules, and
will continue to be usable as-is.

As mentioned above, Stacking will no longer be possible in the `pox` contract.  Calls to
Stacking operations in `pox` will fail.  All future Stacking operations happen
through the new `pox-2` contract.  However, the read-only contract calls in `pox`
will continue to be available for posterity.

All Stacked STX in `pox` will automatically unlock when this SIP activates, even if
they were locked for subsequent reward cycles.  Users will have a chance to re-Stack
their STX into the new `pox-2` contract in order to continue participating in
PoX once the subsequent reward cycle begins.

# Activation 

Because this SIP proposes a breaking change it is of paramount importance that
the ecosystem find this proposal acceptable.  To measure this, three sets of criteria
must be met in order to determine that there is sufficient support for
this SIP: one set for Stacked STX holders, one set for un-Stacked STX
holders, and one set for miners.  These critera are meant to broaden the set of
participating users above and beyond what has been done in the past.  In
particular, users who do not Stack are invited to vote on this SIP, as are users
who Stack in pools.

In all cases, voting will take place during reward cycles 46 and 47.  This
window is estimated to begin **starting November 10, 2022** and **ending
December 8, 2022**.

## For Stackers

In order for this SIP to activate, the following criteria must be met by the set
of Stacked STX:

* At least 80 million Stacked STX must vote _at all_ to activate this SIP.  This
  number is chosen because it is more than double the amount of STX locked by
the largest Stacker at the time of this writing (reward cycle 44).

* Of the Stacked STX that vote, at least 80% of them must vote "yes."

The act of not voting is the act of siding with the outcome, whatever it may be.
We believe that these thresholds are sufficient to demonstrate interest from
Stackers -- Stacks users who have a long-term interest in the Stacks
blockchain's succesful operation -- in performing this upgrade.

### How To Vote

If a user is Stacking, then their STX can be used to vote in one of two ways,
depending on whether or not they are solo-stacking or stacking through a
delegate.

The reason voting is streched across two reward cycles is to accommodate users
whose STX will have unlocked during the voting period.  If a user's STX
unlock in the first cycle, they can re-Stack them and vote in the second cycle.

In all cases, if a user votes at all, they can only vote in _one_ of the two reward cycles.
If a user casts a vote in both reward cycles, even if it is for the same
decision, then the vote is discarded.

#### Solo Stacking

The user must send a minimal amount of BTC from their PoX reward address to one
of the following Bitcoin addresses:

* For **"yes"**, the address is `11111111111111X6zHB1ZC2FmtnqJ`.  This is the
  base58check encoding of the hash in the Bitcoin script `OP_DUP OP_HASH160
000000000000000000000000007965732d322e31 OP_EQUALVERIFY OP_CHECKSIG`.  The value
`000000000000000000000000007965732d322e31` encodes "yes-2.1" in ASCII, with
0-padding.

* For **"no"**, the address is `1111111111111117CrbcZgemVNFx8`.  This is the
  base58check encoding of the hash in the Bitcoin script `OP_DUP OP_HASH160
00000000000000000000000000006e6f2d322e31 OP_EQUALVERIFY OP_CHECKSIG`.  The value
`00000000000000000000000000006e6f2d322e31` encodes "no-2.1" in ASCII, with
0-padding.

From there, the vote tabulation software will track the Bitcoin transaction back
to the PoX address in the `.pox` contract that sent it, and identify the
quantity of STX it represents.  The STX will count towards a "yes" or "no" based
on the Bitcoin address the PoX address sends to.

If the PoX address holder votes for both "yes" and "no" by the end of the vote,
the vote will be discarded.

Note that this voting procedure does _not_ apply to Stacking pool operators.

#### Pooled Stacking

If the user is stacking in a pool, then they must send a minimal amount of STX
from their Stacking address to one of the following Stacks addresses to commit
their STX to a vote:

* For **"yes"**, the address is `SP00000000000003SCNSJTCHE66N2PXHX`.  This is the
  c32check-encoded Bitcoin address for "yes" (`11111111111111X6zHB1ZC2FmtnqJ`) above.

* For **"no"**, the address is `SP00000000000000DSQJTCHE66XE1NHQ`.  This is the
  c32check-encoded Bitcoin address for "no" (`1111111111111117CrbcZgemVNFx8`)
above.

From there, the vote tabulation software will track the STX back to the sender,
and verify that the sender also has STX stacked in a pool.  The Stacked STX will
be tabulated as a "yes" or "no" depending on which of the above two addresses
receive a minimal amount of STX.

If the Stacks address holder votes for both "yes" and "no" by the end of the
vote period, the vote will be discarded.

## For Non-Stackers

If the user is _not_ Stacking, then they can still vote with their liquid STX.
To facilitate this, the user would vote "yes" or "no" for a forthcoming Stacks 2.1
proposal in EcosystemDAO [1].  The text of this proposal shall be this SIP.
The STX in the user's Hiro Web Wallet will be tabulated 
to count for a "yes" or "no".

To prevent whales from interfering with the vote process, and to prevent
Stackers from also voting with liquid STX that would unlock during the voting
period, a _snapshot_ of all Stacks balances and lock-up states will be used to determine
how many STX a user can commit to a "yes" or "no" vote.  The snapshot will
be back-dated to a Stacks block prior to this SIP's publication, whose hash and
height shall be provided here before this SIP reaches Recommended status.

For this SIP to activate, a 66% majority of liquid STX must vote "yes".  There is no
threshold for how many STX must participate.

To prevent the STX in this back-dated snapshot from being double-counted,
the vote tabulation software will only consider the _untouched_ STX balance
of the address in the snapshot at the _end_ of the voting period.  For example,
if Alice has 100 STX at the time of the snapshot, but transfers 40 STX during
the voting period to a new address (or Stacks 40 STX), then only 60 of her STX
will count for the vote.  Any STX Alice receives after the snapshot will not
count; if Alice later receives 45 STX, then still only 60 of her unspent STX will be
counted.

If a user Stacks their STX and votes with their Stacked STX in addition to with
their liquid STX, then only the unstacked STX will be counted for the liquid STX
vote.  However, the user may vote with their Stacked STX separately.  So for
example, if Alice had 100 STX at the time of the snapshot and Stacks 90 STX,
then she can vote with her 90 STX via the Stacker voting procedure above with
her 90 STX and can vote with the Non-Stacker procedure with her 10 STX.

To prevent exchanges and large liquid holders from interfering with the vote,
each address will only be permitted to vote with a maximum amount of STX equal
to the reward cycle's minimum Stacking threshold in the reward cycle in which
they vote.  For example, if Alice has 1 million liquid STX, but votes in a reward cycle
in which the minimum Stacking threshold is 120,000 STX, then only 120,000 of her
STX will be counted.  This, combined with the fact that the STX balances are
calculated from a frozen snapshot that precedes this vote, ensure that a whale
cannot work around this maximum by distributing their STX across many addresses.

## For Miners

There is only one criterion for miners to activate this SIP: they must mine the
Stacks blockchain up to and past the end of the voting period.  In all reward
cycles between cycle 45 and the end of the voting period, PoX must activate.

## Examples

### Voting "yes" as a solo Stacker

Suppose Alice has stacked 100,000 STX to `1LP3pniXxjSMqyLmrKHpdmoYfsDvwMMSxJ`
during at least one of the voting period's reward cycles.  To vote,
she sends 5500 satoshis for **yes** to `11111111111111X6zHB1ZC2FmtnqJ`.  Then, her 100,000
STX are tabulated as "yes".

### Voting "no" as a pool Stacker

Suppose Bob has Stacked 1,000 STX in a Stacking pool and wants to vote "no", and
suppose it remains locked in PoX during at least one reward cycle in the voting
period.  Suppose his Stacks address is `SP2REA2WBSD3XMVMYS48NJKS3WB22JTQNB101XRRZ`.  To
vote, he sends 1 uSTX from `SP2REA2WBSD3XMVMYS48NJKS3WB22JTQNB101XRRZ` for **no** to
`SP00000000000000DSQJTCHE66XE1NHQ`. Then, his 1,000 STX are tabulated as "no."

### Voting "yes" with liquid STX

Suppose Charlie owns 1,000 STX in his wallet at the time of the snapshot,
and he wants to vote "yes."  To do
this, he would sign into EcosystemDAO (https://stx.eco) with his Web wallet,
select the Stacks 2.1 proposal, and select "yes."  If he does not spend or Stack
any STX over the voting period, then his 1,000 STX are tabulated as "yes."

### Voting "no" with liquid STX that are partially spent

Suppose Danielle owns 1,000 STX in her wallet at the time of the snapshot, and
she wants to vote "no."  After voting as Charlie had done in the previous
example, she sends 200 STX to an exchange, and later receives 30 STX, and
finally unlocks 2,000 STX from a Stacking pool.  In total, only 800 of her STX
will be tabulated as "no."

### Voting with both liquid STX and Stacked STX

Suppose Erik owns 1,000 STX in his wallet at the time of the snapshot, and he
wants to vote "yes."  After voting via EcosystemDAO as Charlie and Danielle
have, he Stacks 900 of his STX in the first voting period reward cycle.  When
the second reward cycle comes, he votes with his Stacked STX address for "no".
In this scenario, 1000 of Erik's STX will have counted towards "yes" for the
non-Stacker vote criteria, and 900 of his STX will have counted towards "no" for
the Stacker vote criteria.

## Activation Status

This section will be expanded as the voting proceeds, and shall record the
history of events leading to the activation or rejection of this SIP.

# Reference Implementation 

The reference implementation of this SIP can be found in the `next` branch of
the Stacks blockchain reference implementation.  It is available at
https://github.com/stacks-network/stacks-blockchain/tree/next.

# References

[1] https://github.com/Clarity-Innovation-Lab/ecosystem-dao

[2] https://ethereum.org/en/history/

[3] https://opentezos.com/tezos-basics/history-of-amendments/

[4] https://github.com/stacksgov/sips/blob/main/sips/sip-012/sip-012-cost-limits-network-upgrade.md

[5] https://github.com/stacksgov/sips/blob/main/sips/sip-000/sip-000-stacks-improvement-proposal-process.md

[6] https://docs.google.com/presentation/d/1iXvQlVZJ30xEB25v3ILHlcKU8eXB9MqpcMUPtoISpM4/edit?usp=sharing

[7] https://us06web.zoom.us/rec/share/vWdVjQ9I_rHsqRiLyo_FBdZFJbsr33tvVl2BdajfwJRFcxxGWrxyyfTuIXfrd-cP.LltAXR2SgAv7H_Vf?startTime=1623866540000
   * Passcode: nHU@4ENY
