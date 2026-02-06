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

This SIP defines a standard set of traits for AI agent registries on the Stacks blockchain. It establishes three core registries: an Identity Registry for agent registration and ownership, a Reputation Registry for client feedback and scoring, and a Validation Registry for third-party verification. These traits enable interoperable agent identity, reputation tracking, and validation across applications built on Stacks, while maintaining compatibility with the ERC-8004 Agent Commerce Protocol for cross-chain agent identity.

# Copyright

This SIP is made available under the terms of the Creative Commons CC0 1.0 Universal license, available at https://creativecommons.org/publicdomain/zero/1.0/. This SIP's copyright is held by the Stacks Open Internet Foundation.

# Introduction

As AI agents become increasingly prevalent in blockchain ecosystems, there is a need for standardized on-chain identity, reputation, and validation mechanisms. Without common standards, each application must implement its own agent management system, leading to fragmentation and preventing agents from building portable reputations across platforms.

This SIP addresses three core requirements for agent commerce:

1. **Identity**: Agents need unique, verifiable identities with associated metadata and URIs pointing to off-chain information.

2. **Reputation**: Clients interacting with agents need a way to provide feedback and view aggregated reputation scores. This feedback system must support both on-chain approval and off-chain signature-based authorization via SIP-018 [1].

3. **Validation**: Third-party validators (such as auditors, compliance services, or capability verifiers) need a standardized way to approve or reject agents based on specific criteria.

The Stacks blockchain's programming language, Clarity, provides built-in primitives for defining traits that allow different smart contracts to interoperate. This SIP defines traits for agent registries that any compliant implementation must follow, enabling wallets, applications, and other contracts to interact with agent registries in a consistent manner.

This standard is designed to be compatible with ERC-8004, enabling cross-chain agent identity using the CAIP-2 multichain identifier format.

# Specification

The agent registry standard consists of three separate traits, each addressing a distinct aspect of agent management. Implementations may deploy these as separate contracts or combine them as appropriate.

## Identity Registry Trait

The Identity Registry manages agent registration, ownership, and metadata. Unlike SIP-009 NFTs, this registry uses direct ownership maps rather than NFT traits, as agents are not intended to be freely transferable assets.

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

Register a new agent with both a URI and initial metadata entries. The metadata entries allow storing up to 10 key-value pairs directly on-chain. Returns the newly assigned agent ID.

This method must be defined with `define-public`.

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

Set or update a metadata key-value pair for an agent. Only the agent owner or an approved operator may call this function.

This method must be defined with `define-public`.

| error code | reason |
| ---------- | ------ |
| u1000 | Caller is not authorized |
| u1001 | Agent does not exist |
| u1003 | Metadata set operation failed |

#### Set Approval for All

`(set-approval-for-all ((agent-id uint) (operator principal) (approved bool)) (response bool uint))`

Grant or revoke operator permissions for a specific agent. An approved operator can perform actions on behalf of the agent owner, such as updating URIs and metadata.

This method must be defined with `define-public`.

| error code | reason |
| ---------- | ------ |
| u1000 | Caller is not authorized |
| u1001 | Agent does not exist |

#### Owner Of

`(owner-of ((agent-id uint)) (response principal uint))`

Return the owner principal of the specified agent.

This method should be defined as read-only, i.e. `define-read-only`.

| error code | reason |
| ---------- | ------ |
| u1001 | Agent does not exist |

#### Get URI

`(get-uri ((agent-id uint)) (response (string-utf8 512) uint))`

Return the URI associated with the specified agent.

This method should be defined as read-only, i.e. `define-read-only`.

| error code | reason |
| ---------- | ------ |
| u1001 | Agent does not exist |

#### Get Metadata

`(get-metadata ((agent-id uint) (key (string-utf8 128))) (response (optional (buff 512)) uint))`

Return the value for a specific metadata key, or none if the key is not set.

This method should be defined as read-only, i.e. `define-read-only`.

#### Is Approved for All

`(is-approved-for-all ((agent-id uint) (operator principal)) (response bool uint))`

Check if the specified principal is an approved operator for the agent.

This method should be defined as read-only, i.e. `define-read-only`.

#### Get Version

`(get-version () (response (string-ascii 16) uint))`

Return the contract version string.

