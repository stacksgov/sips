# Preamble

SIP Number: 02x

Title: Non-sequential Multisig Transactions

Author: Jeff Bencin <jbencin@hiro.so>

Consideration: Technical

Type: Consensus

Status: Draft

Created: 2023-08-30

License: BSD 2-Clause

Sign-off:

Discussions-To: https://github.com/stacksgov/sips

# Abstract

This SIP proposes a new multisig transaction format which is intended to be easier to use than the current format described in SIP-005.
It does not remove support for the current format, rather it is intended to co-exist with the old format and give users a choice of which format to use.

The issue with the current format is that it establishes a signer order when funds are sent to multisig account address, and requires signers to sign in the same order to spend the funds.
In practice, the current format has proven proven difficult for developers to understand and implement, as evidenced by the lack of Stacks multisig implementations today.

This new format intendeds to simplify the signing algorithm and remove the requirement for in-order signing, without comprimising on security or increasing transaction size.
It is expected that this will lead to better wallet support for Stacks multisig transactions.

# Introduction

Currently, a multisig transaction requires the first signer to sign the transaction itself, and following signers to sign the signature of the previous signer.
For a transaction with *n* signers, the final signature is generated in the following way:

```
signature_n(...(signature_2(signature_1(tx))))
```

# Specification

# Related Work

This section will be expanded upon after this SIP is ratified.

# Backwards Compatibility

The Stacks Blockchain will continue to treat multisig transactions using the current format as valid.

# Activation

# Reference Implementations

To be implemented in Rust. See https://github.com/blockstack/stacks-blockchain.
