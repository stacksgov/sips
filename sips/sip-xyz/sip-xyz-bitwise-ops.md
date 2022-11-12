# Preamble

SIP Number: XYZ

Title: Bitwise Operations in Clarity

Authors: Cyle Witruk <https://github.com/cylewitruk>, Brice Dobry
<https://github.com/obycode>

Consideration: Technical, Governance

Type: Consensus

Status: Draft

Created: 12 November 2022

License: CC0-1.0

Sign-off:

Layer: Consensus (hard fork)

Discussions-To: https://github.com/stacksgov/sips

# Abstract

This SIP adds bitwise operations to the Clarity language which could simplify
the implementation of smart contracts that require manipulation of bits. The
changes include the addition of the following operations:

- Bitwise Xor (`^`)
- Bitwise And (`&`)
- Bitwise Or (`|`)
- Bitwise Not (`~`)
- Binary Left Shift (`<<`)
- Binary Right Shift (`>>`)

# License and Copyright

This SIP is made available under the terms of the Creative Commons CC0 1.0
Universal license, available at
https://creativecommons.org/publicdomain/zero/1.0/ This SIP's copyright is held
by the Stacks Open Internet Foundation.

# Introduction

Bitwise operations are common in other programming languages. Common algorithms,
including many used in encryption for example, would be much more difficult to
implement without the use of these operations. When executing a contract using
these operations, the common hardware on which miners and nodes are likely to be
running can all perform these operations very efficiently -- these are typically
single cycle operations.

# Specification

## Bitwise Xor (`^`)

`(^ i1 i2...)`

- **Inputs:** int, ... | uint, ...
- **Output:** int | uint

Returns the result of bitwise exclusive or'ing a variable number of integer
inputs.

### Examples

```
(^ 1 2) ;; Returns 3
(^ 120 280) ;; Returns 352
(^ -128 64) ;; Returns -64
(^ u24 u4) ;; Returns u28
(^ 1 2 4 -1) ;; Returns -8
```

## Bitwise And (`&`)

`(& i1 i2...)`

- **Inputs:** int, ... | uint, ...
- **Output:** int | uint

Returns the result of bitwise and'ing a variable number of integer inputs.

### Examples

```
(& 24 16) ;; Returns 16
(& 28 24 -1) ;; Returns 24
(& u24 u16) ;; Returns u16
(& -128 -64) ;; Returns -128
(& 28 24 -1) ;; Returns 24
```

## Bitwise Or (`|`)

`(& i1 i2...)`

- **Inputs:** int, ... | uint, ...
- **Outputs:** int | uint

Returns the result of bitwise inclusive or'ing a variable number of integer
inputs.

### Examples

```
(| 4 8) ;; Returns 12
(| 1 2 4) ;; Returns 7
(| 64 -32 -16) ;; Returns -16
(| u2 u4 u32) ;; Returns u38
```

## Bitwise Not (`~`)

`(~ i1)`

- **Inputs:** int | uint
- **Output:** int | uint

Returns the result of bitwise not, effectively reversing the bits of `i1` (1's
complement).

### Examples

```
(~ 3) ;; Returns -4
(~ u128) ;; Returns u340282366920938463463374607431768211327
(~ 128) ;; Returns -129
(~ -128) ;; Returns 127
```

## Bitwise Left Shift (`<<`)

`(<< i1 i2)`

- **Inputs:** int, uint | uint, uint
- **Outputs:** int | uint

Shifts all the bits in `i1` to the left by the number of places specified in
`i2`. New bits are filled with zeros.

### Examples

```
(<< 2 u1) ;; Returns 4
(<< 16 u2) ;; Returns 64
(<< -64 u1) ;; Returns -128
(<< u4 u2) ;; Returns u16
(<< u240282366920938463463374607431768211327 u3) ;; Returns 30756142965880123323311949751266331049856
(<< u123 u24028236699) ;; Returns 0
```

## Bitwise Right Shift (`>>`)

`(>> i1 i2)`

- **Inputs:** int, uint | uint, uint
- **Output:** int | uint

Shifts all the bits in `i1` to the right by the number of places specified in
`i2`. When `i1` is a `uint` (unsigned), new bits are filled with zeros. When
`i1` is an `int` (signed), the sign is preserved, meaning that new bits are
filled with the value of the previous sign-bit.

### Examples

```
(>> 2 u1) ;; Returns 1
(>> 128 u2) ;; Returns 32
(>> -64 u1) ;; Returns -32
(>> u128 u2) ;; Returns u32
(>> u240282366920938463463374607431768211327 u2402823) ;; Returns u0
(>> -3 u300) ;; Returns -1
```

# Related work

Not applicable

# Backwards Compatibility

Because this SIP introduces new Clarity operators, it is a consensus-breaking
change. A contract that uses one of these new operators would be invalid before
this SIP is activated, and valid after it is activated.

# Activation

This SIP will be a rider on SIP-015. It will be considered activated if SIP-015
(and Stacks 2.1) is activated.

# Reference Implementations

- https://github.com/stacks-network/stacks-blockchain/pull/3389
