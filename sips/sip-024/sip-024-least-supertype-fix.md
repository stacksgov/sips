# Preamble

SIP Number: 024

Title: Emergency Fix to Data Validation and Serialization Behavior

Authors:
    Aaron Blankstein <aaron@hiro.so>,
    Brice Dobry <brice@hiro.so>,
    Jude Nelson <jude@stacks.org>,
    Pavitthra Pandurangan <pavitthra@stacks.org>,

Consideration: Technical, Governance

Type: Consensus

Status: Ratified

Created: 11 May 2023

License: BSD 2-Clause

Sign-off: Jason Shrader <jason@joinfreehold.com> (Governance CAB Chair), Brice Dobry <brice@hiro.so> (Technical CAB Chair), Jude Nelson <jude@stacks.org> (Steering Committee Chair)

Discussions-To: https://github.com/stacksgov/sips

# Abstract

On 8 May 2023, a critical Denial-of-Service vulnerability manifested
in the Stacks network. While the initial DoS threat was remedied
through a non-consensus breaking hotfix, the underlying bug that
triggered the vulnerability requires consensus changes to fix.
This underlying bug has existed in the Stacks blockchain implementation
since the launch of Stacks 2.0, and has the potential to impact the
functionality of contracts even if they do not currently rely on the
buggy behavior.

This SIP proposes a **consensus-breaking change** to be included in
the SIP-022 hardfork (Epoch 2.4) to remediate this negative impact.

# Introduction

Stacks 2.0 allows contracts to include tuple types with _extra_ fields
to be included in lists with tuples with fewer fields:

```clarity
(list (tuple (a 1)) (tuple (b 1) (a 1)))
```

The Clarity runtime will treat each item of this list as if it only
had the field `a`, which creates an issue for the database on reads and writes.
On database reads, the Clarity database checks if the found type
matches the expected type, and discovers a mismatch. This mismatch
led to a DoS on 8 May 2023, and was fixed by converting the node
crash into a transaction invalidation.

However, transaction invalidation is _not_ sufficient as a long-term
solution due to the following:

1. Miners must be able to charge for these kinds of failures
2. Contracts which do not directly rely on this behavior could still
   receive buggy values because of the behavior (which could lead to storage failures).

# Specification

The proposed changes to the Epoch 2.4 hard fork will do the following:

* Add a value sanitization routine which eliminates any of these extra
  fields from the in-memory representation of a Clarity value.
* Invoke the sanitization routine on contract-call arguments and
  return values.
* Invoke the sanitization routine on database reads.
* Invoke the sanitization routine during Clarity value constructors
  which relied on the buggy type check behavior.

This will preserve the existing type system behavior, but it will ensure
that values constructed this way _match_ the expected type.

# Related work
The Stacks network has precedent for fixing consensus bugs through hard forks, some being released on 
short timelines. 

Other blockchains have also detected and fixed consensus critical bugs quickly. A prominent example of 
this happened on Bitcoin, which had a bug that would allow the minting of an arbitrary amount of BTC 
above the 21 million cap. A patched version was quickly released, and the network upgraded in a 
matter of hours. 

# Backwards Compatibility 
Everyone who runs a 2.3 node will be able to run a Stacks 2.4 node 
off of their existing chainstate. There are no changes to the chainstate database schemas in this SIP.

Stacks 2.4 nodes will not interact with Stacks 2.3 nodes on the peer network (defined in SIP-022)
after the Bitcoin block activation height of `791551`. In addition, Stacks 2.4 nodes
will ignore block-commits from Stacks 2.3 nodes (as well as from nodes on prior versions). 
Similar changes were made for Stacks 2.05 and Stacks 2.1 to ensure that the new network
cleanly separates from stragglers still following the old rules.

# Activation 
The changes described in this SIP will ship in the same release as the changes described in SIP-022, which discusses
and proposes a fix to the proof of transfer protocol.

This release will ship 500 blocks prior to reward cycle 60, which is Bitcoin block height 791,551. 
This gives stackers ample time (~3 days) to stack through the new contract. 

The node software for Stacks 2.4 shall be merged to the `master` branch of the
reference implementation no later than four days prior to the activation
height.  This means that everyone shall have at least three days to upgrade
their Stacks 2.3 nodes to Stacks 2.4. This change does not require a sync from genesis.

# Reference Implementation
The reference implementation of this SIP can be found in the
`feat/epoch-2.4-sanitize` branch of the Stacks blockchain reference implementation.  It is available at
https://github.com/stacks-network/stacks-blockchain.
