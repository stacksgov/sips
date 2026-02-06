# Preamble

SIP Number: XXX

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
- SIP pull request: https://github.com/stacksgov/sips/pull/XXX

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
(define-trait identity-registry-trait
  (
    ;; Register a new agent with empty URI
    (register () (response uint uint))

    ;; Register a new agent with URI
    (register-with-uri ((string-utf8 512)) (response uint uint))

    ;; Register a new agent with URI and metadata
    (register-full ((string-utf8 512) (list 10 {key: (string-utf8 128), value: (buff 512)})) (response uint uint))

    ;; Update agent URI
    (set-agent-uri (uint (string-utf8 512)) (response bool uint))

    ;; Set metadata key-value pair
    (set-metadata (uint (string-utf8 128) (buff 512)) (response bool uint))

    ;; Grant or revoke operator permissions
    (set-approval-for-all (uint principal bool) (response bool uint))

    ;; Set agent wallet to tx-sender
    (set-agent-wallet-direct (uint) (response bool uint))

    ;; Set agent wallet with SIP-018 signature
    (set-agent-wallet-signed (uint principal uint (buff 65)) (response bool uint))

    ;; Remove agent wallet
    (unset-agent-wallet (uint) (response bool uint))

    ;; Transfer agent identity NFT
    (transfer (uint principal principal) (response bool uint))

    ;; Get agent owner (legacy)
    (owner-of (uint) (optional principal))

    ;; Get agent URI
    (get-uri (uint) (optional (string-utf8 512)))

    ;; Get metadata value for key
    (get-metadata (uint (string-utf8 128)) (optional (buff 512)))

    ;; Check operator approval
    (is-approved-for-all (uint principal) bool)

    ;; Get agent wallet
    (get-agent-wallet (uint) (optional principal))

    ;; Check if spender is authorized or owner
    (is-authorized-or-owner (principal uint) (response bool uint))

    ;; Get contract version
    (get-version () (string-utf8 8))

    ;; SIP-009 NFT trait functions
    (get-last-token-id () (response uint uint))
    (get-token-uri (uint) (response (optional (string-utf8 512)) uint))
    (get-owner (uint) (response (optional principal) uint))
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

`(read-feedback ((agent-id uint) (client principal) (index uint)) (response (optional {value: int, value-decimals: uint, tag1: (string-utf8 64), tag2: (string-utf8 64), is-revoked: bool}) uint))`

Retrieve a specific feedback entry. Returns none if the feedback does not exist.

This method should be defined as read-only, i.e. `define-read-only`.

#### Get Summary

`(get-summary ((agent-id uint) (client-addresses (list 200 principal)) (tag1 (string-utf8 64)) (tag2 (string-utf8 64))) (response {count: uint, summary-value: int, summary-value-decimals: uint} uint))`

Calculate aggregate reputation metrics for an agent across specified clients and optional tag filters. All feedback values are normalized to WAD (18 decimals) for averaging, then scaled back to the mode (most common) decimals value among the feedback entries. Empty tag strings match all values. Returns empty summary if client-addresses is empty or no matching feedback exists.

This method should be defined as read-only, i.e. `define-read-only`.

#### Read All Feedback

`(read-all-feedback ((agent-id uint) (opt-clients (optional (list 50 principal))) (opt-tag1 (optional (string-utf8 64))) (opt-tag2 (optional (string-utf8 64))) (include-revoked bool)) (response (list 50 {client: principal, index: uint, value: int, value-decimals: uint, tag1: (string-utf8 64), tag2: (string-utf8 64), is-revoked: bool}) uint))`

Retrieve feedback entries for an agent with optional filters. If opt-clients is none, reads from all clients who have given feedback. Tag filters are optional. Maximum 50 entries returned.

This method should be defined as read-only, i.e. `define-read-only`.

#### Get Last Index

`(get-last-index ((agent-id uint) (client principal)) (response uint uint))`

Get the last feedback index submitted by a client for an agent. Returns 0 if no feedback has been submitted.

This method should be defined as read-only, i.e. `define-read-only`.

#### Get Clients

`(get-clients ((agent-id uint)) (response (optional (list 1024 principal)) uint))`

Get the list of all clients who have given feedback for an agent.

This method should be defined as read-only, i.e. `define-read-only`.

#### Get Approved Limit

`(get-approved-limit ((agent-id uint) (client principal)) (response uint uint))`

Get the approved index limit for a client. Returns 0 if no approval exists.

This method should be defined as read-only, i.e. `define-read-only`.

#### Get Response Count

`(get-response-count ((agent-id uint) (opt-client (optional principal)) (opt-feedback-index (optional uint)) (opt-responders (optional (list 200 principal)))) (response uint uint))`

Flexible response counting with optional filters. Can count responses across all clients, a specific client, a specific feedback entry, or specific responders. If opt-client is none, counts across all clients. If opt-feedback-index is none or 0, counts all feedback for the client(s). If opt-responders is provided, only counts responses from those principals.

This method should be defined as read-only, i.e. `define-read-only`.

#### Get Responders

`(get-responders ((agent-id uint) (client principal) (index uint)) (response (optional (list 256 principal)) uint))`

Get the list of principals who have responded to a specific feedback entry.

This method should be defined as read-only, i.e. `define-read-only`.

### Reputation Registry Trait Implementation

```clarity
(define-trait reputation-registry-trait
  (
    ;; Pre-authorize a client to provide feedback
    (approve-client (uint principal uint) (response bool uint))

    ;; Submit feedback (permissionless)
    (give-feedback (uint int uint (string-utf8 64) (string-utf8 64) (string-utf8 512) (string-utf8 512) (buff 32)) (response uint uint))

    ;; Submit feedback (on-chain approval)
    (give-feedback-approved (uint int uint (string-utf8 64) (string-utf8 64) (string-utf8 512) (string-utf8 512) (buff 32)) (response uint uint))

    ;; Submit feedback (SIP-018 signature)
    (give-feedback-signed (uint int uint (string-utf8 64) (string-utf8 64) (string-utf8 512) (string-utf8 512) (buff 32) principal uint uint (buff 65)) (response uint uint))

    ;; Revoke submitted feedback
    (revoke-feedback (uint uint) (response bool uint))

    ;; Respond to feedback
    (append-response (uint principal uint (string-utf8 512) (buff 32)) (response bool uint))

    ;; Read single feedback entry
    (read-feedback (uint principal uint) (response (optional {value: int, value-decimals: uint, tag1: (string-utf8 64), tag2: (string-utf8 64), is-revoked: bool}) uint))

    ;; Get aggregate reputation summary (WAD-normalized)
    (get-summary (uint (list 200 principal) (string-utf8 64) (string-utf8 64)) (response {count: uint, summary-value: int, summary-value-decimals: uint} uint))

    ;; Read filtered feedback
    (read-all-feedback (uint (optional (list 50 principal)) (optional (string-utf8 64)) (optional (string-utf8 64)) bool) (response (list 50 {client: principal, index: uint, value: int, value-decimals: uint, tag1: (string-utf8 64), tag2: (string-utf8 64), is-revoked: bool}) uint))

    ;; Get last feedback index for a client
    (get-last-index (uint principal) (response uint uint))

    ;; Get all clients who gave feedback
    (get-clients (uint) (response (optional (list 1024 principal)) uint))

    ;; Get approved index limit for a client
    (get-approved-limit (uint principal) (response uint uint))

    ;; Get response count with optional filters
    (get-response-count (uint (optional principal) (optional uint) (optional (list 200 principal))) (response uint uint))

    ;; Get responders to feedback
    (get-responders (uint principal uint) (response (optional (list 256 principal)) uint))
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

`(get-summary ((agent-id uint) (opt-validators (optional (list 200 principal))) (opt-tag (optional (string-utf8 64)))) {count: uint, avg-response: uint})`

Calculate aggregate validation metrics for an agent, optionally filtered by validators and a single tag. The opt-tag parameter accepts a single optional string instead of a list - an empty string or none matches all tags. Only validations where has-response is true are counted in the aggregation. Returns a tuple with count (number of matching validations) and avg-response (average validation score), or {count: 0, avg-response: 0} if no matching validations exist.

This method should be defined as read-only, i.e. `define-read-only`.

#### Get Agent Validations

`(get-agent-validations ((agent-id uint)) (optional (list 1024 (buff 32))))`

Get all validation request hashes for an agent. Returns none if the agent has no validations.

This method should be defined as read-only, i.e. `define-read-only`.

#### Get Validator Requests

`(get-validator-requests ((validator principal)) (optional (list 1024 (buff 32))))`

Get all validation request hashes assigned to a validator. Returns none if the validator has no requests.

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
(define-trait validation-registry-trait
  (
    ;; Request validation from a validator
    (validation-request (principal uint (string-utf8 512) (buff 32)) (response bool uint))

    ;; Submit validation response (progressive: can be called multiple times)
    (validation-response ((buff 32) uint (string-utf8 512) (buff 32) (string-utf8 64)) (response bool uint))

    ;; Get validation status (returns none if not found)
    (get-validation-status ((buff 32)) (optional {validator: principal, agent-id: uint, response: uint, response-hash: (buff 32), tag: (string-utf8 64), last-update: uint, has-response: bool}))

    ;; Get aggregate validation summary (only counts entries with has-response=true)
    (get-summary (uint (optional (list 200 principal)) (optional (string-utf8 64))) {count: uint, avg-response: uint})

    ;; Get all validations for an agent
    (get-agent-validations (uint) (optional (list 1024 (buff 32))))

    ;; Get all requests for a validator
    (get-validator-requests (principal) (optional (list 1024 (buff 32))))

    ;; Get linked identity registry
    (get-identity-registry () principal)

    ;; Get contract version
    (get-version () (string-utf8 8))
  )
)
```

## Error Code Summary

This section lists all error codes used across the three registry contracts in v2.0.0.

### Identity Registry Errors (u1000-u1008)

| error code | reason |
| ---------- | ------ |
| u1000 | Not authorized (caller is not owner or approved operator) |
| u1001 | Agent not found |
| u1002 | Agent already exists |
| u1003 | Metadata set failed |
| u1004 | Reserved key (agentWallet cannot be set via set-metadata or during registration) |
| u1005 | Invalid sender (tx-sender must match sender parameter in transfer) |
| u1006 | Wallet already set (tx-sender is already the agent wallet) |
| u1007 | Expired signature (deadline passed or exceeds MAX_DEADLINE_DELAY) |
| u1008 | Invalid signature (recovery failed or doesn't match expected principal) |

### Validation Registry Errors (u2000-u2005)

| error code | reason |
| ---------- | ------ |
| u2000 | Not authorized (caller is not owner, approved operator, or designated validator) |
| u2001 | Agent not found |
| u2002 | Validation not found |
| u2003 | Validation already exists |
| u2004 | Invalid validator (cannot be self) |
| u2005 | Invalid response (exceeds 100) |

### Reputation Registry Errors (u3000-u3012)

| error code | reason |
| ---------- | ------ |
| u3000 | Not authorized (signer is not owner or approved operator) |
| u3001 | Agent not found |
| u3002 | Feedback not found |
| u3003 | Feedback already revoked |
| u3004 | Invalid value (reserved, unused in v2.0.0) |
| u3005 | Self-feedback not allowed (caller is owner or approved operator) |
| u3006 | Invalid index (must be > 0) |
| u3007 | Signature verification failed |
| u3008 | Authorization expired |
| u3009 | Index limit exceeded |
| u3010 | Empty response URI |
| u3011 | Invalid decimals (exceeds 18) |
| u3012 | Empty client list (reserved, unused in v2.0.0) |

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
| Stacks Mainnet | 1 | `stacks:1:SP000000000000000000002Q6VF78.identity-registry:42` |
| Stacks Testnet | 2147483648 | `stacks:2147483648:ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.identity-registry:0` |

## Cross-Chain Registration

Agents can be registered on multiple blockchains and advertise all registrations in their registration file's `registrations` array. Each entry contains:

```json
{
  "agentId": 42,
  "agentRegistry": "stacks:1:SP000000000000000000002Q6VF78.identity-registry"
}
```

### Example: Multi-Chain Agent

An agent registered on both Stacks mainnet (agent ID 42) and Ethereum mainnet (agent ID 123) would list both in the registration file:

```json
{
  "registrations": [
    {
      "agentId": 42,
      "agentRegistry": "stacks:1:SP000000000000000000002Q6VF78.identity-registry"
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

Developers building applications that interact with agent registries should follow these guidelines:

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
      "agentRegistry": "stacks:1:SP000000000000000000002Q6VF78.identity-registry"
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

The v2.0.0 contracts implement a strict authorization model based on transaction sender identity and cross-contract authorization checks. This section documents the key patterns used throughout the registry implementations.

### tx-sender vs contract-caller

All ownership and authorization checks in v2.0.0 use `tx-sender` exclusively, never `contract-caller`. This is a critical security decision that prevents delegation attacks.

**Why tx-sender?**

Using `tx-sender` ensures that only the actual transaction originator can perform privileged operations. If contracts used `contract-caller` instead, a malicious intermediary contract could impersonate the owner by calling registry functions on behalf of users, even without explicit permission.

**Example from identity-registry.clar:**

```clarity
(define-public (set-agent-uri (agent-id uint) (new-uri (string-utf8 512)))
  (begin
    (asserts! (is-authorized agent-id tx-sender) ERR_NOT_AUTHORIZED)
    (map-set uris {agent-id: agent-id} new-uri)
    ;; ...
  )
)
```

The `is-authorized` helper checks if `tx-sender` (not `contract-caller`) is either the NFT owner or an approved operator:

```clarity
(define-private (is-authorized (agent-id uint) (caller principal))
  (let (
    (owner-opt (nft-get-owner? agent-identity agent-id))
  )
    (match owner-opt owner
      (or
        (is-eq caller owner)
        (is-approved-for-all agent-id caller)
      )
      false
    )
  )
)
```

**Trade-off:** This approach prevents delegation through intermediary contracts. For delegated operations, owners must use `set-approval-for-all` to explicitly grant operator permissions instead of relying on contract-level delegation.

### is-authorized-or-owner Pattern

The Identity Registry exposes a public read-only function for cross-contract authorization checks:

```clarity
(define-read-only (is-authorized-or-owner (spender principal) (agent-id uint))
  (let (
    (owner (unwrap! (nft-get-owner? agent-identity agent-id) ERR_AGENT_NOT_FOUND))
  )
    (ok (or
      (is-eq spender owner)
      (is-approved-for-all agent-id spender)
    ))
  )
)
```

This function returns `(response bool uint)`:
- `(ok true)` if the spender is authorized (owner or approved operator)
- `(ok false)` if the spender is not authorized
- `(err u1001)` if the agent does not exist

**Usage in reputation-registry.clar:**

The Reputation Registry uses this function to prevent self-feedback. In the permissionless `give-feedback` function:

```clarity
(let (
  (auth-check (contract-call? .identity-registry is-authorized-or-owner caller agent-id))
)
  ;; Verify agent exists (is-authorized-or-owner returns error if not)
  (asserts! (is-ok auth-check) ERR_AGENT_NOT_FOUND)
  ;; Verify caller is NOT authorized (prevent self-feedback)
  (asserts! (not (unwrap-panic auth-check)) ERR_SELF_FEEDBACK)
  ;; ... continue with feedback submission
)
```

This pattern enables composable authorization across registry contracts while maintaining the tx-sender security model.

### Agent Wallet System

The Identity Registry includes a special metadata system for agent wallets through the reserved key `"agentWallet"`. This enables agents to control a separate wallet from their owner account—useful when the owner is a multisig or custody solution, but the agent needs a hot wallet for rapid transactions.

**Reserved Key Protection:**

The `"agentWallet"` key cannot be set via the standard `set-metadata` function or included in the `metadata-entries` array during `register-full`. Attempting to do so returns error u1004 (ERR_RESERVED_KEY).

**Automatic Initialization:**

When an agent is registered, the agent wallet is automatically set to the owner's address:

```clarity
(define-public (register-full
  (token-uri (string-utf8 512))
  (metadata-entries (list 10 {key: (string-utf8 128), value: (buff 512)}))
)
  (let ((agent-id (var-get next-agent-id)) (owner tx-sender))
    ;; ... mint NFT and set URI ...
    ;; Auto-set agent-wallet to owner
    (map-set agent-wallets {agent-id: agent-id} owner)
    ;; ...
  )
)
```

**Transfer Behavior:**

When an agent identity NFT is transferred via the `transfer` function, the agent wallet is automatically cleared to prevent stale wallet associations:

```clarity
(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) ERR_INVALID_SENDER)
    ;; ... authorization checks ...
    ;; Clear agent wallet before transfer
    (map-delete agent-wallets {agent-id: token-id})
    (try! (nft-transfer? agent-identity token-id sender recipient))
    ;; ...
  )
)
```

The new owner must then re-verify wallet ownership using one of the update methods below.

**Update Methods:**

Two functions allow updating the agent wallet, each proving wallet ownership differently:

1. **Direct Update (Transaction Signature):**

   ```clarity
   (define-public (set-agent-wallet-direct (agent-id uint))
     (let ((owner (unwrap! (nft-get-owner? agent-identity agent-id) ERR_AGENT_NOT_FOUND)))
       ;; Check caller is authorized (owner or approved operator)
       (asserts! (is-authorized agent-id tx-sender) ERR_NOT_AUTHORIZED)
       ;; ... check wallet not already set to tx-sender ...
       ;; Set new wallet
       (map-set agent-wallets {agent-id: agent-id} tx-sender)
       (ok true)
     )
   )
   ```

   The wallet proves ownership by being the transaction sender (`tx-sender`). Only the agent owner or an approved operator can initiate this call, but the wallet being set is always `tx-sender`.

2. **Signed Update (SIP-018 Signature):**

   ```clarity
   (define-public (set-agent-wallet-signed
     (agent-id uint)
     (new-wallet principal)
     (deadline uint)
     (signature (buff 65))
   )
     (let ((owner (unwrap! (nft-get-owner? agent-identity agent-id) ERR_AGENT_NOT_FOUND)))
       ;; Authorization check (caller must be owner or operator)
       (asserts! (is-authorized agent-id tx-sender) ERR_NOT_AUTHORIZED)
       ;; Deadline validation
       (asserts! (<= current-height deadline) ERR_EXPIRED_SIGNATURE)
       (asserts! (<= deadline (+ current-height MAX_DEADLINE_DELAY)) ERR_EXPIRED_SIGNATURE)
       ;; Verify signature from new-wallet
       ;; ... SIP-018 signature verification ...
       (map-set agent-wallets {agent-id: agent-id} new-wallet)
       (ok true)
     )
   )
   ```

   The new wallet proves ownership by providing a valid SIP-018 signature. The deadline must be the current block height or future, but within MAX_DEADLINE_DELAY (1500 blocks, approximately 5 minutes at 200s block times). This prevents replay attacks while allowing reasonable clock skew.

The agent wallet can be read via `get-agent-wallet` (returns `(optional principal)`) and removed via `unset-agent-wallet`.

## Use Cases and Common Patterns

The following patterns illustrate how agent registries can be used across applications:

1. **Portable Reputation** - Agents maintain a verifiable track record that can move across platforms and chains. An agent registered on Stacks can reference its reputation history when interacting with services on other chains via CAIP-2 identifiers.

2. **Spam Prevention** - Index limits and approval mechanisms in the Reputation Registry reduce review bombing and low-quality feedback. The `approve-client` function ensures only authorized clients can submit feedback.

3. **Transparency** - All feedback is public and immutable unless explicitly revoked by the author. The `revoke-feedback` function allows authors to retract feedback while preserving the on-chain record that it existed.

4. **Dispute Resolution** - Agents can respond to negative feedback via `append-response` and provide on-chain context, creating a transparent dialogue between agents and their clients.

5. **Bitcoin-Level Security** - Stacks settlement ensures reputation data remains durable and tamper-resistant, even if individual platforms disappear.

## Displaying Reputation

When displaying agent reputation:
- Show both the average score and the number of feedback entries
- Indicate whether feedback entries have been revoked
- Display recent feedback with associated tags for context
- Consider filtering by validation status for quality assurance

# Security Considerations

This section outlines potential security risks and recommended mitigations for implementations of the agent registry standard.

## Sybil Attacks on Permissionless Feedback

The Reputation Registry allows permissionless feedback by default—any principal can submit feedback for any agent without prior authorization. While this openness enables broad participation, it creates vulnerability to Sybil attacks where a single entity creates multiple client accounts to artificially inflate or deflate an agent's reputation.

**Attack Scenario:**

An attacker controls 100 principals and submits positive feedback from all of them to boost their own agent's reputation, or negative feedback to harm a competitor.

**Built-in Protections:**

1. **Self-feedback prevention**: The `give-feedback` function uses `is-authorized-or-owner` to verify the caller is not the agent owner or an approved operator. This prevents the simplest form of self-promotion.

2. **Three authorization paths**: Agents can choose their feedback model:
   - **Permissionless** (`give-feedback`): Anyone can submit feedback except the owner/operators
   - **On-chain approval** (`give-feedback-approved`): Only pre-authorized clients can submit feedback
   - **SIP-018 signed** (`give-feedback-signed`): Off-chain authorization with cryptographic signatures

**Recommended Mitigations:**

- **Application-level filtering**: Applications SHOULD filter feedback by trusted client lists rather than accepting all feedback equally. For example, only show feedback from clients who have been validated, have established reputations themselves, or have paid bonds.

- **Meta-reputation systems**: Implement reputation-of-raters where client credibility is tracked. Weight feedback from high-reputation clients more heavily than unknown clients.

- **Economic barriers**: Require clients to stake tokens or pay fees to submit feedback, making Sybil attacks economically infeasible at scale.

- **Curated feedback**: Agents concerned about spam should use `approve-client` to pre-authorize trusted clients with index limits, or use `give-feedback-signed` for full off-chain control.

- **Temporal analysis**: Monitor feedback submission patterns. Sudden bursts of feedback from new clients should be flagged for review.

## On-Chain URI Pointers vs Full Data Storage

The registry contracts store URI pointers (strings up to 512 characters) rather than full data on-chain. This design choice optimizes for gas costs and flexibility but introduces availability and mutability risks.

**Design Rationale:**

Storing full agent registration files, feedback details, or validation reports on-chain would be prohibitively expensive and inflexible. Large JSON files would cost thousands of dollars in transaction fees and couldn't be updated without redeploying contracts.

**Risks:**

1. **URI target disappearance**: A URI pointing to `https://example.com/agent.json` will fail if the server goes offline or the domain expires.

