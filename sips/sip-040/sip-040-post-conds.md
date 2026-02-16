# Preamble

SIP Number: 040

Title: Improved Post-Conditions

Author(s):

- Brice Dobry <brice@stackslabs.com>

Status: Draft

Consideration: Governance, Technical

Type: Consensus

Layer: Consensus (hard fork)

Created: 2025-02-06

License: BSD-2-Clause

Sign-off:

Discussions-To:

- https://forum.stacks.org/t/improved-post-conditions/18661

# Abstract

This proposal improves on the current transaction post-conditions by introducing
a third post-condition mode, `Originator` mode, and a new condition code for
non-fungible tokens, `MAY SEND`.

`Allow` mode provides high flexibility, but it does not provide protection for
callers, so it should not be used outside of development. `Deny` mode provides
maximum security, but for complex applications, it can be difficult, or
impossible to enumerate all of the asset movement that a transaction may cause.
`Originator` mode offers a hybrid approach. It applies `Deny` logic strictly to
the origin account's assets, while applying `Allow` logic to all other
principals (contracts or other users) involved in the transaction.

When specifying post-conditions for STX or FTs, users can choose to say that the
transaction must spend N tokens (`=`) or that it may spend **at most** N tokens
(`<=`). For non-fungible tokens, however, post-conditions can only specify
`SEND` or `NOT SEND`. This proposal adds the new NFT code, `MAY SEND`, to allow
users to specify that an NFT might be sent, but need not be, similar to the `<=`
condition for FTs.

# Copyright

This SIP is made available under the terms of the BSD-2-Clause license,
available at https://opensource.org/licenses/BSD-2-Clause. This SIP’s copyright
is held by the Stacks Open Internet Foundation.

# Introduction

In the current ecosystem, `Deny` mode is the safest way to interact with smart
contracts, and users should be in the habit of never signing a transaction in
`Allow` mode. The reality is that some applications, e.g. DeFi apps, move assets
between a variety of contracts as part of one contract call. The movements may
be dynamic and difficult or impossible to predict in advance, so users end up
reverting to signing `Allow` mode transactions, just to make it work. This is a
very bad habit to teach our users, and we can do better. The concern of the user
is typically about assets moving out of their own wallet, and they are not
concerned about assets moving in and out of contracts, triggered by their call.
Contracts that they do care about should be protected internally, using the
contract-level post-conditions supported by `as-contract?`. `Originator` mode
allows the user to specify only the restrictions on their own assets, allowing
any movements of assets amongst other principals.

`MAY SEND` fills an obvious gap in the existing post-condition implementation,
and does not require any more introduction or motivation.

# Specification

The specification for both of these is based on and builds off of the original
post-condition specification in
[SIP-005](../sip-005/sip-005-blocks-and-transactions.md).

## `Originator` Mode

All post-conditions continue to be evaluated in the same way, with the addition
that in `Originator` mode, the transaction's origin account's assets are
protected as in `Deny` mode, while other principals are protected as in `Allow`
mode.

The origin account is the account identified by the origin spending condition in
the transaction authorization structure (SIP-005). It is fixed for the
transaction and does not change during execution. It is distinct from
`tx-sender`, and does not change under `as-contract?`. In sponsored
transactions, it is the account that signs first (the origin).

In `Originator` mode, all post-conditions MUST hold. Additionally, when
enforcing allowlist coverage, a transaction MUST be rejected only if there
exists an asset transfer not covered by any post-condition whose sending
principal is the origin account. Uncovered transfers from any other principal
are permitted.

The transaction encoding reserves 1-byte for the post-condition mode.
`Originator` mode uses the value `0x03`.

## `MAY SEND` Condition

This new `MAY SEND` condition shall be implemented as a check on the NFT asset
movement upon completion of the transaction. It is always satisfied regardless
of whether the specified NFT is sent, and it is treated as covering that
specific NFT instance for the specified principal when enforcing allowlist
coverage in `Deny` or `Originator` mode. In `Allow` mode, it is redundant but
valid.

The transaction encoding reserves 1-byte for the non-fungible condition code.
`MAY SEND` adds a new acceptable value for this byte, `0x12`.

## Updates to the SIP-005 Specification

Adding these changes into SIP-005's spec produces the following diff:

```diff
diff --git a/sips/sip-005/sip-005-blocks-and-transactions.md b/sips/sip-005/sip-005-blocks-and-transactions.md
index 64d3a5d..253164b 100644
--- a/sips/sip-005/sip-005-blocks-and-transactions.md
+++ b/sips/sip-005/sip-005-blocks-and-transactions.md
@@ -305,10 +305,12 @@ The Stacks blockchain supports the following two types of comparators:
 * **Non-fungible asset state** -- that is, a question of _whether or not_ an
   account sent a non-fungible asset when the transaction ran.

-In addition, the Stacks blockchain supports an "allow" or "deny" mode for
-evaluating post-conditions:  in "allow" mode, other asset transfers not covered
-by the post-conditions are permitted, but in "deny" mode, no other asset
-transfers are permitted besides those named in the post-conditions.
+In addition, the Stacks blockchain supports an "allow", "deny", or "originator"
+mode for evaluating post-conditions:  in "allow" mode, other asset transfers
+not covered by the post-conditions are permitted, but in "deny" mode, no other
+asset transfers are permitted besides those named in the post-conditions, and
+in "originator" mode, no other asset transfers from the transaction's origin
+account are permitted besides those named in the post-conditions.

 Post-conditions are meant to be added by the user (or by the user's wallet
 software) at the moment they sign with their origin account.  Because the
@@ -359,6 +361,8 @@ encoded as big-endian.
      post-conditions.
    * `0x02`:  This transaction may NOT affect other assets besides those listed
      in the post-conditions.
+   * `0x03`: This transaction may NOT affect other assets from the origin
+     account besides those listed in the post-conditions.
 * A length-prefixed list of **post-conditions**, describing properties that must be true of the
   originating account's assets once the transaction finishes executing.  It is encoded as follows:
    * A 4-byte length, indicating the number of post-conditions.
@@ -625,6 +629,7 @@ non-fungible token, with respect to whether or not the particular non-fungible
 token is owned by the account.  It can take the following values:
 * `0x10`: "The account will SEND this non-fungible token"
 * `0x11`: "The account will NOT SEND this non-fungible token"
+* `0x12`: "The account MAY SEND this non-fungible token"

 Post-conditions are defined in terms of which assets each account sends or
 does not send during the transaction's execution.  To enforce post-conditions,
```

# Related Work

- This SIP adds to the existing specification for post-conditions in
  [SIP-005](../sip-005/sip-005-blocks-and-transactions.md)
- This SIP will activate in epoch 3.4 together with
  [SIP-039](../sip-039/sip-039-clarity5.md)

# Backwards Compatibility

These new post-condition additions are backwards compatible for transactions
that do not use the new mode or condition code. Nodes need to be updated to
accept transactions with these new features, but existing SIP-005
post-conditions will continue to operate as they do now. Pre-upgrade nodes will
reject transactions that use post-condition mode `0x03` or non-fungible
condition code `0x12`.

# Activation

This change adds new functionality that is backwards compatible and optional to
use. To activate, it should only require approval from the Technical CAB and the
Steering Committee. If approved, it should go live together with Clarity 5 in
epoch 3.4, as described in [SIP-039](../sip-039/sip-039-clarity5.md).
Transactions using `Originator` mode or `MAY SEND` MUST be rejected prior to
activation.

# Reference Implementation

Implementation of these new features is in progress in
https://github.com/stacks-network/stacks-core/pull/6885.
