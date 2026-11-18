# Preamble

SIP Number: 041

Title: Standard Trait Definition for Agent Registries

Author(s):
- AIBTC <build@aibtc.dev>
- Tony <@tony1908>
- Jason Schrader <jason@joinfreehold.com>

Consideration: Technical

Type: Standard

Status: Draft

Created: 2026-01-01

License: CC0-1.0

Sign-offs:

Layer: Traits

Discussions-To:
- SIP pull request: https://github.com/stacksgov/sips/pull/258

# Abstract

This SIP defines a standard set of traits for AI agent registries on the Stacks blockchain. It establishes three core registries: an Identity Registry implementing the SIP-009 NFT trait for agent registration and ownership, a Reputation Registry supporting signed value scoring with WAD normalization and three authorization paths (permissionless, on-chain approval, SIP-018 signed), and a Validation Registry enabling progressive third-party verification responses. The Identity Registry includes an agent wallet system via reserved metadata keys, enabling agents to control their own wallets separate from owner accounts. These traits enable interoperable agent identity, reputation tracking, and validation across applications built on Stacks, while maintaining compatibility with the ERC-8004 Agent Commerce Protocol for cross-chain agent identity.

# Copyright

This SIP is made available under the terms of the Creative Commons CC0 1.0 Universal license, available at https://creativecommons.org/publicdomain/zero/1.0/. This SIP's copyright is held by the Stacks Open Internet Foundation.

# Introduction

As AI agents become increasingly prevalent in blockchain ecosystems, there is a need for standardized on-chain identity, reputation, and validation mechanisms. Without common standards, each application must implement its own agent management system, leading to fragmentation and preventing agents from building portable reputations across platforms.

This SIP addresses three core requirements for agent commerce:

1. **Identity**: Agents need unique, verifiable identities with associated metadata and URIs pointing to off-chain information. By implementing the SIP-009 NFT trait, agent identities gain standard wallet visibility, explorer integration, and transfer event tracking. The registry also supports an agent wallet system through reserved metadata keys, enabling agents to control separate wallets from their owner accounts—agents can prove wallet ownership via transaction signatures (tx-sender) or owners can provide SIP-018 signatures to update the wallet.

2. **Reputation**: Clients interacting with agents need a way to provide feedback and view aggregated reputation scores using signed values (integer value + decimals 0-18) that support negative feedback and high-precision ratings. The feedback system operates permissionlessly by default (no pre-approval required), with self-feedback blocked via cross-contract authorization checks. Agents can optionally enable on-chain approval or accept SIP-018 signed feedback, providing three distinct authorization paths to balance openness with control.

3. **Validation**: Third-party validators (such as auditors, compliance services, or capability verifiers) need a standardized way to approve or reject agents based on specific criteria. The validation system supports progressive responses, allowing validators to submit multiple updates per request (e.g., preliminary → final scores) following a soft-to-hard finality workflow without monotonic constraints.

The Stacks blockchain's programming language, Clarity, provides built-in primitives for defining traits that allow different smart contracts to interoperate. This SIP defines traits for agent registries that any compliant implementation must follow, enabling wallets, applications, and other contracts to interact with agent registries in a consistent manner.

This standard is designed to be compatible with ERC-8004, enabling cross-chain agent identity using the CAIP-2 multichain identifier format.

# Specification

The agent registry standard consists of three separate traits, each addressing a distinct aspect of agent management. Implementations may deploy these as separate contracts or combine them as appropriate.

**Trait Design Note:** Clarity traits can only enforce function signatures that return `(response ...)` types. Each trait below includes only public state-changing functions and response-wrapped read-only functions. Read-only functions returning raw types (optionals, tuples, bools, strings) cannot be enforced by traits but are still required in implementation contracts and are documented in the function listings.

## Identity Registry Trait

The Identity Registry manages agent registration, ownership, and metadata. It implements the SIP-009 NFT trait, providing standard wallet and explorer compatibility while maintaining sequential agent ID assignment and cross-contract authorization checks.

### Trait Functions

#### Register

`(register () (response uint uint))`

Register a new agent with an empty URI. Returns the newly assigned agent ID as an unsigned integer. Agent IDs are assigned sequentially starting from 0.

This method must be defined with `define-public`.

#### Register with URI

`(register-with-uri ((token-uri (string-utf8 512))) (response uint uint))`

Register a new agent with the specified URI. The URI should point to a JSON metadata file describing the agent. Returns the newly assigned agent ID.

This method must be defined with `define-public`.

#### Register Full

`(register-full ((token-uri (string-utf8 512)) (metadata-entries (list 10 {key: (string-utf8 128), value: (buff 512)}))) (response uint uint))`

Register a new agent with both a URI and initial metadata entries. The metadata entries allow storing up to 10 key-value pairs directly on-chain. The reserved key "agentWallet" cannot be included in metadata entries; the agent wallet is automatically set to the owner on registration. Returns the newly assigned agent ID.

This method must be defined with `define-public`.

| error code | reason |
| ---------- | ------ |
| u1003 | Metadata set operation failed |
| u1004 | Reserved key (agentWallet cannot be set during registration) |

#### Set Agent URI

`(set-agent-uri ((agent-id uint) (new-uri (string-utf8 512))) (response bool uint))`

Update the URI for an existing agent. Only the agent owner or an approved operator may call this function.

This method must be defined with `define-public`.

| error code | reason |
| ---------- | ------ |
| u1000 | Caller is not authorized (not owner or approved operator) |
| u1001 | Agent with specified ID does not exist |

#### Set Metadata

`(set-metadata ((agent-id uint) (key (string-utf8 128)) (value (buff 512))) (response bool uint))`