2. **URI target mutation**: Centrally-hosted URIs can be changed after registration, potentially misleading users who expect immutable records.

3. **Censorship**: Centralized hosting providers can remove content or block access.

**Recommended Mitigations:**

- **Content-addressed storage**: Use IPFS URIs with CID (Content Identifier) encoding. Example: `ipfs://QmX7M9CiYXjVeFnrSUdREuH3QdFkX3vKkMcfLH2RuH7RjN`. The CID cryptographically guarantees content integrity—if the content changes, the CID changes.

- **Hash verification**: For non-content-addressed URIs, include hash fields (`feedback-hash`, `response-hash`, `request-hash`) in function calls. Applications should verify the hash matches the fetched content.

- **Redundant storage**: Mirror critical URIs across multiple storage providers (IPFS, Arweave, Filecoin, centralized backups).

- **On-chain fallback**: For critical metadata, use base64-encoded `data:` URIs to store content directly on-chain: `data:application/json;base64,eyJ0eXBlIjoi...`

- **Monitoring services**: Implement URI availability monitoring and alert systems for broken links.

**Current Implementation:**

- `identity-registry`: Stores `token-uri` (512 char string)
- `reputation-registry`: Stores feedback values on-chain, emits `feedback-uri` in events (not stored)
- `validation-registry`: Stores `request-uri` and `response-uri` (512 char strings each)

