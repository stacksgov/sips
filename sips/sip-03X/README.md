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

This SIP defines a standard trait interface for liquidity pools on the Stacks blockchain. The standard enables independent implementation of liquidity pools while maintaining a unified interface, facilitating the development of swap aggregators and multi-hop transactions across multiple pools. The standard introduces an extensible opcode buffer system for advanced pool operations.

# License and Copyright

This SIP is made available under the terms of the Creative Commons CC0 1.0 Universal license, available at https://creativecommons.org/publicdomain/zero/1.0/

# Introduction

Liquidity pools are a fundamental component of decentralized finance, enabling automated market making and token swapping capabilities. Each pool manages a pair of SIP-010 fungible tokens and provides functionality for:

1. Adding liquidity by depositing both tokens
2. Removing liquidity by burning LP tokens
3. Swapping one token for the other
4. Querying pool state and quotes

The standard introduces an opcode buffer system that enables advanced pool operations while maintaining backward compatibility. This allows for future extensions such as concentrated liquidity, flash loans, and advanced routing without requiring interface changes. By standardizing the interface for liquidity pools, we enable:

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
    (amount uint) 
    (opcode (optional (buff 16)))
  ) 
  (response 
    (tuple (dx uint) (dy uint) (dk uint)) 
    uint))
```

Adds liquidity by depositing proportional amounts of both tokens. Returns a tuple containing the amounts of token A (dx), token B (dy), and LP tokens minted (dk).

### Remove Liquidity

```clarity
(remove-liquidity 
  (
    (amount uint)
    (opcode (optional (buff 16)))
  )
  (response 
    (tuple (dx uint) (dy uint) (dk uint)) 
    uint))
```

Burns LP tokens and returns both underlying tokens. The tuple contains the amounts of token A (dx), token B (dy), and LP tokens burned (dk).

### Swap

```clarity
(swap
  (
    (amount uint)
    (opcode (optional (buff 16)))
  )
  (response uint uint))
```

Swaps one token for another. The direction of the swap is determined by the first byte of the opcode buffer (0x00 for token A input, 0x01 for token B input).

## Quote Functions

### Add Liquidity Quote

```clarity
(get-add-liquidity-quote
  (
    (amount uint)
    (opcode (optional (buff 16)))
  )
  (response 
    (tuple (dx uint) (dy uint) (dk uint))
    uint))
```

Returns expected amounts for adding liquidity.

### Remove Liquidity Quote

```clarity
(get-remove-liquidity-quote
  (
    (amount uint)
    (opcode (optional (buff 16)))
  )
  (response 
    (tuple (dx uint) (dy uint) (dk uint))
    uint))
```

Returns expected amounts for removing liquidity.

### Swap Quote

```clarity
(get-swap-quote
  (
    (amount uint)
    (opcode (optional (buff 16)))
  )
  (response 
    (tuple (dx uint) (dy uint))
    uint))
