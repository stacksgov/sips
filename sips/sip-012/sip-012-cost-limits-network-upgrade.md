# Preamble

SIP Number: 012

Title: Burn Height Selection for a Network Upgrade to Introduce New Cost-Limits

Authors:
* Asteria <asteria@syvita.org>
* Aaron Blankstein <aaron@hiro.so>
* Diwaker Gupta <diwaker@hiro.so>
* Hank Stoever <hank@stackerlabs.co>
* Jason Lau <jason@okcoin.com>
* Jude Nelson <jude@stacks.org>
* Ludovic Galabru <ludo@hiro.so>
* Trevor Owens <trevor@stacks.ac>
* Xan Ditkoff <xan@daemontechnologies.co>

Consideration: Governance, Technical

Type: Consensus

Status: Draft

Created: 2021-10-08

License: BSD 2-Clause

Sign-off:

Discussions-To: https://github.com/stacksgov/sips

# Abstract

The current Clarity cost limits were set very conservatively in Stacks 2.0:
blocks with contract-calls frequently meet one or more of these limits, which
negatively affects transaction throughput. This SIP proposes an update to these
cost-limits via a network upgrade and further, that the network upgrade be
executed at a block height chosen by an off-chain process described in this SIP.

# License and Copyright

This SIP is made available under the terms of the Creative Commons CC0 1.0
Universal license, available at
https://creativecommons.org/publicdomain/zero/1.0/ This SIP's copyright is held
by the Stacks Open Internet Foundation.

# Introduction