## Validator Incentive Alignment

The Validation Registry provides a standard interface for third-party validators to submit verification responses but does not include built-in economic incentives. This creates a free-rider problem where validators lack motivation to provide accurate, timely responses.

**Problem:**

Without staking, bonding, or payment mechanisms, validators can:
- Submit inaccurate responses with no penalty
- Delay responses indefinitely
- Collude with agents to provide favorable scores
- Abandon requests after accepting them

**Progressive Validation Design:**

The v2.0.0 `validation-response` function allows validators to submit multiple updates per request (preliminary → final scores) without monotonic constraints. This supports iterative validation workflows but also enables validators to change scores arbitrarily.

**Recommended Mitigations:**

1. **Wrapper contracts with staking**: Deploy proxy contracts that require validators to stake tokens before accepting requests. Slashing conditions can penalize late or inaccurate responses.

2. **Meta-validation**: Track validator accuracy by comparing responses across multiple validators for the same agent. Validators with poor accuracy records should be deprioritized.

3. **Multi-validator aggregation**: Request validation from multiple independent validators and aggregate scores (median, weighted average). This reduces reliance on any single validator's honesty.

4. **Validator bonds**: Implement challenge-response systems where validators post bonds that can be forfeited if their responses are successfully disputed.

5. **Reputation of validators**: Maintain validator reputation scores based on historical accuracy, response time, and client satisfaction. Applications should filter validators by reputation.