```

Returns expected amounts for a swap.



## Trait Implementation

```clarity
(define-trait liquidity-pool-trait
  (
    ;; Liquidity Operations
    (add-liquidity (uint (optional (buff 16))) 
      (response (tuple (dx uint) (dy uint) (dk uint)) uint))
    (remove-liquidity (uint (optional (buff 16))) 
      (response (tuple (dx uint) (dy uint) (dk uint)) uint))
    
    ;; Swap Operations
    (swap (uint (optional (buff 16))) (response uint uint))
    
    ;; Quotes
    (get-add-liquidity-quote (uint (optional (buff 16))) 
      (response (tuple (dx uint) (dy uint) (dk uint)) uint))
    (get-remove-liquidity-quote (uint (optional (buff 16))) 
      (response (tuple (dx uint) (dy uint) (dk uint)) uint))
    (get-swap-quote (uint (optional (buff 16))) 
      (response (tuple (dx uint) (dy uint)) uint))
    
  )
)
```

# Implementation Guidelines

## AMM Design Flexibility
- Implementations may use any pricing formula or AMM design
- Quote functions must accurately reflect the actual behavior of the pool
- Pool behavior can be modified through opcode parameters

## Fee Structure
- Fees and rebates can be implemented freely
- Quote functions must accurately reflect all fees and rebates
- Fee behavior can be modified through opcode parameters

## Liquidity Operations
- Default behavior for add-liquidity should be documented
- Opcode parameters can modify liquidity allocation
- Support for single-sided, imbalanced, and oracle-weighted deposits

## Post Conditions
- All slippage protection must be implemented using post conditions
- Post conditions should account for any opcode-modified behavior

## Opcode Buffer Implementation
- Must handle missing or partial opcode buffers gracefully
- Unknown opcodes should be ignored
- Default behavior must be clearly documented
- All opcode-modified behaviors must be reflected in quotes

# Applications

## Swap Aggregators
Aggregators implementing this standard should:
1. Query pool info to discover token pairs and reserves
2. Use quote functions to calculate optimal routes
3. Set appropriate post conditions for slippage protection
4. Properly construct opcode buffers for complex operations

## Direct Integration
Applications directly integrating with pools should:
1. Verify pool and token contracts implement required traits
2. Use get-pool-info to fetch current state
3. Get quotes before executing operations
4. Handle opcode buffer construction appropriately

# Reference Implementation

[Link to reference implementation repository](https://explorer.hiro.so/txid/SP2ZNGJ85ENDY6QRHQ5P2D4FXKGZWCKTB2T0Z55KS.dexterity-token?chain=mainnet)

# OPCODE Buffer Specification

The OPCODE buffer is a powerful 16-byte buffer that enables advanced pool operations through compact parameter encoding. This section provides detailed documentation for implementing and using the OPCODE system.

## OPCODE Table

| Byte Position | Bit Position | Section | Status | Function | Values | Description |
|--------------|--------------|---------|---------|-----------|---------|-------------|
| 0            | 0-1         | 1.1     | Implemented | Token Direction | 0x00: Token A input (default) | Controls swap direction |
|              |             |         |           |             | 0x01: Token B input | |
|              | 2-7         | -       | Reserved | - | - | Reserved for future use |
| 1            | 0-7         | 2.1     | Proposed | Swap Type | 0x00: Exact input (default) | Controls swap execution |
|              |             |         |           |             | 0x01: Exact output | |
|              |             |         |           |             | 0x02-0xFF: Reserved | |
| 2            | 0-7         | 2.2     | Proposed | Fee Control | 0x00: Default fees | Modifies fee behavior |
|              |             |         |           |             | 0x01: Reduced fees | |
|              |             |         |           |             | 0x02: Dynamic fees | |
|              |             |         |           |             | 0x03: Oracle fees | |
| 3            | 0-7         | 2.3     | Proposed | Liquidity | 0x00: Balanced (default) | Controls liquidity addition |
|              |             |         |           |             | 0x01: Single-sided A | |
|              |             |         |           |             | 0x02: Single-sided B | |
|              |             |         |           |             | 0x03: Oracle-weighted | |
| 4-7          | 0-31        | 2.4     | Proposed | Oracle | Various | Price oracle integration |
| 8-11         | 0-31        | 2.5     | Proposed | Routing | Various | Route optimization |
| 12-13        | 0-15        | 2.6     | Proposed | Concentrated | Various | Concentrated liquidity |
| 14-15        | 0-15        | 2.7     | Proposed | Limit Orders | Various | Limit order parameters |

## Table of Contents

1. Implemented Operations
   1. Token Direction (Byte 0, Bits 0-1)

2. Proposed Operations
   1. Swap Type (Byte 1)
   2. Fee Control (Byte 2)
   3. Liquidity Addition (Byte 3)
   4. Oracle Integration (Bytes 4-7)
   5. Route Optimization (Bytes 8-11)
   6. Concentrated Liquidity (Bytes 12-13)
   7. Limit Orders (Bytes 14-15)

3. Future Extensions
   1. Flash Loans
   2. Yield Farming
   3. Governance
   4. MEV Protection

## Buffer Structure
The buffer consists of 16 bytes (128 bits) that can encode various parameters and flags to modify pool behavior. Each section below details the specific byte ranges and their purposes.

## 1. Implemented Operations

### 1.1 Token Direction (Byte 0, Bits 0-1)
Controls the direction of token flow in swap operations.

Values:
- 0x00: Token A is input token (default)
- 0x01: Token B is input token

Implementation Notes:
- Must be checked first in swap operations
- Affects quote calculations
- Remaining bits (2-7) reserved for future use

## 2. Theoretical Operations

### 2.1 Swap Type (Byte 1)
Controls exact input vs exact output behavior

Possible Values:
- 0x00: Exact input amount (default)
- 0x01: Exact output amount
- 0x02-0xFF: Reserved for future swap types

Implementation Notes:
- Affects quote calculation methodology
- Must be considered in slippage calculations
- Can be combined with fee modifications

### 2.2 Fee Modification (Byte 2)
Enables dynamic fee structures and custom rebate models

Possible Values:
- 0x00: Default pool fees
- 0x01: Reduced fees with utility token burn
- 0x02: Dynamic fees based on pool imbalance
- 0x03: Oracle-based fees
- 0x04-0xFF: Reserved for future fee models

Implementation Notes:
- Can modify both swap fees and LP rewards
- Could interact with governance systems
- Must be reflected in quote calculations

### 2.3 Liquidity Addition Control (Byte 3)
Enables advanced liquidity provision strategies

Possible Values:
- 0x00: Balanced deposit (default)
- 0x01: Single-sided Token A
- 0x02: Single-sided Token B
- 0x03: Oracle-weighted deposit
- 0x04: Imbalanced custom ratio
- 0x05-0xFF: Reserved for future strategies

Implementation Notes:
- Affects add-liquidity behavior
- Must update pool balances correctly
- Should consider price impact

### 2.4 Oracle Integration (Bytes 4-7)
Enables price oracle integration and TWAP calculations

Byte Structure:
- Bytes 4-5: Oracle parameters
- Bytes 6-7: Time window

Implementation Notes:
- Can be used for price feeds
- Enables advanced pricing models
- Supports external oracle integration

### 2.5 Route Optimization (Bytes 8-11)
Enables advanced routing and arbitrage features

Byte Structure:
- Byte 8: Route flags
- Bytes 9-11: Route parameters

Implementation Notes:
- Supports multi-hop operations
- Enables atomic arbitrage
- Can specify route preferences

### 2.6 Concentrated Liquidity (Bytes 12-13)
Enables Uniswap V3 style concentrated liquidity

Byte Structure:
- Byte 12: Tick spacing and range
- Byte 13: Position parameters

Implementation Notes:
- Defines liquidity ranges
- Supports multiple positions
- Enables fee tier selection

### 2.7 Limit Orders (Bytes 14-15)
Enables limit order functionality

Byte Structure:
- Byte 14: Order type and flags
- Byte 15: Time parameters

Implementation Notes:
- Supports price limits
- Enables time-based execution
- Can implement stop-loss orders

## 3. Future Extension Possibilities

### 3.1 Flash Loans
- Loan amount encoding
- Collateral requirements
- Repayment terms

### 3.2 Yield Farming
- Boost multipliers
- Program participation
- Reward distribution

### 3.3 Governance
- Voting weight calculation
- Parameter updates
- Protocol integration

### 3.4 MEV Protection
- Transaction ordering
- Sandwich protection
- Front-running mitigation

## Developer Guidelines

### Error Handling
- Invalid opcodes should not cause failures
- Unknown values should use defaults
- Partial buffers must be supported

### Testing
- Test all opcode combinations
- Verify quote accuracy
- Validate state transitions

### Documentation
- Document all supported opcodes
- Provide usage examples
- Keep modification history

### Security Considerations
- Validate all parameters
- Check state transitions
- Prevent value extraction

# Activation

This SIP will be considered activated when:
1. The trait is deployed to mainnet
2. At least 3 different implementations are deployed
3. A functional swap aggregator demonstrates multi-hop capabilities
