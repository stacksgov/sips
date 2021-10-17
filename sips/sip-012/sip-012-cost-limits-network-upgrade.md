# Preamble

SIP Number: 012

Title: Burn Height Selection for a Network Upgrade to Introduce New Cost-Limits

Authors:
* 0xAsteria <asteria@syvita.org>
* Aaron Blankstein <aaron@hiro.so>
* Diwaker Gupta <diwaker@hiro.so>
* Hank Stoever <hank@oby.io>
* Jason Lau <jason@okcoin.com>
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
transactions with contract-calls frequently exceed these limits, which
negatively affects transaction throughput. This SIP proposes an update to these
cost-limits via a network upgrade and further, that the network upgrade be
executed at a block height chosen by an off-chain process described in this SIP.


# License and Copyright

This SIP is made available under the terms of the Creative Commons CC0 1.0
Universal license, available at
https://creativecommons.org/publicdomain/zero/1.0/ This SIP’s copyright is held
by the Stacks Open Internet Foundation.


# Introduction

The current Clarity cost limits were set very conservatively in Stacks 2.0.
Since the mainnet launch on 2021-01-14, traffic on the network has grown
steadily. And in recent months we have seen network congestion adversely
impacting user experience on multiple occassions: valid transactions are not
getting processed because they exceed one or more of the block limits, and are
therefore not included by miners.

