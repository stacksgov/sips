# SIP Implementation Guidelines

This document provides guidelines for implementing Stacks Improvement Proposals (SIPs) in your smart contracts and applications.

## Table of Contents

1. [Token Standards](#token-standards)
2. [SIP-009 NFT Implementation](#sip-009-nft-implementation)
3. [SIP-010 Fungible Token Implementation](#sip-010-fungible-token-implementation)
4. [SIP-013 Semi-Fungible Token Implementation](#sip-013-semi-fungible-token-implementation)
5. [Testing Your Implementation](#testing-your-implementation)
6. [Common Pitfalls](#common-pitfalls)

## Token Standards

The Stacks ecosystem has standardized token interfaces that ensure interoperability across wallets, exchanges, and applications.

| SIP | Type | Purpose |
|-----|------|---------|
| SIP-009 | NFT | Non-fungible tokens (unique items) |
| SIP-010 | FT | Fungible tokens (currencies, points) |
| SIP-013 | SFT | Semi-fungible tokens (editions, game items) |

## SIP-009 NFT Implementation

### Trait Definition

```clarity
(define-trait sip009-nft-trait
  (
    ;; Last token ID, limited to uint range
    (get-last-token-id () (response uint uint))
    
    ;; URI for metadata associated with the token
    (get-token-uri (uint) (response (optional (string-ascii 256)) uint))
    
    ;; Owner of a given token identifier
    (get-owner (uint) (response (optional principal) uint))
    
    ;; Transfer from the sender to a new principal
    (transfer (uint principal principal) (response bool uint))
  )
)
```

### Complete Implementation Example

```clarity
;; SIP-009 NFT Contract Example
(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

;; Define the NFT
(define-non-fungible-token my-nft uint)

;; Data vars
(define-data-var last-token-id uint u0)
(define-data-var base-uri (string-ascii 200) "https://api.example.com/nft/")

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-token-not-found (err u102))

;; SIP-009 Functions
(define-read-only (get-last-token-id)
  (ok (var-get last-token-id))
)

(define-read-only (get-token-uri (token-id uint))
  (ok (some (var-get base-uri)))
)

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? my-nft token-id))
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    ;; Verify ownership
    (asserts! (is-eq tx-sender sender) err-not-token-owner)
    (asserts! (is-some (nft-get-owner? my-nft token-id)) err-token-not-found)
    
    ;; Execute transfer
    (try! (nft-transfer? my-nft token-id sender recipient))
    (ok true)
  )
)

;; Mint function (admin only)
(define-public (mint (recipient principal))
  (let ((token-id (+ (var-get last-token-id) u1)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (try! (nft-mint? my-nft token-id recipient))
    (var-set last-token-id token-id)
    (ok token-id)
  )
)

;; Burn function
(define-public (burn (token-id uint))
  (begin
    (asserts! (is-eq (some tx-sender) (nft-get-owner? my-nft token-id)) err-not-token-owner)
    (nft-burn? my-nft token-id tx-sender)
  )
)
```

### Metadata JSON Standard

```json
{
  "name": "My NFT #1",
  "description": "A unique digital collectible",
  "image": "ipfs://QmXx.../1.png",
  "attributes": [
    {
      "trait_type": "Background",
      "value": "Blue"
    },
    {
      "trait_type": "Rarity",
      "value": "Legendary"
    },
    {
      "trait_type": "Power",
      "value": 95,
      "display_type": "number"
    }
  ],
  "external_url": "https://example.com/nft/1"
}
```

## SIP-010 Fungible Token Implementation

### Trait Definition

```clarity
(define-trait sip010-ft-trait
  (
    ;; Transfer tokens to a specified principal
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    
    ;; Get token name
    (get-name () (response (string-ascii 32) uint))
    
    ;; Get token symbol
    (get-symbol () (response (string-ascii 32) uint))
    
    ;; Get decimal places
    (get-decimals () (response uint uint))
    
    ;; Get balance of principal
    (get-balance (principal) (response uint uint))
    
    ;; Get total supply
    (get-total-supply () (response uint uint))
    
    ;; Get token URI
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)
```

### Complete Implementation Example

```clarity
;; SIP-010 Fungible Token Example
(impl-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)

(define-fungible-token my-token)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-balance (err u101))
(define-constant err-invalid-sender (err u102))

;; Data vars
(define-data-var token-uri (optional (string-utf8 256)) 
  (some u"https://example.com/token-metadata.json"))

;; SIP-010 Functions
(define-read-only (get-name)
  (ok "My Token")
)

(define-read-only (get-symbol)
  (ok "MTK")
)

(define-read-only (get-decimals)
  (ok u6)
)

(define-read-only (get-balance (account principal))
  (ok (ft-get-balance my-token account))
)

(define-read-only (get-total-supply)
  (ok (ft-get-supply my-token))
)

(define-read-only (get-token-uri)
  (ok (var-get token-uri))
)

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    ;; Verify sender authorization
    (asserts! (is-eq tx-sender sender) err-invalid-sender)
    
    ;; Execute transfer
    (try! (ft-transfer? my-token amount sender recipient))
    
    ;; Print memo if provided
    (match memo to-print (print to-print) 0x)
    
    (ok true)
  )
)

;; Mint function (owner only)
(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ft-mint? my-token amount recipient)
  )
)

;; Burn function
(define-public (burn (amount uint))
  (ft-burn? my-token amount tx-sender)
)
```

## SIP-013 Semi-Fungible Token Implementation

### Trait Definition

```clarity
(define-trait sip013-semi-fungible-token-trait
  (
    ;; Transfer amount of token with given ID
    (transfer (uint uint principal principal) (response bool uint))
    
    ;; Transfer many tokens
    (transfer-many ((list 200 {token-id: uint, amount: uint, sender: principal, recipient: principal})) (response bool uint))
    
    ;; Get balance of token ID for principal
    (get-balance (uint principal) (response uint uint))
    
    ;; Get overall balance for principal
    (get-overall-balance (principal) (response uint uint))
    
    ;; Get total supply of token ID
    (get-total-supply (uint) (response uint uint))
    
    ;; Get overall supply
    (get-overall-supply () (response uint uint))
    
    ;; Get decimals
    (get-decimals (uint) (response uint uint))
    
    ;; Get token URI
    (get-token-uri (uint) (response (optional (string-ascii 256)) uint))
  )
)
```

### Implementation Example

```clarity
;; SIP-013 Semi-Fungible Token Example
(impl-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip013-semi-fungible-token-trait.sip013-semi-fungible-token-trait)

;; Storage
(define-map token-balances {token-id: uint, owner: principal} uint)
(define-map token-supplies uint uint)
(define-map token-uris uint (string-ascii 256))
(define-data-var total-supply uint u0)

;; Constants
(define-constant err-insufficient-balance (err u1))
(define-constant err-invalid-sender (err u2))

;; Get balance
(define-read-only (get-balance (token-id uint) (who principal))
  (ok (default-to u0 (map-get? token-balances {token-id: token-id, owner: who})))
)

;; Get overall balance
(define-read-only (get-overall-balance (who principal))
  ;; Simplified - would need to iterate all token IDs
  (ok u0)
)

;; Get total supply of token ID
(define-read-only (get-total-supply (token-id uint))
  (ok (default-to u0 (map-get? token-supplies token-id)))
)

;; Get overall supply
(define-read-only (get-overall-supply)
  (ok (var-get total-supply))
)

;; Get decimals (all tokens have same decimals)
(define-read-only (get-decimals (token-id uint))
  (ok u0) ;; NFT-like, no decimals
)

;; Get token URI
(define-read-only (get-token-uri (token-id uint))
  (ok (map-get? token-uris token-id))
)

;; Transfer
(define-public (transfer (token-id uint) (amount uint) (sender principal) (recipient principal))
  (let (
    (sender-balance (default-to u0 (map-get? token-balances {token-id: token-id, owner: sender})))
  )
    (asserts! (is-eq tx-sender sender) err-invalid-sender)
    (asserts! (>= sender-balance amount) err-insufficient-balance)
    
    ;; Update balances
    (map-set token-balances {token-id: token-id, owner: sender} (- sender-balance amount))
    (map-set token-balances {token-id: token-id, owner: recipient}
      (+ (default-to u0 (map-get? token-balances {token-id: token-id, owner: recipient})) amount))
    
    (ok true)
  )
)

;; Transfer many
(define-public (transfer-many (transfers (list 200 {token-id: uint, amount: uint, sender: principal, recipient: principal})))
  (fold transfer-many-iter transfers (ok true))
)

(define-private (transfer-many-iter 
  (item {token-id: uint, amount: uint, sender: principal, recipient: principal}) 
  (prev-result (response bool uint)))
  (match prev-result
    success (transfer (get token-id item) (get amount item) (get sender item) (get recipient item))
    error (err error)
  )
)
```

## Testing Your Implementation

### Unit Tests with Clarinet

```typescript
// tests/my-nft_test.ts
import { Clarinet, Tx, Chain, Account, types } from 'clarinet';
import { assertEquals } from 'std/testing/asserts';

Clarinet.test({
  name: "Ensure NFT can be minted",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('my-nft', 'mint', [types.principal(wallet1.address)], deployer.address)
    ]);
    
    assertEquals(block.receipts.length, 1);
    assertEquals(block.receipts[0].result, types.ok(types.uint(1)));
    
    // Verify ownership
    let ownerResult = chain.callReadOnlyFn(
      'my-nft',
      'get-owner',
      [types.uint(1)],
      deployer.address
    );
    assertEquals(ownerResult.result, types.ok(types.some(types.principal(wallet1.address))));
  }
});

Clarinet.test({
  name: "Ensure NFT transfer works correctly",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    const wallet2 = accounts.get('wallet_2')!;
    
    // Mint NFT to wallet1
    let block = chain.mineBlock([
      Tx.contractCall('my-nft', 'mint', [types.principal(wallet1.address)], deployer.address)
    ]);
    
    // Transfer from wallet1 to wallet2
    block = chain.mineBlock([
      Tx.contractCall(
        'my-nft',
        'transfer',
        [types.uint(1), types.principal(wallet1.address), types.principal(wallet2.address)],
        wallet1.address
      )
    ]);
    
    assertEquals(block.receipts[0].result, types.ok(types.bool(true)));
    
    // Verify new owner
    let ownerResult = chain.callReadOnlyFn(
      'my-nft',
      'get-owner',
      [types.uint(1)],
      deployer.address
    );
    assertEquals(ownerResult.result, types.ok(types.some(types.principal(wallet2.address))));
  }
});
```

### Integration Tests

```typescript
// Verify your contract works with wallets and marketplaces
Clarinet.test({
  name: "Verify SIP-009 trait compliance",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    
    // All SIP-009 functions should be callable
    const functions = [
      { name: 'get-last-token-id', args: [] },
      { name: 'get-token-uri', args: [types.uint(1)] },
      { name: 'get-owner', args: [types.uint(1)] }
    ];
    
    for (const fn of functions) {
      const result = chain.callReadOnlyFn(
        'my-nft',
        fn.name,
        fn.args,
        deployer.address
      );
      
      // Should return ok response
      assert(result.result.includes('ok'));
    }
  }
});
```

## Common Pitfalls

### 1. Missing Trait Implementation

```clarity
;; WRONG - Missing trait functions
(define-non-fungible-token my-nft uint)

;; RIGHT - Implement all required trait functions
(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

(define-non-fungible-token my-nft uint)

(define-read-only (get-last-token-id) ...)
(define-read-only (get-token-uri (id uint)) ...)
(define-read-only (get-owner (id uint)) ...)
(define-public (transfer (id uint) (sender principal) (recipient principal)) ...)
```

### 2. Incorrect Transfer Authorization

```clarity
;; WRONG - No sender verification
(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (nft-transfer? my-nft token-id sender recipient)
)

;; RIGHT - Verify sender is tx-sender
(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) err-not-token-owner)
    (nft-transfer? my-nft token-id sender recipient)
  )
)
```

### 3. Not Handling Optional Memo in FT Transfers

```clarity
;; WRONG - Ignoring memo entirely
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (ft-transfer? my-token amount sender recipient)
)

;; RIGHT - Print memo for indexers
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (try! (ft-transfer? my-token amount sender recipient))
    (match memo to-print (print to-print) 0x)
    (ok true)
  )
)
```

### 4. Incorrect Return Types

```clarity
;; WRONG - Boolean instead of response
(define-read-only (get-owner (token-id uint))
  (some tx-sender)
)

;; RIGHT - Wrapped in response
(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? my-nft token-id))
)
```

## Additional Resources

- [SIP Repository](https://github.com/stacksgov/sips)
- [Clarity Language Reference](https://docs.stacks.co/clarity)
- [Clarinet Testing Framework](https://github.com/hirosystems/clarinet)

---

*This guide is maintained by the community. Contributions welcome!*