6. **Payment integration**: Integrate with payment protocols (x402, direct transfers) to compensate validators for work. Payments can be released upon completion or held in escrow subject to dispute resolution.

**Example Staking Wrapper Pattern:**

```clarity
(define-public (request-validation-with-bond (validator principal) (agent-id uint) ...)
  (begin
    ;; Require validator to have staked minimum bond
    (asserts! (>= (get-validator-stake validator) MIN_STAKE) ERR_INSUFFICIENT_STAKE)
    ;; Forward request to validation-registry
    (contract-call? .validation-registry validation-request validator agent-id ...)
    ;; Lock validator stake until response or timeout
  )
)
```

## tx-sender Authorization and Delegation

The exclusive use of `tx-sender` for authorization checks provides strong security guarantees but limits delegation patterns.

**Security Benefit:**

By checking `tx-sender` instead of `contract-caller`, the registries prevent intermediary contract attacks. A malicious contract cannot impersonate the owner by forwarding calls, because `tx-sender` always represents the transaction originator, not the immediate caller.

**Example Attack (prevented by tx-sender):**

If contracts used `contract-caller`:
1. Alice owns agent #42
2. Bob deploys a malicious contract that calls `set-agent-uri(42, "evil-uri")`
3. Bob tricks Alice into calling his contract for an unrelated purpose
4. The malicious contract's call to `set-agent-uri` would have `contract-caller = malicious-contract`
5. If authorization checked `contract-caller`, the call would fail (good)
6. But if the malicious contract first called another intermediary that then called the registry, `contract-caller` could be spoofed

