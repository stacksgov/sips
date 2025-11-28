# Preamble

SIP Number: XXX  
Title: Standard for Multi-Party Agent Coordination  
Author: [Kwame Bryan] (<kwame.bryan@gmail.com>)  
Consideration: Technical  
Type: Standard  
Status: Draft  
Created: 28 November 2025  
Licence: CC0-1.0 (Creative Commons Zero v1.0 Universal)  
Sign-off: *(pending)*

# Abstract

This proposal introduces a standard primitive for secure coordination among multiple independent agents on the Stacks blockchain. It defines an **intent** message format and protocol by which an initiator posts a desired action (the intent) and other participants submit cryptographic acceptances. The intent becomes **executable** once all required participants have provided acceptance attestations before a specified expiry. This standard specifies the data structures, canonical status codes, Clarity contract interface, and rules needed to implement this coordination framework on Stacks. It leverages off-chain **signed structured data** (per SIP-018) and on-chain verification using Clarity’s cryptographic functions. By standardising multi-party approval workflows, SIP-XXX enables trust-minimised coordination in use cases such as multi-sig transactions, decentralised MEV mitigation strategies, and cross-contract agent actions, all using a common protocol.

# Licence and Copyright

This SIP is released under the terms of the **Creative Commons CC0 1.0 Universal** licence:contentReference[oaicite:17]{index=17}. By contributing to this SIP, authors agree to dedicate their work to the public domain. The Stacks Open Internet Foundation holds copyright for this document.

# Introduction

As decentralised applications and autonomous agents become more complex, there are many scenarios where a group of independent actors must agree on an action before it is executed. Examples include multi-signature wallet approvals, collaborative trades or arbitrage across DEXs, and MEV (Maximal Extractable Value) mitigation where solvers and bidders coordinate on transaction ordering. In current practice, these often rely on bespoke protocols or off-chain agreements, leading to fragmentation and potential security risks.

On Ethereum, the concept of *intents* has emerged to express desired actions in a chain-agnostic way, but earlier standards (like ERC-7521 and ERC-7683) handled only single-initiator flows:contentReference[oaicite:18]{index=18}. Ethereum’s recent ERC-8001 filled this gap by introducing a minimal coordination primitive for multiple parties:contentReference[oaicite:19]{index=19}. This SIP adapts ERC-8001’s approach to Stacks, taking into account Clarity’s design and existing SIPs (e.g. SIP-018 for signing data).

The key idea is that an initiator can propose an intent which enumerates all participants who need to agree. Each participant (including the initiator) produces a digital signature (an **acceptance attestation**) to confirm their agreement under certain conditions. These signatures are collected on-chain. If and only if every listed party’s attestation is present and valid within the allowed time window, the intent is marked as ready to execute. This guarantees that the intended action has unanimous approval from the required set of agents, without needing an off-chain coordinator to aggregate trust.

Privacy and advanced policies (like threshold k-of-n approvals, bond posting, or cross-chain intents) are intentionally **out of scope** for this base standard:contentReference[oaicite:20]{index=20}:contentReference[oaicite:21]{index=21}. The goal is to establish a simple, extensible on-chain core that other modules and protocols can build upon for added functionality.

# Specification

The keywords “MUST”, “SHOULD”, and “MAY” in this document are to be interpreted as described in RFC 2119.

## Status Codes

Implementations MUST use the following canonical status codes for each intent’s lifecycle state:contentReference[oaicite:22]{index=22}:

- `None` (`0`): No record of the intent (default state before proposal).
- `Proposed` (`1`): Intent has been proposed and stored, but not all required acceptances are yet present.
- `Ready` (`2`): **All participants have accepted.** The intent is fully signed and can be executed.
- `Executed` (`3`): Intent was executed successfully (finalised outcome).
- `Cancelled` (`4`): Intent was explicitly cancelled by the initiator and will not execute.
- `Expired` (`5`): Intent expired before execution.

A compliant contract MUST provide a read-only function (e.g. `get-coordination-status(intentId)`) that returns one of these status codes for a given intent. External tools and UI can use these codes to inform users of the intent’s state.

