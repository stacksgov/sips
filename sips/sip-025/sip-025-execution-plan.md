# Preamble

SIP Number: 

Title: Optimistic Dynamic Dispatch and Execution Plan Commitment

Author: Ludo Galabru ([ludovic@hiro.so](mailto:ludovic@hiro.so))

Consideration: Technical

Type: Consensus

Status: Draft

Created: March 19 2024

License: CC0-1.0

Sign-off: 

Layer: Clarity VM, Wire Format, RPC Endpoint

# Abstract

Dynamic Dispatch is a pattern that developers can utilize in their smart contracts to enable routing of contract calls at runtime. This routing directs the calls to contracts deployed on the Stacks blockchain subsequent to the initial deployment of the smart contract. This is in contrast to Static Dispatch, where contract IDs are hard-coded into the contract.

In the Clarity 1 and Clarity 2 implementations, the **`contract-call?`** function can be only be use with a contract ID coming from the list of arguments signed by the transaction author.

This SIP reevaluates the existing approach and proposes a new design that gives developers more freedom in assembling their execution plan (a set of dynamic contract IDs to invoke), while also providing users with a method to verify, after execution, that the executed plan matches with what they committed to.

Consequently, if the execution plan changes between the time a user signs and broadcasts their transaction and the time the transaction is executed, the said transaction would be rolled back, similar to a rollback triggered by a post-condition failure.

The concept of Optimistic Dynamic Dispatch is defined as follows: by default, the smart contract is trusted to correctly route the contract calls. Additionally, a mechanism is provided for users to have the transaction rolled back if the execution ends up incorporating components that were not initially specified.

# **License and Copyright**

This SIP is made available under the terms of the Creative Commons CC0 1.0 Universal license, available at https://creativecommons.org/publicdomain/zero/1.0/ 

This SIP's copyright is held by the Stacks Open Internet Foundation.

# **Specification**

The novel post conditions mechanism introduced in Stacks 2.0 is being utilized to design optimistic dynamic dispatch. 

## Execution Plan Commitment Usage

### Augmenting Transaction Wire Format

Users can require an execution plan commitment in the post conditions:

```markdown
A 1-byte post-condition mode, identifying whether or not post-conditions must fully cover all transferred assets. It can take the following values:
- 0x01 (existing): This transaction may affect other assets not listed in the post-conditions.
- 0x02 (existing): This transaction may NOT affect other assets besides those listed in the post-conditions.
- 0x03 (new): This transaction may follow a constrained execution plan.
```

### Augmenting Transaction Receipts

During the execution of a contract-call transaction, the Clarity VM builds a tree of the different contracts and public methods invoked.

All the branches of this tree are collected, hashed and added in their order of execution in a Merkle Tree. The Merkle Root constitute the Execution Plan Commitment that users can incorporate in their transactions post conditions.

### Augmenting HTTP Endpoint `/v2/contracts/call-read`

In order to help users computing an execution plan commitment, the JSON response of the existing HTTP endpoint `/v2/contracts/call-read/` can be augmented to return:

```json
{
  "okay":true,
	"execution_plan_commitment": "0x607b5e64b8d51f78ac5a37984e64f6493e9a7f90b605fa068be86ff035f48141"
}
```

This HTTP endpoint must also be able to execute any kind of function `readonly` , but also `readwrite` simulating writes to an in-memory store.

### Augmenting Post conditions checks

Upon successful execution of a contract call, the post-condition logic must be updated to handle the new variant `ExecutionPlanCommitment`, and to rollback the transaction if the Merkle Root of the executed contract turns out to be different from the one specified by the user.

### Relax Dynamic Dispatch Constraints

The implementation of traits is a complex and specific case in the Clarity typing and value variants system. Relaxing all the constraints currently present in the codebase would greatly simplify the implementation.

This needs further exploration, but it is possible that the trait variant logic could be removed from the Clarity 3 codebase.

## Example

Assuming a Contract call leading to the following call graph execution:

```clarity
  ;; Transaction entrypoint, user is swapping u1000 token-a with u500 token-b
  (contract-call? 'SP..01.swap swap-tokens u1000 'SP..1a.token-a u500 'SP..1b.token-b)

      ;; SP..01.swap::swap-tokens is internally calling `SP..1a.token-a` contract 
      ;; The swap contract debits u1000 token-a from tx-sender's balance
      (contract-call? 'SP..1a.token-a transfer u1000 tx-sender 'SP..01.swap)
          // SP..1a.token-a is a centralized token highly scrutinized by the SEC
          // with business logic evolving over time and regulations.
          // The method (get-check-ban-list-contract) returns 'SP..1a.check-ban-list-v1
          // The method (get-storage-contract) returns 'SP..1a.token-storage-v1
          // It internally calls both `SP..1a.check-ban-list-v1` and `SP..1a.token-storage-v1` contract
          (contract-call? (get-check-ban-list-contract) check-address tx-sender)
          (contract-call? (get-check-ban-list-contract) check-address 'SP..01.swap)
          (contract-call? (get-storage-contract) transfer-tokens u1000 tx-sender 'SP..01.swap)

      ;; After successfully performing the previous contract call, 
      ;; SP..01.swap::swap-tokens is internally calling `SP..1b.token-b` contract.
      ;; The swap contract credits tx-sender's balance with u500 token-b
      (contract-call? 'SP..1b.token-b transfer u500 'SP..01.swap tx-sender)
          // SP..1b.token-b is a meme, simple, yolo-style SIP10 token
          // It internally performs a static dispatch
          (contract-call? 'SP..1b.token-storage transfer-tokens u1000 tx-sender 'SP..01.swap)

```



During the execution, all the contract calls (static, dynamic and optimistic) are being collected, and attached to the transaction receipt:

```clarity
(list
  'SP..01.swap::swap-tokens                         ;; Transaction entrypoint
  'SP..1a.token-a::transfer                         ;; Dynamic dispatch
  'SP..1a.check-ban-list-v1::check-address          ;; Optimistic dispatch
  'SP..1a.check-ban-list-v1::check-address          ;; Optimistic dispatch
  'SP..1a.SP..1a.token-storage-v1::transfer-tokens  ;; Optimistic dispatch
  'SP..1b.token-b::transfer                         ;; Dynamic dispatch
  'SP..1b.token-storage::transfer-tokens            ;; Static dispatch
)
```

Each element (contract-id, method) of the set is hashed and placed in a merkle tree.
The merkle root of this tree is referred as a `Execution Plan Commitment` in this document.

When an optimistic dispatch is present in a contract-call execution trace, the transaction MUST include a commitment matching the merkle root computed during the execution for the transaction to be valid. 

# Motivations

Smart contracts, which are self-executing agreements written in code, can sometimes have bugs or vulnerabilities. These issues can lead to significant problems, especially when they affect critical operations or secure large sums of money. To help developers manage these challenges, a new feature involving proxy contracts has been introduced.

Proxy contracts act as a stable front-facing interface for users and other developers, providing a consistent address to interact with. Behind this interface, the actual business logic of the smart contract (the implementation contract) can be updated or upgraded as needed. This setup is crucial for fixing bugs or improving the contract's functionality over time without disrupting the service for users or the integrations built by other developers.

In the context of working with critical partners, especially those operating bridges between different blockchains or managing large amounts of liquidity, contract upgradability becomes a vital feature. This is because errors in these high-stakes environments can propagate across multiple blockchains, leading to extensive financial and operational damage. Thus, having the flexibility to upgrade contracts to address potential issues quickly is a key requirement for maintaining robust and secure blockchain ecosystems.