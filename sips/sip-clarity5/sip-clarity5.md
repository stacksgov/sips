# Preamble

SIP Number: TBD

Title: Clarity 5: Fixing known issues in Clarity

Author(s):

- Brice Dobry <brice@stackslabs.com>

Status: Draft

Consideration: Governance, Technical

Type: Consensus

Layer: Consensus

Created: 2025-01-16

License: BSD-2-Clause

Sign-off:

Discussions-To:

- Link to where previous discussions took place. For example a mailing list or a
  Stacks Forum thread.

# Abstract

The goal of this version of Clarity is not to add any new features, but to
resolve known issues with existing functionality, specifically those that
require a hard-fork to change. The implementation for this SIP should only
resolve problems in the current Clarity implementation or make beneficial
changes to under-specified aspects of the Clarity language and virtual machine
(VM).

# Copyright

This SIP is made available under the terms of the BSD-2-Clause license,
available at https://opensource.org/licenses/BSD-2-Clause. This SIP’s copyright
is held by the Stacks Open Internet Foundation.

# Introduction

This SIP intends to solve the known issues in the implementation of the Clarity
VM, without making any changes to its intended behavior.

# Specification

## Resolve the discrepancy in `secp256r1-verify` described in SIP-035

In Clarity 5 and above, `secp256r1-verify` will no longer double-hash its input.

## Runtime error when passing an empty buffer to `from-consensus-buff?` (see issue [#6683](https://github.com/stacks-network/stacks-core/issues/6683))

Beginning in Clarity 5, computing the cost of passing an empty buffer to
`from-consensus-buff?` will no longer trigger a runtime error. Instead, the cost
will be charged appropriately, and the expression will return `none`, as
originally intended.

## Bug with `burn-block-height` inside an `at-block` expression (see issue [#6123](https://github.com/stacks-network/stacks-core/issues/6123))

In Clarity 5 and above, `burn-block-height` will return the correct value when
used inside of an `at-block` expression.

## Increased stack depth

Currently, the Clarity VM limits the call stack of a transaction execution to a
depth of 64 and several user applications have been hitting this limit recently.
This value was not specified in any previous SIPs, but was chosen to constrain
memory usage by the VM. Upon further testing, it has been determined that this
value can safely be increased to 128 without imposing u nreasonable requirements
on Stacks node runners. Effective in Clarity 5, the stack depth will be set
to 128.

## Rejectable transactions

Several kinds of errors have been avoided in the Clarity VM via a soft-fork
mechanism, causing transactions that trigger these problematic situations to be
rejected, not allowed to be included in a block. This strategy is useful for
quickly patching issues without requiring a hard-fork. However, once the
soft-fork is in place, the next time a hard-fork is executed, these errors can
all be transitioned to errors that can be included in a block. This is much
better for the network, since not including a transaction in a block has several
downsides:

- Miners cannot charge a fee for processing the transaction
- Users may be confused as to why their transaction is not being included,
  causing that transaction and all later transactions (with higher nonces) to
  stall
- These unmineable transactions remain in the mempool, unprocessed, until they
  age out

With the upgrade to Clarity 5, all outstanding "rejectable" errors will
transitioned to includable errors.

# Related Work

This SIP is focused on fixing consensus issues discovered in previous
implementations of Clarity, or improving behavior which is unspecified in prior
SIPs. The existing SIPs defining Clarity are:

- [SIP-002 (Clarity)](../sip-002/sip-002-smart-contract-language.md)
- [SIP-015 (Clarity 2)](../sip-015/sip-015-network-upgrade.md)
- [SIP-021 (Clarity 3)](../sip-021/sip-021-nakamoto.md)
- [SIP-033 (Clarity 4)](../sip-033/sip-033-clarity4.md)

# Backwards Compatibility

Clarity 5 will be implemented with these changes while maintaining backwards
compatibility for previous versions of Clarity. Existing contracts will continue
to execute with the existing behavior, but new contracts will default to
Clarity 5.

# Activation

Since this SIP only proposes fixes to the existing Clarity designs, it will not
require a community vote. In order to activate epoch 3.4 and Clarity 5, this SIP
must be approved by the Technical CAB and the Steering Committee. Once approved,
an activation height must be selected, allowing ample time for the changes to be
implemented, a release published, and community members to update. This block
height may be decided jointly by the Steering Committee, Technical CAB, and
Stacks core engineers implementing the changes.

# Reference Implementation

At the time of this writing, the following public implementations are available
so far:

- [`secp256r1-verify?` change](https://github.com/stacks-network/stacks-core/pull/6763)
- [`from-consensus-buff?` change](https://github.com/stacks-network/stacks-core/pull/6820)
