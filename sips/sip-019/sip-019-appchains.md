# Preamble

SIP Number: TBD

Title: Application-specific Stacks Chains

Authors:
* Jude Nelson <jude@stacks.org>

Consideration: Technical

Type: Standard

Status: Draft

Created: 2022-03-27

License: BSD 2-Clause

Sign-Off:

Discussions-To: https://github.com/stacksgov/sips

# Abstract

This SIP proposes appchains as a scaling solution for the Stacks blockchain.
Instead of sharing a single blockchain, different applications can instantiate
their own Stacks network, called an _appchain_, which is mined via a smart
contract deployed on an existing Stacks network (which can be either the Stacks blockchain,
or another appchain).  Each appchain has its own native token, 
its own set of miners (who mine the appchain's token), and most importantly,
its own block capacity.  Appchain networks are organized hierarchically: the Stacks
blockchain is the root of the hierarchy, and each appchain has a distinct
"parent chain" to which its miners spend that parent chain's tokens via PoX or
PoB mining to produce appchain blocks.

Appchains enable developers to trade chain safety for chain bandwidth.  The
cost to reorganize an appchain's blocks for a given depth _D_ is only as high
as the cost to reorganize the least-resilient chain that links the appchain to
Stacks.  But, the upside is that appchains with a higher degree of separation
have less on-going demand (since they don't host as many other appchains),
and can offer users lower fees than those with a smaller degree of separation.

To navigate this trade-off, appchains let developers customize the
consensus rules in order to both tailor the chain's behavior to
their application and help keep the chain secure while fees are low. 
For example, an appchain can forbid forks past a certain depth, and can
resort to closed-membership mining when fees and PoX commits drop beneath a
given threshold.  This customization happens through a special boot code
contract in the appchain.

This SIP argues for a hierarchical arrangement of Stacks networks as a means for
scaling transaction capacity, and proposes specifications for how appchain
miners mine blocks in the parent chain and how developers script the appchain's
consensus rules.

# License and Copyright

This SIP is made available under the terms of the BSD-2-Clause license,
available at https://opensource.org/licenses/BSD-2-Clause.  This SIP's copyright
is held by the Stacks Open Internet Foundation.

# Introduction

Blockchains do not scale.  The number of transactions (amount of useful work) a
blockchain can perform per unit time is fixed independently of the amount of
computing resources available to it.  In fact, the lack of scalability is a
feature of blockchains, because it permits anyone with adequate
computing resources to maintain a full replica of the chain state.  This begets
a resilient blockchain where users do not need to trust particular entities
to learn the state of network.

However, demand for transaction-processing capacity is elastic and unbound.
As more and more people try to use a blockchain, the cost per
transaction increases due to the limited amount of work a blockchain can
perform per unit of time.  This has a detrimental effect on the user experience of
a blockchain -- namely, the user must pay a high
transaction fee, or wait for many blocks to be mined before their transaction
is applied to the chainstate.  The more demand there is, the higher the fee or the longer
the wait time will be.

A naive way to increase a blockchain's transaction-processing capacity is to
increase the limits its protocol imposes on the work performed per block.  In
the Stacks blockchain, this is achieved by increasing the block execution 
cost limits.  However, this is not a sustainable solution for growing the
overall networks' capacity.  While the demand for block capacity grows
without limits, there are inevitably real limits on how much useful work a single
blockchain node can do.  Because a blockchain node must maintain a full replica
of the chain state, the rate at which it can process transactions is bound by
the rate at which the node's hardware is able to process them.
Therefore, any strategy for increasing the total amount of
transaction-processing capacity in the Stacks blockchain must _not_
require every node to process every transaction.

This SIP proposes empowering developers to spawn application-specific
deployments of the Stacks blockchain, called **appchains**, to process
transactions for their specific applications.  A user would only run an appchain
node for appchain state that they care about.  They are not required to run
appchain nodes for applications they do not care about.

Like the Stacks blockchain, appchains are mined via PoX ([1], [2]).
Appchains are created by developers by deploying a smart contract that
adheres to a trait and data space layout described in this SIP.  Once the smart contract is
deployed, its appchain is instantiated and maintained by appchain miners, who
write VRF public keys and block-commit metadata to the contract's data
space (much like how they store it in Bitcoin `OP_RETURN` outputs in Stacks
[3]).  Appchain nodes process these records from the smart contract in order to
reconstruct the appchain fork history and block hashes, which they use to fetch
blocks and microblocks from appchain peers.

Appchain networks are organized hierarchically.  Each appchain has a parent chain, which
is either the Stacks blockchain or another appchain.  Each parent chain is
oblivious to the state of its appchains -- it only processes the VRF
key-registration and block-commit records from their miners.  In doing so,
parent chains do not need to maintain appchain state, and new appchains can be
spawned permissionlessly by deploying additional appchain mining smart
contracts.

This hierarchical arrangement yields a viable scaling strategy, since 
it is now the case that not every node must process every transaction.  But despite
this, it is still possible to achieve useful safety and liveness properties
in appchains.  Namely, because appchains are mined by a dedicated set of mining
nodes, they will have their own quantifiable security budgets.  Also,
because appchain state is not processed by the parent chain, appchain failures
are isolated from the rest of the system.  An appchain liveness or safety failure
(i.e. a crash; a reorg) does not cascade to the parent chain; it only cascades to 
its children appchains.

This hierarchical arrangement of PoX-mineable chains enables developers to trade security
budgets for additional transaction-processing capacity.  Each appchain has its
own native token, which is used to incentivize its miners to produce blocks.
The value of this token relative to the parent chain's token informs the
appchain security budget: producing a malicious fork is as expensive as the act of mining a longer
fork.  But as with the Stacks chain on Bitcoin, each parent chain maintains the
full fork history for their appchains, so any malicious reorgs will be public
knowledge well before they have a chance of succeeding.  Moreover, the
hierarchical arrangement places the Stacks blockchain at the root, meaning that
the Bitcoin blockchain commits to the fork histories of all appchains.

# Specification

The overriding design goal for appchains is to empower users to run blockchain
nodes for only the chain state they care about.  A user should be able to run
an appchain node without running other appchain nodes besides its immediate 
ancestors, and still receive reasonable, quantifiable liveness and
safety guarantees. This design goal informs all of the subsequent decisions in this SIP -- in
particular, it _necessitates_ realizing appchains as mineable blockchain
networks with their own native tokens, and it _precludes_ an implementation that
relies on the availability of local node services (such as the parent chain 
event stream, or the parent chain state databases).

For the purposes of this SIP, an appchain is an instance of the Stacks blockchain.
Unless noted otherwise, it uses the same Clarity VM [4], the same peer network [5], the same data
structures [6] [7], and the same runtime cost analysis and assessment [8] [9], and the same mining
process [1] [2].  The key differences between an appchain and the Stacks
blockchain are:

* The appchain does not anchor its blocks to Bitcoin, but instead to a smart
  contract running on either the Stacks blockchain or another existing
appchain.  This is achieved through a "mining contract" described in this
section.

* The appchain has its own native token, and has a separate name for the Clarity
  functions for manipulating it.  For example, if the token's name is `foo`,
then instead of `stx-transfer?`, the appchain's Clarity VM has an equivalent
`foo-transfer?` function with the same return values and runtime cost.  The only
difference is the function name, which reflects the name of the token.  This
means that smart contracts are easily portable between appchains,
but not automatically so (which precludes smart contract transaction
replays between chains).

* The appchain does not support the equivalent `PreStxOp`, `StackStxOp`, and
  `TransferStxOp` burnchain operations that the Stacks blockchain has.  This is
because these operations are primarily used in Stacks to support users who hold
STX on legacy Bitcoin wallets from before the Stacks 2.0 release.  This
constraint does not apply to appchains.  A future SIP may be written to add
these operations to appchains if there is sufficient desire.

* The appchain's peer network and transaction format use a different, globally-unique network
  identifier from the Stacks chain.

* The appchain does not index the Bitcoin blockchain.  Instead, it indexes a
  specially-formed smart contract in either the Stacks blockchain or another
appchain (its "parent chain").  This section describes the interface and
requisite data space types for a smart contract instance.

* The appchain may have additional boot code beyond what the Stacks chain has
  (i.e. smart contracts instantiated in the genesis block), and may have
completely different initial balances in its genesis block.

* The appchain may have a different block limit than the Stacks chain.

* Certain aspects of the appchain's block-processing logic can be optionally
  scripted in Clarity, via a specially-named boot code contract.  Its interface
is described in this SIP.  This contract determines the following _additional_
consensus rules for appchains:

   * The appchain's token issuance schedule.

   * Additional rules for what constitutes a valid transaction.

   * Additional rules for what constitutes a valid block or microblock.

   * Additional rules for what constitutes a valid sortition.

This section describes these key differences in detail.

## Mining Contract

Appchain networks treat their parent chains the way that Stacks treats Bitcoin.
The parent chain is not aware of the appchain; it is instead only aware of a
smart contract that stores the same data that Stacks miners embed in Bitcoin
transactions.  The smart contract has three responsibilities:

* **Provide a standard interface for appchain nodes to mine appchain blocks**.
  Appchain miners send contract-call transactions to the parent chain to
register their VRF proving keys and block-commit transactions, and appchain
users have the option to send a contract-call transaction to the parent chain
to transfer and stack their appchain tokens without having to worry about the
appchain miners interfering with it.  That is, a correct appchain mining
contract implements the same on-Bitcoin operations supported by Stacks,
but within a Clarity contract.

* **Provide an efficient representation of each miners' transactions**.  The
representation enables an appchain node to (1) fetch all of an appchain miners'
transactions from the parent chain given the parent chain block identifier, and
(2) use a MARF merkle proof [10] to verify that the transaction data are
consistent with the parent chain headers.

* **Host enough information to enable an appchain node to boot up.**  In
  addition to hosting mining transaction state, the appchain mining contract
stores a plethora of appchain network configuration data that is meant to
facilitate booting up appchain nodes.  The contract interface and data space are
designed to minimize the amount of information an appchain node must learn
out-of-band in order to boot up.  With this contract specification, an appchain
node only needs to know of a parent chain node, and the mining contract address.

With this contract, each appchain node can synchronize with the appchain network
by deducing the entire appchain state
structure, in much the same way as Stacks learns the Stacks chain state structure
from Bitcoin.  The appchain would use this contract and a parent chain's RPC API
to do the following:

1. Download and validate the parent chain's canonical fork's block headers,
   including determining how much economic activity they represent in order to
determine how trustworthy they are.

2. For each parent chain block, fetch the appchain transactions' data (i.e.
   stored within this contract) and a MARF merkle proof linking the data to that
block's header.

3. Use each group of appchain transaction data to calculate a cryptographic
   sortition (per SIP-001 and SIP-007) to determine the winning appchain block
for each parent block.

4. Fetch the winning block and microblock stream from other appchain peers.

To faciliate this boot-up process, this SIP requires that the mining contract
not only confirm to the following trait, but also the following data space.

### Mining Trait 

The trait for this contract is specified below:

```
(define-trait sip-019-appchain-trait
   (
      ;; Register a VRF public key for a miner
      ;; argument 1: the SIP-001-serialized VRF key registration payload
      (register-vrf-key ((buff 80)) (response bool uint))

      ;; Mine an appchain block
      ;; argument 1: the SIP-001-serialized block-commit payload
      ;; argument 2: the amount of this chain's token to burn
      ;; argument 3: the list of recipients that will receive a PoX payout
      ;; argument 4: the amount of this chain's token that each recipient will receive
      (mine-block ((buff 80) uint (list 2 principal) uint) (response bool uint))
   )
)
```

This trait is designed to enable a Clarity-supporting blockchain to emulate the
Bitcoin chain.  In particular, it takes the same data payloads that would otherwise be encoded
in a Bitcoin `OP_RETURN` output as `(buff 80)` arguments.  This is proposed
for two reasons:

* It simplifies the appchain implementation by enabling it to leverage the same code
paths for parsing parent chain operations, regardless of which chain is the
parent chain (Bitcoin or otherwise).  If needed, the contract implementation may
parse these payloads according to SIP-001 and SIP-007 to extract the same data
for on-chain usage.

* It reduces the runtime cost of loading and storing these payloads by relying
  on a simple type (`(buff 80)`), instead of a more-expressive `tuple` type.
Most appchain trait implementations will need to parse these payloads, so it
does not make sense at this time to require their miners to pay for the extra
runtime costs of reasoning about their structured representations.

The methods in this trait do not need to perform any validation on their
`(buff 80)` inputs; it is sufficient to them in a specially-formed
data map for later retrieval (see below).  This is because the appchain
implementation will have enough information to validate them when it performs each
cryptographic sortition.  Therefore, there is no inherent need for the smart
contract to spend computing resources validating this data.

### Mining Data Space

In addition to confirming to this trait, the mining contract must have the
following data space variables defined with the given type signatures:

```
;; The version of this appchain data space schema (this SIP requires `u1`)
(define-data-var appchain-version uint u1)

;; The appchain-specific transaction data, grouped by parent chain block.
;; The appchain node will query this data map to learn each appchain transaction
;; for a given parent block, in order to both calculate cryptographic sortitions
;; and process parent chain-hosted user transactions.  All `(buff 80)` payloads
;; from the trait methods must end up in this data map if they are accepted.
(define-map appchain
    ;; parent chain block height
    uint
    ;; list of appchain transactions at that height
    (list 128 {
        ;; miner address
        sender: principal,
        ;; Is this operation chained to the last one?  Only applies to block-commits.
        ;; Used to indicate whether or not a block-commit is "late."
        chained?: bool,
        ;; burnchain op payload (serialized per SIP-001 and SIP-007)
        data: (buff 80),
        ;; amount of parent chain tokens destroyed by this operation
        burnt: uint,
        ;; total amount of parent chain tokens transferred by this operation
        transferred: uint,
        ;; PoX recipients on the parent chain
        recipients: (list 2 principal)
    })
)

;; This is a configuration structure for the appchain.  An appchain peer will
;; query this structure when it boots up in order to learn how it should
;; configure itself and who to fetch the appchain boot code from.
;;
;; All fields in this config should be treated as *immutable* -- there should 
;; be no way to modify this data-var in the implementation!
(define-data-var appchain-config
    {
        ;; chain ID used to identify transactions and p2p messages from this appchain
        chain-id: uint,
        ;; the height on the parent chain at which this appchain's transactions begin
        ;; (i.e. the smallest possible key for the `appchain` map).
        start-height: uint,
        ;; PoX configuration for the appchain
        pox: {
            ;; Number of parent chain blocks in an appchain reward cycle.
            ;; For Stacks, this is 2100.
            reward-cycle-length: uint,
            ;; Number of parent chain blocks in an appchain prepare phase.
            ;; For Stacks, this is 100.
            prepare-length: uint,
            ;; Number of confirmations an appchain block needs to be a PoX
            ;; anchor block (for Stacks, this is 80).
            anchor-threshold: uint,
            ;; Integer percentage of liquid appchain tokens that may vote to
            ;; disable PoX for the next reward cycle (for Stacks, this is 25).
            pox-rejection-fraction: uint,
            ;; Integer percentage of liquid appchain tokens that must be stacked
            ;; for PoX to begin (for Stacks, this is 5).
            pox-participation-threshold-pct: uint,
            ;; Parent chain block height at which the PoX sunset begins.
            sunset-start: uint,
            ;; Parent chain block height at which the PoX sunset ends.
            sunset-end: uint
        },
        ;; Appchain block limit
        block-limit: {
            ;; Maximum number of bytes that can be written per block (including
            ;; the confirmed microblock stream).
            write-length: uint,
            ;; Maximum number of writes that can occur per block (including the
            ;; confirmed microblock stream).
            write-count: uint,
            ;; Maximum number of bytes that can be read per block (including the
            ;; confirmed microblock stream). 
            read-length: uint,
            ;; Maximum number of reads that can occur per block (including the
            ;; confirmed microblock stream).
            read-count: uint,
            ;; Maximum amount of CPU time that can be used per block (including
            ;; the confirmed microblock stream).
            runtime: uint
        },
        ;; Ticker name for the token, used to identify native token functions in
        ;; the appchain's Clarity VM
        token-name: (string-ascii 16),
        ;; List of initial account balances in the appchain genesis block.
        initial-balances: (list 128 {
            ;; the recipient in the appchain (cannot be a contract)
            recipient: principal,
            ;; the amount of appchain tokens
            amount: uint
        }),
        ;; Ordered list of names of smart contracts that will be instantiated
        ;; in the appchain genesis block.  The names do not include the 
        ;; address -- for example, you would put `pox` instead of
        ;; `SP000000000000000000002Q6VF78.pox`.
        boot-code: (list 128 (string-ascii 128)),
        ;; What consensus ruleset should the appchain use?  These correspond to
        ;; the rulesets for Stacks epochs 2.0, 2.05, and 2.1.  The value here
        ;; should be `u20` for 2.0, `u205` for 2.05, or `u21` for 2.1.
        epoch: uint
    }
)

;; a list of IP addresses and public keys for appchain boot nodes
(define-data-var appchain-boot-nodes
   (list 16 {
      ;; compressed secp256k1 public key
      public-key: (buff 33),
      ;; IPv6 address of the node's p2p endpoint, in network byte order.
      ;; An IPv4 address can be mapped to an IPv6 space via IETF RFC 4038:
      ;; simply set the first 10 bytes to 0x00, bytes 10-11 to 0xff, and
      ;; bytes 12-16 to the IPv4 address.
      host: (buff 16),
      ;; IP port of the p2p endpoint, in network byte order
      port: (buff 2),
      ;; IPv6 address of the node's RPC endpoint, in network byte order.
      ;; It can also be a mapped IPv4 address per IETF RFC 4038.
      data-host: (buff 16),
      ;; IP poort of the RPC endpoint, in network byte order
      data-port: (buff 2)
   })
)
```

The mining contract must have each of these data variables and maps defined,
with _exactly_ these types, in order for the appchain node to boot.  While
Clarity traits do not yet permit the developer to specify a required data space
type signature, the appchain implementation will refuse to interact with an
appchain mining contract that does not have a data space with these type
signatures.

### `(register-vrf-key (key-op (buff 80)))`

This function takes a SIP-001-enoded VRF key registration payload [11],
including the `magic` and `op` bytes, as its sole argument.  As with Stacks on
Bitcoin, the `key-op` payload encodes a VRF public key that will be used by the
network to verify VRF proofs in the appchain blocks produced by this miner.

If successful, this method _must_ do the following:

* Store the `key-op` value to the `appchain` data map, within the list that
corresponds to the parent chain's current block height.  The following values
are required for the list entry:

   * The `burnt` and `transferred` fields _must_ be `u0`.

   * The `sender` field _must_ be the address of the miner that will use it.

This method _must_ return `(ok true)` on success.

No error values are mandated by this SIP.  Different implementations may use
different error values.

### `(mine-block (block-op (buff 80)) (to-burn uint) (recipients (list 2 principal)) (recipient-amount uint))`

This function takes a SIP-001-encoded block-commit registration payload [12],
including the `magic` and `op` bytes, as the first argument (`block-op`).  
This `(buff 80)` encodes the same data as a Bitcoin `OP_RETURN` for a
block-commit does for Stacks.  This method does not need to validate the
contents of `block-op`, but it will need to store it if the method succeeds.

The `to-burn` argument is the number of parent chain tokens to burn on
successful execution, via the parent chain's `stx-burn?`-equivalent function.
This value may be `u0`.  A non-zero value would only be supplied by miners during a
the PoX sunset phase; burning parent chain tokens in a PoX prepare phase is
achieved by instead sending `recipient-amount` parent chain tokens to a
designated burn address in the `recipients` list.

The `recipients` list is a list of at most two principals that will receive the
parent chain tokens from the miner.  Each recipient will receive
`recipient-amount` tokens.  This list may not be empty; if it is empty, then the
transaction record will be ignored by the appchain.

If successful, this method _must_ do the following:

* Store the `block-op` value to the `appchain` data map, within the list that
  corresponds to the parent chain's current block height.

   * The `burnt` field _must_ be set to `to-burn`.

   * The `transferred` field _must_ be set to `(* (len recipients) recipient-amount)`.

   * The `sender` field _must_ be set to the address of the miner.

   * The `recipients` field _must_ be set to the `recipients` argument.

   * The `chained` field _must_ be set to `true` if the miner mined in the last
     parent chain block, or `false` otherwise.  If this value is `false`, then
the miner will be penalized by the appchain sortition algorithm for not
consistently mining (just as Stacks miners are so penalized for not consistently
mining on Bitcoin).  A sample contract below describes one way to calculate this
value.

* Burn `to-burn` parent chain tokens, if `to-burn` is positive.

* Transfer `recipient-amount` parent chain tokens to each principal in
  `recipients`.

This method _must_ return `(ok true)` on success.

This method may return one of the following errors:

* `(err u0)` indicates that the `recipients` list is invalid (i.e. empty).

* `(err u1)` indicates that the miner does not have sufficient parent chain
  tokens to pay the recipients and burns.

* `(err u3)` indicates that `recipient-amount` is not positive.

#### Block-commit Chaining

As with Stacks, appchains require miners to consistently spend parent chain
tokens for a time before their block-commits will be considered for sortition
with non-trivial probability.  In Stacks, the miner's block-commit spend address
must be used _only_ for mining: each block-commit Bitcoin transaction must spend
a UTXO created by a previous block-commit transaction.  These criteria improve
the chain's safety by ensuring that an attempted 51% attack will be seen by
the rest of the network (i.e. by inspecting the recent Bitcoin blocks) before
the attacker has a non-negligeable chance of winning a sortition.

Because Stacks is not a UTXO-based blockchain, the mining contract is
responsible for determining whether or not two block-commits from the same miner
are "chained" this way.  The rules for deciding this is up to the
implementation, but the `chained?` field of the block-commit's entry in the
`appchain` transaction list must be set to `true` if the block-commit is linked
to the miner's previous block-commit.

One way to do this is to have the contract implementation keep track of the last
parent chain block height in which a miner attempted to mine a block.  If the
miner consistently tries to mine blocks -- i.e. the last block height the miner
mined in happens to be the parent chain tip -- then the block-commit being
submitted is treated as chained to the last block-commit this miner sent.
Another more-forgiving way to do this is to treat a block-commit as chained to the miner's last
block-commit if the last block-commit was sent within a fixed window _W_ of
parent chain blocks.  It is up to the implementation to decide what these rules
are.

### `appchain-version`

This data-var contains the trait and data space schema version of this appchain.
For now, this _must_ be set to `u1`, which represents the schemas defined in
this SIP.  A subsequent SIP may propose an alternative trait and/or data space
schema, in which case, a different value of this data-var must be used.

This data-var _must_ be set before any blocks are mined.  The appchain node
implementation may simply refuse to boot without this data-var set.

### `appchain`

This data map provides a per-parent-chain-block list of all appchain
miner-submitted transactions, as well as the accompanying metadata for them that
are required by the appchain implementation to process them.

The reason this data map is organized this way is to facilitate fast and
efficient appchain node queries and MARF merkle proof generation and
verification.  With this organization, the appchain miner data for each parent
chain block can be queried in one network round-trip, along with a single MARF
merkle proof that links the miner data to the parent chain block headers.

The downside of this organization is that appchain miners whose transactions are
processed later in the block will be more expensive, since the act of updating
the `(list 128)` for a given parent block height requires reading and writing all of the
previous miners' transactions in that parent block as part of a `map-get?` and
`map-set`.  Despite this, this organization is recommended for the following reasons:

* It is more important to reduce the total number of data space loads and stores
  than the total number of bytes read and written.  This is because each load
and store requires a MARF query and MARF insert, and the number of MARF
operations per block is much harder to increase in subsequent releases 
than the total amount of data read or written per block.  This, in turn,
is because the number of MARF operations per block the system can support is fundamentally
limited by the underlying storage medium's seek time, whereas the number of
bytes read and written is limited by storage I/O bandwidth.  It is
harder to improve seek time than I/O bandwidth because the former
is physically constrained by the speed of electrical signal propagation 
whereas the latter is constrained by I/O bus widths (i.e. number
of concurrent signals).

* Keeping all of an appchain's miner transactions within a single MARF-indexed
  record means that only one MARF merkle proof is needed to attest to all of an
appchain's miner transactions for a given sortition.  It also means that only a
single network round-trip is needed to query these transactions.

* Keeping all of this data in a data map exposes both the data and MARF proofs
  via the parent chain's RPC API, which enables an appchain node to run without
a co-located parent chain node.  The need for a MARF proof precludes exposing
the appchain miner transaction state via a read-only Clarity function.

Each entry in the `appchain` data map is keyed by the parent chain block height.
Each value in the `appchain` data map is a list of up to 128 tuples with the
following fields:

* `sender`:  This is the address of the miner.  It can be a contract address.

* `chainded?`:  This is `true` if (1) this is a block-commit record and (2) the
  miner that sent it built upon a recent prior block-commit, as described above
under the `mine-block` method description.

* `data`:  This is the SIP-001-encoded block-commit payload that represents the
  block being considered for sortition.  See SIP-001 for details on how to
produce this value.

* `burnt`:  This is the number of parent chain tokens burnt when processing this
  transaction (only applies to contract-calls to `mine-block`).

* `transferred`:  This is the _total_ number of parent chain tokens transferred to 
  _all_ principals in the `recipients` list (only applies to contract-calls to
`mine-block`).

* `recipients`:  This is a list of one or two principals that received parent
  chain tokens in this transaction (only applies to contract-calls to
`mine-block`).

### `appchain-config`

This structure defines various global configuration parameters for the appchain.
An appchain node will query this data-var's value to determine how to boot
itself up.

This data-var has the following fields:

* `chain-id`:  This is a 4-byte chain identifier that is unique to this
  appchain.  Establishing global uniqueness is outside of the scope of this SIP,
but would likely be implemented by a registry contract such as BNS.  This value
is included in all p2p messages as the `network_id` field in the message preamble [14],
and in all transactions in the `chain_id` field [15].  Different values for
different appchains prevent them from accidentally interacting.  Once set, this
value must never be changed.

* `start-height`:  This is a block height in the parent chain at which the
  appchain starts.  All keys in the `appchain` data map are greater than this
value.  Once set, this value must never change.

* `pox`:  This is the PoX configuration for the appchain.  Once set, it must
  never be changed later.

   * `reward-cycle-length`:  This is a positive integer that determines how long
     the whole PoX reward cycle is, including both the reward and prepare
phases.  For Stacks, this is 2100 (2000-block reward phase plus a 100-block
prepare phase).  It must be greater than the `prepare-length` field.

   * `prepare-length`:  This is a positive integer that determines how long the
     prepare phase of the PoX reward cycle is.  For Stacks, this is 100.

   * `anchor-threshold`:  This is the number of confirmations that an appchain
     block must receive during the prepare phase for it to be a PoX anchor
block.  It must be greater than half of the `prepare-length` value -- i.e. a PoX
anchor block must always have a majority of confirmations during the prepare
phase in order to ensure that at most one such block will be found.

   * `pox-rejection-fraction`:  This is a number between 0 and 100 inclusive
     that represents the fraction of liquid appchain tokens that vote to disable
PoX for this reward cycle.  For Stacks, this is 5.

   * `sunset-start`: This is the parent chain block height at which PoX will
     begin transitioning to proof-of-burn (PoB).  If this is not desired for the
appchain, then this value should be very large.  If the appchain should instead
function exclusively through PoB, then this value should be set to `u0`.

   * `sunset-end`: This is the parent chain block height at which PoX will
     finish transitioning to proof-of-burn (PoB).  If this is not desired for
the appchain, then this value should be very large.  If the appchain should
instead function exclusively through PoB, then this value shoudl be set to `u0`.

* `block-limit`: This tuple represents the block limits for the appchain.

   * `write-length`: This is the number of bytes that can be written per block,
     including by the microblock stream it confirms.

   * `write-count`: This is the number of writes that can occur per block,
     including by the microblock stream it confirms.

   * `read-length`: This is the number of bytes that can be written per block,
     including by the microblock stream it confirms.

   * `read-count`: This is the number of reads that can occur per block,
     including by the parent microblock stream it confirms.

   * `runtime`: This is the maximum amount of computation that can occur per
     block (see SIP-006 [16] and SIP-012 [17]).

* `token-name`: This is the name of the token, as it will be represented in the
  Clarity VM for the appchain.  All instances of `stx` in the Clarity VM's
built-in functions and variables will have this name instead, according to this
template.  For example, if `token-name` is `foo`, then in Stacks epochs 2.05 and
earlier, the following functions and variables are renamed as follows:

   * `stx-transfer?` becomes `foo-transfer?`

   * `stx-get-balance` becomes `foo-get-balance`

   * `stx-burn?` becomes `foo-burn?`

   * `stx-liquid-supply` becomes `foo-liquid-supply`

   This change applies to all boot code in the appchain as well, including the
mandatory boot code contracts.

* `initial-balances`: This is a list of principals that will receive an initial
  appchain token balance in the genesis block.  The principals can be smart
contracts, so if the appchain needs to distribute tokens to more principals than
this list allows, it can do so via the contract code.

* `boot-code`: This is the sequence of _names_ of smart contracts to be
  downloaded from an existing appchain node and installed in the node's boot
code.  These names do _not_ include the contract address, because the contract
address of the boot code is fixed by the protocol (i.e.
`SP000000000000000000002Q6VF78` on mainnet).  This list must include the mandatory
boot code contracts, since new appchain nodes fetch the appchain-specific
implementations of these mandatory contracts when they boot up.

* `epoch`:  This number defines the rulset the appchain implementation uses.
  The Stacks blockchain has three rulesets: Epoch 2.0, Epoch 2.05, and Epoch
2.1.  Epoch 2.0 is the ruleset that the network launched with, Epoch 2.05 is the
ruleset defined in SIP-012, and Epoch 2.1 is an as-of-yet-unreleased ruleset.
The appchain must choose which ruleset it runs in.  It is highly recommended to
use the latest ruleset.  The allowed values are `u20` for Epoch 2.0, `u205` for
Epoch 2.05, and `u21` for Epoch 2.1 (note that Epoch 2.1 might not be supported
at the time of this SIP's ratification, but it will be once the Stacks 2.1
upgrade happens).

### `appchain-boot-nodes`

This data-var contains a list of already-running appchain nodes that a new
appchain node can connect to.  The list items are comprised of the following:

* `public-key`: This is a secp256k1 compressed public key.  This is the
  public key used to authenticate p2p messages from the boot node.

* `host`: This is either an IPv6 address, or an IPv4 address mapped to an IPv6 
  address space (see IETF RFC 4038).  It is the IP address of the boot node's
  p2p endpoint.

* `port`: This is the port of the p2p endpoint, in network byte order.

* `data-host`: This is either an IPv6 address, or an IPv4 address mapped to
  an IPv6 address space.  It is the IP address of the boot node's RPC
endpoint.  It may be different from the `host` address.

* `data-port`: This is the port of the RPC endpoint, in network byte order.

Unlike `appchain-config`, this data-var may be changed by the contract at any
time, such as to add or remove boot nodes.  In practice, an implementation of
this contract would provide a means for curating this list (many strategies
exist).

### Sample Implementation

Below is a sample implementation of an appchain mining contract.

```
(define-data-var appchain-version uint u1)

(define-map appchain
    uint
    (list 128 {
        sender: principal,
        chained?: bool,
        data: (buff 80),
        burnt: uint,
        transferred: uint,
        recipients: (list 2 principal)
    })
)
(define-data-var appchain-config
    {
        chain-id: uint,
        start-height: uint,
        pox: {
            reward-cycle-length: uint,
            prepare-length: uint,
            anchor-threshold: uint,
            pox-rejection-fraction: uint,
            pox-participation-threshold-pct: uint,
            sunset-start: uint,
            sunset-end: uint
        },
        block-limit: {
            write-length: uint,
            write-count: uint,
            read-length: uint,
            read-count: uint,
            runtime: uint
        },
        initial-balances: (list 128 { recipient: principal, amount: uint }),
        boot-code: (list 128 (string-ascii 128)),
    }
    {
        chain-id: u2147483650,   ;; 0x80000002
        start-height: (+ u5 block-height),
        pox: {
            ;; very short reward cycles
            reward-cycle-length: u5,
            prepare-length: u3,
            anchor-threshold: u2,
            pox-rejection-fraction: u25,
            pox-participation-threshold-pct: u5,
            ;; no sunset
            sunset-start: u18446744073709551615,
            sunset-end: u18446744073709551615
        },
        block-limit: {
            write-length: u15000000,
            write-count: u7750,
            read-length: u100000000,
            read-count: u7750,
            runtime: u5000000000
        },
        initial-balances: (list
            {
                ;; private key: 3bfbeabafb8c6708ac85e66feaf76074a827e74f3e81678600153d94b5bd1a2b01
                recipient: 'ST3N0JG3EE5Z2R3HN7WAEFM0HRGHHMCD4E170C0T1,
                amount: u1000000
            }
        ),
        boot-code: (list
            "hello-world"
        ),
        epoch: u205
    }
)
(define-data-var appchain-boot-nodes
   (list
      {
          ;; private key: 9f1f85a512a96a244e4c0d762788500687feb97481639572e3bffbd6860e6ab001
          public-key: 0x038cc1dc238b5b6f8d0a8b38baf5c52280396f8a209cc4de33caff2daefe756c23, 
          ;; 127.0.0.1:8000
          host: 0x00000000000000000000ffff7f000001,
          port: 0x1f40,
          ;; 127.0.0.1:8001
          data-host: 0x00000000000000000000ffff7f000001,
          data-port: 0x1f41
      }
   )
)

;; Used for deducing block-commit chaining
(define-map last-mined-heights
    ;; sender
    principal
    ;; height at which a block-commit was last sent
    uint
)

;; Store a non-block-commit mining operation
(define-private (add-nonmining-block-op (payload (buff 80)) (recipients (list 2 principal)))
    (let (
       (op-list (default-to (list ) (map-get? appchain block-height)))
    )
       (map-set appchain block-height 
           (unwrap-panic
               (as-max-len? (append op-list {
                   sender: tx-sender,
                   chained?: true,
                   data: payload,
                   burnt: u0,
                   transferred: u0,
                   recipients: recipients
               })
               u128)
           )
       )
       (ok true)
    )
)

(define-public (register-vrf-key (key-op (buff 80)))
    (add-nonmining-block-op key-op (list ))
)

;; Allow this contract to be a miner as well
(define-public (register-vrf-key-as-contract (key-op (buff 80)))
   (as-contract (register-vrf-key key-op))
)

(define-private (send-to-recipient (recipient principal) (amount uint))
    (begin
        (unwrap-panic
            (if (not (is-eq tx-sender recipient))
                (stx-transfer? amount tx-sender recipient)
                (ok true)
            )
        )
        amount
    )
)

(define-public (mine-block (block-op (buff 80)) (to-burn uint) (recipients (list 2 principal)) (recipient-amount uint))
    (let (
        (op-list (default-to (list ) (map-get? appchain block-height)))
        ;; pessimistic take: consider block-commits chained only if the miner mined in the last block
        (chained? (is-eq block-height (+ u1 (default-to u0 (map-get? last-mined-heights tx-sender)))))
    )
        (asserts! (> (len recipients) u0)
            (err u0))   ;; no recipients

        (asserts! (> recipient-amount u0)
            (err u3))   ;; amount to send is non-positive

        (asserts! (>= (stx-get-balance tx-sender) (+ to-burn (* (len recipients) recipient-amount)))
            (err u1))   ;; insufficient balance

        (if (> to-burn u0)
            (unwrap-panic (stx-burn? to-burn tx-sender))
            true
        )

        (fold send-to-recipient recipients recipient-amount)

        (map-set appchain block-height
            (unwrap-panic
                (as-max-len? (append op-list {
                    sender: tx-sender,
                    chained?: chained?,
                    data: block-op,
                    burnt: to-burn,
                    transferred: (* (len recipients) recipient-amount),
                    recipients: recipients
                })
                u128)
            )
        )

        ;; update chaining information for this miner
        (map-set last-mined-heights tx-sender block-height)
        (ok true)
    )
)

;; Allow this contract to be a miner as well
(define-public (mine-block-as-contract (block-op (buff 80)) (to-burn uint) (recipients (list 2 principal)) (recipient-amount uint))
    (begin
        (unwrap-panic (stx-transfer? (+ to-burn (* (len recipients) recipient-amount)) tx-sender (as-contract tx-sender)))
        (as-contract (mine-block block-op to-burn recipients recipient-amount))
    )
)
```

## The Appchain Lifecycle 

The mining contract trait and data space are designed to make it easy
for an appchain node operator to boot up an appchain node.  An appchain node
operator only needs the following to boot up a full chain state replica:

* Access to the RPC API of a parent chain node it can trust to provide valid
  block headers

* The fully-qualified name of the appchain mining contract on the parent chain

The only exception is the first-ever online appchain node, which the appchain
creator spawns.  In practice, this node should be listed in the
`appchain-boot-nodes` data-var.

### Genesis Block

Before an appchain can boot, its creator must prepare its genesis block.  The
genesis block contains two types of data:

* Initial token allocations

* Boot code

The initial token allocations are simply the list of accounts which are instantiated
with a non-zero token balance.  An appchain is not required to have any initial
allocations, but if there are some, then they must be published in the
`appchain-config` data-var.

The boot code consists of a list of smart contracts that are instantiated by the
address (i.e. `SP000000000000000000002Q6VF78` on mainnet)
before the first block is mined.  As it
is in Stacks, this address is a system address -- no private key is known for
it; it is only used to publish Clarity code needed by the Stacks network to
function correctly (such as `.pox`).

Because appchains handle application-specific workloads, they may need to be
instantiated with additional boot code beyond what Stacks offers.  This
additional boot code gives the developer the ability to pre-populate the
appchain state with Clarity code, accounts, and data structures that will
be needed by its users later. 

Each appchain instantiates the same boot code in the same order.
The appchain boots by first creating the initial appchain token allocations, and then instantiating
the appchain-specific boot code.  This gives the appchain-specific boot code the
opportunity to further set up the initial appchain token balances before the
system accepts its first block.

The `boot-code` list _must_ include all contracts in the boot code, including
ones that are blessed by the implementation such as `.pox` and `.costs`.
Moreover, because the name of the built-in native token functions and global
variables are different, these contracts will need to be modified by the creator
to use them with the appchain's token (see "Best Practices" below). 
In practice, this is achieved simply via a find/replace.

#### Mandatory Boot Code

The appchain uses the same Clarity VM as the Stacks chain, and it expects that
the following smart contracts are the first-ever contracts in the boot code,
deployed in this order:

* `.pox`

* `.cost-voting`

* `.costs`

If instantiating an appchain with epoch 2.05, then the following additional boot
code contracts must be defined after these contracts:

* `.costs-2`

(This list will be updated for epoch 2.1 when it is specified in a later SIP).

These smart contracts _must_ have the same public functions and interfaces as
those in Stacks.  The implementations may be different, however.  This is
because the Clarity VM expects these contracts to exist as they are in Stacks,
and has extra code paths that depend on the existence and behavior of the
functions they contain.

### Boot-up

When an appchain node boots, it contacts its designated parent chain node to obtain the
block headers for the canonical parent chain fork.  In particular, the appchain
node needs to build up an internal mapping between block hashes and MARF state
root hashes, which it will use to verify MARF merkle proofs for data in the
mining contract.  Once it has done so, the node
requests the current `appchain-version` and `appchain-config` data-var values from the
mining contract on the parent chain, as well as a MARF merkle proof to verify
their values are consistent with the canonical chain's tip.  Once it has
authenticated and parsed the configuration structure, it
selects some or all of the nodes listed in the `appchain-boot-nodes` list 
to proceed to boot the appchain.

With the exception of the first-ever appchain node, all appchain nodes use the
`boot-code` list in `appchain-config` to identify the appchain boot code
contrats to download from one of the seed nodes.  The appchain node simply
downloads the smart contract code bodies via the seed node's
`/v2/contracts/source` API endpoint [19] and authenticates them with a MARF
merkle proof.  The first-ever appchain node is
simply given the smart contract source directly by the node operator, such as
via files loaded at runtime from disk.

Once the appchain node has obtained the boot code, it can proceed to produce the
genesis block as described above.  It verifies that the boot code is valid by
checking the resulting genesis state root hash against the genesis state root
hash reported by the seed node (i.e. via the `/v2/info` API endpoint on the seed
node, in the `.genesis_chainstate_hash` field [18]).  If the resulting genesis
chain state root hash is correct, then the appchain node proceeds to fetch
blocks, microblocks, and neighbor addressess from its seed node.

In this proposal, the genesis state root hash must either be trusted from the
boot node, or it must be provided out-of-band.  However, it is possible to
construct an **appchain registry** smart contract on the Stacks chain that lists each
appchain's genesis state root hash along with its smart contract address.  The
registry contract must reside on the Stacks chain (i.e. must be a singleton and
must be available to all appchains) in order to ensure that appchain chain IDs
and genesis root hashes are globally unique.
However, the design of this registry contract and the protocol for using it are
out-of-scope for this SIP.

### Synchronization

Once an appchain node has processed its genesis block, it proceeds to scan the
mining contract's `appchain` data map by querying each entry in order by successive
parent chain block height.  It verifies the authenticity of the value list using a
MARF merkle proof that links it to the canonical tip of the parent chain.
Once it has a given list of appchain miner transaction data, it proceeds to
execute a cryptographic sortition via the same SIP-001 and SIP-007 rules that
Stacks uses in order to determine the winning appchain block hash for that
parent chain block.  The appchain uses the `pox-constants` field of
`appchain-config` to determine how long its reward cyles are, and by extension,
how many PoX address slots it supports per reward cycle.  Appchains pay out to
at most two addresses under PoX, just as Stacks does.

As the node discovers the block hashes for the appchain in this way, it crawls
the appchain peer network and fetches blocks and microblocks from other
already-booted appchain nodes, per SIP-003.  All blocks and microblocks have the
same wire formats as Stacks (described in SIP-005), but the appchain's Clarity
VM will enforce the block limit listed in its `appchain-config` data-var.

## Extension Contracts

The Stacks blockchain is an open-membership, forkable blockchain with a
predetermined token emission schedule, meaning that
there are no protocol-enfoced barriers to entry for miner or user participation
beyond requiring miners to spend the parent chain's token.  This openness comes
at the cost of allowing arbitrarily deep forks and chain reorganizations, and
does not offer any way to add or remove tokens from circulation as demand grows
or shrinks. However, different applications are expected to have different liveness and
safety requirements, and will need to make different trade-offs in terms of how
permissive appchain participation can be, and what kinds of transactions will be
allowed.

For example:

* An appchain could implement a multiplayer game session, where the players
  themselves are the miners.  This appchain would need to prevent forks, even if
it meant stalling the chain, since forks constitute a form of re-doing the game
session in favor of the fork instigator.  In addition, the miner set would need to be closed-membership
if players are not meant to be able to join mid-game.  For example, an appchain
implementing a poker session would require both of these constraints in order
for a majority of honest players to compel honest play, even in the face of
player losses.  Finally, the appchain would require players to take turns mining
in a round-robin fashion in order to implement game turns.

* An appchain could implement a single user's social media wall, where the user
  both posts new content and accepts friend-submitted comments by mining blocks
that contain URLs and hashes to them (thereby publishing them in a
nonrepudiable, and nonrevokable manner).  In this system, the appchain would
need to be closed-membership (i.e. only the user can post to their own wall),
but would also need to support forks in order to support "undoing" recent posts.
The posts would not go away, since the fork history is preserved on the parent
chain, but it preserves the ability of the user to modify their canonical post
history.

* An appchain could implement a DAO, where miners are the initial members but
  after a certain amount of parent token has been spent, or a certain amount of
time has passed, additional non-mining members would be permitted.  At this
point, the appchain should forbid miners from censoring non-mining members by
orphaning blocks which contain their transactions (i.e. the appchain would
require each member's transactions, once seen, to be present in all forks).

* An appchain could implement an equity table for a corporation.  Tokens on
  the appchain could represent units of stock.  This appchain could have very
particular token and participation requirements, such as:
   * The miners would be controlled by the corporate board of directors.
   * A token holder would be unable to transfer tokens if the current calendar
     date falls on a backout period.
   * A token holder's set of spendible tokens would unlock over time, or with
     permission from the board of directors, in order to implement vesting
cliffs.
   * A transaction would have no transaction fees in the native token (lest the
     user destroy equity to write to the chain).
   * PoX would be selectively turned on and off by the board of directors as a way of
     paying token holders dividends according to their (locked) token
allocation.

   Such an appchain would need a closed-membership miner set, would need to
prevent forks, and would need to support a custom token minting process to
implement equity grants, vesting, lockups, and blackout dates.

To support these features and more, appchains implement _extension contracts_.
An extension contract is a special piece of boot code that lets the developer specify
extra validity rules for blocks and transactions, as well as specify how tokens
are minted.  These rules apply _in addition to_ the rules used by the Stacks
blockchain to validate its blocks and microblocks.  Like `.pox` and `.costs`,
this is a "blessed" contract, meaning that the appchain implementation must
run the `.extensions` contract in consensus-critical code paths in order to
decide how to process new blocks and transactions.

This contract  _must_ have the name `.extensions`, and it must confirm to the following trait:

```
(define-trait sip-019-appchain-extension
   (
      ;; Function to determine how many tokens to mint.
      ;; Returns the number of tokens to mint on success, as well as the
      ;; alternative principal to which to award them (if different from the
      ;; sortition winner)
      ;; Returns an error code on failure
      (mint-tokens! (
         ;; appchain block height
         uint
         ;; appchain block hash
         (buff 32)
         ;; parent chain block height
         uint
         ;; parent chain block hash
         (buff 32))
         (response { tokens: uint, alt-recipient: (optional principal) } uint))

      ;; Function to validate a transaction.
      ;; Returns true if valid; false if not
      ;; Returns an error code on failure
      (validate-transaction (
         ;; appchain block height of the parent appchain block
         uint
         ;; appchain block hash of the parent appchain block
         (buff 32)
         ;; appchain block height of the appchain block that confirms or contains this tx
         uint
         ;; appchain block hash of the appchain block that confirms or contains this tx
         (buff 32)
         ;; appchain microblock hash and sequence, if mined in a microblock
         (optional { microblock: (buff 32), sequence: uint }),
         ;; transaction version
         uint
         ;; sender principal
         principal
         ;; sender nonce
         uint
         ;; sponsor principal
         principal
         ;; sponsor nonce
         uint
         ;; anchor mode
         uint
         ;; post-condition mode
         uint
         ;; list of post-conditions
         (list 1048576 { type: uint, sender: principal, asset-info: (optional { contract: principal, name: (string-ascii 128) }), code: uint })
         ;; Transaction payload.  Exactly one field will be (some ...); all the rest will be none.
         {
            coinbase: (optional (buff 32)),
            token-transfer: (optional { recipient: principal, amount: uint, memo: (buff 34) }),
            contract-call: (optional { contract: principal, function-name: (string-ascii 128), function-args: (list 1024 (buff 1048576)) }),
            smart-contract: (optional { contract-name: (string-ascii 128), code-body (string-ascii 1048576) }),
         }
      ) (response bool uint))

      ;; Function to validate a microblock.
      ;; Returns true if valid; false if not.
      ;; Returns an error on failure
      (validate-microblock (
         ;; parent appchain block height
         uint
         ;; parent appchain block hash
         (buff 32)
         ;; child appchain block height
         uint
         ;; child appchain block hash
         (buff 32)
         ;; sending miner address (i.e. tx-sender of the miner that produced this block)
         principal
         ;; microblock sequence
         uint
         ;; microblock hash
         (buff 32)
         ;; version
         uint
         ;; tx merkle root
         (buff 32)
         ;; signature
         (buff 65)
      ) (response bool uint))
     
      ;; Function to validate a block.
      ;; Returns true if valid; false if not.
      ;; Returns an error on failure.
      (validate-block (
         ;; parent appchain block height
         uint
         ;; parent appchain block
         (buff 32) 
         ;; appchain block height
         uint
         ;; appchain block hash
         (buff 32)
         ;; parent appchain microblock hash and sequence, if applicable
         (optional { parent-microblock: (buff 32), parent-microblock-sequence: uint })
         ;; version
         uint
         ;; total work (i.e. block height)
         uint
         ;; total burn (i.e. total parent tokens spent so far)
         uint
         ;; tx merkle root
         (buff 32)
         ;; MARF merkle root
         (buff 32)
         ;; microblock public key hash
         (buff 20)
         ;; miner address (i.e. tx-sender of coinbase)
         principal
         ;; coinbase payload
         (buff 32)
         ;; parent chain block height
         uint
         ;; parent chain block hash
         (buff 32)
      ) (response bool uint))

      ;; Function to run a sortition.
      ;; Returns the index into the block-commits of who the winner should be.
      ;; * (ok (some (some x))) means that the x-th block-commit is the winner
      ;; * (ok (some none)) means that there is no winner
      ;; * (ok none) means to use what default sortition algorithm decided
      ;; Returns an error on failure.
      (run-sortition (
         ;; parent chain block height
         uint
         ;; parent chain block hash
         (buff 32)
         ;; list of blocks committed, and metadata
         (list 1024 {
            ;; hash of attempted block,
            block-hash: (buff 32),
            ;; attempted block height,
            block-height: uint,
            ;; parent block hash
            parent-block: (buff 32),
            ;; parent block height
            parent-block-height: uint,
            ;; miner address on the parent chain
            miner: principal,
            ;; burn modulus
            burn-modulus: uint,
            ;; memo bits
            memo: uint,
            ;; parent chain txid
            txid: (buff 32),
            ;; PoX recipients
            recipients: (list 2 principal),
            ;; total amount of parent tokens sent
            total-spend: uint,
            ;; parent chain transaction fee
            tx-fee: uint
         })
         ;; which entry in the block list was the winner, if there was one at all, 
         ;; using the built-in sortition logic described in SIP-001 and SIP-007.
         (optional uint)
      ) (response (optional (optional uint)) uint))

      ;; Function to decide if the tenure is valid
      (accept-tenure? (
         ;; appchain block height
         uint
         ;; appchain block hash
         (buff 32)
         ;; parent chain block height
         uint
         ;; parent chain block hash
         (buff 32)
      ) (response bool uint))
   )
)
```

There are no requirements for the extension contract data space.

The extension contract's methods are evaluated by the appchain's block- and
transaction-processing logic.  While they are accessible to other Clarity smart
contracts, the implementation can determine when they are being used by the
appchain by inspecting `tx-sender`.  If called by the appchain itself,
`tx-sender` will be equal to the system boot address (i.e.
`SP000000000000000000002Q6VF78` on mainnet).  This way, the implementation can
take steps to prevent other smart contracts from calling them, if desired.

Unlike most smart contracts, the extension contracts are not subject to a runtime limit
when invoked by the appchain to validate chain state.  They do not contribute to the
block's overall execution in this usage.  They do, however, contribute to block
execution limits if called from a transaction.

Because the `.extensions` contract is part of the appchain's custom boot code,
it _must_ be listed in the `boot-code` list in the appchain's mining contract's
`appchain-config` data-var.  Appchain nodes will download and instantiate the
`.extensions` contract as part of normal boot-up.

### `(mint-tokens!)`

This function is responsible for determining how many appchain tokens to mint for a given
appchain block mined on a given parent chain block, and which appchain principal
will receive them.  A pre-determined mint schedule, such as the one used in
Stacks, would only consider the appchain block height to determine how many
tokens to mint, and would return `none` for the principal (meaning that the
tokens go to the miner account).  If this function returns `(err ...)`, then the
node will exit with a runtime panic.

### `(validate-transaction)`

This function is responsible for determining whether or not a given transaction
is valid on the appchain, _in addition to_ meeting all of the validity
requirements that the Stacks blockchain would have imposed.  In Stacks, this
function is a no-op, but an appchain implementation would use it to _further_
constrain what constitutes a legal transaction.  For example, an appchain that
did not permit users to instantiate smart contracts would return `(ok false)` if
the transaction payload tuple had `(some ...)` for the `smart-contract` field.

This function is called for each appchain transaction for a given miner tenure.  That
is, it is called for all of an appchain block's parent microblock stream's
transactions, and then for each of the appchain block's transactions.  The
function is called for all transactions before the tenure is committed.

This method may be called on a transaction more than once.  For example, if the
transaction is present in a microblock stream, and multiple appchain blocks
confirm the microblock that contains this transaction, then this method is
called when processing each such block.  In these cases, the parent appchain
block heights and parent block hashes (arguments 1 and 2) will be the same, but the 
height and hash of the block that either contains or confirms this transaction
(arguments 3 and 4) will be different.  It is possible that a transaction will
be considered valid or invalid depending on the block that confirms or contains
it.

A return value of `(ok true)` indicates that the transaction is valid for this
appchain.  A return value of `(ok false)` indicates that the transaction is
invalid, and the miner tenure that produced it should not be committed (i.e. the block
that confirms it will be rejected and marked as invalid).  A return value of
`(err ...)` will trigger a runtime panic, causing the node to log the error code
and shut down.

### `(validate-microblock)`

This function is responsible for determining whether or not a given microblock
is valid on the appchain, _in addition to_ being an otherwise-valid microblock
according to the Stacks blockchain's validation rules.  The method takes all of
the microblock header metadata as arguments.

This function is called for each microblock confirmed by the current anchor
block under consideration.  This function will be called in microblock stream
order, and will be called for each microblock before the tenure state is
committed.

This function can be called more than once for the microblock, such as when the
microblock stream has multiple descendant appchain blocks.  In this case, the
parent appchain block height and hash arguments (arguments 1 and 2) will be the
same, but the child appchain block height and hash arguments (arguments 3 and 4)
will be different.  A microblock may be treated as either
invalid or valid depending on which appchain block confirms it.

A return value of `(ok true)` indicates that the microblock is valid for this
appchian.  A return value of `(ok false)` indicates that the microblock is
invalid, and the block that confirms it should be rejected by the network.  A
return value of `(err ...)` will lead to a runtime panic, causing the node to
log the error code and shut down.

### `(validate-block)`

This function is responsible for determining whether or not a given appchain
block is valid for hte appchain, _in addition to_ being an otherwise-valid block
according to the Stacks blockchain's validation rules.  This method takes all of
the block header fields as arguments, as well as the parent chain block hash and
height that selected this block for inclusion.

This method takes the 32-byte payload from the block's coinbase transaction as
an argument.  The reason for this is that the coinbase transaction variant is
meant to provide miners with an in-band signaling mechanism for coordinating
on-chain behavior _without_ relying on an in-band smart contract (i.e. for
helping miners coordinate a hard-fork in the event that a catastrophic bug is
discovered in the Clarity VM).  The data for
this payload is passed to the `(validate-block)` function so that the
`.extensions` contract can serve a hypothetical coordination mechanism.

This function is called exactly once for each appchain block considered.

A return value of `(ok true)` indicates that the block is valid for this
appchain, and should be accepted.  A return value of `(ok false)` indicates that
the block is invalid, and should be rejected.  A return value of `(err ...)`
will lead to a runtime panic, causing the node to log the error code and shut
down.

### `(run-sortition)`

This function is responsible for determining who wins an appchain block race,
if different from the default sortition algorithms described in SIP-001 and
SIP-007. The arguments represent the state of the sortition,
including the winner if one was selected.  The state is the height and hash
of the parent chain block, and the list of all
well-formed block-commit transaction data extracted from that block.  The 
block-commit data is given in the order they occur within the parent block.

The appchain uses this method to further constrain the rules for winning a
sortition, or even overrule it.  If the return value is `(ok (some (some x)))`, then
the enclosed `x` will be the index into the list of block-commit transactions
that _should_ be the winner, _even if_ it was not picked by the default
sortition algorithm.  If the return value is `(ok (some none))`, then the winner will
be determined by the default sortition algorithm.  If the return value is `(ok
none)`, then there is no winner for this sortition.  If the return value is
`(err ...)`, a runtime panic will occur, and the node will log the error code
and shut down.  If the value of `x` in the `(ok (some (some x)))` case is not a
valid index into the given list of block-commit transaction data,
then the node will also encounter a runtime panic.

### `(accept-tenure?)`

This function is called when the node has finished processing all state for the
tenure, but before it has been committed.  It is used by the appchain node to
make the final decision to accept or reject the transactions for this tenure,
now that it has seen them all.  It takes the appchain block height and hash and
the parent chain block height and hash as arguments, which uniquely identify the
tenure to consider.

This function returns `(ok true)` to accept the tenure's transactions, `(ok
false)` to reject them, and `(err ...)` to trigger a runtime panic.

### Invocation

The extension contract methods constitute the body of a validation state
machine.  They are evaluated in the following order when
processing each appchain miner tenure:

1. `(run-sortition)` is invoked once all valid block-commits are extracted
   from the parent chain, and the default sortition algorithm has been run on them to
determine what the default winner would be.  If `(run-sortition)` returns a
different winner than the default, then that block-commit will be chosen as the sortition winner
instead.  If this function returns `(ok none)`, then no further processing will
take place for this miner tenure.

2. `(validate-microblock)` is invoked on each of the parent microblocks of the
   winning appchain block from step 1.  `(validate-transaction)` is invoked for
each transaction within each microblock before moving on to the next microblock.
For example, if the winning appchain
block confirmed three microblocks _m1_, _m2_, _m3_, and each microblock had three transactions
_m[i].1_, _m[i].2_, _m[i].3_, then the following invocations occur:

   1. `(validate-microblock m1)`
   2. `(validate-transaction m1.1)`
   3. `(validate-transaction m1.2)`
   4. `(validate-transaction m1.3)`
   5. `(validate-microblock m2)`
   6. `(validate-transaction m2.1)`
   7. `(validate-transaction m2.2)`
   8. `(validate-transaction m2.3)`
   9. `(validate-microblock m3)`
   10. `(validate-transaction m3.1)`
   11. `(validate-transaction m3.2)`
   12. `(validate-transaction m3.3)`

   If any invocation of `(validate-microblock)` or `(validate-transaction)`
returns `(ok false)`, then miner tenure evaluation will stop and the
transactions in this tenure will all be rejected.

3. `(validate-block)` is invoked on the new appchain block.  `(validate-transaction)`
   is invoked on each of the transactions in the
   appchain block, in the order they were applied.  If this function returns `(ok
false)`, then processing stops for this tenure and the tenure transactions are
all rejected.

4. `(accept-tenure?)` is invoked with the appchain block and parent block's
   heights and block hashes, in order for the extension contract to make the
final decision on whether or not to accept this tenure.  If this function
returns `(ok false)`, then processing stops for this tenure and the tenure
transactions are all rejected.

5. `(mint-tokens!)` is invoked to determine how many appchain tokens to create,
   and to whom to grant them.  As with Stacks, the tokens will not be spendable
for the next 100 appchain blocks.

### Implementation Sketches

This section sketches the implementations of the `.extensions` contracts for the
aforementioned examples

### Multiplayer Game Sessions

A multiplayer game session appchain does not tolerate forks.  This can be
enforced by either the `(run-sortition)` function, which can reject
block-commits that have the same appchain height as a previously-seen
block-commit, or via `(validate-block)`, which can invalidate a block if it has
the same height (i.e. "total work") as a previously-seen block.

The system can enforce closed-membership round-robin mining by inspecting the
miner principal in `(validate-microblock)` and `(validate-block)` to ensure that
each player takes their turn at the right times. 

### Social Media Walls

A social media wall appchain would only permit blocks and microblocks
originating from a designated miner address to be valid.  Moreover, the
`.extensions` contract would keep a whitelisted list of friends' addresses, and
require that a transaction's origin account be present in this whitelist in
order to be valid.

### DAOs

A DAO appchain would keep a list of the DAO members' principals in its `.extensions`
contract.  If the DAO operates in a closed-membership manner, the
`(validate-block)` function would require that the block be produced by a
principal in this whitelist by checking the coinbase's `tx-sender`.  If the DAO
operates in an open-membership manner but wants to prevent transaction
censorship from miners, then the `.extensions` contract's
`(validate-transaction)` function would track all the block heights at which a
principal's transaction was seen, and require that if a transaction _T_ was
mined in height _B_, then it must be in all blocks at _B + e_ for some constant
_e_.

### Equity Tables

An equity table appchain would operate in a closed-membership manner, such that
each miner was a board member.  The `(validate-block)` function would require
that each block be produced by a multisig address that represents a voting
majority of the board seats, according to the company bylaws.

The `(validate-transaction)` function would only accept transactions with zero
fees.  Moreover, the `(validate-transaction)` function would not permit any
smart contracts from being instantiated, except from miners.  This way, only the
board members can update the rules for managing the token-backed equity.

The appchain would come with an extra boot contract that provided the
administrative interfaces for board members to vote on and grant equity to
employees, as well as interfaces for implementing equity lock-up periods,
vesting, and black-out dates.  This contract would additionally provide a
self-service API for employees to purchase, sell, or Stack their unlocked equity
units.

Reward cycles for this appchain could be structured to match the duration of a
fiscal quarter.  Each quarter, the board of directors would pay out dividends
via PoX to the reward set (which represents equity holders).  The dividends
themselves come from profits earned by the company; the board distributes them
through the mining protocol.

## Best Practices

The following are best practices to follow when building and operating an
appchain.  Following them is not mandatory for implementing this SIP. They are
provided here for informational purposes only.

### The `.extensions` Contract

The `.extensions` contract is expected to be stateful.
In order to apply the appchain's bespoke validation rules, each extension contract 
function is called in a read/write context, so that each function can store
bookkeeping state for making the ultimate accept/reject decision in
`(accept-tenure?)`.  Implementations are encouraged to store data passed to
these methods in the data space in order to expose that data back
to appchain smart contracts.

The `.extensions` contract is expected to provide public read-only functions for
querying data relating to its past decisions, so that other smart contracts in
the appchain can gain insight into what blocks and transactions have been
accepted or rejected.  This information would be used to supplement data returned by
the Clarity built-in function `(get-block-info?)` that is specific to this appchain.

### Mandatory Boot Code

Recall that the appchain uses the same Clarity VM as the Stacks chain, and it expects that
certain smart contracts are defined and provide the same interfaces.
The least error-prone way to make sure these contracts are included in the
appchain is to do the following:

1. Make copies these contracts' `.clar` files (they can be found in the Stacks
   blockchain reference implementation source tree).

2. Replace all usages of the STX-specific built-in functions and variables with
   the appchain token equivalents, subject to the appchain's `token-name` value
in the `appchain-config` data var in the mining contract.

3. Add the contract names to the `boot-code` list in the `appchain-config` data
   var in the mining contract in the expected order, subject to the appchain's
system epoch.

The source files for these contracts will need to be supplied to the first
appchain node when it boots up, along with the other appchain-specific boot
code.

### Mining Contract Administration

The `appchain-boot-nodes` data-var may need to be updated
from time to time.  The mining contract should provide a mechanism to do this,
if desired.  However, the specification of this mechanism is outside of the
scope of this SIP, since there are many possible useful mechanisms.  For
example, the contract could have a developer-only admin function for setting the
boot nodes.  As another example, the boot nodes could be inferred from state
within the appchain itself, and a merkle proof for that state could be written
to the mining contract that proves that the boot nodes for a particular appchain
block exist as of a particular appchain block-commit.

The mining contract is not limited to soring VRF key registrations and
block-commit metadata.  It could also implement a mining pool, an escrow
service, a two-way asset peg service, and so on.   However, these functions
are outside the scope of this SIP.

## Limitations

The following are a list of known limitations with this proposal which can be
corrected by the release of Stacks 2.1:

* Right now, the appchain node must trust the parent chain node to serve it the
  canonical block headers.  With the arrival of Stacks 2.1, it will become
possible to compare block header forks by determining which fork has the most
PoX anchor blocks selected without having to process the blockchain.
In Stacks 2.1, the canonical blockchain necessarily includes the most PoX anchor blocks, 
and each PoX anchor block can be deduced _solely_ by inspecting block-commits
in the prepare-phase (this is not the case in Stacks 2.05 and earlier).  With
this change, the appchain node can deduce the fork history of all its parent
chain's PoX anchor blocks and use it to identify the canonical blockchain: it is
the blockchain fork that includes the most PoX anchor blocks _and_ represents
the most economic activity of any such fork within the _current_ reward cycle.

Other fixable limitations that can be corrected by a subsequent SIP include:

* The deployment of an **appchain registry contract**.  Once there is a
  designated appchain registry contract, it will be possible to ensure that all
appchain chain IDs are globally unique, and it will be possible for the appchain
creator to publish the genesis state root hash.  Appchain nodes will not need to
assume that the chain ID is globally unique, nor will they need to obtain the
genesis state root hash out-of-band.

# Related Work 

TBD

# Backwards Compatibility

Not applicable

# Activation

# References

[1] https://github.com/stacksgov/sips/blob/main/sips/sip-001/sip-001-burn-election.md

[2] https://github.com/stacksgov/sips/blob/main/sips/sip-007/sip-007-stacking-consensus.md

[3] https://github.com/stacksgov/sips/blob/main/sips/sip-001/sip-001-burn-election.md#bitcoin-wire-formats

[4] https://github.com/stacksgov/sips/blob/main/sips/sip-002/sip-002-smart-contract-language.md

[5] https://github.com/stacksgov/sips/blob/main/sips/sip-003/sip-003-peer-network.md

[6] https://github.com/stacksgov/sips/blob/main/sips/sip-004/sip-004-materialized-view.md

[7] https://github.com/stacksgov/sips/blob/main/sips/sip-005/sip-005-blocks-and-transactions.md

[8] https://github.com/stacksgov/sips/blob/main/sips/sip-008/sip-008-analysis-cost-assessment.md

[9] https://github.com/stacksgov/sips/blob/main/sips/sip-012/sip-012-cost-limits-network-upgrade.md

[10] https://github.com/stacksgov/sips/blob/main/sips/sip-004/sip-004-materialized-view.md#marf-merkle-proofs

[11] https://github.com/stacksgov/sips/blob/main/sips/sip-001/sip-001-burn-election.md#leader-vrf-key-registrations

[12] https://github.com/stacksgov/sips/blob/main/sips/sip-001/sip-001-burn-election.md#leader-block-commit

[13] https://github.com/stacksgov/sips/blob/main/sips/sip-007/sip-007-stacking-consensus.md#stackstxop

[14] https://github.com/stacksgov/sips/blob/main/sips/sip-003/sip-003-peer-network.md#messages

[15] https://github.com/stacksgov/sips/blob/main/sips/sip-005/sip-005-blocks-and-transactions.md#transaction-encoding

[16] https://github.com/stacksgov/sips/blob/main/sips/sip-006/sip-006-runtime-cost-assessment.md

[17] https://github.com/stacksgov/sips/blob/main/sips/sip-012/sip-012-cost-limits-network-upgrade.md

[18] https://hirosystems.github.io/stacks-blockchain-api/#operation/get_core_api_info

[19] https://hirosystems.github.io/stacks-blockchain-api/#operation/get_contract_source
