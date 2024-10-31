# Preamble

**SIP Number:** 029

**Title:** Bitcoin-Aligned Halving Schedule with Incentive Preservation

**Authors:**
- Brittany Laughlin (brittany@stacks.org)
- Jesse Wiley (jesse@stacks.org)
- Jude Nelson (jude@stacks.org)
- Will Corcoran (will@stacks.org)

**Consideration:** Economics

**Type:** Consensus (hard fork)

**Status:** Draft

**Created:** 2024-10-31

**License:** BSD 2-Clause

**Sign-off:**
- Rafael Cárdenas rafael@hiro.so (SIP Editor)
- MattySTX mattystx@gmail.com (Economics CAB)
- Jude Nelson (jude@stacks.org) (Steering Committee)

**Discussions-To:**
- [Stacks Forum](https://forum.stacks.org/t/aligning-with-bitcoin-halving-and-incentives-after-nakamoto/17668)

# Abstract

This SIP proposes modifying the Stacks token emission schedule to align with Bitcoin's halving schedule while preserving critical network incentives during the launch of sBTC and Nakamoto upgrades. The current Stacks halving schedule, while similar to Bitcoin's four-year cycle, has drifted due to implementation differences, resulting in a December 2024 halving that would reduce incentives during a critical network transition period. This proposal would extend the current emission rate until April 2026, aligning subsequent halvings with Bitcoin while maintaining a 100 STX tail emission and resulting in a reduced 2050 supply, slightly below the originally proposed 1.818B STX.

# Introduction

## Problem Statement

The Stacks blockchain's halving schedule, while designed to mirror Bitcoin's four-year cycles, currently faces three key challenges:

1. Timing misalignment with Bitcoin halvings due to using Stacks blocks instead of Bitcoin blocks for timing
2. An impending halving in December 2024 that would reduce miner and stacker incentives during critical protocol upgrades
3. Growing drift between Stacks and Bitcoin halving schedules that reduces predictability for network participants

## Proposed Solution

This SIP proposes to:
1. Extend the current 1000 STX per block emission until April 2026
2. Align subsequent halvings with Bitcoin's schedule
3. Reduce the tail emission from 125 STX to 100 STX to maintain supply targets
4. Preserve incentives during sBTC and Nakamoto launches while achieving better Bitcoin alignment

# Specification

## Current vs Proposed Schedule


### Proposed STX Coinbase Reduction Schedule

| Coinbase Reward Reduction Phase | Approximate Date (time b/w halvings) | STX Reward (reduction) | STX Supply (after) |
|--------------------------------|-------------------------------------|----------------------|-------------------|
| Current                           | -                                   | 1000                 | -                  |
| 1st*                            | ~April 2026 (+1.33 yrs)            | 500 (-50%)           | 1,607,907,038      |
| 2nd                             | ~April 2028 (2 yrs)                | 250 (-50%)           | 1,652,242,188      |
| 3rd                             | ~April 2032 (4 yrs)                | 125 (-50%)           | 1,696,547,013      |
| 4th                             | ~April 2036 (4 yrs)                | 100 (-20%)           | 1,718,699,425      |
| -                               | ~Jan 2050 (13.833 yrs)            | 100 (0%)             | 1,779,628,415      |

### Existing (aka “Baseline”) STX Coinbase Halving Schedule (for reference only)
| Coinbase Reward Reduction Phase | Approximate Date (time b/w halvings) | STX Reward (reduction) | STX Supply (after) |
|--------------------------------|-------------------------------------|----------------------|-------------------|
| Current                         | -                                   | 1000                 | -                  |
| 1st                             | ~Dec 2024 (4 yrs)                  | 500 (-50%)           | 1,512,993,315      |
| 2nd                             | ~Dec 2028 (4 yrs)                  | 250 (-50%)           | 1,645,084,888      |
| 3rd                             | ~Dec 2032 (4 yrs)                  | 125 (-50%)           | 1,689,389,675      |
| -                               | ~Jan 2050 (17.08 yrs)             | 125 (0%)             | 1,783,063,600      |

## Technical Implementation

The implementation requires modifying the following consensus rules:

1. Extend the current reward phase (1000 STX/block) until Bitcoin block 945,000 (~April 2026)
2. Implement new reduction schedule:
   - 500 STX/block from blocks 945,000 to 1,050,000
   - 250 STX/block from blocks 1,050,000 to 1,260,000
   - 125 STX/block from blocks 1,260,000 to 1,470,000
   - 100 STX/block perpetual tail emission thereafter

## Supply Impact

The projected STX supply in January 2050 will be 1,779,628,415 STX, which is:
- Less than current projection of 1,783,063,600 STX
- Well below the accepted 2050 supply cap of 1.818B STX

# Related Work

The concept of adjusting Stacks' emission schedule has been previously explored by the community. In November 2023, a comprehensive discussion was initiated on the Stacks Forum which included several detailed analyses and alternative proposals.

Two key reports emerged from this discussion.

First, in July 2023, the Stacks Foundation commissioned 7th Avenue Group to conduct an analysis of Mining Emissions and examine potential risks associated with the STX halving. This initial report highlighted concerns about halving timing and its impact on network security.

Following this, in November 2023, 7th Avenue Group published a follow-up report titled "Halving Proposals" which established three fundamental criteria for revising the STX emissions schedule:

1. Maintain network security through adequate miner rewards
2. Preserve the 2050 supply cap of 1.818B STX
3. Align with Bitcoin's halving schedule

The report acknowledged these criteria created a "trilemma" where optimizing for all three simultaneously proved challenging. In response, four distinct proposals (Schedules A, B, C, and D) were presented, each optimizing for two of the three criteria while compromising on the third.

These earlier proposals, while thorough in their analysis, did not anticipate the timing requirements that would emerge with the successful launch of Nakamoto and the imminent deployment of sBTC. A detailed emissions model was made available to the community, allowing for transparent evaluation of various scheduling options.

The current proposal builds upon this previous work while specifically addressing the new timing considerations introduced by recent protocol upgrades. It achieves all three original criteria while also preserving critical network incentives during the sBTC launch period.

The full discussion related to [Stacks Halving Schedule: Reports and Recommendations](https://forum.stacks.org/t/stacks-halving-schedule-reports-and-recommendations/15774
) is available on the Stacks Forum along with the following, related resources and reports:


[1] "Mining Emissions and Risks of the STX Halving", 7th Avenue Group, July 2023
[2] "Halving Proposals", 7th Avenue Group, November 2023
[3] "STX Halving Model", 7th Avenue Group, November 2023

# Backwards Compatibility

This change requires a hard fork of the Stacks blockchain. All nodes must upgrade to maintain consensus.

# Activation

## Voting Timeline

Voting will occur during reward cycle 97 (November 11-26, 2024).

## Activation Requirements

For Stackers:
1. Minimum participation threshold of double the largest stacker's balance
2. 80% "yes" votes from participating Stacked STX required

For Non-Stackers:
- 80% majority of participating liquid STX required to vote in favor

[Voting addresses and technical details to be added]

# Reference Implementation

[To be added: Link to implementation PR]
