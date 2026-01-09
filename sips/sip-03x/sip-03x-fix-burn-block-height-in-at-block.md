# Preamble

SIP Number: 03x

Title: Fix `burn-block-height` in `at-block`

Authors: Jeff Bencin <jbencin@hiro.so>

Consideration: Technical

Type: Consensus

Status: Draft

Created: 2024-12-05

License: BSD 2-Clause

Sign-off:

Discussions-To: https://github.com/stacksgov/sips

# Abstract

This SIP corrects the behavior of the Clarity keyword `burn-block-height` inside of an `at-block` statement.

# Introduction

Currently, `burn-block-height` does not take into account the context set by `at-block`, and will always return the burn block height at the latest Stacks block.
This behavior was reported in first reported in issue #1615 on the hirosystems/clarinet repository ([link](https://github.com/hirosystems/clarinet/issues/1615))
The correct behavior would be to return the burn block height **at the height of the Stacks block passed to `at-block`**.

This behavior only occurs in Stacks Epoch 3.0 and above, and is due to a change in how the burn block is calculated for Nakamoto blocks.
`burn-block-height` returns the expected result inside of `at-block` in Stacks Epoch 2.x and below.

The proposed fix is to correct the behavior for `burn-block-height` in Stacks Epoch 3.1 and above, and leave the incorrect behavior in Stacks Epoch 3.0, to avoid breaking consensus.

## Examples

If we open a session in `clarinet console`, and enter the following commands:

1. ```
   ::set_epoch 3.0
   ```

2. ```clarity
   (define-read-only (get-burn (height uint))
       (let
           (
               (id (unwrap! (get-stacks-block-info? id-header-hash height) (err 1)))
           )
           (at-block id
               (ok { burn-block-height: burn-block-height, stacks-block-height: stacks-block-height })
           )
       )
   )
   ```

3. ```
   ::advance_burn_chain_tip 100
   ```

4. ```clarity
   (contract-call? .contract-0 get-burn u3)
   ```

It will return:

```clarity
(ok { burn-block-height: u101, stacks-block-height: u3 })
```

Where we would expect it to return:

```clarity
(ok { burn-block-height: u3, stacks-block-height: u3 })
```

# Specification

When called in the context of `at-block <stacks-block-id>`, `burn-block-height` will return the following result based on the current Stacks Epoch:

| Epoch   | `burn-block-height` returns                                      |
| ------: | ---------------------------------------------------------------- |
| < 3.0   | Height of burn block associated with parent of `stacks-block-id` |
|   3.0   | Height of burn block associated with latest Stacks block         |
| > 3.0   | Height of burn block associated with `stacks-block-id`           |

# Related Work

- [hirosystems/clarinet#1615](https://github.com/hirosystems/clarinet/issues/1615): The issue that reports this behavior
- [stacks-network/stacks-core#5524](https://github.com/stacks-network/stacks-core/pull/5524): The PR to introduce the correct behavior described in this SIP

# Layer

Consensus (hard fork)

# Requires

N/A

# Backwards Compatibility

To avoid breaking consensus, the behavior of `burn-block-height` in blocks prior to Stacks Epoch 3.1 will not change

# Activation

Since this SIP requires a change to the stacks consensus rules a community vote is additionally required.

## Process of Activation

Users can vote to approve this SIP with either their locked/stacked STX or with unlocked/liquid STX, or both. The criteria for the stacker and non-stacker voting is as follows.

## For Stackers:

TODO

# Activation Status

TODO

# Reference Implementations

To be implemented in Rust. See https://github.com/stacks-network/stacks-core/pull/5524.