## Data Structures

**Agent Intent:** The core message posted by an initiator describing the coordination request. It is a tuple of fields:
- `payloadHash` (`buff 32`): A hash (e.g. SHA-256 or KECCAK256) of the detailed payload of the intent. The payload can include domain-specific instructions or data for execution, but is not interpreted by the core contract (opaque to this SIP).
- `expiry` (`uint`): A Unix timestamp (in seconds) by which the intent expires. The intent cannot be executed after this time. It MUST be set to a future time when proposing and is used to determine *Expired* status.
- `nonce` (`uint`): A monotonic sequence number for intents per initiator (agent). This provides replay protection – each new intent from the same agent MUST use a `nonce` greater than their previous intents’ nonces:contentReference[oaicite:23]{index=23}.
- `agentId` (`principal`): The Stacks principal of the initiator (the one proposing the intent). This principal must match the transaction sender that creates the intent on-chain.
- `coordinationType` (`buff 32`): An application-specific identifier for the type or context of this coordination. For example, it could be the hash of a string like `"MEV_SANDWICH_V1"` or `"MULTISIG_TXN"` to indicate how the payload should be interpreted by off-chain actors.
- `coordinationValue` (`uint`): An optional value field (e.g. an amount in micro-STX or an abstract value) that is informational for the core protocol. The core standard does not assign meaning to this field, but higher-level modules MAY use it (for example, to require a bond or to encode an expected payment amount).
- `participants` (`list(principal)`): The list of all participants’ principals involved in this intent, **including the initiator** (`agentId`). This list MUST be strictly ascending (sorted) by principal and contain no duplicates:contentReference[oaicite:24]{index=24}:contentReference[oaicite:25]{index=25}. Ordering the addresses canonically ensures everyone computes the same intent hash and prevents duplicate signers.

**Acceptance Attestation:** A participant’s acceptance of an intent. It is represented by:
- `intentHash` (`buff 32`): The hash of the Agent Intent that the participant is agreeing to. (See **Signature Semantics** below for how this hash is computed).
- `participant` (`principal`): The participant’s principal (the signer of this attestation).
- `nonce` (`uint`): An optional nonce for the acceptance. In the core standard, this MAY be omitted or set to `0` for simplicity. (In extended use, participants could use a personal nonce to prevent replay of their acceptance across different similar intents, but that is not required here).
- `expiry` (`uint`): The timestamp until which this acceptance is valid. This allows a participant to impose an earlier deadline than the intent’s overall expiry. The attestation is only valid to execute the intent if the current time is <= this expiry. Typically, participants set this equal to or slightly less than the intent’s `expiry` to ensure timely execution.
- `conditionsHash` (`buff 32`): A hash of any participant-specific conditions for their acceptance. This field is optional and not interpreted by the base contract logic. It might encode constraints like “price must be above X” or other domain-specific requirements that the participant expects to be true at execution. If no extra conditions, this can be a zero hash (all 0x00 bytes).
- `signature` (`buff 64/65`): The participant’s digital signature over the intent. This is the Secp256k1 ECDSA signature (65 bytes including recovery ID, or 64-byte compact form per EIP-2098) that proves the participant indeed signed the `intentHash` (and associated domain).

**Coordination Payload:** (Optional in core) The full data that `payloadHash` represents. The structure of this payload is outside the scope of SIP-XXX, as it is application-specific. However, by convention it could include fields like `version` (a format identifier), `coordinationType` (MUST equal the above type for redundancy), `coordinationData` (opaque binary or structured commands to execute), `conditionsHash` (the combined conditions for execution), `timestamp` (when the intent was created), and `metadata`. These are not processed by the core contract, but hashing them into `payloadHash` ensures that all participants are agreeing to the exact same details.

## Signature Semantics and Domain Separation

