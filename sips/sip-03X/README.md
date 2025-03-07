# Preamble

SIP Number: 03X

Title: Standard Trait Definition for Liquidity Pools

Author: rozar.btc

Consideration: Technical

Type: Standard

Status: Draft

Created: 24 December 2024

License: CC0-1.0

Layer: Traits

Sign-off: [Sign Off]

Discussions-To: [URL]

# Abstract

This SIP defines a minimalist trait interface for liquidity pools on the Stacks blockchain. The standard enables independent implementation of liquidity pools while maintaining a unified interface, facilitating the development of swap aggregators and multi-hop transactions across multiple pools. The standard introduces an extensible opcode buffer system that enables advanced pool operations while maintaining a simple core interface.

# License and Copyright

This SIP is made available under the terms of the Creative Commons CC0 1.0 Universal license, available at https://creativecommons.org/publicdomain/zero/1.0/

# Introduction

Liquidity pools are a fundamental component of decentralized finance, enabling automated market making and token swapping capabilities. Each pool manages a pair of SIP-010 fungible tokens and mints LP tokens to track liquidity provider shares. The core operations include:

1. Adding liquidity (deposit both tokens)
2. Removing liquidity (burn LP tokens)
3. Swapping one token for another
4. Querying pool state and quotes

This standard introduces a unified execute/quote interface with an opcode buffer system that enables advanced pool operations while maintaining backward compatibility. This allows for:

- Consistent interaction patterns across different implementations
- Development of swap aggregators and routing engines
- Common tooling and integration patterns
- Future extensibility through optional opcodes

# Specification

## Core Interface

```clarity
(define-trait liquidity-pool-trait
  (
    (execute 
      (uint (optional (buff 16))) 
      (response (tuple (dx uint) (dy uint) (dk uint)) uint))
    (quote 
      (uint (optional (buff 16)))
      (response (tuple (dx uint) (dy uint) (dk uint)) uint))
  )
)
```

### Execute Function

```clarity
(execute (amount uint) (opcode (optional (buff 16))))
```

The execute function performs all pool operations based on the opcode provided:

- Amount: The primary input amount (interpretation depends on operation)
- Opcode: Optional 16-byte buffer encoding operation parameters
- Returns: Tuple containing amounts (dx, dy, dk) representing:
  - dx: Token A amount consumed
  - dy: Token B amount produced
  - dk: LP token amount minted/burned

### Quote Function

```clarity
(quote (amount uint) (opcode (optional (buff 16))))
```

The quote function provides expected outputs for operations without execution:

- Amount: The primary input amount to quote
- Opcode: Same opcode buffer that would be used in execute
- Returns: Same tuple format as execute

## OPCODE Specification

The opcode buffer is structured as follows:

| Byte Position | Description |
|---------------|-------------|
| 0 | Operation Type |
| 1 | Swap Type |
| 2 | Fee Type |
| 3 | Liquidity Type |
| 4-15 | Reserved for future use |

### Operation Types (Byte 0)

```clarity
(define-constant OP_SWAP_A_TO_B 0x00)     ;; Swap token A for B
(define-constant OP_SWAP_B_TO_A 0x01)     ;; Swap token B for A
(define-constant OP_ADD_LIQUIDITY 0x02)   ;; Add liquidity
(define-constant OP_REMOVE_LIQUIDITY 0x03) ;; Remove liquidity
```

### Swap Types (Byte 1)

```clarity
(define-constant SWAP_EXACT_INPUT 0x00)    ;; Exact input amount
(define-constant SWAP_EXACT_OUTPUT 0x01)   ;; Exact output amount
```

### Fee Types (Byte 2)

```clarity
(define-constant FEE_REDUCE_INPUT 0x00)    ;; Fee reduces input amount
(define-constant FEE_REDUCE_OUTPUT 0x01)   ;; Fee reduces output amount
(define-constant FEE_BURN_ENERGY 0x02)     ;; Fee burns protocol token
```

### Liquidity Types (Byte 3)

```clarity
(define-constant LIQUIDITY_BALANCED 0x00)  ;; Balanced liquidity add/remove
```

## Operation Details

### Swap Operations (0x00, 0x01)
- Amount represents exact input token quantity
- dx represents input amount after fees
- dy represents output amount
- dk is unused (zero)
- Fee calculation determined by byte 2 (FEE_TYPE)

### Add Liquidity (0x02)
- Amount represents desired LP tokens
- dx/dy represent token deposits required
- dk represents actual LP tokens minted
- Liquidity type in byte 3 determines ratio calculation

### Remove Liquidity (0x03)
- Amount represents LP tokens to burn
- dx/dy represent tokens returned
- dk represents LP tokens burned
- Liquidity type in byte 3 determines withdrawal strategy

## Implementation Guidelines

### Core Requirements

1. Must implement both execute and quote functions exactly as specified
2. Must handle missing/empty opcode by defaulting to SWAP_A_TO_B with FEE_REDUCE_INPUT
3. Must implement SIP-010 trait for LP token
4. Quote must accurately predict execute behavior
5. Must use consistent precision (6 decimals recommended)

### Security Considerations

1. Must implement comprehensive post conditions
2. All state changes must occur atomically
3. Rounding must favor the pool (floor for outputs)
4. Must validate opcode format before execution
5. Must implement proper principal checks

## Multi-Hop Router Integration

The standard enables path execution through a router contract with functions for 1-9 hops:

```clarity
;; Router function type pattern
(define-public (swap-{n}
    (amount uint)
    (hop-1 {pool: <pool-trait>, opcode: (optional (buff 16))})
    ...
    (hop-n {pool: <pool-trait>, opcode: (optional (buff 16))}))
    (response (list 9 {dx: uint, dy: uint, dk: uint}) uint))

;; Example single-hop implementation  
(define-public (swap-1 
    (amount uint) 
    (hop-1 {pool: <pool-trait>, opcode: (optional (buff 16))}))
  (let (
    (pool (get pool hop-1))
    (opcode (get opcode hop-1))
    (result (try! (contract-call? pool execute amount opcode))))
    (ok (list result))))
```

# Reference Implementation

A reference implementation demonstrating all core functionality is available in the Dexterity Protocol:

Contract: [SP2ZNGJ85ENDY6QRHQ5P2D4FXKGZWCKTB2T0Z55KS.dexterity-traits-v0]
SDK: [https://github.com/dexterity/sdk]

The implementation includes:
- Core pool implementation with full opcode support
- Multi-hop router supporting up to 5 hops
- TypeScript SDK for integration
- Comprehensive test suite

# Future Extensions

The opcode buffer system enables future extensions through reserved bytes:

1. Oracle Integration (Bytes 4-7)
   - Price feed integration
   - TWAP calculations
   - Dynamic fee adjustment

2. Advanced Routing (Bytes 8-11)
   - Split routes
   - Flash swap support
   - Cross-chain bridging

3. Advanced AMM Features (Bytes 12-15)
   - Concentrated liquidity
   - Range orders
   - Dynamic fees
   - Vault strategies

# Activation

This SIP will be considered activated when:
1. The trait is deployed to mainnet at SP2ZNGJ85ENDY6QRHQ5P2D4FXKGZWCKTB2T0Z55KS.dexterity-traits-v0
2. At least 3 different pool implementations adopt the trait
3. A functional swap aggregator demonstrates multi-hop capabilities across implementations

The trait and router designs have been battle-tested in production, with live implementations supporting multiple token pairs and significant trading volume.
