# Preamble

SIP Number: 023

Title: Emergency Fix to Trait Invocation Behavior

Authors:
    Aaron Blankstein <aaron@hiro.so>,
    Brice Dobry <brice@hiro.so>,
    Jude Nelson <jude@stacks.org>,

Consideration: Technical, Governance

Type: Consensus

Status: Accepted

Created: 1 May 2023

License: BSD 2-Clause

Sign-off: Jesse Wiley <jesse@stacks.org> (Acting Technical CAB Chair), Jason Schrader <jason@joinfreehold.com> (Governance CAB Chair)

Discussions-To: https://github.com/stacksgov/sips

# Abstract

On 1 May 2023, it was discovered that smart contracts deployed prior to Stacks 2.1
that exposed public methods with
trait arguments could not be invoked with previously working trait-implementing
contract arguments.

This bug was caused by the activation of Stacks Epoch 2.2 (https://github.com/stacksgov/sips/blob/main/sips/sip-022/sip-022-emergency-pox-fix.md).

This SIP proposes an **immediate consensus-breaking change** to
introduce a new Stacks epoch 2.3 that corrects this regression.

**This SIP proposes a Bitcoin activation height of 788,240**

# Introduction

Clarity 2, introduced in Stacks 2.1, includes a new type checker and type system which
impacts trait invocations. In order for existing contracts to remain
compatible, their types must be _canonicalized_. In the context of traits,
the type canonicalization rules implement the new trait semantics introduced in
[SIP-015](./sips/sip-015/sip-015-network-upgrade.md).

## Epoch 2.2 Bug Behavior

The type canonicalization method performed an exact check for the current epoch:

```rust
    pub fn canonicalize(&self, epoch: &StacksEpochId) -> TypeSignature {
        match epoch {
            StacksEpochId::Epoch21 => self.canonicalize_v2_1(),
            _ => self.clone(),
        }
    }
```

Therefore, a pre-2.1 function with trait arguments that is invoked in Stacks 2.2
will fail to canonicalize its trait arguments, and abort with a
runtime analysis error. Specifically:

* If a miner includes a contract call transaction with trait arguments in a block, the transaction will abort with a runtime error.

* If a user submits a contract call transaction with trait arguments to the
  mempool, it will be rejected.

* A read-only contract-call with trait arguments will fail with a runtime
  analysis error.

# Specification

This hard fork will do the following:

* In epoch 2.2, the current buggy behavior will be preserved.  All
  contract-calls with trait arguments must fail with a runtime analysis error.

* In epoch 2.3, the desired behavior will be restored.  The trait semantics
  described in SIP-015 will be restored, and trait arguments in
  contract-calls will be treated as they were in Stacks 2.1.

* Set the minimum required block-commit memo bits to `0x08`.  All block-commits
  after the Bitcoin block activation height must have a memo value of at least
`0x08`.  This ensures that miners that do not upgrade from Stacks 2.2 will not
be able to mine in Stacks 2.3.

* Set the mainnet peer network version bits to `0x18000008`.  This ensures that follower
  nodes that do not upgrade to Stacks 2.3 will not be able to talk to Stacks
2.3 nodes.

* Set the testnet peer network version bits to `0xfacade08`.  This ensures that
  testnet follower nodes that do not upgrade to Stacks 2.3 will not be able to
talk to Stacks 2.3 nodes.

The reference implementation will update the `canonicalize()` method to match on all epochs, setting
the epoch 2.3 behavior to `self.canonicalize_v2_1()`, and the epoch 2.2 behavior to `self.clone()`.
This will preserve the buggy 2.2 behavior during the 2.2 epoch (so that the
hard fork does not require rollback), but fix the behavior after activation
of the 2.3 epoch.

# Related Work

Several potential workarounds were explored first to try to solve this issue without a hard-fork. 
Unfortunately, attempts to wrap pre-2.1 contracts with 2.2 contracts can avoid the mempool rejection, 
but still hit the same error in the form of a runtime type-checker error.
Upon further inspection into the code paths, a hard-fork option was determined to be the only viable option in this case.

Consensus bugs requiring immediate attention such as this
have been detected and fixed in other blockchains.  In the
absence of a means of gathering user comments on proposed fixes, the task of
activating these bugfixes has fallen to miners, exchanges, and node runners.  As
long as sufficiently many participating entities upgrade, then a chain split is
avoided and the fixed blockchain survives.  A prominent example was Bitcoin
[CVE-2010-5139](https://www.cvedetails.com/cve/CVE-2010-5139/), in which a
specially-crafted Bitcoin transaction could mint arbitrarily many BTC well above
the 21 million cap.  The [developer
response](https://bitcointalk.org/index.php?topic=823.0) was to quickly release
a patched version of Bitcoin and rally enough miners and users to upgrade.  In a
matter of hours, the canonical Bitcoin chain ceased to include any transactions
that minted too much BTC.

# Backwards Compatibility

There are no changes to the chainstate database schemas in this SIP.  Everyone
who runs a Stacks 2.2 node today will be able to run a Stacks 2.3 node off of
their existing chainstates before the activation height.

Stacks 2.3 nodes will not interact with Stacks 2.2 nodes on the peer
network after the Bitcoin block activation height passes.  In
addition, Stacks 2.3 nodes will ignore block-commits from Stacks 2.2
nodes.  Similar changes were made for Stacks 2.05, Stacks 2.1, and
Stacks 2.2 to ensure that the new network cleanly separates from
stragglers still following the old rules.

# Activation

This SIP shall be considered Activated if the Stacks 2.3 network is live at the
Bitcoin block activation height.

The node software for Stacks 2.3 shall be merged to the `master` branch of the
reference implementation no later than two days prior to the activation
height. This means that everyone shall have at least two days to upgrade
their Stacks 2.2 nodes to Stacks 2.3.

# Reference Implementation

The reference implementation of this SIP can be found in the
`feat/2.3-traits-only-fix` branch of
the Stacks blockchain reference implementation.  It is available at
https://github.com/stacks-network/stacks-blockchain.
