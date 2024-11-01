# Preamble

**SIP Number:** 029

**Title:** Bootstrapping sBTC Liquidity and Nakamoto Signer Incentives

**Authors:**
- Brittany Laughlin (brittany@stacks.org)
- Jesse Wiley (jesse@stacks.org)
- Jude Nelson (jude@stacks.org)
- Will Corcoran (will@stacks.org)

**Consideration:** Economics, Governance, Technical

**Type:** Consensus (hard fork)

**Status:** Draft

**Created:** 2024-10-31

**License:** BSD 2-Clause

**Sign-off:** `tbd`

**Discussions-To:**
- Stacks Forum Post: [Aligning with Bitcoin Halving and Incentives after Nakamoto](https://forum.stacks.org/t/aligning-with-bitcoin-halving-and-incentives-after-nakamoto/17668)

# Abstract

This SIP proposes modifying the Stacks token emission schedule to preserve critical network incentives during two major protocol developments: the launch of sBTC and the continued operation of Nakamoto signers. The current emission schedule would reduce incentives in December 2024, precisely when the network needs to bootstrap sBTC liquidity and maintain high-quality Nakamoto signers. This proposal would extend the current emission rate until April 2026, followed by a modified reduction schedule that maintains these crucial incentives while resulting in a 2050 supply that is 2.11% below the originally proposed 1.818B STX cap.

# Introduction

## Problem Statement

The Stacks ecosystem faces two critical challenges that require immediate attention:

Bootstrapping sBTC Liquidity: The success of sBTC depends on establishing and maintaining substantial liquidity from launch. Early adopters and liquidity providers require predictable BTC yield through PoX rewards to justify participation. The current December 2024 halving would cut these rewards at the exact moment when they are most needed to attract liquidity.

Maintaining Nakamoto Signer Participation: The security and performance of the Stacks blockchain relies on high-quality Nakamoto signers who validate, sequence, and sign blocks. These signers require predictable PoX rewards to justify their ongoing operational costs and infrastructure investments. Reducing their compensation during the critical sBTC launch period risks degrading network security and performance.


## Proposed Solution

This SIP proposes a modification to the STX emission schedule specifically designed to solve these problems:

Maintain Current Emission Rate: By extending the 1000 STX per block emission until April 2026, we ensure adequate PoX rewards are available during the crucial sBTC bootstrapping period. This enables ecosystem partners to reliably contribute to sBTC liquidity incentives through their PoX income.

Gradual Reduction Schedule: Following the extension, implement a modified reduction schedule that balances the need for ongoing incentives with long-term supply management. The schedule includes an adjustment to the tail emission that results in a final 2050 supply 0.19% lower than currently projected.

Through these changes, the proposal ensures that both sBTC and Nakamoto signers have the economic support needed for success, while maintaining responsible tokenomics. As a beneficial side effect, the new schedule also better aligns with Bitcoin's halving cycle, providing additional predictability for network participants.

# Specification

## Proposed STX Coinbase Reduction Schedule

Here's the revised table with the Bitcoin Block Height column added:

| Coinbase Reward Reduction Phase | Bitcoin Block Height | Approximate Date (time b/w halvings) | STX Reward (reduction) | STX Supply (after) |
|--------------------------------|---------------------|-------------------------------------|----------------------|-------------------|
| Current                        | -                   | -                                   | 1000                 | -                 |
| 1st*                     | 945,000             | ~April 2026 (+1.33 yrs)            | 500 (-50%)           | 1,607,907,038     |
| 2nd                     | 1,050,000           | ~April 2028 (2 yrs)                | 250 (-50%)           | 1,652,242,188     |
| 3rd                      | 1,260,000           | ~April 2032 (4 yrs)                | 125 (-50%)           | 1,696,547,013     |
| 4th                      | 1,470,000           | ~April 2036 (4 yrs)                | 100 (-20%)           | 1,718,699,425     |
| -                          | -                   | ~Jan 2050 (13.833 yrs)             | 100 (0%)             | 1,779,628,415     |


## Existing STX Coinbase Halving Schedule (for reference only)

| Coinbase Reward Reduction Phase | Approximate Date (time b/w halvings) | STX Reward (reduction) | STX Supply (after) |
|--------------------------------|-------------------------------------|----------------------|-------------------|
| Current                         | -                                   | 1000                 | -                  |
| 1st                             | ~Dec 2024 (4 yrs)                  | 500 (-50%)           | 1,512,993,315      |
| 2nd                             | ~Dec 2028 (4 yrs)                  | 250 (-50%)           | 1,645,084,888      |
| 3rd                             | ~Dec 2032 (4 yrs)                  | 125 (-50%)           | 1,689,389,675      |
| -                               | ~Jan 2050 (17.08 yrs)             | 125 (0%)             | 1,783,063,600      |


## Supply Impact

The projected STX supply in January 2050 will be 1,779,628,415 STX, which is:
- 0.19% less than current projection of 1,783,063,600 STX
- 2.11% less than the accepted 2050 supply cap of 1.818B STX

# Backwards Compatibility

This change requires a hard fork of the Stacks blockchain. All nodes must upgrade to maintain consensus.

# Activation

## Voting Timeline

Voting will occur during reward cycle 97 (November 11-26, 2024).

## Activation

The SIP-029 STX emission schedule is designed to activate on Stacks 3.0 as defined in [SIP-021](https://github.com/stacksgov/sips/blob/feat/sip-021-nakamoto/sips/sip-021/sip-021-nakamoto.md). Therefore, this SIP is only meaningful when SIP-021 activates.

### Process of Activation

Users can vote to approve this SIP with either their locked/stacked STX or with unlocked/liquid STX, or both. The SIP voting page can be found at [stx.eco](https://stx.eco). The criteria for the stacker and non-stacker voting is as follows.

#### For Stackers:

In order for this SIP to activate, the following criteria must be met by the set of Stacked STX:

- At least 80 million Stacked STX must vote, with least 80% voting "yes".

The voting addresses will be:

| Vote | Bitcoin Address | Stacks Address | Msg | ASCII-encoded msg | Bitcoin script |
| - | - | - | - | - | - |
| yes      | `tbd` | `tbd` | `yes-sip-29` | `tbd` | `OP_DUP` `OP_HASH160` `tbd` `OP_EQUALVERIFY` `OP_CHECKSIG` |
| no       | `tbd` | `tbd`  | `no-sip-29`  | `tbd` | `OP_DUP` `OP_HASH160` `tbd` `OP_EQUALVERIFY` `OP_CHECKSIG` |

The addresses have been generated as follows:

- Encode `<message>` in ASCII, with 0-padding.
- Use the resulting `<encoding>` in the Bitcoin script`OP_DUP` `OP_HASH160` `<encoding>` `OP_EQUALVERIFY` `OP_CHECKSIG`.
- The Bitcoin address is the `base58check` of the hash of the Bitcoin script above.
- The Stacks address is the `c32check-encoded` Bitcoin address.

Stackers (pool and solo) vote by sending Stacks dust to the corresponding Stacks address from the account where their Stacks are locked.

Solo stackers only can also vote by sending a bitcoin dust transaction (6000 sats) to the corresponding bitcoin address.

#### For Non-Stackers:

Users with liquid STX can vote on proposals directly at [stx.eco](https://stx.eco) using the Ecosystem DAO. Liquid STX is the user’s balance, less any STX they have locked in the PoX stacking protocol, at the block height at which the voting started (preventing the same STX from being transferred between accounts and used to effectively double vote). This is referred to generally as "snapshot" voting.

For this SIP to pass, 70% of all liquid STX committed by voting must be in favor of the proposal.

We believe that these thresholds are sufficient to demonstrate interest from Stackers -- Stacks users who have a long-term interest in the Stacks blockchain's successful operation -- in performing this upgrade.

# Reference Implementation

[To be added: Link to implementation PR]