Using `tx-sender` prevents this entire class of attacks because `tx-sender` always equals Alice regardless of call chain depth.

**Trade-off:**

The downside is that delegation through smart contracts is not supported. For example, a DAO contract cannot directly manage agents on behalf of members. However, the `set-approval-for-all` function provides an alternative: owners can explicitly grant operator permissions to contracts, enabling controlled delegation.

**Recommendation:**

For DAO or multisig agent management, use `set-approval-for-all` to grant the DAO/multisig contract operator privileges. This provides explicit, revocable delegation without compromising the tx-sender security model.

## Agent Wallet Security

The agent wallet system introduces additional security considerations around key management and transfer handling.

**Automatic Clearing on Transfer:**

When an agent identity NFT is transferred, the `agentWallet` metadata is automatically cleared (set to none). This prevents stale wallet associations where the old owner retains payment rights after transferring ownership.

**Example scenario (mitigated):**
1. Alice owns agent #42 with wallet set to 0xABC
2. Alice transfers agent #42 to Bob
3. Without automatic clearing, 0xABC would still receive payments intended for Bob
4. With automatic clearing, Bob must re-verify a new wallet, ensuring payment control matches ownership

**Deadline Validation:**

The `set-agent-wallet-signed` function requires a `deadline` parameter that must satisfy:
- `deadline >= stacks-block-height` (not expired)
- `deadline <= stacks-block-height + MAX_DEADLINE_DELAY` (not too far in future)

