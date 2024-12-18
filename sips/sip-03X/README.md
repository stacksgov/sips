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
  - dx: Token A amount
  - dy: Token B amount  
  - dk: LP token amount

### Quote Function

```clarity
(quote (amount uint) (opcode (optional (buff 16))))
```

The quote function provides expected outputs for operations without execution:

- Amount: The primary input amount to quote
- Opcode: Same opcode buffer that would be used in execute
- Returns: Same tuple format as execute

## OPCODE Specification

The first byte of the opcode buffer determines the core operation:

| Value | Operation | Description |
|-------|-----------|-------------|
| 0x00 | SWAP_A_TO_B | Swap token A for token B |
| 0x01 | SWAP_B_TO_A | Swap token B for token A |
| 0x02 | ADD_LIQUIDITY | Add liquidity to pool |
| 0x03 | REMOVE_LIQUIDITY | Remove liquidity from pool |

### Operation Details

#### Swap Operations (0x00, 0x01)
- Amount represents input token quantity
- dx/dy represent input/output amounts
- dk is unused (zero)

#### Add Liquidity (0x02)
- Amount represents desired LP tokens
- dx/dy represent token deposits required
- dk represents LP tokens minted

#### Remove Liquidity (0x03)
- Amount represents LP tokens to burn
- dx/dy represent tokens returned
- dk represents LP tokens burned

## Implementation Guidelines

### Core Requirements

1. Must implement both execute and quote functions
2. Must handle missing/empty opcode buffer gracefully
3. Must return consistent tuple format for all operations
4. Must implement SIP-010 trait for LP token
5. Quote must accurately reflect execute behavior

### Security Considerations

1. Post conditions must be used for slippage protection
2. All state changes must occur atomically
3. Rounding must favor the pool
4. Operation validation must occur before state changes

### Best Practices

1. Document default behavior without opcodes
2. Use descriptive error codes
3. Validate parameter ranges
4. Include clear logging/events
5. Document fee structures

## Multi-Hop Router Integration

The standard enables efficient path execution through a router contract that can:

1. Chain multiple pool operations
2. Support routes up to 9 hops
3. Automatically propagate output amounts
4. Maintain consistent slippage protection

Example router functions:

```clarity
;; Single hop swap
(define-public (swap-1 
    (amount uint) 
    (hop-1 {pool: <pool-trait>, opcode: (optional (buff 16))}))
  (let ((result (try! (execute-swap amount hop-1))))
    (ok (list result))))

;; Multi-hop swap
(define-public (swap-2
    (amount uint)
    (hop-1 {pool: <pool-trait>, opcode: (optional (buff 16))})
    (hop-2 {pool: <pool-trait>, opcode: (optional (buff 16))}))
  (let (
    (result-1 (try! (execute-swap amount hop-1)))
    (result-2 (try! (execute-swap (get dy result-1) hop-2))))
    (ok (list result-1 result-2))))
```

# Applications

## Swap Aggregators
Aggregators implementing this standard can:
1. Query pools implementing the trait
2. Calculate optimal routes
3. Execute atomic multi-hop swaps
4. Provide accurate quotes

## Direct Integration
Applications directly integrating should:
1. Verify trait implementation
2. Get quotes before execution
3. Set appropriate post conditions
4. Handle operation failures gracefully

# Reference Implementation

A reference implementation demonstrating all core functionality is available at:
[Link to reference implementation](https://explorer.hiro.so/txid/SP2ZNGJ85ENDY6QRHQ5P2D4FXKGZWCKTB2T0Z55KS.dexterity-token?chain=mainnet)

It includes:
- Core pool implementation
- Multi-hop router
- Example integrations

# Future Extensions

The opcode buffer system enables future extensions without interface changes:

1. Oracle Integration (Bytes 4-7)
2. Advanced Routing (Bytes 8-11)  
3. Concentrated Liquidity (Bytes 12-13)
4. Limit Orders (Bytes 14-15)

# Activation

This SIP will be considered activated when:
1. The trait is deployed to mainnet
2. At least 3 different implementations are deployed
3. A functional swap aggregator demonstrates multi-hop capabilities

The trait and router designs have been battle-tested in production, with live implementations handling significant trading volume. This provides confidence in the interface design and its ability to support a robust DeFi ecosystem.
