# Preamble

SIP Number: 006

Title: Clarity Execution Cost Assessment

Author: Aaron Blankstein <aaron@blockstack.com>, Reed Rosenbluth <reed@blockstack.com>

Consideration: Technical

Type: Consensus

Status: Ratified

Created: 19 October 2019

License: BSD 2-Clause

Sign-off: Jude Nelson <jude@stacks.org>, Technical Steering Committee Chair

Discussions-To: https://github.com/stacksgov/sips

# Abstract

This document describes the measured costs and asymptotic costs
assessed for the execution of Clarity code. This will not specify the
_constants_ associated with those asymptotic cost functions. Those
constants will necessarily be measured via benchmark harnesses and
regression analyses. Furthermore, the _analysis_ cost associated with
this code will not be covered by this proposal.

The asymptotic cost functions for Clarity functions are modifiable
via an on-chain voting mechanism. This enables new native functions to
be added to the language over time.

This document also describes the memory limit imposed during contract
execution, and the memory model for enforcing that limit.

# Introduction

Execution cost of a block of Clarity code is broken into 5 categories:

1. Runtime cost: captures the number of cycles that a single
   processor would require to process the Clarity block. This is a
   _unitless_ metric, so it will not correspond directly to cycles,
   but rather is meant to provide a basis for comparison between
   different Clarity code blocks.
2. Data write count: captures the number of independent writes
   performed on the underlying data store (see SIP-004).
3. Data read count: captures the number of independent reads
   performed on the underlying data store.
4. Data write length: the number of bytes written to the underlying
   data store.
5. Data read length: the number of bytes read from the underlying
   data store.

Importantly, these costs are used to set a _block limit_ for each
block.  When it comes to selecting transactions for inclusion in a
block, miners are free to make their own choices based on transaction
fees, however, blocks may not exceed the _block limit_. If they do so,
the block is considered invalid by the network --- none of the block's
transactions will be materialized and the leader forfeits all rewards
from the block.

## Static versus Dynamic Cost Assessment

Tracking the execution cost of a contract may be done either dynamically
or statically. Dynamic cost assessment involves tracking, at the VM level,
the various metrics as a contract is executed. Static cost assessment is
performed via analysis of the contract source code, and is inherently
a more pessimistic accounting of the execution cost: list operations
are charged according to the _maximum_ size of the list (per the type
annotations and inferences from the source code) and branching statements
are charged according to the _maximum_ branch cost (per metric tracked, i.e.,
if one branch performs 1 write and has a runtime cost of 1, and another
branch performs 0 writes and has a runtime cost of 2, the whole statement
will be assessed as having a maximum of 1 write and runtime cost of 2).

# Specification

## Costs of Common Operations

### Variable Lookup

Looking up variables in Clarity incurs a non-constant cost -- the stack
depth _and_ the length of the variable name affect this cost. However,
variable names in Clarity have bounded length -- 128 characters. Therefore,
the cost assessed for variable lookups may safely be constant with respect
to name length.

The stack depth affects the lookup cost because the variable must be
checked for in each context on the stack.

The cost model of Clarity depends on a copy-on-read semantic for
objects. This allows operations like appends, matches, wrapping/unwrapping,
to be constant cost, but it requires that variable lookups be charged for
copies.

Cost Function:

```
a*X+b*Y+c
```

a, b, and c are constants \
X := stack depth \
Y := variable size

### Function Lookup

Looking up a function in Clarity incurs a constant cost with respect
to name length (for the same reason as variable lookup). However,
because functions may only be defined in the top-level contract
context, stack depth does not affect function lookup.

Cost Function:

```
a
```

a is a constant.

### Name Binding

The cost of binding a name in Clarity -- in either a local or the contract
context is _constant_ with respect to the length of the name:

```
binding_cost = a
```

a is a constant

### Function Application

