# Preamble

SIP Number: 03X

Title: Standard Trait Definition for Liquidity Pools

Author: rozar.btc

Consideration: Technical

Type: Standard

Status: Draft

Created: 10 December 2024

License: CC0-1.0

Layer: Traits

Sign-off: [Sign Off]

Discussions-To: [URL]

# Abstract

This SIP defines a standard trait interface for liquidity pools on the Stacks blockchain. The standard enables independent implementation of liquidity pools while maintaining a unified interface, facilitating the development of swap aggregators and multi-hop transactions across multiple pools.

# License and Copyright

This SIP is made available under the terms of the Creative Commons CC0 1.0 Universal license, available at https://creativecommons.org/publicdomain/zero/1.0/

# Introduction

Liquidity pools are a fundamental component of decentralized finance, enabling automated market making and token swapping capabilities. Each pool manages a pair of SIP-010 fungible tokens and provides functionality for:

1. Adding liquidity by depositing both tokens
2. Removing liquidity by burning LP tokens
3. Swapping one token for the other
4. Querying pool state and quotes

By standardizing the interface for liquidity pools, we enable:
- Consistent interaction patterns across different implementations
- Development of swap aggregators and routing engines
- Common tooling and integration patterns
- Future extensibility through memo commands

# Specification

## Core Functions

### Add Liquidity

```clarity
(add-liquidity 
  (
    (token-a-amount uint) 
    (token-b-amount uint)
    (memo (optional (buff 34)))
  ) 
  (response uint uint))
```

Adds liquidity by depositing both tokens, returns the amount of LP tokens minted.

### Remove Liquidity

```clarity
(remove-liquidity 
  (
    (lp-token-amount uint)
    (memo (optional (buff 34)))
  )
  (response (tuple (token-a uint) (token-b uint)) uint))
```

Burns LP tokens and returns both underlying tokens.

### Swap

```clarity
(swap
  (
    (token-in <ft-trait>)
    (amount-in uint)
    (memo (optional (buff 34)))
  )
  (response uint uint))
```

Swaps one token for the other. The output token is implictly determined by the pool token being passed in and/or if an optional memo is provided.

## Quote Functions

### Add Liquidity Quote

```clarity
(get-add-liquidity-quote
  (
    (token-a-amount uint)
    (token-b-amount uint)
    (memo (optional (buff 34)))
  )
  (response 
    (tuple (token-a uint) (token-b uint) (lp-tokens uint))
    uint))
```

Returns expected amounts for adding liquidity.

### Remove Liquidity Quote

```clarity
(get-remove-liquidity-quote
  (
    (lp-token-amount uint)
    (memo (optional (buff 34)))
  )
  (response 
    (tuple (token-a uint) (token-b uint) (lp-tokens uint))
    uint))
```

Returns expected amounts for removing liquidity.

### Swap Quote

```clarity
(get-swap-quote
  (
    (token-in <ft-trait>)
    (amount-in uint)
    (memo (optional (buff 34)))
  )
  (response (tuple (token-in uint) (token-out uint)) uint))
```

Returns expected amounts for a swap.

## Pool Information

```clarity
(get-pool-info () 
  (response
    (tuple
      (token-a (tuple (contract principal) (identifier (string-ascii 32)) (reserve uint)))
      (token-b (tuple (contract principal) (identifier (string-ascii 32)) (reserve uint)))
      (lp-token (tuple (contract principal) (identifier (string-ascii 32)) (supply uint)))
    )
    uint))
```

Returns comprehensive pool information including token contracts, identifiers, reserves and supply.

## Trait Implementation

```clarity
(define-trait liquidity-pool-trait
  (
    ;; Liquidity Operations
    (add-liquidity (uint uint (optional (buff 34))) (response uint uint))
    (remove-liquidity (uint (optional (buff 34))) 
      (response (tuple (token-a uint) (token-b uint)) uint))
    
    ;; Swap Operations
    (swap (<ft-trait> uint (optional (buff 34))) (response uint uint))
    
    ;; Quotes
    (get-add-liquidity-quote (uint uint (optional (buff 34))) 
      (response (tuple (token-a uint) (token-b uint) (lp-tokens uint)) uint))
    (get-remove-liquidity-quote (uint (optional (buff 34))) 
      (response (tuple (token-a uint) (token-b uint) (lp-tokens uint)) uint))
    (get-swap-quote (<ft-trait> uint (optional (buff 34))) 
      (response (tuple (token-in uint) (token-out uint)) uint))
    
    ;; Pool Information
    (get-pool-info () 
      (response
        (tuple
          (token-a (tuple (contract principal) (identifier (string-ascii 32)) (reserve uint)))
          (token-b (tuple (contract principal) (identifier (string-ascii 32)) (reserve uint)))
          (lp-token (tuple (contract principal) (identifier (string-ascii 32)) (supply uint)))
        )
        uint))
  )
)
```

# Implementation Guidelines

## Post Conditions
All slippage protection must be implemented using post conditions rather than explicit parameters. Implementations should set appropriate post conditions for:
- Minimum LP tokens when adding liquidity
- Minimum output tokens when removing liquidity
- Minimum output tokens when swapping

## Memo Support
- Pools may support advanced operations through memo buffers
- Memo command documentation is out of scope for this SIP
- Memo parsing should be robust and fail gracefully

# Applications

## Swap Aggregators
Aggregators implementing this standard should:
1. Query pool info to discover token pairs
2. Use quote functions to calculate optimal routes
3. Set appropriate post conditions for slippage protection

## Direct Integration
Applications directly integrating with pools should:
1. Verify pool and token contracts implement required traits
2. Use get-pool-info to fetch current state
3. Get quotes before executing operations
4. Set appropriate post conditions

# Reference Implementation

[Link to reference implementation repository]

# Activation

This SIP will be considered activated when:
1. The trait is deployed to mainnet
2. At least 3 different implementations are deployed
3. A functional swap aggregator demonstrates multi-hop capabilities
