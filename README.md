# Stacks Improvement Proposals (SIPs)

The SIPs describe the design, implementation, and governance
of the Stacks 2.0 blockchain.  The SIP process
([SIP-000](./sips/sip-000/sip-000-stacks-improvement-proposal-process.md))
describes how to make a SIP and get it ratified.  

Anyone in the Stacks community
may submit a SIP. The first step is to post a brief proposal in the
[SIP issue tracker](https://github.com/stacksgov/sips/issues).

## SIPs in the Process of Being Activated

* None

## Ratified SIPs

* [SIP-000](./sips/sip-000/sip-000-stacks-improvement-proposal-process.md): The
  Stacks Improvement Proposal Process
* [SIP-001](./sips/sip-001/sip-001-burn-election.md): Burn Election
* [SIP-002](./sips/sip-002/sip-002-smart-contract-language.md): The Clarity
  Smart Contract Language
* [SIP-003](./sips/sip-003/sip-003-peer-network.md): Stacks P2P Network
* [SIP-004](./sips/sip-004/sip-004-materialized-view.md): Cryptographic
  Commitment to Materialized Views
* [SIP-005](./sips/sip-005/sip-005-blocks-and-transactions.md): Blocks,
  Transactions, and Accounts
* [SIP-006](./sips/sip-006/sip-006-runtime-cost-assessment.md): Clarity Cost
  Execution Assessment
* [SIP-007](./sips/sip-007/sip-007-stacking-consensus.md): Stacking Consensus
* [SIP-008](./sips/sip-008/sip-008-analysis-cost-assessment.md): Clarity Parsing
  and Analysis Cost Assessment
* [SIP-009](./sips/sip-009/sip-009-nft-standard.md): Standard Trait Definition
  for Non-Fungible Tokens
* [SIP-010](./sips/sip-010/sip-010-fungible-token-standard.md): Standard Trait Definition for Fungible Tokens
* [SIP-012](./sips/sip-012/sip-012-cost-limits-network-upgrade.md):  Burn Height Selection for a Network Upgrade to Introduce New Cost-Limits
* [SIP-013](./sips/sip-013/sip-013-semi-fungible-token-standard.md):  Standard Trait Definition for Semi-Fungible Tokens
* [SIP-015](./sips/sip-015/sip-015-network-upgrade.md): Stacks Upgrade of Proof-of-Transfer and Clarity
* [SIP-016](./sips/sip-016/sip-016-token-metadata.md): Metadata for Tokens
* [SIP-018](./sips/sip-018/sip-018-signed-structured-data.md): Signed Structured Data
* [SIP-019](./sips/sip-019/sip-019-token-metadata-update-notifications.md): Notifications for Token Metadata Updates
* [SIP-020](./sips/sip-020/sip-020-bitwise-ops.md): Bitwise Operations in Clarity
* [SIP-021](./sips/sip-021/sip-021-nakamoto.md): Nakamoto: Fast and Reliable Blocks through PoX-assisted Block Propagation
* [SIP-022](./sips/sip-022/sip-022-emergency-pox-fix.md): Emergency Fix to PoX Stacking Increases
* [SIP-023](./sips/sip-023/sip-023-emergency-fix-traits.md): Emergency Fix to Trait Invocation Behavior
* [SIP-024](./sips/sip-024/sip-024-least-supertype-fix.md): Emergency Fix to Data Validation and Serialization Behavior
* [SIP-025](./sips/sip-025/sip-025-iterating-towards-weighted-schnorr-threshold-signatures.md): Iterating Towards WSTS
* [SIP-027](./sips/sip-027/sip-027-non-sequential-multisig-transactions.md): Non-sequential Multisig Transactions
* [SIP-028](./sips/sip-028/sip-028-sbtc_peg.md): Signer Criteria for sBTC, A Decentralized and Programmable Asset Backed 1:1 with BTC
* [SIP-029](./sips/sip-029/sip-029-halving-alignment.md): Bootstrapping sBTC Liquidity and Nakamoto Signer Incentives

## How to Get Involved

There are several ways you can get involved with the SIP process:

* **SIP Editor**.  SIP editors help SIP authors make sure their SIPs are
  well-formed and follow the right process.  They help get SIPs ready for deep
review by advancing it them from Draft to Accepted status.  If you want to become a SIP editor, 
open an issue with your name and email to ask to be added to the list of SIP editors.

* **Joining a Consideration Advisory Board**.  SIPs fall under the purview of
  one or more considerations, such as "technical," "economic," "governance,"
and so on.  A full list is in the `considerations/` directory.  Members of SIP
consideration advisory boards use their domain expertise to give Accepted SIPs a
deep read, and give the authors any/all feedback to help make the SIP workable.
If you want to join a board, reach out to the board's chairperson via the
listed contact information.

* **Creating a Consideration Advisory Board**.  Anyone can create a
consideration advisory board by opening a PR to create a new
consideration track, and SIP authors can opt to have you review their work by
adding your consideration to the SIP's list of considerations.  You are expected
to vote on such SIPs in a fair and timely manner if you start a board.

* **Steering Committee**.  The Steering Committee organizes the consideration
  advisory boards and votes to advance Recommended SIPs to
Activation-in-Progress status, and then to either Ratified or Rejected status.
Once they are in the process of being activated,
they use a SIP's Activation section to determine whether or not the Stacks
ecosystem has ratified or rejected the SIP.  Joining this committee requires the
consent of the Stacks Foundation board.