Set or update a metadata key-value pair for an agent. Only the agent owner or an approved operator may call this function. The reserved key "agentWallet" cannot be set via this function; use the agent wallet functions instead.

This method must be defined with `define-public`.

| error code | reason |
| ---------- | ------ |
| u1000 | Caller is not authorized |
| u1001 | Agent does not exist |
| u1003 | Metadata set operation failed |
| u1004 | Reserved key (agentWallet cannot be set directly) |

#### Set Approval for All

`(set-approval-for-all ((agent-id uint) (operator principal) (approved bool)) (response bool uint))`

Grant or revoke operator permissions for a specific agent. An approved operator can perform actions on behalf of the agent owner, such as updating URIs and metadata.

This method must be defined with `define-public`.

| error code | reason |
| ---------- | ------ |
| u1000 | Caller is not authorized |
| u1001 | Agent does not exist |

#### Owner Of

`(owner-of ((agent-id uint)) (optional principal))`

Return the owner principal of the specified agent, or none if the agent does not exist. This is a legacy function; prefer using get-owner for SIP-009 compatibility.

This method should be defined as read-only, i.e. `define-read-only`.

#### Get URI

`(get-uri ((agent-id uint)) (optional (string-utf8 512)))`

Return the URI associated with the specified agent, or none if not set or agent does not exist.

This method should be defined as read-only, i.e. `define-read-only`.

#### Get Metadata

`(get-metadata ((agent-id uint) (key (string-utf8 128))) (optional (buff 512)))`

Return the value for a specific metadata key, or none if the key is not set or agent does not exist.

This method should be defined as read-only, i.e. `define-read-only`.

#### Is Approved for All

`(is-approved-for-all ((agent-id uint) (operator principal)) bool)`

Check if the specified principal is an approved operator for the agent. Returns false if agent does not exist.

This method should be defined as read-only, i.e. `define-read-only`.

#### Get Version

`(get-version () (string-utf8 8))`

Return the contract version string.

This method should be defined as read-only, i.e. `define-read-only`.

#### Get Last Token ID

`(get-last-token-id () (response uint uint))`

Return the ID of the most recently registered agent. This is a SIP-009 NFT trait function.

This method should be defined as read-only, i.e. `define-read-only`.

| error code | reason |
| ---------- | ------ |
| u1001 | No agents have been registered yet |

#### Get Token URI

`(get-token-uri ((token-id uint)) (response (optional (string-utf8 512)) uint))`

Return the URI for the specified token ID (agent ID). Returns none wrapped in an ok response if the URI is empty or token doesn't exist. This is a SIP-009 NFT trait function.

This method should be defined as read-only, i.e. `define-read-only`.

#### Get Owner

`(get-owner ((token-id uint)) (response (optional principal) uint))`

Return the owner principal for the specified token ID (agent ID). Returns none wrapped in an ok response if the token doesn't exist. This is a SIP-009 NFT trait function that complements the legacy owner-of function.

This method should be defined as read-only, i.e. `define-read-only`.

#### Transfer

`(transfer ((token-id uint) (sender principal) (recipient principal)) (response bool uint))`

Transfer agent identity NFT from sender to recipient. Only the token owner can initiate transfers, and tx-sender must equal the sender parameter. Clears agent-wallet on transfer to prevent stale wallet associations. This is a SIP-009 NFT trait function.

This method must be defined with `define-public`.

| error code | reason |
| ---------- | ------ |
| u1000 | Caller is not authorized (sender is not the token owner) |
| u1001 | Agent does not exist |
| u1005 | Invalid sender (tx-sender must equal sender parameter) |

#### Get Agent Wallet

`(get-agent-wallet ((agent-id uint)) (optional principal))`

Return the agent wallet principal for the specified agent, or none if not set. The agent wallet is a reserved metadata key that allows agents to control a separate wallet from their owner account.

This method should be defined as read-only, i.e. `define-read-only`.

#### Set Agent Wallet Direct

`(set-agent-wallet-direct ((agent-id uint)) (response bool uint))`

Set the agent wallet to tx-sender. Requires caller to be authorized (owner or approved operator). The wallet proves ownership via transaction signature. Returns error if tx-sender is already the current wallet.

This method must be defined with `define-public`.

| error code | reason |
| ---------- | ------ |
| u1000 | Caller is not authorized |
| u1001 | Agent does not exist |
| u1006 | Wallet already set to this principal |

#### Set Agent Wallet Signed

`(set-agent-wallet-signed ((agent-id uint) (new-wallet principal) (deadline uint) (signature (buff 65))) (response bool uint))`

Set agent wallet using SIP-018 signature from the new wallet principal. Requires caller to be authorized (owner or approved operator). The signature must be valid and deadline must be current block height or future (within MAX_DEADLINE_DELAY of 1500 blocks).

This method must be defined with `define-public`.

