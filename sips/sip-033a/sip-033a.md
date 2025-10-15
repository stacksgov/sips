# Preamble

SIP Number: 033-a

Title: Dimension specific tenure extend variants 

Author(s):

- Aaron Blankstein <aaron@stackslabs.com>

Status: Draft

Consideration: Technical

Type: Consensus

Layer: Consensus (hard fork)

Created: 2025-10-15

License: CC0-1.0

# Abstract

This SIP details a rider to SIP-033, including a new variant of the tenure change
control transaction. This variant allows the tenure change to specify a specific 
dimension of the block budget to reset.

# Copyright

This SIP is made available under the terms of the CC0 (Creative Commons Zero)
license, available at https://opensource.org/licenses/CC0-1.0. This SIP’s
copyright is held by the Stacks Open Internet Foundation.

# Introduction

The Stacks network controls total runtime and I/O expenditure during nakamoto tenures
via a total tenure budget. Costs are tracked using worst-case estimates of the actual
runtime or I/O expended to evaluate a given Clarity operation. In Nakamoto rules,
signers and miners may coordinate to include a tenure change payload which extends
the current tenure and resets the block limits for the tenure.

This mechanism allows the tenure budget to be reset if, e.g., there has been a long
delay between bitcoin blocks. However, if the assessed Clarity costs are much higher
than the actual runtime or I/O characteristics of the executed blocks (i.e., the actual
block runtime is much faster than the worst-case scenario around which costs are modeled),
signers and miners have limited ability to address this. This is because a mismatch in one
dimension (e.g., read-count) should not result in another dimension being reset (e.g., write-count).
Resetting all dimensions of the block budget when only one was misaligned would open the
network up to denial of service (unintentional or otherwise).

To address these concerns, this SIP proposes to add a new variant to tenure change payloads which
allows them to specify **which** dimension should be reset (or all of them).

# Protocol Specification

The serialization of the TenureChangePayload will be a backwards-compatible extension of
the existing SIP-021 serialization:

```
tenure consensus hash:	            20 bytes
previous tenure consensus hash:     20 bytes
burn view consensus hash:	        20 bytes
previous tenure end:	            32 bytes
previous tenure blocks:             4 bytes, big-endian
cause:                              1 byte
pubkey hash	20 bytes
```

The cause field serializes the new variant in a backwards compatible scheme:

```
0x00 indicates NewBlockFound    whole budget is reset
0x01 indicates Extend           whole budget is reset.
0x02 indicates Extend           read-count budget is reset.
0x03 indicates Extend           runtime budget is reset.
0x04 indicates Extend           read-length budget is reset.
0x05 indicates Extend           write-count budget is reset.
0x06 indicates Extend           write-length budget is reset.
```

# Activation

This is intended as a rider SIP to SIP-033. If voting on this SIP is
approved *and* voting on SIP-033 is approved, this SIP will activate with
SIP-033.