All signatures in this protocol MUST be made over a well-defined message that includes a domain separator specific to this SIP and the current contract:
- The initiator’s signature covers the **Agent Intent**. Off-chain, the initiator SHOULD sign a digest computed as `H = keccak256(domain, AgentIntent)` or similar, where `domain` binds the network (mainnet/testnet), the SIP number, and the contract address (including contract name):contentReference[oaicite:26]{index=26}. This prevents an intent for one contract or chain from being re-used on another. The contract’s Clarity code can reconstruct the expected `intentHash` on-chain to verify any signatures.
- Each participant’s **Acceptance Attestation** signature covers their `intentHash` plus their own constraints. In practice, a participant would sign a message encoding: the `intentHash` (linking to a specific intent), their `participant` address, optional `nonce`, `expiry`, and `conditionsHash`, along with the same domain separator. This yields a 32-byte hash that is then signed via Secp256k1.
- Clarity’s `secp256k1-verify` or `secp256k1-recover?` functions are used to verify these signatures on-chain. A compliant implementation MUST support 65-byte signatures with low-S values and SHOULD support 64-byte compact signatures:contentReference[oaicite:27]{index=27}. If a signature’s recovery byte is present, the contract will use it to recover the public key and derive the signing principal (via `principal-of?`); otherwise, the contract can verify directly given a provided public key.
- **Stacks Signed Message Prefix:** Implementations SHOULD prepend the standard `"Stacks Signed Message:\n"` prefix (as defined in SIP-018) when computing signature hashes for off-chain signing:contentReference[oaicite:28]{index=28}. However, since SIP-018 primarily covers personal messages, the use of a structured EIP-712-like approach with an explicit domain as described is RECOMMENDED for clarity and to avoid ambiguities.

By following these semantics, any signature collected under this standard is tightly bound to the specific intent and contract, mitigating replay attacks across contexts.

## Standard Contract Interface (Clarity)

An implementing smart contract MUST provide public functions roughly as follows (names are illustrative):

- `(define-public (propose-intent (intent <IntentType>)) (response (buff 32) uint))`  
  Creates a new intent on-chain. Accepts the intent fields (or a struct/tuple) as parameters. On success, stores the intent and returns a unique identifier (e.g. the `intentHash`). The function MUST verify that:
    - `intent.agentId` matches the `tx-sender` (only the initiator can propose their intent).
    - The `participants` list includes `agentId` and is sorted and without duplicates.
    - `intent.nonce` is strictly greater than the last used nonce for this `agentId` (to prevent reuse).
    - `intent.expiry` is in the future (greater than current time).
      If these checks pass, the intent is recorded (e.g. in a map from `intentHash` to intent data) with status `Proposed`:contentReference[oaicite:29]{index=29}. It also initialises tracking for acceptances (e.g. zero accepted count). If any check fails, it returns an error code and does not create the intent.
- `(define-public (accept-intent (intent-hash (buff 32)) (sig (buff 65)) [optional pubkey/fields])) (response bool uint))`  
  Records a participant’s acceptance for the given intent. The participant calling this function (`tx-sender`) is implicitly the accepting principal. The contract will:
    - Look up the intent by `intent-hash`. If not found, return an error (intent doesn’t exist).
    - Check that the intent’s status is `Proposed` (only accept if still gathering signatures).
    - Verify that `tx-sender` is indeed one of the intent’s `participants` and that they have not already accepted.
    - Verify the provided `sig` using `tx-sender`’s public key or by recovering it. The signature must be valid ECDSA over the expected acceptance message (containing `intentHash` and the participant’s constraints). If the contract requires the participant to also supply their `expiry` or `conditionsHash`, it must check those values too against what was signed.
    - Check that neither the intent nor the acceptance is expired at the current time.
      On success, the acceptance is recorded (e.g. mark this participant as having signed, increment a counter) and if this was the last required acceptance, update the intent’s status to `Ready`. The function returns `(ok true)` on success. If any verification fails, it returns an error code.
