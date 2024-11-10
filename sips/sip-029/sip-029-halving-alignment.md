# Preamble

**SIP Number:** 029

**Title:** Bootstrapping sBTC Liquidity and Nakamoto Signer Incentives

**Authors:**
- Alex Miller (alex@hiro.so)
- Andre Serrano (andre@bitcoinl2labs.com)
- Brittany Laughlin (brittany@lattice.vc)
- Jesse Wiley (jesse@stacks.org)
- Jude Nelson (jude@stacks.org)
- Philip De Smedt (philip@stackingdao.com)
- Tycho Onnasch (tycho@zestprotocol.com)
- Will Corcoran (will@stacks.org)

**Consideration:** Economics, Technical, Governance

**Type:** Consensus (hard fork)

**Status:** Draft

**Created:** 2024-11-06

**License:** BSD 2-Clause

**Sign-off:**

**Discussions-To:**
- Stacks Forum Post: [Aligning with Bitcoin Halving and Incentives after Nakamoto](https://forum.stacks.org/t/aligning-with-bitcoin-halving-and-incentives-after-nakamoto/17668)


# Abstract

The first Stacks halving is expected to take place at Stacks block height 210,384, which is set to occur during Reward Cycle 100 in December 2024, cutting the STX block reward from 1,000 STX to 500 STX. This SIP proposes a modification to the emissions schedule given that the network is going through two major launches (Nakamoto and sBTC) which rely on predictable economic incentives. The proposed schedule modification and associated STX emission rate would create time for Nakamoto and sBTC to launch and settle in, but, being mindful of supply, would still result in an overall reduced target 2050 STX supply (0.19% lower) and a reduced tail emission rate (20% lower).

# License and Copyright

This SIP is made available under the terms of the BSD-2-Clause license,
available at https://opensource.org/licenses/BSD-2-Clause.  This SIP’s copyright
is held by the Stacks Open Internet Foundation.

# Introduction

STX halvings were originally designed to happen every 4 years, similar to Bitcoin. The first Stacks halving is expected to take place at Stacks block height 210,384, which is set to occur during Reward Cycle 100 in December 2024, cutting the STX block reward from 1,000 STX to 500 STX, thereby significantly altering the economic incentives of mining on the Stacks blockchain. At the same time, the Stacks network is going through two major upgrades/changes, both of which are highly dependent on economic incentives.

First, the role of Stackers is changing. The role of Stackers in the Nakamoto blockchain (SIP-021) differs from their role in the original Stacks blockchain in that they must now collectively sign Stacks blocks. This is required to prevent Stacks forks from arising, and to secure the chain tip before it can be fully anchored to the Bitcoin chain. This also means that Stackers must run and maintain signing nodes with high availability in order to ensure that blocks always reach the requisite signature threshold. The PoX payouts (SIP-007) granted to Stackers by miners provide a positive monetary incentive for Stackers to carry out this task.

Second, the release of the Nakamoto blockchain unblocks sBTC (SIP-028), a wrapped Bitcoin asset on the Stacks blockchain which benefits from Nakamoto’s newfound resistance to forks. Because inducing a chain reorganization (a reorg) in Nakamoto is at least as hard as doing so in the Bitcoin blockchain, applications can rely on Nakamoto to ensure that each sBTC token is backed 1:1 by a BTC token – there is no feasible way to double-spend sBTC through a Stacks blockchain reorg.

Because of how important both of these upgrades are to the future of the Stacks blockchain and the dependency of all blockchains on economic incentives for security, changing the incentives while the system is going through a transition could have negative impacts. In particular, given that miners bid BTC in order to win the STX coinbase reward (and that BTC is what provides PoX payouts for Signers), it is highly likely that a 50% reduction in the STX coinbase reward would lead to a corresponding 50% reduction in PoX payouts, thereby dramatically decreasing incentives for signers while Nakamoto and sBTC are gaining adoption. Additionally, as discussed in the 7th Avenue Group report [1], by reducing the gross value of the block rewards and corresponding PoX payouts, it is likely that some miners and signers may choose to cease their work on the Stacks blockchain, reducing competition and economics further.

While ultimately halvings do need to happen, for those reasons, it would be highly preferable to not change the economic incentives until both Nakamoto and sBTC have been live for some time, as well as to have reductions in the STX block reward happen at the same time as reductions in the BTC block reward given their links.

Therefore, this SIP proposes altering the token emission schedule to preserve the existing incentive structure while ensuring no increase in the 2050 target supply, and incorporating these principles:

* All STX holders would see a reduced 2050 target STX supply by 0.19%, thereby making STX more scarce
* All STX holders would see a reduced tail inflation after the final halving
* Stacks miners and signers’ economic incentives would remain consistent with the existing incentives for the next 16 months
* The new Stacks halving schedule would align with Bitcoin halvings starting in 2028 to strengthen the connection the Stacks L2 has to Bitcoin and also synchronize the economic adjustments of both assets, reducing changes in incentives for miners and signers at each halving, as further outlined in the Forum post [2]

# Specification

The _current_ STX emission schedule is presented as follows.  Note that the **first STX halving is in December 2024**.  The tail emission after the final halving in 2050 would be 125 STX per block, and the total supply at that time is projected to be 1,783,063,600 STX.

| Coinbase Reward Reduction Phase | Approximate Date (time b/w halvings) | STX Reward (reduction) | STX Supply (after) |
|--------------------------------|-------------------------------------|----------------------|-------------------|
| Current                         | -                                   | 1000                 | -                  |
| 1st                             | ~Dec 2024 (4 yrs)                  | 500 (50%)           | 1,512,993,315      |
| 2nd                             | ~Dec 2028 (4 yrs)                  | 250 (50%)           | 1,645,084,888      |
| 3rd                             | ~Dec 2032 (4 yrs)                  | 125 (50%)           | 1,689,389,675      |
| -                               | ~Jan 2050 (17.08 yrs)             | 125 (0%)             | 1,783,063,600      |


The _proposed_ STX emission schedule is presented as follows.  In particular, this SIP proposes preserving the 1000 STX coinbase until April 2026.  After this, there would be a reduction to 500 STX after two years, and another reduction to 125 STX after two more years.  The tail emission after the final halving in 2050 would be 100 STX, and the total supply at that time is projected to be 1,783,063,600 STX (about 0.19% lower).


| Coinbase Reward Reduction Phase | Bitcoin Block Height | Approximate Date (time b/w halvings) | STX Reward (reduction) | STX Supply (after) |
|--------------------------------|---------------------|-------------------------------------|----------------------|-------------------|
| Current                        | -                   | -                                   | 1000                 | -                 |
| 1st*                     | 945,000             | ~April 2026 (+1.33 yrs)            | 500 (50%)           | 1,607,907,038     |
| 2nd                     | 1,050,000           | ~April 2028 (2 yrs)                | 250 (50%)           | 1,652,242,188     |
| 3rd                      | 1,260,000           | ~April 2032 (4 yrs)                | 125 (50%)           | 1,696,547,013     |
| 4th                      | 1,470,000           | ~April 2036 (4 yrs)                | 100 (20%)           | 1,718,699,425     |
| -                          | -                   | ~Jan 2050 (13.833 yrs)             | 100 (0%)             | 1,779,628,415     |


With these changes, miner incentives and PoX yield remain unchanged for another 16 months, which we believe is sufficient time for the nascent Nakamoto signer set to develop into a set of stable, professional block signers, and for the sBTC project to attract sufficient initial liquidity.

# Related Work

While many blockchain protocols implement token emission schedules with periodic reductions in block rewards, we are not aware of any precedent for modifying an emission schedule specifically to maintain economic incentives during major protocol upgrades.

# Backwards Compatibility

This change requires a hard fork of the Stacks blockchain

# Activation

## Voting Timeline

Voting will begin at bitcoin block height 870,750, which occurs ~ Sunday, November 17th, 2024.
Voting will conclude at bitcoin block height 872,750, which occurs ~ Sunday, December 1st, 2024.

## Activation

The SIP-029 STX emission schedule is designed to activate on Stacks 3.0 as defined in [SIP-021](https://github.com/stacksgov/sips/blob/main/sips/sip-021/sip-021-nakamoto.md). 

### Process of Activation

Users can vote to approve this SIP with either their locked/stacked STX or with unlocked/liquid STX, or both. The SIP voting page can be found at [stx.eco](https://stx.eco). The criteria for the stacker and non-stacker voting is as follows.

#### For Stackers:

In order for this SIP to activate, the following criteria must be met by the set of Stacked STX:

- At least 80 million Stacked STX must vote, with at least 80% (64 million) voting "yes".

The voting addresses will be:

| Vote | Bitcoin Address | Stacks Address | Msg | ASCII-encoded msg | Bitcoin script |
| - | - | - | - | - | - |
| yes      | `11111111111mdWK2VXcrA1e7in77Ux` | `SP00000000001WPAWSDEDMQ0B9J76GZNR3T` | `yes-sip-29` | `000000000000000000007965732d7369702d3239` | `OP_DUP` `OP_HASH160` `000000000000000000007965732d7369702d3239` `OP_EQUALVERIFY` `OP_CHECKSIG` |
| no       | `111111111111ACW5wa4RwyeKgtEJz3` | `SP000000000006WVSDEDMQ0B9J76NCZPNZ`  | `no-sip-29`  | `00000000000000000000006e6f2d7369702d3239` | `OP_DUP` `OP_HASH160` `00000000000000000000006e6f2d7369702d3239` `OP_EQUALVERIFY` `OP_CHECKSIG` |

The addresses have been generated as follows:

- Encode `<message>` in ASCII, with 0-padding.
- Use the resulting `<encoding>` in the Bitcoin script`OP_DUP` `OP_HASH160` `<encoding>` `OP_EQUALVERIFY` `OP_CHECKSIG`.
- The Bitcoin address is the `base58check` of the hash of the Bitcoin script above.
- The Stacks address is the `c32check-encoded` message.

Stackers (pool and solo) vote by sending Stacks dust to the corresponding Stacks address from the account where their Stacks are locked.

Solo stackers only can also vote by sending a bitcoin dust transaction (6000 sats) to the corresponding bitcoin address.

#### For Non-Stackers:

Users with liquid STX can vote on proposals directly at [stx.eco](https://stx.eco) using the Ecosystem DAO. Liquid STX is the user’s balance, less any STX they have locked in the PoX stacking protocol, at the block height at which the voting started (preventing the same STX from being transferred between accounts and used to effectively double vote). This is referred to generally as "snapshot" voting.

For this SIP to pass, 80% of all liquid STX committed by voting must be in favor of the proposal.

We believe that these thresholds are sufficient to demonstrate interest from Stackers -- Stacks users who have a long-term interest in the Stacks blockchain's successful operation -- in performing this upgrade.

# Reference Implementation

[To be added: Link to implementation PR]

# References

[1] Soslow J (2023) Review of Mining Emissions and Risks of the Halving. Available at https://stx.is/emissions-report-1 [Verified 5 November 2024]
[2] Laughlin, B (2024) Aligning with Bitcoin Halving and Incentives after Nakamoto. [Online forum post] forum.stacks.org https://forum.stacks.org/t/aligning-with-bitcoin-halving-and-incentives-after-nakamoto/17668 [Verified 5 November 2024]