| error code | reason |
| ---------- | ------ |
| u1000 | Caller is not authorized |
| u1001 | Agent does not exist |
| u1007 | Expired signature (deadline passed or exceeds MAX_DEADLINE_DELAY) |
| u1008 | Invalid signature (recovery failed or doesn't match new-wallet) |

#### Unset Agent Wallet

`(unset-agent-wallet ((agent-id uint)) (response bool uint))`

Remove the agent wallet association. Requires caller to be authorized (owner or approved operator).

This method must be defined with `define-public`.

| error code | reason |
| ---------- | ------ |
| u1000 | Caller is not authorized |
| u1001 | Agent does not exist |

#### Is Authorized or Owner

`(is-authorized-or-owner ((spender principal) (agent-id uint)) (response bool uint))`

Check if the specified principal is either the owner or an approved operator for the agent. Used for cross-contract authorization checks (e.g., reputation registry self-feedback prevention).

This method should be defined as read-only, i.e. `define-read-only`.

| error code | reason |
| ---------- | ------ |
| u1001 | Agent does not exist |

### Identity Registry Trait Implementation

```clarity
;; title: identity-registry-trait
;; version: 2.0.0
;; summary: Trait definition for ERC-8004 Identity Registry
;; description: Defines the interface for identity registry contracts. Includes all public state-changing functions and response-wrapped read-only functions (SIP-009 + is-authorized-or-owner).

(define-trait identity-registry-trait
  (
    ;; Registration functions
    (register () (response uint uint))
    (register-with-uri ((string-utf8 512)) (response uint uint))
    (register-full ((string-utf8 512) (list 10 {key: (string-utf8 128), value: (buff 512)})) (response uint uint))

    ;; Metadata management
    (set-agent-uri (uint (string-utf8 512)) (response bool uint))
    (set-metadata (uint (string-utf8 128) (buff 512)) (response bool uint))

    ;; Approval management
    (set-approval-for-all (uint principal bool) (response bool uint))

    ;; Agent wallet management
    (set-agent-wallet-direct (uint) (response bool uint))
    (set-agent-wallet-signed (uint principal uint (buff 65)) (response bool uint))
    (unset-agent-wallet (uint) (response bool uint))

    ;; NFT transfer (SIP-009)
    (transfer (uint principal principal) (response bool uint))

    ;; SIP-009 trait functions (response-wrapped read-only)
    (get-last-token-id () (response uint uint))
    (get-token-uri (uint) (response (optional (string-utf8 512)) uint))
    (get-owner (uint) (response (optional principal) uint))

    ;; Authorization helper (response-wrapped read-only)
    (is-authorized-or-owner (principal uint) (response bool uint))
  )
)
```

## Reputation Registry Trait

The Reputation Registry enables clients to provide feedback on agents and allows agents to respond. It supports two authorization methods: on-chain approval and SIP-018 [1] signed structured data for off-chain authorization.

### Trait Functions

#### Approve Client

`(approve-client ((agent-id uint) (client principal) (index-limit uint)) (response bool uint))`

Pre-authorize a client to provide feedback for an agent up to the specified index limit. Only the agent owner or approved operator may call this function. This enables rate-limited, on-chain approval for trusted clients.

This method must be defined with `define-public`.

| error code | reason |
| ---------- | ------ |
| u3000 | Caller is not authorized |

#### Give Feedback (Permissionless)

`(give-feedback ((agent-id uint) (value int) (value-decimals uint) (tag1 (string-utf8 64)) (tag2 (string-utf8 64)) (endpoint (string-utf8 512)) (feedback-uri (string-utf8 512)) (feedback-hash (buff 32))) (response uint uint))`

Submit feedback for an agent without prior authorization. Anyone may submit feedback except the agent owner or approved operators (self-feedback is blocked). The value is a signed integer with decimals 0-18 for high-precision ratings (WAD-normalized in summaries). Tags provide categorical labels. The endpoint is emit-only (for off-chain routing), while feedback-uri and feedback-hash provide content verification. Returns the feedback index.

This method must be defined with `define-public`.

| error code | reason |
| ---------- | ------ |
| u3001 | Agent does not exist |
| u3005 | Cannot provide feedback on self |
| u3011 | Invalid decimals (exceeds 18) |

#### Give Feedback (Approved)

`(give-feedback-approved ((agent-id uint) (value int) (value-decimals uint) (tag1 (string-utf8 64)) (tag2 (string-utf8 64)) (endpoint (string-utf8 512)) (feedback-uri (string-utf8 512)) (feedback-hash (buff 32))) (response uint uint))`

Submit feedback with on-chain approval via `approve-client`. The client must have been pre-authorized with an index limit greater than or equal to the next feedback index. Self-feedback is blocked. Returns the feedback index.

This method must be defined with `define-public`.

| error code | reason |
| ---------- | ------ |
| u3001 | Agent does not exist |
| u3005 | Cannot provide feedback on self |
| u3009 | Index limit exceeded |
| u3011 | Invalid decimals (exceeds 18) |

#### Give Feedback (Signed)

`(give-feedback-signed ((agent-id uint) (value int) (value-decimals uint) (tag1 (string-utf8 64)) (tag2 (string-utf8 64)) (endpoint (string-utf8 512)) (feedback-uri (string-utf8 512)) (feedback-hash (buff 32)) (signer principal) (index-limit uint) (expiry uint) (signature (buff 65))) (response uint uint))`

Submit feedback using SIP-018 signed authorization. The signer must be the agent owner or approved operator, and must sign a structured data message containing agent-id, client (tx-sender), index-limit, and expiry. The signature is verified using secp256k1 recovery. Self-feedback is blocked. Returns the feedback index.

This method must be defined with `define-public`.

| error code | reason |
| ---------- | ------ |
| u3000 | Signer is not authorized |
| u3001 | Agent does not exist |
| u3005 | Cannot provide feedback on self |
| u3007 | Signature verification failed |
| u3008 | Authorization has expired |
| u3009 | Index limit exceeded |
| u3011 | Invalid decimals (exceeds 18) |

#### Revoke Feedback

`(revoke-feedback ((agent-id uint) (index uint)) (response bool uint))`

Revoke previously submitted feedback. Only the original feedback submitter (tx-sender) may revoke their own feedback. Revoked feedback is excluded from summary aggregations.

This method must be defined with `define-public`.

| error code | reason |
| ---------- | ------ |
| u3002 | Feedback entry not found |
| u3003 | Feedback already revoked |
| u3006 | Invalid index (must be > 0) |

#### Append Response

`(append-response ((agent-id uint) (client principal) (index uint) (response-uri (string-utf8 512)) (response-hash (buff 32))) (response bool uint))`

Allow anyone to respond to feedback. Multiple responders can respond to the same feedback entry, and each responder can respond multiple times (tracked via response-count). The response-uri must not be empty.

This method must be defined with `define-public`.

| error code | reason |
| ---------- | ------ |
| u3002 | Feedback entry not found |
| u3006 | Invalid index (must be > 0) |
| u3010 | Response URI is empty |

#### Read Feedback

`(read-feedback ((agent-id uint) (client principal) (index uint)) (optional {value: int, value-decimals: uint, wad-value: int, tag1: (string-utf8 64), tag2: (string-utf8 64), is-revoked: bool}))`

Retrieve a specific feedback entry. Returns none if the feedback does not exist. The wad-value field contains the WAD-normalized (18 decimals) value for O(1) aggregation.

This method should be defined as read-only, i.e. `define-read-only`.

#### Get Summary

`(get-summary ((agent-id uint)) {count: uint, summary-value: int, summary-value-decimals: uint})`

Returns O(1) aggregate metrics using running totals. All feedback values are normalized to WAD (18 decimals) for averaging. The summary-value is the average WAD-normalized value, and summary-value-decimals is always u18. Returns {count: u0, summary-value: 0, summary-value-decimals: u18} if no feedback exists. For filtered aggregations (by client/tag), use SIP-019 indexer.

This method should be defined as read-only, i.e. `define-read-only`.

#### Read All Feedback

`(read-all-feedback ((agent-id uint) (opt-tag1 (optional (string-utf8 64))) (opt-tag2 (optional (string-utf8 64))) (include-revoked bool) (opt-cursor (optional uint))) {items: (list 14 {client: principal, index: uint, value: int, value-decimals: uint, wad-value: int, tag1: (string-utf8 64), tag2: (string-utf8 64), is-revoked: bool}), cursor: (optional uint)})`

Retrieve feedback entries for an agent using cursor-based pagination (PAGE_SIZE=14). Uses global feedback sequence for cross-client iteration. Tag filters are optional (none matches all). Returns {items: (list 14 {...}), cursor: (optional uint)} where cursor is some(offset) if more results exist. Items include wad-value field for WAD-normalized values.

This method should be defined as read-only, i.e. `define-read-only`.

#### Get Last Index

`(get-last-index ((agent-id uint) (client principal)) uint)`

Get the last feedback index submitted by a client for an agent. Returns u0 if no feedback has been submitted.

This method should be defined as read-only, i.e. `define-read-only`.

#### Get Agent Feedback Count

`(get-agent-feedback-count ((agent-id uint)) uint)`

Get the total number of feedback entries for an agent across all clients. Returns the last global index, or u0 if no feedback exists. This is the global feedback sequence counter.

This method should be defined as read-only, i.e. `define-read-only`.

#### Get Clients

`(get-clients ((agent-id uint) (opt-cursor (optional uint))) {clients: (list 14 principal), cursor: (optional uint)})`

Get clients who have given feedback for an agent using cursor-based pagination (PAGE_SIZE=14). Returns {clients: (list 14 principal), cursor: (optional uint)} where cursor is some(offset) if more results exist.

This method should be defined as read-only, i.e. `define-read-only`.

#### Get Approved Limit

`(get-approved-limit ((agent-id uint) (client principal)) uint)`

Get the approved index limit for a client. Returns u0 if no approval exists.

This method should be defined as read-only, i.e. `define-read-only`.

#### Get Response Count Single

`(get-response-count-single ((agent-id uint) (client principal) (index uint) (responder principal)) uint)`

Get the response count for a specific responder on a specific feedback entry. Returns u0 if no responses exist. This is a legacy function kept for backwards compatibility; prefer get-response-count for flexible querying.

This method should be defined as read-only, i.e. `define-read-only`.

#### Get Response Count

`(get-response-count ((agent-id uint) (opt-client (optional principal)) (opt-feedback-index (optional uint)) (opt-responders (optional (list 200 principal))) (opt-cursor (optional uint))) {total: uint, cursor: (optional uint)})`

Flexible response counting with optional filters and cursor-based pagination. Can count responses across all clients, a specific client, a specific feedback entry, or specific responders. If opt-client is none, counts across all clients. If opt-feedback-index is none or 0, counts all feedback for the client(s). If opt-responders is provided, only counts responses from those principals. Returns {total: uint, cursor: (optional uint)} where cursor is some(offset) if more results exist (when paginating across clients/feedback).

This method should be defined as read-only, i.e. `define-read-only`.

#### Get Responders

`(get-responders ((agent-id uint) (client principal) (index uint) (opt-cursor (optional uint))) {responders: (list 14 principal), cursor: (optional uint)})`

Get principals who have responded to a specific feedback entry using cursor-based pagination (PAGE_SIZE=14). Returns {responders: (list 14 principal), cursor: (optional uint)} where cursor is some(offset) if more results exist.

This method should be defined as read-only, i.e. `define-read-only`.

#### Get Identity Registry

`(get-identity-registry () principal)`

Return the principal of the linked Identity Registry contract. This is hardcoded to .identity-registry at deployment time.

This method should be defined as read-only, i.e. `define-read-only`.

#### Get Auth Message Hash

`(get-auth-message-hash ((agent-id uint) (client principal) (index-limit uint) (expiry uint) (signer principal)) (buff 32))`

Calculate the SIP-018 message hash for give-feedback-signed authorization. Exposed for off-chain tooling to generate signatures. Returns the 32-byte hash that must be signed by the signer principal.

This method should be defined as read-only, i.e. `define-read-only`.

### Reputation Registry Trait Implementation

```clarity
;; title: reputation-registry-trait
;; version: 2.0.0
;; summary: Trait definition for ERC-8004 Reputation Registry
;; description: Defines the interface for reputation registry contracts. Includes all public state-changing functions. Read-only functions are not included as they return raw types (tuples, uints, optionals).

(define-trait reputation-registry-trait
  (
    ;; Client approval
    (approve-client (uint principal uint) (response bool uint))

    ;; Feedback submission (permissionless)
    (give-feedback (uint int uint (string-utf8 64) (string-utf8 64) (string-utf8 512) (string-utf8 512) (buff 32)) (response uint uint))

    ;; Feedback submission (pre-approved client)
    (give-feedback-approved (uint int uint (string-utf8 64) (string-utf8 64) (string-utf8 512) (string-utf8 512) (buff 32)) (response uint uint))

    ;; Feedback submission (signed authorization)
    (give-feedback-signed (uint int uint (string-utf8 64) (string-utf8 64) (string-utf8 512) (string-utf8 512) (buff 32) principal uint uint (buff 65)) (response uint uint))

    ;; Feedback management
    (revoke-feedback (uint uint) (response bool uint))

    ;; Response management
    (append-response (uint principal uint (string-utf8 512) (buff 32)) (response bool uint))
  )
)
```

## Validation Registry Trait

The Validation Registry enables third-party validators to approve or reject agents based on specific criteria such as compliance, capability verification, or audits.

### Trait Functions

#### Validation Request

`(validation-request ((validator principal) (agent-id uint) (request-uri (string-utf8 512)) (request-hash (buff 32))) (response bool uint))`

Request validation from a specific validator. Only the agent owner or approved operator may initiate a request. Creates an initial validation record with response=0 and has-response=false. The request-uri points to off-chain validation request details, and the request-hash is a unique identifier for this validation request.

This method must be defined with `define-public`.

| error code | reason |
| ---------- | ------ |
| u2000 | Caller is not authorized |
| u2001 | Agent does not exist |
| u2003 | Validation request already exists |
| u2004 | Invalid validator (cannot be self) |

#### Validation Response

`(validation-response ((request-hash (buff 32)) (response uint) (response-uri (string-utf8 512)) (response-hash (buff 32)) (tag (string-utf8 64))) (response bool uint))`

Submit a validation response. Only the designated validator for the request may respond. This function supports progressive validation and can be called multiple times to update the response score, response-uri, response-hash, and tag. The response score must be between 0 and 100, where 0 indicates rejection and higher scores indicate varying levels of approval. There is no monotonic requirement, so the response score can decrease in subsequent calls (e.g., from preliminary to final assessment). The response-uri points to off-chain validation response details.

This method must be defined with `define-public`.

| error code | reason |
| ---------- | ------ |
| u2000 | Caller is not the designated validator |
| u2002 | Validation request not found |
| u2005 | Invalid response (exceeds 100) |

#### Get Validation Status

`(get-validation-status ((request-hash (buff 32))) (optional {validator: principal, agent-id: uint, response: uint, response-hash: (buff 32), tag: (string-utf8 64), last-update: uint, has-response: bool}))`

Retrieve the status of a validation request. Returns none if the validation is not found. The has-response field indicates whether the validator has provided a response (false after validation-request, true after first validation-response call). The response field (renamed from score for clarity) contains the validation score.

This method should be defined as read-only, i.e. `define-read-only`.

#### Get Summary

`(get-summary ((agent-id uint)) {count: uint, avg-response: uint})`

Returns O(1) aggregate metrics using running totals. Only validations where has-response is true are counted. Returns {count: uint, avg-response: uint} where avg-response is the average validation score, or {count: u0, avg-response: u0} if no validations exist. For filtered aggregations (by validator/tag), use SIP-019 indexer.

This method should be defined as read-only, i.e. `define-read-only`.

#### Get Agent Validations

`(get-agent-validations ((agent-id uint) (opt-cursor (optional uint))) {validations: (list 14 (buff 32)), cursor: (optional uint)})`

Get validation request hashes for an agent using cursor-based pagination (PAGE_SIZE=14). Returns {validations: (list 14 (buff 32)), cursor: (optional uint)} where cursor is some(offset) if more results exist.

This method should be defined as read-only, i.e. `define-read-only`.

#### Get Validator Requests

`(get-validator-requests ((validator principal) (opt-cursor (optional uint))) {requests: (list 14 (buff 32)), cursor: (optional uint)})`

Get validation request hashes assigned to a validator using cursor-based pagination (PAGE_SIZE=14). Returns {requests: (list 14 (buff 32)), cursor: (optional uint)} where cursor is some(offset) if more results exist.

This method should be defined as read-only, i.e. `define-read-only`.

#### Get Identity Registry

`(get-identity-registry () principal)`

Return the principal of the linked Identity Registry contract.

This method should be defined as read-only, i.e. `define-read-only`.

#### Get Version

`(get-version () (string-utf8 8))`

Return the contract version string.

This method should be defined as read-only, i.e. `define-read-only`.

### Validation Registry Trait Implementation

```clarity
;; title: validation-registry-trait
;; version: 2.0.0
;; summary: Trait definition for ERC-8004 Validation Registry
;; description: Defines the interface for validation registry contracts. Includes all public state-changing functions. Read-only functions are not included as they return raw types (tuples, optionals).

(define-trait validation-registry-trait
  (
    ;; Validation request
    (validation-request (principal uint (string-utf8 512) (buff 32)) (response bool uint))

    ;; Validation response
    (validation-response ((buff 32) uint (string-utf8 512) (buff 32) (string-utf8 64)) (response bool uint))
  )
)
```

# Multichain Identity

This standard supports cross-chain agent identity using CAIP-2 [4] compliant identifiers, enabling agents registered on Stacks to be referenced from other chains and vice versa. Agents advertise all their cross-chain registrations in the registration file's `registrations` array.

## Identifier Format

Each agent is uniquely identified globally using the CAIP-2 format:

```
<namespace>:<chainId>:<registry>:<agentId>
```

For Stacks agents:
- `<namespace>` is `stacks`
- `<chainId>` is the chain identifier (1 for mainnet, 2147483648 for testnet)
- `<registry>` is the fully-qualified registry contract principal
- `<agentId>` is the agent's numeric ID

## Chain Identifiers

| Network | Chain ID | Example |
| ------- | -------- | ------- |
| Stacks Mainnet | 1 | `stacks:1:SP1NMR7MY0TJ1QA7WQBZ6504KC79PZNTRQH4YGFJD.identity-registry-v2:42` |
| Stacks Testnet | 2147483648 | `stacks:2147483648:ST3YT0XW92E6T2FE59B2G5N2WNNFSBZ6MZKQS5D18.identity-registry-v2:0` |

## Cross-Chain Registration

Agents can be registered on multiple blockchains and advertise all registrations in their registration file's `registrations` array. Each entry contains:

```json
{
  "agentId": 42,
  "agentRegistry": "stacks:1:SP1NMR7MY0TJ1QA7WQBZ6504KC79PZNTRQH4YGFJD.identity-registry-v2"
}
```

### Example: Multi-Chain Agent

An agent registered on both Stacks mainnet (agent ID 42) and Ethereum mainnet (agent ID 123) would list both in the registration file:

```json
{
  "registrations": [
    {
      "agentId": 42,
      "agentRegistry": "stacks:1:SP1NMR7MY0TJ1QA7WQBZ6504KC79PZNTRQH4YGFJD.identity-registry-v2"
    },
    {
      "agentId": 123,
      "agentRegistry": "eip155:1:0x742d35Cc6634C0532925a3b844Bc454e4438f44e"
    }
  ]
}
```

This enables applications on any chain to discover the agent's presence on other chains and aggregate reputation signals across the entire network. For complete details on cross-chain agent identity, see ERC-8004 [3].

# Implementing in Wallets and Applications

Developers building applications that interact with agent registries should follow these guidelines.

## Validating Registry Contracts

Before interacting with a registry contract, applications should verify that the contract implements the appropriate trait. This can be done by checking the contract's interface or attempting to call read-only functions.

## Agent Registration File

The URI returned by `get-uri` (or `get-token-uri` for SIP-009 compatibility) points to the agent registration file. The URI may use any scheme: `ipfs://` (e.g., `ipfs://QmHash`), `https://` (e.g., `https://example.com/agent.json`), or a base64-encoded `data:` URI (e.g., `data:application/json;base64,eyJ0eXBlIjoi...`) for fully on-chain metadata.

The registration file MUST follow the ERC-8004 [3] registration file structure to ensure cross-chain compatibility:

```json
{
  "type": "https://eips.ethereum.org/EIPS/eip-8004#registration-v1",
  "name": "Agent Name",
  "description": "Description of the agent's purpose and capabilities",
  "image": "https://example.com/agent-avatar.png",
  "services": [
    {
      "name": "web",
      "endpoint": "https://web.agentxyz.com/"
    },
    {
      "name": "A2A",
      "endpoint": "https://agent.example/.well-known/agent-card.json",
      "version": "0.3.0"
    },
    {
      "name": "MCP",
      "endpoint": "https://mcp.agent.eth/",
      "version": "2025-06-18"
    },
    {
      "name": "OASF",
      "endpoint": "ipfs://{cid}",
      "version": "0.8",
      "skills": [],
      "domains": []
    },
    {
      "name": "ENS",
      "endpoint": "agent.eth",
      "version": "v1"
    },
    {
      "name": "email",
      "endpoint": "mail@agent.com"
    }
  ],
  "x402Support": false,
  "active": true,
  "registrations": [
    {
      "agentId": 42,
      "agentRegistry": "stacks:1:SP1NMR7MY0TJ1QA7WQBZ6504KC79PZNTRQH4YGFJD.identity-registry-v2"
    }
  ],
  "supportedTrust": [
    "reputation",
    "validation"
  ]
}
```

### Required Fields

- `type`: MUST be `"https://eips.ethereum.org/EIPS/eip-8004#registration-v1"`
- `name`: Human-readable agent name
- `description`: Natural language description of the agent's purpose and capabilities
- `image`: URI pointing to agent avatar image

### Optional Fields

- `services`: Array of service endpoints (A2A, MCP, OASF, ENS, DID, web, email, etc.)
- `x402Support`: Boolean indicating support for x402 payment protocol
- `active`: Boolean indicating agent operational status
- `registrations`: Array of on-chain registrations across multiple blockchains (see Multichain Identity section)
- `supportedTrust`: Array of trust models supported by the agent (e.g., `"reputation"`, `"validation"`, `"crypto-economic"`, `"tee-attestation"`)

The `services` array allows agents to advertise multiple communication endpoints. Each service entry contains a `name`, `endpoint`, and optional `version`. The flexibility of this structure enables agents to support emerging protocols while maintaining backward compatibility with existing standards.

## SIP-018 Signature Integration

This standard uses SIP-018 [1] signed structured data for two operations: `set-agent-wallet-signed` in the Identity Registry and `give-feedback-signed` in the Reputation Registry.

### Hash Construction

The SIP-018 message hash is constructed as follows:

```clarity
(sha256 (concat SIP018_PREFIX (concat domain-hash structured-data-hash)))
```

Where:
- `SIP018_PREFIX` is `0x534950303138` (the ASCII string "SIP018" in hexadecimal)
- `domain-hash` is `sha256(to-consensus-buff? domain)` where domain is `{name: (string-ascii 64), version: (string-ascii 64), chain-id: uint}`
- `structured-data-hash` is `sha256(to-consensus-buff? message)` where message contains the function-specific fields
- `to-consensus-buff?` is Clarity's native serialization format (analogous to EIP-712's typed data encoding)