The current Clarity cost limits were set very conservatively in Stacks 2.0.
Since the mainnet launch on 2021-01-14, traffic on the network has grown
steadily.  In recent months, we have seen network congestion adversely
impacting the user experience: valid transactions are not
getting mined in a timely manner because there is far more demand for block compute
capacity than supply.  For example, in Stacks blocks from height 27,672 through 28,573, 675
blocks' highest-filled compute dimension was their `runtime` dimension, but 319
blocks' highest-filled compute dimension was their `read_count` dimension ([full
report](./SIP-012-001.ods)).  In another study of 455 Stacks blocks between height
30,904 and 33,002, just over 14% of them exceeded the `read_count` dimension
and just over 85% exceeded the `runtime` dimension ([full report](https://github.com/blockstack/stacks-blockchain/discussions/2883)).

While there will likely always be more demand than supply for block compute
capacity, the current supply is artifically limited in three principal ways:

* At the time of the launch, the MARF index (see SIP-004) was implemented in
  such a way that a block could only execute 7,500 MARF index reads and writes
while being processed by a non-mining node on consumer hardware in a reasonable
amount of time.  This number was arrived at by measuring how many MARF reads and writes
could be completed on a consumer laptop in 10 seconds in 2019.  But because the block limit is a
consensus-critical constant that all Stacks nodes must agree on, increasing the
number of MARF reads and writes per block can only be done via a breaking
change.  This means that any improvements to the MARF's performance that could
permit significant increase in the number of operations per block can only
be capitalized upon via a breaking change.

* An emerging Clarity contract design pattern is to store data maps and data
  variables comprised of lists with a large maximum length.  The reason
for this, we suspect, is because it permits storing a lot of MARF-indexed data with
few MARF reads and writes.  However, the Clarity VM assesses list storage based
on its _maximum_ length, not the length of the data stored.  Assessing storage
based on the length of the data would allow contracts to make better use of the
`read_length` and `write_length` compute resources (which have been hit in
practice), but this would require a breaking change.

* Most of the cost functions in SIP-006 have constants that are far too
  conservative in practice.  The numbers used when mainnet launched were chosen
to minimize the risk of a network-wide denial-of-service arising from producing
blocks that would take an inordinate amount of time to validate; they were not
chosen through a rigorous benchmarking process.  In the months since then,
we have developed a more rigorous 
[benchmark suite](https://github.com/blockstack/clarity-benchmarking)
for the Clarity VM implementation, and have arrived at more accurate runtime
constants for the cost functions that permit suitable block validation times on contemporary
hardware.  The new limits, listed in [Appendix A](#appendix-a), 
would vastly increase the number of Clarity functions that can be
executed per block.  But in order to capitalize on this new data, STX token holders would
need to execute the SIP-006 cost voting protocol to activate new cost functions.

This SIP proposes a **breaking change** that would address these first two
limitations.  It would increase the block runtime `read_count` and `write_count`
limits by a factor of 2, in order to allow the network to capitalize on a [recent MARF performance
improvement](https://github.com/blockstack/stacks-blockchain/issues/2869).  It
would also change storage cost assessment for list data to consider the length
of the value being stored, instead of its maximum length.  In addition, this 
would bypass the voting protocol in SIP-006 to set 
[new proposed runtime cost functions parameters](https://forum.stacks.org/t/more-accurate-cost-functions-for-clarity-native-functions/12386)
via a voting protocol described in this SIP.

## A Note on Bypassing SIP-006

This SIP explicitly bypasses the voting procedure in SIP-006 by means of a separate
voting procedure described below.  However, this SIP does not supersede SIP-006,
nor does it set a precedent for this particular voting procedure's general
applicability to making collective decisions in the SIP process.  The voting
procedure in this SIP is specific to this SIP, and is only meant to activate the
changes described in this SIP.

The reason for this accommodation is that the SIP-006 voting procedure may be
too costly to use in practice, since STX holders must forego Stacking to use it.
A future SIP may study this problem further, and propose a new voting procedure 
for runtime costs in recognition of this.  However, that is not the subject of
this SIP.

We are aware of one other proposal
(distinct from the procedure described in SIP-006) suggested
using a voting contract to determine the block height at which a
network-upgrade, described in detail in [this Github
discussion](https://github.com/blockstack/stacks-blockchain/discussions/2845).
However, at the time of this writing, this proposal is not yet ready for review in the SIP process.

# Specification

## Activation Protocol

In the text below, "Stacks 2.05" refers to the proposed network-upgrade for
cost-limits.

Due to the far-reaching effects a breaking change will have on the Stacks
ecosystem, this SIP can only be activated through a collective decision-making
process.  There are three major steps to this activation procedure:

   1.  The SIP authors will propose a Bitcoin block number at which the new cost-limits
   take effect. The block number should be at least two calendar weeks from when
   this SIP transitions into _Recommended_ status, so as to provide sufficient time for
   node operators to upgrade. Tentatively this block number would be chosen to fall
   on November 29th or November 30th, 2021.  In this document, this is the
**activation block**.

   2.  In the two whole reward cycles prior to the activation block, users who
       have Stacked STX will have the opportunity to cast a vote to activate
this SIP.  The cut-off for voting will be a _separate_ Bitcoin block whose
expected arrival time is one calendar week prior to the activation block.  This
document refers to this block as the **vote deadline block.**

   3.  If the activation voting threshold is met as of the vote deadline block,
then the Stacks Foundation will cut a relase of the Stacks blockchain
reference implementation with this
SIP's changes applied and set to take effect once the activation block passes.
If on the other hand there is insufficient support for this SIP by the vote
deadline block, then no action will be taken and this SIP will not activate.

To activate this SIP, users who have Stacked STX in either of the last two whole
reward cycles prior to the vote deadline block height will have the opportunity to
vote with their STX by sending a minimial amount of BTC to one of two addresses.
There will be two Bitcoin addresses whose UTXOs will be used to tally the
vote: a "yes" address, and a "no" address.

* The "yes" address will be a p2pkh Bitcoin address whose inner Hash160 is
  `00000000000000000000000000000000000000ee`.  On mainnet, this is address
`111111111111111111112czxoHN`.

* The "no" address will be a separate p2pkh Bitcoin address whose inner Hash160
  is `00000000000000000000000000000000000000ff`.  On mainnet, this is address
`111111111111111111112kmzDG2`.

Note that these are similar addresses to the PoX burn address, but they all
differ from one another in their checksums.

Vote tallying is performed by examining how many STX the sender has recently
Stacked.  The Bitcoin transaction identifies the amount of STX in the `.pox`
smart contract's data space.  So, by examining the UTXOs for these two Bitcoin
addresses, anyone with a full copy of the Stacks chain state as of the voting
deadline will be able to calculate how many recently-Stacked STX have signaled
"yes" or "no" support for this SIP.

To match the Bitcoin transaction to the Stacker's state in the `.pox` contract,
the `scriptSig` of the first transaction input must be signed by either the user's PoX reward
address's public key(s), or the public key(s) of the Stacks address that Stacked
the tokens (the option is provided here because not all Stackers have access to their PoX
addresses). In either case, the vote commits the Stacker's
most-recently-locked STX to "yes" or "no" if the Stacker had some STX locked
in the past two reward cycles as of the vote deadline block.

### Activation Criteria 

The SIP will be considered _Ratified_ if the vote to activate Stacks 2.05
passes. This requires:

* 2/3 of all votes passed are "yes", weighted by the STX they represent, at a
  Bitcoin block height at or before the vote deadline block.

* At least 60 million STX are represented by the "yes" votes. This is 2x the
  largest Stacker at the time of this writing.

### Rationale 

The rationale for this voting procedure is that it simultaneously gives the
community a way to veto the SIP while also accommodating low turnout. The
problem with blockchain-based voting systems in the past is that unless
there is a financial incentive to vote (e.g. mining, staking), turnout is low.
For example, the Ethereum carbon vote [1] to disable the DAO smart contract had only
5.5% turnout [2].  As another example, BitShares' [3] highest-voted delegate in its
delegated proof-of-stake consensus algorithm only received 18% of the vote [4].

This SIP's activation procedure takes the position that non-voters are passive
system participants and do not care about the outcome of this SIP -- they will
be happy either way.  But, this SIP also acknowledges that of the voters that
_do_ care about the vote outcome, those who vote "no" are financially
disincentivized to do so, because it would render the Stacks blockchain in a
worse-off state.  Therefore, this SIP requires a supermajority of "yes" votes to
activate, since a strong minority of "no" votes would be a strong signal that
something is seriously wrong with this SIP (despite its apparent benefits).

## Changes to Mining

Nodes that run Stacks 2.05 must put `0x05` in the memo field. Block-commit
transactions that do not have `0x05` will be considered invalid. The purpose of
this change is to ensure that in the unlikely event some miners didn't know
about this SIP, they will quickly find out because their blocks will never be
confirmed or recognized by other users and exchanges that have upgraded.

## Changes to Runtime Costs

This SIP proposes two breaking changes to runtime costs, as well as a new set of
default cost functions (bypassing SIP-006's voting procedure).

### Block Limit

This SIP proposes increasing the block limits
for MARF reads and writes.  This is a breaking change.

Based on the expected performance improvements in the
implementation of the MARF (see [issue #2869](https://github.com/blockstack/stacks-blockchain/issues/2869)) 
this SIP proposes doubling the current limits on blocks:

```rust
pub const BLOCK_LIMIT_MAINNET: ExecutionCost = ExecutionCost {
    write_length: 15_000_000, // roughly 15 mb
    write_count: 15_000,
    read_length: 100_000_000,
    read_count: 15_000,
    runtime: 5_000_000_000,
};
```

### Changes to Static vs. Dynamic Tabulation of Costs

The cost assessment in Clarity for most data-handling functions (e.g.,
`map-get?`) use the static cost of the fetch rather than the dynamic cost. 
This is a breaking change.  For more information, see [issue #2864](https://github.com/blockstack/stacks-blockchain/issues/2864) in the
`stacks-blockchain` repository.

There are two motivating reasons for doing this:

* It makes static analysis of costs easier, because the cost assessed at runtime
  would always use the declared size of the map entry.
* It allows the cost to be assessed before running the operation.

However, these reasons have not been shown to be practical in production.
For (1), static analysis is always going to overestimate anyways, so system
throughput would improve by using the actual runtime overhead instead of the
maximum runtime overhead when assessing storage costs.  For (2),
allowing a single "speculative" evaluation before aborting a block due to cost
overflow is not particularly burdensome to the network: the maximum size of an
overread is a single Clarity value, which takes only 2MB.

The benefit of using dynamic costs, however, could be significant. Many contracts use
patterns where potentially long lists are stored in data maps, but in practice
the stored lists are relatively short.

Because of this, this SIP proposes using a dynamic cost for these assessments.
Specifically, it proposes changes to the inputs of the following
functions' cost functions:

* `var-get`
* `var-set`
* `map-get?`
* `map-set`
* `map-insert`
* `map-delete`
* `concat`

#### `(var-get var-name) -> value`

The `x` input to the `var-get` cost function should be the length in
bytes of the consensus serialization (see [SIP-005](https://github.com/stacksgov/sips/blob/main/sips/sip-005/sip-005-blocks-and-transactions.md#clarity-value-representation)
for details on this format) of the returned `value`.

#### `(var-set var-name value)`

The `x` input to the `var-get` cost function should be the length in
bytes of the consensus serialization (see [SIP-005](https://github.com/stacksgov/sips/blob/main/sips/sip-005/sip-005-blocks-and-transactions.md#clarity-value-representation)
for details on this format) of the newly stored `value`.

The memory usage of this function should be this same value. The
memory usage of `var-set` remains in effect until the end of the
transaction (data operations remain in memory during the whole
transaction to enable rollbacks and post-conditions).

#### `(map-get? map-name key) -> value`

The `x` input to the `map-get` cost function should be the sum of the
length in bytes of the consensus serialization of the supplied `key`
and the returned `value`.

#### `(map-set map-name key value)`

The `x` input to the `map-set` cost function should be the sum of the
length in bytes of the consensus serialization of the supplied `key` and
`value` arguments.

The memory usage of this function should be this same value. The
memory usage of `map-set` remains in effect until the end of the
transaction (data operations remain in memory during the whole
transaction to enable rollbacks and post-conditions).

#### `(map-insert map-name key value)`

If the insert is successful, the `x` input to the `map-insert` cost
function should be the sum of the length in bytes of the consensus
serialization of the supplied `key` and `value` arguments.

If the insert is unsuccessful, the `x` input to the `map-insert` cost
function should be the length in bytes of the consensus serialization
of just the supplied `key` argument.

The memory usage of this function should be this same `x` value. The
memory usage of `map-insert` remains in effect until the end of the
transaction (data operations remain in memory during the whole
transaction to enable rollbacks and post-conditions).

#### `(map-delete map-name key)`

The `x` input to the `map-delete` cost function should be the length
in bytes of the consensus serialization of the supplied `key`
argument plus the length in bytes of the consensus serialization of
a `none` Clarity value.

The memory usage of this function should be this same `x` value. The
memory usage of `map-delete` remains in effect until the end of the
transaction (data operations remain in memory during the whole
transaction to enable rollbacks and post-conditions).

#### `(concat list-a list-b)`

The `x` input to the `concat` cost function should be the length of
`list-a` plus the length of `list-b`.

### New Default Cost Functions

Based on results from the
[clarity-benchmarking](https://github.com/blockstack/clarity-benchmarking)
project, this SIP proposes new default cost functions. The new costs are supplied in
the form of a new Clarity smart contract in [Appendix A](#appendix-a).

This could have been carried out through a SIP-006 cost voting procedure, but
due to the opportunity costs incurred by STX holders foregoing PoX rewards to
carry this vote out, this SIP instead proposes bypassing the SIP-006 voting
procedure in this one instance and instead using this SIP's activation procedure
to install these new functions.

# Activation

The SIP will be considered Ratified once all of the following are true:

* A vote deadline block height and activation block height are chosen and added
  to this SIP's text.  This is a pre-condition for advancing this SIP to
_Recommended_ status.

* This SIP is advanced to Activation-in-Progress by the respective consideration
  advisory boards.

* The SIP has garnered sufficient support by the vote deadline block height. Voting by
  sending Bitcoin transactions can begin once the SIP text is updated with the
  "yes" / "no" addresses. Voting concludes one week prior to the Stacks 2.05
  activation block.

* A new release of Stacks blockchain (available at
  https://github.com/blockstack/stacks-blockchain/releases) contains the updated
  cost-limits and a mechanism to use the new cost-limits beyond the activation
block height listed in this SIP.  This release is announced by the Stacks
Foundation.

* The activation block height passes on the Bitcoin chain.

# References

[1] http://v1.carbonvote.com/

[2] https://en.wikipedia.org/wiki/Ethereum_Classic#Carbon_vote

[3] https://en.bitcoinwiki.org/wiki/BitShares

[4] https://bitcointalk.org/index.php?topic=916696.330;imode

# Appendices

## Appendix A

The new proposed cost functions, which will be instantiated at
`SP000000000000000000002Q6VF78.costs-2.05.clar`:

```lisp
(define-read-only (cost_analysis_type_annotate (n uint))
    (runtime (linear n u3 u12)))

(define-read-only (cost_analysis_type_lookup (n uint))
    (runtime (linear n u1 u5)))

(define-read-only (cost_analysis_visit (n uint))
    (runtime u17))

(define-read-only (cost_analysis_option_cons (n uint))
    (runtime u51))

(define-read-only (cost_analysis_option_check (n uint))
    (runtime u131))

(define-read-only (cost_analysis_bind_name (n uint))
    (runtime (linear n u14 u144)))

(define-read-only (cost_analysis_list_items_check (n uint))
    (runtime (linear n u25 u5)))

(define-read-only (cost_analysis_check_tuple_get (n uint))
    (runtime (logn n u1 u1)))

(define-read-only (cost_analysis_check_tuple_cons (n uint))
    (runtime (nlogn n u12 u64)))

(define-read-only (cost_analysis_tuple_items_check (n uint))
    (runtime (linear n u13 u50)))

(define-read-only (cost_analysis_check_let (n uint))
    (runtime (linear n u51 u87)))

(define-read-only (cost_analysis_lookup_function (n uint))
    (runtime u21))

(define-read-only (cost_analysis_lookup_function_types (n uint))
    (runtime (linear n u1 u27)))

(define-read-only (cost_analysis_lookup_variable_const (n uint))
    (runtime u15))

(define-read-only (cost_analysis_lookup_variable_depth (n uint))
    (runtime (nlogn n u1 u65)))

(define-read-only (cost_ast_parse (n uint))
    (runtime (linear n u171 u282923)))

(define-read-only (cost_ast_cycle_detection (n uint))
    (runtime (linear n u141 u26)))

(define-read-only (cost_analysis_storage (n uint))
    {
        runtime: (linear n u1 u5),
        write_length: (linear n u1 u1),
        write_count: u1,
        read_count: u1,
        read_length: u1
    })

(define-read-only (cost_analysis_use_trait_entry (n uint))
    {
        runtime: (linear n u9 u736),
        write_length: (linear n u1 u1),
        write_count: u0,
        read_count: u1,
        read_length: (linear n u1 u1)
    })


(define-read-only (cost_analysis_get_function_entry (n uint))
    {
        runtime: (linear n u82 u1345),
        write_length: u0,
        write_count: u0,
        read_count: u1,
        read_length: (linear n u1 u1)
    })

(define-read-only (cost_lookup_variable_depth (n uint))
    (runtime (linear n u2 u14)))

(define-read-only (cost_lookup_variable_size (n uint))
    (runtime (linear n u2 u1)))

(define-read-only (cost_lookup_function (n uint))
    (runtime u26))

(define-read-only (cost_bind_name (n uint))
    (runtime u273))

(define-read-only (cost_inner_type_check_cost (n uint))
    (runtime (linear n u2 u9)))

(define-read-only (cost_user_function_application (n uint))
    (runtime (linear n u26 u0)))

(define-read-only (cost_let (n uint))
    (runtime (linear n u1 u270)))

(define-read-only (cost_if (n uint))
    (runtime u191))

(define-read-only (cost_asserts (n uint))
    (runtime u151))

(define-read-only (cost_map (n uint))
    (runtime (linear n u1186 u3325)))

(define-read-only (cost_filter (n uint))
    (runtime u437))

(define-read-only (cost_len (n uint))
    (runtime u444))

(define-read-only (cost_element_at (n uint))
    (runtime u548))

(define-read-only (cost_fold (n uint))
    (runtime u489))

(define-read-only (cost_type_parse_step (n uint))
    (runtime u5))

(define-read-only (cost_tuple_get (n uint))
    (runtime (nlogn n u4 u1780)))

(define-read-only (cost_tuple_merge (n uint))
    (runtime (linear n u208 u185)))

(define-read-only (cost_tuple_cons (n uint))
    (runtime (nlogn n u11 u1481)))

(define-read-only (cost_add (n uint))
    (runtime (linear n u11 u152)))

(define-read-only (cost_sub (n uint))
    (runtime (linear n u11 u152)))

(define-read-only (cost_mul (n uint))
    (runtime (linear n u12 u151)))

(define-read-only (cost_div (n uint))
    (runtime (linear n u13 u151)))

(define-read-only (cost_geq (n uint))
    (runtime u162))

(define-read-only (cost_leq (n uint))
    (runtime u164))

(define-read-only (cost_le (n uint))
    (runtime u152))

(define-read-only (cost_ge (n uint))
    (runtime u152))

(define-read-only (cost_int_cast (n uint))
    (runtime u157))

(define-read-only (cost_mod (n uint))
    (runtime u166))

(define-read-only (cost_pow (n uint))
    (runtime u166))

(define-read-only (cost_sqrti (n uint))
    (runtime u165))

(define-read-only (cost_log2 (n uint))
    (runtime u156))

(define-read-only (cost_xor (n uint))
    (runtime u163))

(define-read-only (cost_not (n uint))
    (runtime u158))

(define-read-only (cost_eq (n uint))
    (runtime (linear n u8 u155)))

(define-read-only (cost_begin (n uint))
    (runtime u189))

(define-read-only (cost_secp256k1recover (n uint))
    (runtime u14312))

(define-read-only (cost_secp256k1verify (n uint))
    (runtime u13488))

(define-read-only (cost_some_cons (n uint))
    (runtime u217))

(define-read-only (cost_ok_cons (n uint))
    (runtime u209))

(define-read-only (cost_err_cons (n uint))
    (runtime u205))

(define-read-only (cost_default_to (n uint))
    (runtime u255))

(define-read-only (cost_unwrap_ret (n uint))
    (runtime u330))

(define-read-only (cost_unwrap_err_or_ret (n uint))
    (runtime u319))

(define-read-only (cost_is_okay (n uint))
    (runtime u275))

(define-read-only (cost_is_none (n uint))
    (runtime u229))

(define-read-only (cost_is_err (n uint))
    (runtime u268))

(define-read-only (cost_is_some (n uint))
    (runtime u217))

(define-read-only (cost_unwrap (n uint))
    (runtime u281))

(define-read-only (cost_unwrap_err (n uint))
    (runtime u273))

(define-read-only (cost_try_ret (n uint))
    (runtime u275))

(define-read-only (cost_match (n uint))
    (runtime u316))

(define-read-only (cost_or (n uint))
    (runtime (linear n u3 u147)))

(define-read-only (cost_and (n uint))
    (runtime (linear n u3 u146)))

(define-read-only (cost_append (n uint))
    (runtime (linear n u1 u1024)))

(define-read-only (cost_concat (n uint))
    (runtime (linear n u1 u1004)))

(define-read-only (cost_as_max_len (n uint))
    (runtime u482))

(define-read-only (cost_contract_call (n uint))
    (runtime u154))

(define-read-only (cost_contract_of (n uint))
    (runtime u13391))

(define-read-only (cost_principal_of (n uint))
    (runtime u15))


(define-read-only (cost_at_block (n uint))
    {
        runtime: u205,
        write_length: u0,
        write_count: u0,
        read_count: u1,
        read_length: u1
    })


(define-read-only (cost_load_contract (n uint))
    {
        runtime: (linear n u1 u10),
        write_length: u0,
        write_count: u0,
        ;; set to 3 because of the associated metadata loads
        read_count: u3,
        read_length: (linear n u1 u1)
    })


(define-read-only (cost_create_map (n uint))
    {
        runtime: (linear n u3 u1650),
        write_length: (linear n u1 u1),
        write_count: u1,
        read_count: u0,
        read_length: u0
    })


(define-read-only (cost_create_var (n uint))
    {
        runtime: (linear n u24 u2170),
        write_length: (linear n u1 u1),
        write_count: u2,
        read_count: u0,
        read_length: u0
    })


(define-read-only (cost_create_nft (n uint))
    {
        runtime: (linear n u4 u1624),
        write_length: (linear n u1 u1),
        write_count: u1,
        read_count: u0,
        read_length: u0
    })


(define-read-only (cost_create_ft (n uint))
    {
        runtime: u2025,
        write_length: u1,
        write_count: u2,
        read_count: u0,
        read_length: u0
    })


(define-read-only (cost_fetch_entry (n uint))
    {
        runtime: (linear n u1 u1466),
        write_length: u0,
        write_count: u0,
        read_count: u1,
        read_length: (linear n u1 u1)
    })


(define-read-only (cost_set_entry (n uint))
    {
        runtime: (linear n u1 u1574),
        write_length: (linear n u1 u1),
        write_count: u1,
        read_count: u1,
        read_length: u0
    })


(define-read-only (cost_fetch_var (n uint))
    {
        runtime: (linear n u1 u679),
        write_length: u0,
        write_count: u0,
        read_count: u1,
        read_length: (linear n u1 u1)
    })


(define-read-only (cost_set_var (n uint))
    {
        runtime: (linear n u1 u723),
        write_length: (linear n u1 u1),
        write_count: u1,
        read_count: u1,
        read_length: u0
    })


(define-read-only (cost_contract_storage (n uint))
    {
        runtime: (linear n u13 u8043),
        write_length: (linear n u1 u1),
        write_count: u1,
        read_count: u0,
        read_length: u0
    })


(define-read-only (cost_block_info (n uint))
    {
        runtime: u5886,
        write_length: u0,
        write_count: u0,
        read_count: u1,
        read_length: u1
    })


(define-read-only (cost_stx_balance (n uint))
    {
        runtime: u1386,
        write_length: u0,
        write_count: u0,
        read_count: u1,
        read_length: u1
    })


(define-read-only (cost_stx_transfer (n uint))
    {
        runtime: u1444,
        write_length: u1,
        write_count: u1,
        read_count: u1,
        read_length: u1
    })


(define-read-only (cost_ft_mint (n uint))
    {
        runtime: u1624,
        write_length: u1,
        write_count: u2,
        read_count: u2,
        read_length: u1
    })


(define-read-only (cost_ft_transfer (n uint))
    {
        runtime: u563,
        write_length: u1,
        write_count: u2,
        read_count: u2,
        read_length: u1
    })


(define-read-only (cost_ft_balance (n uint))
    {
        runtime: u543,
        write_length: u0,
        write_count: u0,
        read_count: u1,
        read_length: u1
    })


(define-read-only (cost_nft_mint (n uint))
    {
        runtime: (linear n u1 u724),
        write_length: u1,
        write_count: u1,
        read_count: u1,
        read_length: u1
    })


(define-read-only (cost_nft_transfer (n uint))
    {
        runtime: (linear n u1 u787),
        write_length: u1,
        write_count: u1,
        read_count: u1,
        read_length: u1
    })


(define-read-only (cost_nft_owner (n uint))
    {
        runtime: (linear n u1 u680),
        write_length: u0,
        write_count: u0,
        read_count: u1,
        read_length: u1
    })


(define-read-only (cost_ft_get_supply (n uint))
    {
        runtime: u474,
        write_length: u0,
        write_count: u0,
        read_count: u1,
        read_length: u1
    })


(define-read-only (cost_ft_burn (n uint))
    {
        runtime: u599,
        write_length: u1,
        write_count: u2,
        read_count: u2,
        read_length: u1
    })


(define-read-only (cost_nft_burn (n uint))
    {
        runtime: (linear n u1 u644),
        write_length: u1,
        write_count: u1,
        read_count: u1,
        read_length: u1
    })


(define-read-only (poison_microblock (n uint))
    {
        runtime: u29374,
        write_length: u1,
        write_count: u1,
        read_count: u1,
        read_length: u1
    })
```

### Determining runtime cost values

The goal of this proposal is to make the total real runtime of a full
block less than 30 seconds. 30 seconds is a short enough period of
time that prospective miners should be able to process a new block
before the next Bitcoin block 95% of the time (`exp( -1/20 ) ~= 95%`).

To determine a new proposed cost for a Clarity function, we executed a
set of benchmarks for each Clarity cost function in the
[clarity-benchmarking](https://github.com/blockstack/clarity-benchmarking)
Github repository. After running these benchmarks, constant factors in
the runtime functions were fitted using linear regression (given a
transform). These benchmarks produced regression fitted functions for
each Clarity cost function, for example:

```
runtime_ns(cost_secp256k1verify) = 8126809.571429
runtime_ns(cost_or) = 2064.4713444648587 * input_len + 91676.397154
```

The runtime block limit in the Stacks network is `5e9` (unitless), and
the goal of this proposal is that this should correspond to 30 seconds
or `3e10` nanoseconds. So, to convert the `runtime_ns` functions into
runtimes for the Stacks network, we have the simple conversion:

```
runtime_stacks = runtime_ns * 5e9 / 3e10ns
```

For running the benchmarks and analysis in the `clarity-benchmarking`
repository, see the [`README.md`](https://github.com/blockstack/clarity-benchmarking/blob/master/README.md)
file in that repository.