- `(define-public (execute-intent (intent-hash (buff 32)) (payload <PayloadType>)) (response bool uint))`  
  Marks a ready intent as executed. This would typically be called by a designated executor (which could be one of the participants or any party, depending on the use case) when it performs the action described in the intent’s payload. The contract MUST verify:
    - The intent exists and has status `Ready`.
    - The current time is <= intent’s expiry and all acceptance expiries (i.e., not too late to execute).
    - (Optionally, the provided `payload` matches the stored `payloadHash` to ensure the actual execution details correspond to what was agreed. Often the payload execution happens off-chain or in another contract, so this might not be applicable in every implementation.)
      On success, the contract sets the status to `Executed` and returns true. Typically, the actual business logic (transferring funds, etc.) is executed off-chain or by another contract that coordinates with this one — SIP-XXX’s reference implementation only handles the state change and verification, not the actual fulfilment of the intent’s action.
- `(define-public (cancel-intent (intent-hash (buff 32))) (response bool uint))`  
  Allows the initiator (and **only** the initiator) to cancel an intent that is not yet executed. This function:
    - Verifies `tx-sender` equals the intent’s `agentId`.
    - If the intent is still `Proposed` or `Ready` (i.e., not executed/expired), it sets status to `Cancelled`. (Once cancelled, any future accept or execute calls for that intent should fail.)
      Returns true on successful cancellation. Cancellation is useful if the initiator wants to abort the process (for example, if conditions changed or a mistake was made), even if some signatures have already been collected. Participants can also implicitly “cancel” by simply not signing, but this formal cancel allows reclaiming of resources or clearing intents.

- `(define-read-only (get-coordination-status (intent-hash (buff 32))) (response uint uint))`  
  Returns the current status code (0–5 as defined above) of the given intent, or an error if the intent is not found. This is used by off-chain clients or other contracts to poll the state of an intent.

The above interface is an example; the actual function names and parameters may vary, but any SIP-XXX compliant contract **MUST** provide equivalent functionality.

## Lifecycle Rules

An implementation of SIP-XXX MUST enforce the following lifecycle:

1. **Proposal:** An initiator calls `propose-intent` to register a new intent on-chain. Initially, its status is `Proposed`. At this point, no acceptances are present. The initiator’s signature on the intent (off-chain) is assumed by virtue of them calling the function (the transaction itself confirms their intent).
2. **Acceptance:** Each participant (including possibly the initiator, if the design requires a separate acceptance from them) calls `accept-intent` with their signature. These can happen in any order. The contract verifies each signature and records it. Participants MAY also provide their acceptance via an off-chain aggregator who then submits them in one transaction, but each acceptance must be individually verifiable on-chain. As acceptances come in, the contract may emit events or simply allow querying of how many acceptances are collected. When the final required acceptance is received, the contract SHOULD update the status to `Ready`.
3. **Execution:** Once an intent is `Ready`, it can be executed. Execution might be triggered by a call to `execute-intent`. In some designs, the same transaction that calls `execute-intent` could also carry out the intended action (e.g., via a payload or by triggering another contract, if the intent’s action is encoded in Clarity). The core contract itself does not mandate how the intent’s action is executed – it only tracks the state. After execution, the status becomes `Executed`. Only one execution is allowed; subsequent calls should be rejected or be no-ops.
4. **Cancellation:** At any time before execution (and before expiry), the initiator can cancel the intent, moving it to `Cancelled`. This halts the process and invalidates any collected signatures for that intent.
5. **Expiration:** If the current time passes the intent’s `expiry` (or any acceptance’s `expiry` if earlier), the intent is considered expired. A contract may implement this by not allowing execution after expiry and marking the status as `Expired` when queried. Expiration does not require an explicit transaction; it’s a state that arises from time passing. However, to be reflected on-chain (for example, if one wants to emit an event or prevent further actions), an explicit check is needed in functions like `accept-intent` and `execute-intent`. Once expired, an intent cannot reach `Ready` if it wasn’t already, and certainly cannot be executed. A new intent would have to be proposed if the parties still wish to proceed.

These rules ensure a coherent flow: intents move forward to execution or terminate via cancellation/expiry, but do not revert backwards in state.

## Backwards Compatibility