### Set Agent Wallet Message

For `set-agent-wallet-signed`, the message structure is:

```clarity
{
  agent-id: uint,
  new-wallet: principal,
  owner: principal,
  deadline: uint
}
```

The signature must be produced by the `new-wallet` principal to prove wallet ownership.

### Give Feedback Signed Message

For `give-feedback-signed`, the message structure is:

```clarity
{
  agent-id: uint,
  client: principal,
  index-limit: uint,
  expiry: uint,
  signer: principal
}
```

The signature must be produced by the `signer` (agent owner or approved operator) to authorize the client to submit feedback up to the specified index limit before the expiry block height.

### Wallet Implementation

Wallets implementing SIP-018 signing for agent registries should:
- Display the domain (contract name, version, chain ID) prominently
- Show all message fields in human-readable format
- Warn users about deadline/expiry constraints
- Use `secp256k1-recover?` for signature verification with the message hash as input

## Authorization Model

All ownership and authorization checks use `tx-sender` exclusively, never `contract-caller`. This design choice provides composability—intermediary contracts can exist between the user and the registry via normal `contract-call?` chains without breaking authorization, since `tx-sender` remains the original transaction sender. If the registries checked `contract-caller` instead, every intermediary contract would need explicit operator approval.

The security guarantee is that a contract cannot set `tx-sender` to an arbitrary principal—it can only change `tx-sender` to its own principal via `as-contract`. A malicious intermediary cannot impersonate a user from a different transaction. However, `tx-sender` authorization does not prevent a malicious contract from performing authorized actions within a transaction the user initiates (since the user's `tx-sender` passes through). Users should review which contracts they interact with.

The Identity Registry exposes `is-authorized-or-owner` as a response-wrapped read-only function for cross-contract authorization checks. The Reputation Registry uses this to prevent self-feedback: it calls `is-authorized-or-owner` and asserts the caller is NOT authorized (i.e., not the agent owner or operator).

For DAO or multisig agent management, use `set-approval-for-all` to grant the DAO/multisig contract operator privileges, since `as-contract` changes `tx-sender` and would fail authorization checks.

## Displaying Reputation

When displaying agent reputation:
- Show both the average score and the number of feedback entries
- Indicate whether feedback entries have been revoked
- Display recent feedback with associated tags for context
- Consider filtering by validation status for quality assurance

# Security Considerations

## Sybil Attacks on Permissionless Feedback

The Reputation Registry allows permissionless feedback by default, creating vulnerability to Sybil attacks where an entity creates multiple accounts to manipulate reputation scores. Self-feedback is blocked via `is-authorized-or-owner`, but this only prevents direct self-promotion.

Agents can mitigate Sybil attacks by using `approve-client` for curated feedback or `give-feedback-signed` for off-chain authorization. Applications SHOULD implement additional filtering such as trusted client lists, meta-reputation systems (reputation-of-raters), economic barriers (staking/fees), or temporal analysis of submission patterns.

## On-Chain URI Pointers

Registry contracts store URI pointers rather than full data on-chain. This introduces availability risks (URI targets may disappear) and mutability risks (centrally-hosted content can change). Implementations SHOULD use content-addressed storage (IPFS CIDs) where possible, verify hash fields (`feedback-hash`, `response-hash`, `request-hash`) against fetched content, and consider base64-encoded `data:` URIs for critical on-chain metadata.

## Validator Incentive Alignment

The Validation Registry does not include built-in economic incentives. Without staking or bonding, validators face no penalty for inaccurate, delayed, or colluded responses. Implementations SHOULD deploy wrapper contracts with staking/slashing mechanisms, use multi-validator aggregation, and maintain validator reputation scores. The progressive `validation-response` function allows score updates without monotonic constraints, so applications should track response history.

## Agent Wallet Security

The agent wallet is automatically cleared on NFT transfer to prevent stale wallet associations. The `set-agent-wallet-signed` function requires deadlines within MAX_DEADLINE_DELAY (1500 blocks, ~5 minutes) to prevent replay attacks. SIP-018 signatures include chain-id to prevent cross-chain replay. The wallet system's primary benefit is separation of concerns: the owner key (cold wallet/multisig) holds the NFT while the agent wallet (hot wallet) handles frequent interactions.

# Related Work

## ERC-8004 (Ethereum/Solidity)

This SIP is designed to be compatible with ERC-8004 [3], the Agent Commerce Protocol on Ethereum. Both standards define the same three registries (Identity, Reputation, Validation) with equivalent functionality, enabling cross-chain agent identity via CAIP-2 [4] identifiers.

Key differences in the Stacks v2.0.0 implementation:
- **Traits vs Interfaces**: Uses Clarity traits instead of Solidity interfaces
- **NFT Standard**: Implements SIP-009 [5] NFT trait for agent identities (transferable, standard wallet/explorer integration) instead of ERC-721
- **Signed Data**: Leverages SIP-018 [1] for signed structured data instead of EIP-712
- **Signed Values**: Uses signed integer values with decimals (0-18) for reputation scores, supporting negative feedback and WAD normalization
- **Agent Wallets**: Includes reserved metadata system for agent-controlled wallets separate from owner accounts
- **Authorization Model**: Strict tx-sender authorization model (prevents delegation attacks) with optional operator approval
- **Event Patterns**: Follows SIP-019 [2] notification patterns for token metadata updates

The Ethereum implementation is available at https://github.com/erc8004-org/erc8004-contracts.

## Solana Program (s8004)

A Solana Anchor implementation of ERC-8004 is available at https://github.com/Woody4618/s8004. The Solana program uses Account-based storage (PDAs) and Borsh serialization instead of map-based storage and Clarity's consensus buffers. Like the Stacks implementation, it supports CAIP-2 multichain identifiers using the format `solana:<chainId>:<programId>:<agentId>`.

Key architectural differences from Stacks:
- **Account Model**: Agents stored in Program Derived Accounts (PDAs) instead of NFT tokens
- **Rent**: Requires rent-exempt balance for account storage (Solana's economic model)
- **Concurrency**: Parallel transaction processing enabled by explicit account dependencies
- **Serialization**: Uses Borsh instead of Clarity's consensus buffers

## Cross-Chain Agent Identity

All three implementations (Ethereum, Stacks, Solana) support the ERC-8004 registration file format, which includes a `registrations` array for tracking agent presence across multiple blockchains. This enables agents to maintain a single canonical metadata file while proving ownership of identities on multiple chains. Applications can resolve agent identities by fetching the registration file URI and validating on-chain ownership for each listed registration.

# Backwards Compatibility

Not applicable. This is a new standard with no prior implementations to maintain compatibility with.

# Activation

This SIP will be considered activated when:

1. The three trait definitions are deployed to mainnet
2. At least one complete implementation of all three registries is deployed to mainnet
3. The implementation passes all test cases from the reference implementation

# Reference Implementations

## Source Code

Reference implementations are available at:
- Stacks (Clarity): https://github.com/aibtcdev/erc-8004-stacks
- Ethereum (Solidity): https://github.com/erc8004-org/erc8004-contracts
- Solana (Anchor): https://github.com/Woody4618/s8004

## Testnet Deployments

The following contracts are deployed on Stacks testnet at `ST3YT0XW92E6T2FE59B2G5N2WNNFSBZ6MZKQS5D18`:

**Traits:**

- Identity Registry Trait: `ST3YT0XW92E6T2FE59B2G5N2WNNFSBZ6MZKQS5D18.identity-registry-trait-v2`
- Reputation Registry Trait: `ST3YT0XW92E6T2FE59B2G5N2WNNFSBZ6MZKQS5D18.reputation-registry-trait-v2`
- Validation Registry Trait: `ST3YT0XW92E6T2FE59B2G5N2WNNFSBZ6MZKQS5D18.validation-registry-trait-v2`

**Contracts:**

- Identity Registry: `ST3YT0XW92E6T2FE59B2G5N2WNNFSBZ6MZKQS5D18.identity-registry-v2`
- Reputation Registry: `ST3YT0XW92E6T2FE59B2G5N2WNNFSBZ6MZKQS5D18.reputation-registry-v2`
- Validation Registry: `ST3YT0XW92E6T2FE59B2G5N2WNNFSBZ6MZKQS5D18.validation-registry-v2`

## Mainnet Deployments

The following contracts are deployed on Stacks mainnet at `SP1NMR7MY0TJ1QA7WQBZ6504KC79PZNTRQH4YGFJD`:

**Traits:**

- Identity Registry Trait: `SP1NMR7MY0TJ1QA7WQBZ6504KC79PZNTRQH4YGFJD.identity-registry-trait-v2`
- Reputation Registry Trait: `SP1NMR7MY0TJ1QA7WQBZ6504KC79PZNTRQH4YGFJD.reputation-registry-trait-v2`
- Validation Registry Trait: `SP1NMR7MY0TJ1QA7WQBZ6504KC79PZNTRQH4YGFJD.validation-registry-trait-v2`

**Contracts:**

- Identity Registry: `SP1NMR7MY0TJ1QA7WQBZ6504KC79PZNTRQH4YGFJD.identity-registry-v2`
- Reputation Registry: `SP1NMR7MY0TJ1QA7WQBZ6504KC79PZNTRQH4YGFJD.reputation-registry-v2`
- Validation Registry: `SP1NMR7MY0TJ1QA7WQBZ6504KC79PZNTRQH4YGFJD.validation-registry-v2`

# References

[1] SIP-018: Signed Structured Data - https://github.com/stacksgov/sips/blob/main/sips/sip-018/sip-018-signed-structured-data.md

[2] SIP-019: Notifications for Token Metadata Updates - https://github.com/stacksgov/sips/blob/main/sips/sip-019/sip-019-token-metadata-update-notifications.md

[3] ERC-8004: Agent Commerce Protocol - https://eips.ethereum.org/EIPS/eip-8004

[4] CAIP-2: Blockchain ID Specification - https://github.com/ChainAgnostic/CAIPs/blob/main/CAIPs/caip-2.md

[5] SIP-009: Standard NFT Trait - https://github.com/stacksgov/sips/blob/main/sips/sip-009/sip-009-nft-standard.md