This method should be defined as read-only, i.e. `define-read-only`.

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

    ;; Get agent owner
    (owner-of (uint) (response principal uint))

    ;; Get agent URI
    (get-uri (uint) (response (string-utf8 512) uint))

    ;; Get metadata value for key
    (get-metadata (uint (string-utf8 128)) (response (optional (buff 512)) uint))

    ;; Check operator approval
    (is-approved-for-all (uint principal) (response bool uint))

    ;; Get contract version
    (get-version () (response (string-ascii 16) uint))
  )
)
```

## Reputation Registry Trait

The Reputation Registry enables clients to provide feedback on agents and allows agents to respond. It supports two authorization methods: on-chain approval and SIP-018 [1] signed structured data for off-chain authorization.

### Trait Functions

#### Approve Client

`(approve-client ((agent-id uint) (client principal) (max-index uint)) (response bool uint))`

Pre-authorize a client to provide feedback for an agent up to the specified index limit. Only the agent owner or approved operator may call this function.

This method must be defined with `define-public`.

| error code | reason |
| ---------- | ------ |
| u3000 | Caller is not authorized |
| u3001 | Agent does not exist |

#### Give Feedback

`(give-feedback ((agent-id uint) (score uint) (tags (list 10 (string-utf8 64))) (feedback-uri (string-utf8 512))) (response uint uint))`

Submit feedback for an agent. Requires prior on-chain approval via `approve-client`. Score must be between 0 and 100. Tags provide categorical labels for the feedback. The feedback-uri points to additional off-chain feedback data. Returns the feedback index.

This method must be defined with `define-public`.

| error code | reason |
| ---------- | ------ |
| u3000 | Caller is not authorized |
| u3001 | Agent does not exist |
| u3004 | Score exceeds maximum (100) |
| u3005 | Cannot provide feedback on self |
| u3010 | Feedback URI is empty |

#### Give Feedback Signed

`(give-feedback-signed ((agent-id uint) (score uint) (tags (list 10 (string-utf8 64))) (feedback-uri (string-utf8 512)) (signature (buff 65)) (auth-expiry uint)) (response uint uint))`

Submit feedback using SIP-018 [1] signed authorization instead of on-chain approval. The signature must be valid according to SIP-018 structured data signing, and the auth-expiry block height must not have passed.

This method must be defined with `define-public`.

| error code | reason |
| ---------- | ------ |
| u3001 | Agent does not exist |
| u3004 | Score exceeds maximum |
| u3005 | Cannot provide feedback on self |
| u3007 | Signature verification failed |
| u3008 | Authorization has expired |
| u3010 | Feedback URI is empty |

#### Revoke Feedback

`(revoke-feedback ((agent-id uint) (index uint)) (response bool uint))`

Revoke previously submitted feedback. Only the original feedback submitter may revoke their feedback.

This method must be defined with `define-public`.

| error code | reason |
| ---------- | ------ |
| u3000 | Caller is not authorized |
| u3002 | Feedback entry not found |
| u3003 | Feedback already revoked |

#### Append Response

`(append-response ((agent-id uint) (index uint) (response-uri (string-utf8 512))) (response bool uint))`

Allow an agent to respond to feedback. Only the agent owner or approved operator may respond.

This method must be defined with `define-public`.

| error code | reason |
| ---------- | ------ |
| u3000 | Caller is not authorized |
| u3002 | Feedback entry not found |

#### Read Feedback

`(read-feedback ((agent-id uint) (client principal) (index uint)) (response {score: uint, tags: (list 10 (string-utf8 64)), feedback-uri: (string-utf8 512), revoked: bool, block-height: uint} uint))`

Retrieve a specific feedback entry.

This method should be defined as read-only, i.e. `define-read-only`.

| error code | reason |
| ---------- | ------ |
| u3002 | Feedback entry not found |

#### Get Summary

`(get-summary ((agent-id uint) (filter-client (optional principal)) (filter-tags (optional (list 10 (string-utf8 64))))) (response {count: uint, average-score: uint, total-score: uint} uint))`

Calculate aggregate reputation metrics for an agent, optionally filtered by client or tags. Returns the count of feedback entries, average score, and total score.

This method should be defined as read-only, i.e. `define-read-only`.

#### Read All Feedback

`(read-all-feedback ((agent-id uint) (offset uint) (limit uint)) (response (list 50 {client: principal, index: uint, score: uint, tags: (list 10 (string-utf8 64)), revoked: bool}) uint))`

Retrieve paginated feedback entries for an agent. Maximum limit is 50 entries per call.

This method should be defined as read-only, i.e. `define-read-only`.

#### Get Responders

`(get-responders ((agent-id uint) (index uint)) (response (list 10 principal) uint))`

Get the list of principals who have responded to a specific feedback entry.

This method should be defined as read-only, i.e. `define-read-only`.

### Reputation Registry Trait Implementation

```clarity
(define-trait reputation-registry-trait
  (
    ;; Pre-authorize a client to provide feedback
    (approve-client (uint principal uint) (response bool uint))

    ;; Submit feedback with on-chain approval
    (give-feedback (uint uint (list 10 (string-utf8 64)) (string-utf8 512)) (response uint uint))

    ;; Submit feedback with SIP-018 signature
    (give-feedback-signed (uint uint (list 10 (string-utf8 64)) (string-utf8 512) (buff 65) uint) (response uint uint))

    ;; Revoke submitted feedback
    (revoke-feedback (uint uint) (response bool uint))

    ;; Respond to feedback
    (append-response (uint uint (string-utf8 512)) (response bool uint))

    ;; Read single feedback entry
    (read-feedback (uint principal uint) (response {score: uint, tags: (list 10 (string-utf8 64)), feedback-uri: (string-utf8 512), revoked: bool, block-height: uint} uint))

    ;; Get aggregate reputation summary
    (get-summary (uint (optional principal) (optional (list 10 (string-utf8 64)))) (response {count: uint, average-score: uint, total-score: uint} uint))

    ;; Read paginated feedback
    (read-all-feedback (uint uint uint) (response (list 50 {client: principal, index: uint, score: uint, tags: (list 10 (string-utf8 64)), revoked: bool}) uint))

    ;; Get responders to feedback
    (get-responders (uint uint) (response (list 10 principal) uint))
  )
)
```

## Validation Registry Trait

The Validation Registry enables third-party validators to approve or reject agents based on specific criteria such as compliance, capability verification, or audits.

### Trait Functions

#### Validation Request

`(validation-request ((agent-id uint) (validator principal) (request-hash (buff 32))) (response bool uint))`

Request validation from a specific validator. Only the agent owner or approved operator may initiate a request. The request-hash is a unique identifier for this validation request.

This method must be defined with `define-public`.

| error code | reason |
| ---------- | ------ |
| u2000 | Caller is not authorized |
| u2001 | Agent does not exist |
| u2003 | Validation request already exists |
| u2004 | Invalid validator (cannot be self) |

#### Validation Response

`(validation-response ((request-hash (buff 32)) (score uint) (response-hash (buff 32)) (tag (string-utf8 64))) (response bool uint))`

Submit a validation response. Only the designated validator for the request may respond. Score must be between 0 and 100, where 0 indicates rejection and higher scores indicate varying levels of approval.

This method must be defined with `define-public`.

| error code | reason |
| ---------- | ------ |
| u2000 | Caller is not the designated validator |
| u2002 | Validation request not found |
| u2005 | Score exceeds maximum (100) |

#### Get Validation Status

`(get-validation-status ((request-hash (buff 32))) (response {validator: principal, agent-id: uint, score: uint, response-hash: (buff 32), tag: (string-utf8 64), last-update: uint} uint))`

Retrieve the status of a validation request.

This method should be defined as read-only, i.e. `define-read-only`.

| error code | reason |
| ---------- | ------ |
| u2002 | Validation not found |

#### Get Summary

`(get-summary ((agent-id uint) (filter-validators (optional (list 10 principal))) (filter-tags (optional (list 10 (string-utf8 64))))) (response {count: uint, average-score: uint, total-score: uint} uint))`

Calculate aggregate validation metrics for an agent, optionally filtered by validators or tags.

This method should be defined as read-only, i.e. `define-read-only`.

#### Get Agent Validations

`(get-agent-validations ((agent-id uint)) (response (list 1024 (buff 32)) uint))`

Get all validation request hashes for an agent.

This method should be defined as read-only, i.e. `define-read-only`.

#### Get Validator Requests

`(get-validator-requests ((validator principal)) (response (list 1024 (buff 32)) uint))`

Get all validation request hashes assigned to a validator.

This method should be defined as read-only, i.e. `define-read-only`.

#### Get Identity Registry

`(get-identity-registry () (response principal uint))`

Return the principal of the linked Identity Registry contract.

This method should be defined as read-only, i.e. `define-read-only`.

#### Get Version

`(get-version () (response (string-ascii 16) uint))`

Return the contract version string.

This method should be defined as read-only, i.e. `define-read-only`.

### Validation Registry Trait Implementation

```clarity
(define-trait validation-registry-trait
  (
    ;; Request validation from a validator
    (validation-request (uint principal (buff 32)) (response bool uint))

    ;; Submit validation response
    (validation-response ((buff 32) uint (buff 32) (string-utf8 64)) (response bool uint))

    ;; Get validation status
    (get-validation-status ((buff 32)) (response {validator: principal, agent-id: uint, score: uint, response-hash: (buff 32), tag: (string-utf8 64), last-update: uint} uint))

    ;; Get aggregate validation summary
    (get-summary (uint (optional (list 10 principal)) (optional (list 10 (string-utf8 64)))) (response {count: uint, average-score: uint, total-score: uint} uint))

    ;; Get all validations for an agent
    (get-agent-validations (uint) (response (list 1024 (buff 32)) uint))

    ;; Get all requests for a validator
    (get-validator-requests (principal) (response (list 1024 (buff 32)) uint))

    ;; Get linked identity registry
    (get-identity-registry () (response principal uint))

    ;; Get contract version
    (get-version () (response (string-ascii 16) uint))
  )
)
```

## Error Code Summary

### Identity Registry Errors (u1000-u1999)

| error code | reason |
| ---------- | ------ |
| u1000 | Not authorized |
| u1001 | Agent not found |
| u1002 | Agent already exists |
| u1003 | Metadata set failed |

### Validation Registry Errors (u2000-u2999)

| error code | reason |
| ---------- | ------ |
| u2000 | Not authorized |
| u2001 | Agent not found |
| u2002 | Validation not found |
| u2003 | Validation already exists |
| u2004 | Invalid validator |
| u2005 | Invalid response score |

### Reputation Registry Errors (u3000-u3999)

| error code | reason |
| ---------- | ------ |
| u3000 | Not authorized |
| u3001 | Agent not found |
| u3002 | Feedback not found |
| u3003 | Feedback already revoked |
| u3004 | Invalid score (exceeds 100) |
| u3005 | Self-feedback not allowed |
| u3006 | Invalid index |
| u3007 | Signature verification failed |
| u3008 | Authorization expired |
| u3009 | Index limit exceeded |
| u3010 | Empty feedback URI |

# Multichain Identity

This standard supports cross-chain agent identity using CAIP-2 [4] compliant identifiers. This enables agents registered on Stacks to be referenced from other chains and vice versa.

## Identifier Format

```
stacks:<chainId>:<registry>:<agentId>
```

Where:
- `stacks` is the namespace identifier
- `<chainId>` is the chain identifier (1 for mainnet, 2147483648 for testnet)
- `<registry>` is the registry contract name
- `<agentId>` is the agent's numeric ID

## Chain Identifiers

| Network | Chain ID | Example |
| ------- | -------- | ------- |
| Stacks Mainnet | 1 | `stacks:1:identity-registry:42` |
| Stacks Testnet | 2147483648 | `stacks:2147483648:identity-registry:0` |

This format aligns with ERC-8004 [3] multichain identifiers, enabling consistent agent identity across Ethereum, Stacks, and other supported chains.

# Implementing in Wallets and Applications

Developers building applications that interact with agent registries should follow these guidelines:

## Validating Registry Contracts

Before interacting with a registry contract, applications should verify that the contract implements the appropriate trait. This can be done by checking the contract's interface or attempting to call read-only functions.

## Agent Metadata

The URI returned by `get-uri` should point to a JSON file with the following recommended schema:

```json
{
  "name": "Agent Name",
  "description": "Description of the agent's purpose and capabilities",
  "image": "https://example.com/agent-avatar.png",
  "capabilities": ["capability1", "capability2"],
  "endpoints": {
    "api": "https://api.example.com/agent",
    "websocket": "wss://ws.example.com/agent"
  },
  "version": "1.0.0"
}
```

## SIP-018 Signature Integration

For `give-feedback-signed`, the structured data domain and message should follow SIP-018 [1] conventions. The message should include:
- Agent ID
- Score
- Tags
- Feedback URI
- Expiry block height

Wallets implementing feedback functionality should provide clear UI for users to understand what they are signing.

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

# Related Work

## ERC-8004

This SIP is designed to be compatible with ERC-8004 [3], the Agent Commerce Protocol on Ethereum. Both standards define the same three registries (Identity, Reputation, Validation) with equivalent functionality, enabling cross-chain agent identity.

Key differences in the Stacks implementation:
- Uses Clarity traits instead of Solidity interfaces
- Leverages SIP-018 [1] for signed structured data instead of EIP-712
- Uses direct ownership maps instead of ERC-721 for identity (agents are not transferable)
- Follows SIP-019 [2] notification patterns for events

## Other Agent Standards

Various blockchain projects have proposed agent identity solutions, but most focus solely on identity without integrated reputation and validation. This standard's three-registry approach provides a more complete foundation for agent commerce.

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