This SIP does not alter any existing Stacks consensus rules or contract standards. It is an additive standard. There is no direct predecessor in Stacks that it must remain compatible with (the concept is new to Stacks, though inspired by Ethereum).

One consideration: SIP-018 (Structured Data Signing) should be compatible with this SIP’s approach to ensure wallets and tools can sign the required messages. This proposal assumes SIP-018 or an equivalent is available to provide the signing prefix and domain as needed.

## Security Considerations

**Replay Prevention:** By using initiator-specific nonces for intents and including the contract’s identity in the signed message, this protocol prevents signatures from one context being reused in another:contentReference[oaicite:30]{index=30}. Each initiator’s `nonce` ensures they (and their wallet software) won’t accidentally reuse an intent message, and domain separation (SIP number, contract address, chain id) ensures an intent on Stacks mainnet contract “X” cannot be executed on a testnet or a different contract “Y”.

**Signature Verification and Malleability:** Implementations must use Clarity’s crypto functions correctly to avoid accepting forged signatures. Only acceptances that produce a valid recoverable public key matching the participant’s address should be counted. Low-S requirement (as enforced by most Secp256k1 libraries) should be ensured:contentReference[oaicite:31]{index=31} – if using `secp256k1-verify`, it returns false for high-S signatures, and if using recovery, the contract should reject any signature that does not pass verification. Both 64-byte and 65-byte signatures should be accepted to accommodate different wallet implementations (per EIP-2098 compressed form).

**Timeliness (Expiry):** The expiry mechanism is crucial for safety. Without expiries, an old intent could linger and potentially be executed much later under different conditions, or a participant’s acceptance could be “banked” and used when they no longer intend. By expiring intents, we limit this risk. However, note that the contract cannot automatically remove an expired intent without a transaction; it can only prevent further actions. It is up to clients or a scheduled off-chain service to clean up or notify about expired intents. Parties should choose reasonable expiry times – long enough to gather signatures and execute, but short enough to limit risk exposure.

**Partial Signatures / Equivocation:** The protocol does not stop a malicious participant from signing multiple intents (equivocation) hoping only one gets executed. If a participant does so and two intents both become ready, an executor might waste resources preparing both. This is an application-level concern; modules can add penalties or reputation tracking to discourage such behaviour:contentReference[oaicite:32]{index=32}. The core simply treats each intent separately. It is RECOMMENDED that when this standard is used in economic protocols, there are additional incentives (like slashing or deposits) to align participants’ behaviour.

**Front-Running and MEV:** Because intents in this standard are posted on-chain in a public contract, a malicious observer could potentially see a `Proposed` intent and attempt to front-run the eventual action. However, since the intent can only be executed with all signatures and after a certain time, the window for exploitation is limited. For greater privacy, participants might delay broadcasting their acceptances until execution is imminent, or use a commit-reveal scheme where only hashes of signatures are posted initially. Those techniques are outside SIP-XXX’s scope but can be layered on. In environments with high MEV risk, consider encrypting the payload off-chain and only revealing it at execution time:contentReference[oaicite:33]{index=33}.

## Reference Implementation

A reference implementation of this standard is provided in the accompanying file: [`contracts/agent-coordination.clar`](contracts/agent-coordination.clar). This Clarity contract illustrates one way to realise SIP-XXX. It uses:
- A map to store proposed intents (keyed by a 32-byte intent hash).
- A map to track each initiator’s latest nonce (to enforce monotonic nonces).
- Functions `propose-intent`, `accept-intent`, `cancel-intent`, `execute-intent`, and getters for status, closely following the interface described above.
- Signature verification via `secp256k1-recover?` to derive the signer’s public key and then `principal-of?` to get the corresponding principal, which is compared to the claimed participant.
- Checks for sorted participants and expiry conditions.

Developers can refer to this implementation as a starting point for their own contracts. Note that depending on the use case, you may need to adjust data types (e.g. use SHA-256 instead of KECCAK, or handle different payload schemas). The reference code is provided under CC0 licence for maximum reuse.