Function application in Clarity incurs a cost in addition to the
cost of executing the function's body. This cost is the cost of
binding the arguments to their passed values, and the cost of
ensuring that those arguments are of the correct type. Type checks
and argument binding are _linear_ in the size of the arguments.

The cost of applying a function is:


```
(a*X+b) + costEval(body)
```

a and b are constants \
X := the cumulative size of the argument types \
`costEval(body)` := the cost of executing the body of the function

### contract-call Transactions

User-signed transactions for contract-calls are charged for the
application of the function, as well as the loading of the contract
data. This charge is the same as a normal contract-call. _However_,
contract principals that are supplied as trait arguments must be
checked by the runtime system to ensure that they validly implement
the trait. The cost of this check is:

```
read_count = 2
read_length = trait_size + contract_size
runtime_cost = a*(contract_size) + b*(trait_size) + c
```

This check needs to read the trait, and then validate that the supplied
contract fulfills that trait by reading the contract in, and checking
the method signatures. This check must be performed for each such
trait parameter.

### Type Parsing

Parsing a type in Clarity incurs a linear cost in the size of the
AST describing the type:

```
type_parsing_cost(X) = (a*X+b)
```

a, b, are constants \
X := the number of elements in the type description AST

The type description AST is the tree of Clarity language elements used
for describing the type, e.g.:

* `(list 1 uint)` - this AST has four elements: `list`, `1`, `uint`
  and the parentheses containing them.
* `(response bool int)` - this AST has four elements: `response`, `bool`, `int`
  and the parentheses containing them.
* `int` - this AST is just one component.

### Function Definition

Defining a function in Clarity incurs an execution cost at the
time of contract publishing (unrelated to any analysis). This
is the cost of _parsing_ the function's signature, which is linear
in the length of the type signatures, and linear in the length of the
function name and argument names.

```
binding_cost + sum(a + type_parsing_cost(Y) for Y in ARG_TYPES)
```

`type_parsing_cost(Y)` := the cost of parsing argument Y \
ARG_TYPES := the function definition's argument type signatures \
a is a constant associated with the binding of argument types

### Contract Storage Cost

Storing a contract incurs both a runtime cost as well as storage costs. Both of
these are _linear_ the size of the contract AST.

```
WRITE_LENGTH = a*X+b
RUNTIME_COST = c*X+d
```

a, b, c, and d, are constants.

## Initial Native Function Costs

