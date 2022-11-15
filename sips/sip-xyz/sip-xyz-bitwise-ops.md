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

- Bitwise Xor (`bit-xor`)
- Bitwise And (`bit-and`)
- Bitwise Or (`bit-or`)
- Bitwise Not (`bit-not`)
- Binary Left Shift (`bit-shift-left`)
- Binary Right Shift (`bit-shift-right`)

# License and Copyright

This SIP is made available under the terms of the Creative Commons CC0 1.0
Universal license, available at
https://creativecommons.org/publicdomain/zero/1.0/ This SIP's copyright is held
by the Stacks Open Internet Foundation.

# Introduction

Bitwise operations are common in other programming languages. Common algorithms,
including many used in encryption, or the ability to set and check flags in a
bit field for example, would be much more difficult to implement without the use
of these operations. When executing a contract using these operations, the
common hardware on which miners and nodes are likely to be running can all
perform these operations very efficiently -- these are typically single cycle
operations. Note that the addition of these bitwise operations commits the
Clarity VM to using 2's complement to represent integers.

# Specification

## Bitwise Xor (`bit-xor`)

`(bit-xor i1 i2...)`

- **Inputs:** int, ... | uint, ...
- **Output:** int | uint

Returns the result of bitwise exclusive or'ing a variable number of integer
inputs.

### Examples

```
(bit-xor 1 2) ;; Returns 3
(bit-xor 120 280) ;; Returns 352
(bit-xor -128 64) ;; Returns -64
(bit-xor u24 u4) ;; Returns u28
(bit-xor 1 2 4 -1) ;; Returns -8
```

## Bitwise And (`bit-and`)

`(bit-and i1 i2...)`

- **Inputs:** int, ... | uint, ...
- **Output:** int | uint

Returns the result of bitwise and'ing a variable number of integer inputs.

### Examples

```
(bit-and 24 16) ;; Returns 16
(bit-and 28 24 -1) ;; Returns 24
(bit-and u24 u16) ;; Returns u16
(bit-and -128 -64) ;; Returns -128
(bit-and 28 24 -1) ;; Returns 24
```

## Bitwise Or (`bit-or`)

`(bit-or i1 i2...)`

- **Inputs:** int, ... | uint, ...
- **Outputs:** int | uint

Returns the result of bitwise inclusive or'ing a variable number of integer
inputs.

### Examples

```
(bit-or 4 8) ;; Returns 12
(bit-or 1 2 4) ;; Returns 7
(bit-or 64 -32 -16) ;; Returns -16
(bit-or u2 u4 u32) ;; Returns u38
```

## Bitwise Not (`bit-not`)

`(bit-not i1)`

- **Inputs:** int | uint
- **Output:** int | uint

Returns the one's compliment (sometimes also called the bitwise compliment or
not operator) of `i1`, effectively reversing the bits in `i1`.

In other words, every bit that is `1` in `ì1` will be `0` in the result.
Conversely, every bit that is `0` in `i1` will be `1` in the result.

### Examples

```
(bit-not 3) ;; Returns -4
(bit-not u128) ;; Returns u340282366920938463463374607431768211327
(bit-not 128) ;; Returns -129
(bit-not -128) ;; Returns 127
```

## Bitwise Left Shift (`bit-shift-left`)

`(bit-shift-left i1 shamt)`

- **Inputs:** int, uint | uint, uint
- **Outputs:** int | uint

Shifts all bits in `i1` to the left by the number of places specified in `shamt`
modulo 128 (the bit width of Clarity integers). New bits are filled with zeros.

Note that there is a deliberate choice made to ignore arithmetic overflow for
this operation. In use cases where overflow should be detected, developers
should use `*`, `/`, and `pow` instead of the shift operators.

### Examples

```
(bit-shift-left 16 u2) ;; Returns 64
(bit-shift-left -64 u1) ;; Returns -128
(bit-shift-left u4 u2) ;; Returns u16
(bit-shift-left 123 u9999999999) ;; Returns -170141183460469231731687303715884105728 (== 123 bit-shift-left 127)
(bit-shift-left u123 u9999999999) ;; Returns u170141183460469231731687303715884105728 (== u123 bit-shift-left 127)
(bit-shift-left -1 u7) ;; Returns -128
(bit-shift-left -1 u128) ;; Returns -1
```

## Bitwise Right Shift (`bit-shift-right`)

`(bit-shift-right i1 shamt)`

- **Inputs:** int, uint | uint, uint
- **Output:** int | uint

Shifts all the bits in `i1` to the right by the number of places specified in
`shamt` modulo 128 (the bit width of Clarity integers). When `i1` is a `uint`
(unsigned), new bits are filled with zeros. When `i1` is an `int` (signed), the
sign is preserved, meaning that new bits are filled with the value of the
previous sign-bit.

Note that there is a deliberate choice made to ignore arithmetic overflow for
this operation. In use cases where overflow should be detected, developers
should use `*`, `/`, and `pow` instead of the shift operators.

### Examples

```
(bit-shift-right 2 u1) ;; Returns 1
(bit-shift-right 128 u2) ;; Returns 32
(bit-shift-right -64 u1) ;; Returns -32
(bit-shift-right u128 u2) ;; Returns u32
(bit-shift-right 123 u9999999999) ;; Returns 0
(bit-shift-right u123 u9999999999) ;; Returns u0
(bit-shift-right -128 u7) ;; Returns -1
(bit-shift-right -256 u1) ;; Returns -128
(bit-shift-right 5 u2) ;; Returns 1
(bit-shift-right -5 u2) ;; Returns -2
```

# Related work

Not applicable

# Backwards Compatibility

Because this SIP introduces new Clarity operators, it is a consensus-breaking
change. A contract that uses one of these new operators would be invalid before
this SIP is activated, and valid after it is activated.

# Activation

This SIP will be a rider on SIP-015. It will be considered activated if and only
if SIP-015 (and Stacks 2.1) is activated.

# Reference Implementations

- https://github.com/stacks-network/stacks-blockchain/pull/3389
- See also discussions in
  https://github.com/stacks-network/stacks-blockchain/pull/3382