Here are some relevant results from a [recent
analysis](https://github.com/blockstack/stacks-blockchain/discussions/2883) of
block data:

* Average number of "events" per block: 34.9. This is lower than the demands of
  many workloads and also lower than the theoretical maximum one would expect.
* Of all transactions that exceed some cost dimension (see SIP-006 for a
  description of all cost dimensions), ~80% exceed the `runtime` limit and ~18%
  exceed the `read_count` limits.

In the last few months, the
[clarity-benchmarking](https://github.com/blockstack/clarity-benchmarking)
project has done rigorous benchmarking on contemporary hardware to come up with
more accurate cost-limits, with a focus on the `runtime` limits. The updated
cost-limits are described in detail in [this forum
post](https://forum.stacks.org/t/more-accurate-cost-functions-for-clarity-native-functions/12386).

In theory, most of these cost-limits can be changed without necessitating a
hard-fork or network-upgrade -- the exact procedure is described in
[SIP-006](https://github.com/stacksgov/sips/blob/main/sips/sip-006/sip-006-runtime-cost-assessment.md#cost-upgrades).
We evaluated the feasibility of this approach and concluded that the current
implementation of the mechanism is badly designed, in that it does not allow
network participants to _quickly_ adapt the system based on availability of
benchmarking data and faster implementations.

Further, there are some performance improvements that _can not_ be incorporated
using Clarity cost upgrades and necessitate a network-uprade. Specifically:

* [The MARF could be 2x faster with minimal
  effort](https://github.com/blockstack/stacks-blockchain/issues/2869), but we
  can't capitalize on it right now because the cost functions for many
  I/O-related Clarity functions only tabulate a single MARF read or MARF write
  (so we can't use cost-voting to increase the number of MARF I/O operations per
  block; we must change the block limit).
* Many smart contracts declare lists of data in their data space with large
  maximum lengths, but in practice don't usually make use of that space. This is
  a problem because the Clarity VM still bills storage reads for lists by their
  maximum length, instead of their actual length. There's no way to correct this
  except via a network upgrade.

We believe that there is broad community support for changing Clarity
cost-limits, the question is exactly how and when they go into effect. A
previous proposal suggested using a voting contract to determine the block
height at which a network-upgrade, described in detail in [this Github
discussion](https://github.com/blockstack/stacks-blockchain/discussions/2845).
Unfortunately, this path would take at least 4 months in the best-case scenario
(factoring in time to test and deploy the voting contract, time to execute the
vote, time for a miner veto window and time to clear the votes).

This SIP posits that the ongoing network congestion warrants a more expedient
route to change the cost-limits, one that does not rely on an on-chain voting
contract.

Equally of note, we consider this SIP as a method of last resort and
that considering the circumstances an exception is justified. All future network
upgrades should use the voting contract (if appropriate); all hard-forks must
follow the processes described in SIP-000 and SIP-011.


# Specification

## Proposal

In the text below, "Stacks 2.05" refers to the proposed network-upgrade for
cost-limits.

The SIP authors will propose a Bitcoin block number at which the new cost-limits
take effect. The block number should be at least two calendar weeks from when
this SIP transitions into “Accepted” state, so as to provide sufficient time for
node operators to upgrade. Tentatively this block number would be chosen to fall
on November 29th or November 30th, 2021.

Miners, developers, Stackers and community members can demonstrate their support
(or lack thereof) for this network upgrade by sending Bitcoin transactions:

* There will be two Bitcoin addresses whose UTXOs will be used to tally the
  vote: a "yes" address, and a "no" address. [TODO: add details on the specific
  addresses]. To vote, you would send a small amount of BTC to either one of
  these addresses.
* The transaction's scriptSig must be signed by either the Stacker's PoX reward
  address's public key(s), or the public key(s) of their Stacks address (the
  option is provided here because not all Stackers have access to their PoX
  addresses). In either case, the vote commits the Stacker's
  most-recently-locked STX to "yes" or "no" if the Stacker had some STX locked
  in the past two reward cycles at the time of the vote.

Nodes that run Stacks 2.05 must put `0x05` in the memo field. Block-commit
transactions that do not have `0x05` will be considered invalid. The purpose of
this change is to ensure that in the unlikely event some miners didn't know
about this SIP, they will quickly find out because their blocks will never be
confirmed.

The SIP will be considered Recommended if the vote to activate Stacks 2.05
passes. This requires:

* 2/3 of all votes passed are "yes", weighted by the STX they represent
* At least 60 million STX are represented by the "yes" votes. This is 2x the
  largest Stacker right now.

The rationale for this voting procedure is that it simultaneously gives the
community a way to veto the SIP while also accommodating a low-ish turnout. The
problem with any blockchain-based voting systems in the past is that unless
there's a financial incentive to vote (e.g. mining, staking), turnout is low. By
introducing a distinct "no" choice and giving it 2x the power of a "yes" vote,
this protocol ensures that if there are real problems discovered with this SIP
that would warrant a "no" response, it will take far less effort to stop its
ratification than to advance it.

In terms of how these cost-limits would actually be applied, this SIP proposes
the following:

* Add new functionality to Stacks blockchain that uses the current cost-limits
  by default and uses new cost-limits if the burn block height exceeds a
  configurable parameter (could be a compile time configuration to avoid runtime
  issues)
* Once a Bitcoin block number has been determined, ship a new Stacks blockchain
  release at least one week before to give miners and node operators time to
  upgrade before the upgrade block height is reached


### Default Cost Functions

Based on results from the
[clarity-benchmarking](https://github.com/blockstack/clarity-benchmarking)
project, we propose new default cost functions. The new costs are supplied in
the form of a new Clarity smart contract in [Appendix A](#appendix-a).

### Block Limit Changes

In addition to the runtime cost changes, we propose increasing the block limits
for MARF reads and writes. Based on the expected performance improvements in the
implementation of the MARF (see [issue
#2869](https://github.com/blockstack/stacks-blockchain/issues/2869)) we propose
doubling the current limits on blocks:

```rust
pub const BLOCK_LIMIT_MAINNET: ExecutionCost = ExecutionCost {
    write_length: 15_000_000, // roughly 15 mb
    write_count: 15_500,
    read_length: 100_000_000,
    read_count: 15_500,
    runtime: 5_000_000_000,
};
```

### Changes to Static vs. Dynamic Tabulation of Costs

The cost assessment in Clarity for most data-handling functions (e.g.,
`map-get?`) use the static cost of the fetch rather than the dynamic cost. For
more information, see [issue
#2864](https://github.com/blockstack/stacks-blockchain/issues/2864) in the
`stacks-blockchain` repository.

There were two motivating reasons for doing this:

* It makes static analysis of costs easier, because the cost assessed at runtime
  would always use the declared size of the map entry.
* It allows the cost to be assessed before running the operation.

However, it's pretty easy to argue that these reasons aren't all that essential.
For (1), static analysis is always going to overestimate anyways, so why not
allow the real cost to match the actual runtime overhead more closely. For (2),
allowing a single "speculative" evaluation before aborting a block due to cost
overflow is not particularly burdensome to the network: the maximum size of an
overread is a single Clarity value, 2MB.

The benefit of using dynamic costs, however, could be great. Many contracts use
patterns where potentially long lists are stored in data maps, but in practice
the stored lists are relatively short.

Because of this, we propose to use a dynamic cost for these assessments.

# Activation

The SIP will be considered Active once:

* A new release of Stacks blockchain (available at
  https://github.com/blockstack/stacks-blockchain/releases) contains the updated
  cost-limits and a mechanism to use the new cost-limits beyond a pre-determined
  Bitcoin block height
* The SIP has garnered sufficient support as described earlier. Voting by
  sending Bitcoin transactions can begin once the SIP text is updated with the
  "yes" / "no" addresses. Voting concludes one week prior to the Stacks 2.05
  activation block.

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