These are the initial set values for native function costs, however, these
can be changed as described below in the [Cost Upgrades](#cost-upgrades)
section of this document.

### Data, Token, Contract-Calls

#### Data Lookup Costs

Fetching data from the datastore requires hashing the key to be looked up.
That cost is linear in the key size:

```
data_hash_cost(X) = a*X+b
```

X := size of the key

#### Data Fetching Costs

Fetching data from the datastore incurs a runtime cost, in addition to
any costs associated with MARF accesses (which are simply counted as the
integer number of times the MARF is accessed). That runtime cost
is _linear_ in the size of the fetched value (due to parsing).

```
read_data_cost = a*X+b
```

X := size of the fetched value.

#### Data Writing Costs

Writing data to the datastore incurs a runtime cost, in addition to
any costs associated with MARF writes (which are simply counted as the
integer number of times the MARF is written). That runtime cost
is _linear_ in the size of the written value (due to data serialization).

```
write_data_cost = a*X+b
```

X := size of the stored value.

#### contract-call

Contract calls incur the cost of a normal function lookup and
application, plus the cost of loading that contract into memory from
the data store (which is linear in the size of the called contract).

```
RUNTIME_COST: (a*Y+b) + func_lookup_apply_eval(X)
READ_LENGTH: Y
```

a and b are constants \
Y := called contract size \
`func_lookup_apply_eval(X)` := the cost of looking up, applying, and
evaluating the body of the function


Note that contract-calls that use _trait_ definitions for dynamic dispatch
are _not_ charged at a different cost rate. Instead, there is a cost for
looking up the trait variable (assessed as a variable lookup), and the cost
of validating any supplied trait implementors is assessed during a transaction's
argument validation.

#### map-get

```
RUNTIME_COST: data_hash_cost(X+Y) + read_data_cost(Z)
READ_LENGTH:  Z
```

X := size of the map's _key_ tuple \
Y := the length of the map's name \
Z := the size of the map's _value_ tuple


#### contract-map-get

```
RUNTIME_COST: data_hash_cost(X) + read_data_cost(Z)
READ_LENGTH:  Z
```

X := size of the map's _key_ tuple \
Z := the size of the map's _value_ tuple

#### map-set

```
RUNTIME_COST: data_hash_cost(X+Y) + write_data_cost(Z)
WRITE_LENGTH:  Z
```

X := size of the map's _key_ tuple \
Y := the length of the map's name \
Z := the size of the map's _value_ tuple

#### map-insert

```
RUNTIME_COST: data_hash_cost(X+Y) + write_data_cost(Z)
WRITE_LENGTH:  Z
```

X := size of the map's _key_ tuple \
Y := the length of the map's name \
Z := the size of the map's _value_ tuple

#### map-delete

```
RUNTIME_COST: data_hash_cost(X+Y) + write_data_cost(1)
WRITE_LENGTH:  1
```

X := size of the map's _key_ tuple \
Y := the length of the map's name \
Y := the length of the map's name

#### var-get

```
RUNTIME_COST: data_hash_cost(1) + read_data_cost(Y)
READ_LENGTH: Y
```

Y := the size of the variable's _value_ type

#### var-set

```
RUNTIME_COST: data_hash_cost(1) + write_data_cost(Y)
WRITE_LENGTH: Y
```

Y := the size of the variable's _value_ type

#### nft-mint

```
RUNTIME_COST: data_hash_cost(Y) + write_data_cost(a) + b
WRITE_LENGTH: a
```

Y := size of the NFT type \
a is a constant: the size of a token owner \
b is a constant cost (for tracking the asset in the assetmap)

#### nft-get-owner

```
RUNTIME_COST: data_hash_cost(Y) + read_data_cost(a)
READ_LENGTH: a
```

Y := size of the NFT type \
a is a constant: the size of a token owner


#### nft-transfer

```
RUNTIME_COST: data_hash_cost(Y) + write_data_cost(a) + write_data_cost(a) + b
READ_LENGTH: a
WRITE_LENGTH: a
```

Y := size of the NFT type \
a is a constant: the size of a token owner \
b is a constant cost (for tracking the asset in the assetmap)

#### ft-mint
 
Minting a token is a constant-time operation that performs a constant
number of reads and writes (to check the total supply of tokens and
incremement).

```
RUNTIME: a
READ_LENGTH: b
WRITE_LENGTH: c
```
a, b, and c are all constants.

#### ft-transfer

Transfering a token is a constant-time operation that performs a constant
number of reads and writes (to check the token balances).

```
RUNTIME: a
READ_LENGTH: b
WRITE_LENGTH: c
```
a, b, and c are all constants.

#### ft-get-balance

Getting a token balance is a constant-time operation that performs a
constant number of reads.

```
RUNTIME: a
READ_LENGTH: b
```
a and b are constants.

#### get-block-info

```
RUNTIME: a
READ_LENGTH: b
```

a and b are constants.

## Control-Flow and Context Manipulation

### let

In addition to the cost of evaluating the body expressions of a `let`,
the cost of a `let` expression has a constant cost, plus
the cost of binding each variable in the new context (similar
to the cost of function evaluation, without the cost of type checks).


```
a + b * Y + costEval(body) + costEval(bindings)
```

a and b are constants \
Y := the number of let arguments \
`costEval(body)` := the cost of executing the body of the let \
`costEval(bindings)` := the cost of evaluating the value of each let binding

### if

```
a + costEval(condition) + costEval(chosenBranch)
```

a is a constant \
`costEval(condition)` := the cost of evaluating the if condition \
`costEval(chosenBranch)` := the cost of evaluating the chosen branch

if computed during _static analysis_, the chosen branch cost is the
`max` of the two possible branches.

### asserts!

```
a + costEval(condition) + costEval(throwBranch)
```

a is a constant \
`costEval(condition)` := the cost of evaluating the asserts condition \
`costEval(throwBranch)` := the cost of evaluating the throw branch in
the event that condition is false

if computed during _static analysis_, the thrown branch cost is always
included.

## List and Buffer iteration
### append

The cost of appending an item to a list is the cost of checking the
type of the added item, plus some fixed cost.

```
a + b * X
```

a and b is a constant \
X := the size of the list _entry_ type

### concat

The cost of concatting two lists or buffers is linear in
the size of the two sequences:

```
a + b * (X+Y)
```

a and b are constants \
X := the size of the right-hand iterable \
Y := the size of the left-hand iterable

### as-max-len?

The cost of evaluating an `as-max-len?` function is constant (the function
is performing a constant-time length check)

### map

The cost of mapping a list is the cost of the function lookup,
and the cost of each iterated function application

```
a + func_lookup_cost(F) + L * apply_eval_cost(F, i)
```

a is a constant \
`func_lookup_cost(F)` := the cost of looking up the function name F \
`apply_eval_cost(F, i)` := the cost of applying and evaluating the body of F on type i \
`i` := the list _item_ type \
`L` := the list length 

If computed during _static analysis_, L is the maximum length of the list
as specified by it's type.

### filter

The cost of filtering a list is the cost of the function lookup,
and the cost of each iterated filter application

```
a + func_lookup_cost(F) + L * apply_eval_cost(F, i)
```

a is a constant \
`func_lookup_cost(F)` := the cost of looking up the function name F \
`apply_eval_cost(F, i)` := the cost of applying and evaluating the body of F on type i \
`i` := the list _item_ type \
`L` := the list length

If computed during _static analysis_, L is the maximum length of the list
as specified by it's type.

### fold


The cost of folding a list is the cost of the function lookup,
and the cost of each iterated application

```
a + func_lookup_cost(F) + (L) * apply_eval_cost(F, i, j)
```

a is a constant \
`func_lookup_cost(F)` := the cost of looking up the function name F \
`apply_eval_cost(F, i, j)` := the cost of applying and evaluating the body of F on types i, j \
`j` := the accumulator type \
`i` := the list _item_ type \
`L` := the list length 

If computed during _static analysis_, L is the maximum length of the list
as specified by it's type.

### len

The cost of getting a list length is constant, because Clarity lists
store their lengths.

### list

The cost of constructing a new list is linear -- Clarity ensures that
each item in the list is of a matching type.

```
a*X+b
```

a and b are constants \
X := the total size of all arguments to the list constructor

### tuple

The cost of constructing a new tuple is `O(nlogn)` with respect to the number of
keys in the tuple (because tuples are represented as BTrees).

```
a*(X*log(X)) + b
```

a and b are constants \
X := the number of keys in the tuple

### get

Reading from a tuple is `O(nlogn)` with respect to the number of
keys in the tuple (because tuples are represented as BTrees).

```
a*(X*log(X)) + b
```

a and b are constants \
X := the number of keys in the tuple

## Option/Response Operations

### match

Match imposes a constant cost for evaluating the match, a cost for checking
that the match-bound name does not _shadow_ a previous variable. The
total cost of execution is:

```
a + evalCost(chosenBranch) + cost(lookupVariable)
```

where a is a constant, and `chosenBranch` is whichever branch
is chosen by the match. In static analysis, this will be:
`max(branch1, branch2)` 

### is-some, is-none, is-error, is-okay

These check functions all have constant cost.

### unwrap, unwrap-err, unwrap-panic, unwrap-err-panic, try!

These functions all have constant cost.

## Arithmetic and Logic Operations

### Variadic operators

The variadic operators (`+`,`-`,`/`,`*`, `and`, `or`) all have costs linear
in the _number_ of arguments supplied

```
(a*X+b)
```

X := the number of arguments

### Binary/Unary operators

The binary and unary operators:

```
>
>=
<
<=
mod
pow
xor
not
to-int
to-uint
```

all have constant cost, because their inputs are all of fixed sizes.

### Hashing functions

The hashing functions have linear runtime costs: the larger the value being
hashed, the longer the hashing function takes.

```
(a*X+b)
```

X := the size of the input.


## Memory Model and Limits

Clarity contract execution imposes a maximum memory usage limit for applications.
For any given Clarity value, the memory usage of that value is counted using
the _size_ of the Clarity value.

Memory is consumed by the following variable bindings:

* `let` - each value bound in the `let` consumes that amount of memory
    during the execution of the `let` block.
* `match` - the bound value in a `match` statement consumes memory during
    the execution of the `match` branch.
* function arguments - each bound value consumes memory during the execution
    of the function. this includes user-defined functions _as well as_ native
    functions.

Additionally, functions that perform _context changes_ also consume memory,
though they consume a constant amount:

* `as-contract`
* `at-block`

### Type signature size

Types in Clarity may be described using type signatures. For example,
`(tuple (a int) (b int))` describes a tuple with two keys `a` and `b`
of type `int`. These type descriptions are used by the Clarity analysis
passes to check the type correctness of Clarity code. Clarity type signatures
have varying size, e.g., the signature `int` is smaller than the signature for a
list of integers.

The size of a Clarity value is defined as follows:

```
type_size(x) :=
  if x = 
     int        => 16
    uint        => 16
    bool        => 1
    principal   => 148
    (buff y)    => 4 + y
    (some y)    => 1 + size(y)
    (ok y)      => 1 + size(y)
    (err y)     => 1 + size(y)
    (list ...)  => 4 + sum(size(z) for z in list)
    (tuple ...) => 1 + 2*(count(entries)) 
                     + sum(size(z) for each value z in tuple)
```

### Contract Memory Consumption

Contract execution requires loading the contract's program state in
memory. That program state counts towards the memory limit when
executed via a programmatic `contract-call!` or invoked by a
contract-call transaction.

The memory consumed by a contract is equal to:

```
a + b*contract_length + sum(size(x) for each constant x defined in the contract)
```

That is, a contract consumes memory which is linear in the contract's
length _plus_ the amount of memory consumed by any constants defined
using `define-constant`.

### Database Writes

While data stored in the database itself does _not_ count against the
memory limit, supporting public function abort/commit behavior requires
holding a write log in memory during the processing of a transaction.

Operations that write data to the data store therefore consume memory
_until the transaction completes_, and the write log is written to the
database. The amount of memory consumed by operations on persisted data
types is defined as:

* `data-var`: the size of the stored data var's value.
* `map`: the size of stored key + the size of the stored value.
* `nft`: the size of the NFT key
* `ft`: the size of a Clarity uint value.

## Cost Upgrades

In order to enable the addition of new native functions to the Clarity
language, there is a mechanism for voting on and changing a function's
_cost-assessment function_ (the asymptotic function that describes its
complexity and is used to calculate its cost). 

New functions can be introduced to Clarity by first being implemented
_in_ Clarity and published in a contract. This is necessary to avoid
a hard fork of the blockchain and ensure the availability of the function
across the network.

If it is decided that a published function should be a part of the Clarity
language, it can then be re-implemented as a native function in Rust and
included in a future release of Clarity. Nodes running this upgraded VM
would instead use this new native implementation of the function when they
encounter Clarity code that references it via `contract-call?`.

The new native function is likely faster and more efficient than the
prior Clarity implementation, so a new cost-assessment function may need
to be chosen for its evaluation. Until a new cost-assessment function is
agreed upon, the cost of the Clarity implementation will continue to be used.

### Voting on the Cost of Clarity Functions

New and more accurate cost-assessment functions can be agreed upon as
follows:

1. A user formulates a cost-assessment function and publishes it in a
Clarity contract as a `define-read-only` function.
2. The user proposes the cost-assessment function by calling the
`submit-proposal` function in the **Clarity Cost Voting Contract**.
3. Voting on the proposed function ensues via the voting functions in
the **Clarity Cost Voting Contract**, and the function is either
selected as a replacement for the existing cost-assessment function,
or ignored.

#### Publishing a Cost-Assessment Function

Cost-assessment functions to be included in proposals can be published
in Clarity contracts. They must be written precisely as follows:

1. The function must be `read-only`.
2. The function must return a tuple with the keys `runtime`, `write_length`,
`write_count`, `read_count`, and `read_length` (the execution cost measurement
[categories](#measurements-for-execution-cost)).
3. The values of the returned tuple must be Clarity expressions representing
the asymptotic cost functions. These expressions must be limited to **arithmetic operations**.
4. Variables used in these expressions must be listed as arguments to the Clarity
function.
5. Constant factors can be set directly in the code.

For example, suppose we have a function that implements a sorting algorithm:

```lisp
(define-public (quick-sort (input (list 1024 int))) ... )
```

The cost-assessment function should have _one_ argument, corresponding to the size
of the `input` field, e.g.

```lisp
(define-read-only (quick-sort-cost (n uint))
  {
    runtime: (* n (log n)),
    write_length: 0,
    write_count: 0,
    read_count: 0,
    read_length: 0,
  })
```

Here's another example where the cost function contains constant factors:

```lisp
(define-read-only (quick-sort-cost (n uint))
   {
     runtime: (+ 30 (* 2 n (log n))),
     write_length: 0,
     write_count: 0,
     read_count: 0,
     read_length: 0
   })
```

#### Making a Cost-Assessment Function Proposal

Stacks holders can propose cost-assessment functions by calling the
`submit-proposal` function in the **Clarity Cost Voting Contract**.

```Lisp
(define-public (submit-proposal
    (function-contract principal)
    (function-name (string-ascii 128))
    (cost-function-contract principal)
    (cost-function-name (string-ascii 128))
    ...
)
```

Description of `submit-proposal` arguments:
- `function-contract`: the principal of the contract that defines
the function for which a cost is being proposed
- `function-name`: the name of the function for which a cost is being proposed
- `cost-function-contract-principal`: the principal of the contract that defines
the cost function being proposed
- `cost-function-name`: the name of the cost-function being proposed

If submitting a proposal for a native function included in Clarity at boot,
provide the principal of the boot costs contract for the `function-contract`
argument, and the name of the corresponding cost function for the `function-name`
argument.

This function will return a response containing the proposal ID, if successful,
and an error otherwise.

Usage:
```Lisp
(contract-call?
    .cost-voting-contract
    "submit-proposal"
    .function-contract
    "function-name"
    .new-cost-function-contract
    "new-cost-function-name"
)
```

#### Viewing a Proposal

To view cost-assessment function proposals, you can use the 
`get-proposal` function in the **Clarity Cost Voting Contract**:

```Lisp
(define-read-only (get-proposal (proposal-id uint)) ... )
```

This function takes a `proposal-id` and returns a response containing the proposal
data tuple, if a proposal with the supplied ID exists, or an error code. Proposal
data tuples contain information about the state of the proposal, and take the
following form:

```Lisp
{
    cost-function-contract: principal,
    cost-function-name: (string-ascii 128),
    function-contract: principal,
    function-name: (string-ascii 128),
    expiration-block-height: uint
}
```

Usage:
```Lisp
(contract-call? .cost-voting-contract "get-proposal" 123)
```

### Voting

#### Stacks Holders

Stacks holders can vote for cost-assessment function proposals by calling the
**Clarity Cost Voting Contract's** `vote-proposal` function. The `vote-proposal`
function takes two arguments, `proposal-id` and `amount`. `proposal-id` is the ID
of the proposal being voted for. `amount` is the amount of STX the voter would like
to vote *with*. The amount of STX you include is the number of votes you are casting.

Calling the `vote` function authorizes the contract to transfer STX out
of the caller's address, and into the address of the contract. The equivalent
amount of `cost-vote-tokens` will be distributed to the voter, representing the
amount of STX they have staked in the voting contract.

STX staked for voting can be withdrawn from the voting contract by the voter with
the `withdraw-votes` function. If staked STX are withdrawn prior to confirmation,
they will not be counted as votes.

Upon withdrawal, the voter permits the contract to reclaim allocated `CFV` tokens,
and will receive the equivalent amount of their staked STX tokens.

**Voting example**
```Lisp
(contract-call? .cost-voting-contract "vote-proposal" 123 10000)
```

The `vote-proposal` function will return a successful response if the STX were staked
for voting, or an error if the staking failed.

**Withdrawal example**
```Lisp
(contract-call? .cost-voting-contract "withdraw-votes" 123 10000)
```

Like the `vote-proposal` function, the `withdraw-votes` function expects a `proposal-id` and
an `amount`, letting the voter withdraw some or all of their staked STX. This function
will return a successful response if the STX were withdrawn, and an error otherwise.

#### Miner Veto

Miners can vote *against* (veto) cost-function proposals by creating a transaction that
calls the **Clarity Cost Voting Contract's** `veto` function and mining
a block that includes this transaction. The `veto` function won't count
the veto if the block wasn't mined by the node that signed that transaction.
In other words, miners must **commit** their veto with their mining power.

Usage:
```Lisp
(contract-call? .cost-voting-contract "veto" 123)
```

This function will return a successful response if the veto was counted, or
an error if the veto failed.

### Confirming the Result of a Vote

In order for a cost-function proposal to get successfully voted in, it must be
**confirmed**. Confirmation is a two step process, involving calling the `confirm-votes`
function _before_ the proposal has expired to confirm the vote threshold was met,
and calling the `confirm-miners` function _after_ to confirm that the proposal wasn't vetoed
by miners.

#### Confirm Votes

Any stacks holder can call the `confirm-votes` function in the **Clarity
Cost Voting Contract** to attempt confirmation. `confirm-votes` will return a
success response and become **vote confirmed** if the following criteria are met.

1. The proposal must receive votes representing 20% of the liquid supply of STX.
This is calculated like such:
   
```lisp
(>= (/ (* votes u100) stx-liquid-supply) u20)
```

2. The proposal must not be expired, meaning its `expiration-height` must
not have been reached.
   
Usage:
```Lisp
(contract-call? .cost-voting-contract "confirm-votes" 123)
```

#### Confirm Miners

Like `confirm-votes`, any stacks holder can call the `confirm-miners` function.
`confirm-miners` will return a success response and the proposal will become
**miner confirmed** if the following criteria are met:

1. The number of vetos is less than 500.
2. There have been less than 10 proposals already confirmed in the current block.
3. The proposal has expired.

Usage:
```Lisp
(contract-call? .cost-voting-contract "confirm-miners" 123)
```

# Related Work

This section will be expanded upon after this SIP is ratified.

# Backwards Compatibility

All Stacks accounts from Stacks 1.0 will be imported into Stacks 2.0 when it
launches.  The state of the Stacks 1.0 chain will be snapshotted at Bitcoin
block 665750.

# Activation

At least 20 miners must register a name in the `.miner` namespace in Stacks 1.0.
Once the 20th miner has registered, the state of Stacks 1.0 will be snapshotted.
300 Bitcoin blocks later (Bitcoin block 666050), the Stacks 2.0 blockchain will launch.  Stacks 2.0
implements this SIP.

# Reference Implementations

Implemented in Rust.  See https://github.com/blockstack/stacks-blockchain.