Where `MAX_DEADLINE_DELAY = 1500` blocks (approximately 5 minutes at 200-second block times).

**Purpose:**
- **Replay attack prevention**: Signatures expire after the deadline, preventing old signatures from being reused
- **Clock skew tolerance**: The future deadline allows for reasonable network propagation delays
- **Bounded validity**: MAX_DEADLINE_DELAY prevents signatures from being valid indefinitely

**Chain-ID Binding:**

SIP-018 signatures include the `chain-id` in the domain hash, preventing cross-chain replay attacks. A signature valid on testnet (chain-id 2147483648) cannot be replayed on mainnet (chain-id 1).

**Key Rotation Recommendation:**

Applications should encourage users to rotate agent wallet keys regularly, especially for high-value agents. Since `set-agent-wallet-signed` signatures expire quickly (1500 blocks maximum), there's no long-term signature reuse risk, but compromised keys should still be rotated immediately.

**Wallet Separation Benefits:**

The agent wallet system's primary security benefit is separation of concerns: the owner key (which holds the NFT) can be a cold wallet or multisig, while the agent wallet can be a hot wallet used for frequent micropayments or protocol interactions. This limits exposure if the agent wallet is compromised—the attacker gains payment routing but not identity ownership.

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
- Ethereum (Solidity): https://github.com/erc-8004/erc-8004-contracts

## Testnet Deployments

The following contracts are deployed on Stacks testnet:

- Identity Registry: `ST3YT0XW92E6T2FE59B2G5N2WNNFSBZ6MZKQS5D18.identity-registry`
- Reputation Registry: `ST3YT0XW92E6T2FE59B2G5N2WNNFSBZ6MZKQS5D18.reputation-registry`
- Validation Registry: `ST3YT0XW92E6T2FE59B2G5N2WNNFSBZ6MZKQS5D18.validation-registry`

## Mainnet Deployments

Mainnet deployment addresses will be added upon activation.

# References

[1] SIP-018: Signed Structured Data - https://github.com/stacksgov/sips/blob/main/sips/sip-018/sip-018-signed-structured-data.md

[2] SIP-019: Notifications for Token Metadata Updates - https://github.com/stacksgov/sips/blob/main/sips/sip-019/sip-019-token-metadata-update-notifications.md

[3] ERC-8004: Agent Commerce Protocol - https://eips.ethereum.org/EIPS/eip-8004

[4] CAIP-2: Blockchain ID Specification - https://github.com/ChainAgnostic/CAIPs/blob/main/CAIPs/caip-2.md
