# Preamble

**SIP Number:** 029

**Title:** Preserving Economic Incentives During Stacks Network Upgrades

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

**Status:** Ratified

**Created:** 2024-11-06

**License:** BSD 2-Clause

**Sign-off:**
- j2p2 i.digg.tech@gmail.com (SIP Editor)
- Mike Cohen mjoecohen@gmail.com (Technical CAB)
- Jason Schrader jason@joinfreehold.com (Governance CAB)
- MattySTX mattystx@gmail.com (Economics CAB)

**Discussions-To:**
- Stacks Forum Post: [Aligning with Bitcoin Halving and Incentives after Nakamoto](https://forum.stacks.org/t/aligning-with-bitcoin-halving-and-incentives-after-nakamoto/17668)


# Abstract

The first Stacks halving is expected to take place 210,384 Bitcoin blocks after the Stacks 2.0 starting height, 666,050, which is Bitcoin height 876,434, which is set to occur during Reward Cycle 100 in December 2024, cutting the STX block reward from 1,000 STX to 500 STX. This SIP proposes a modification to the emissions schedule given that the network is going through two major launches (Nakamoto and sBTC) which rely on predictable economic incentives. The proposed schedule modification and associated STX emission rate would create time for Nakamoto and sBTC to launch and settle in, but, being mindful of supply, would still result in an overall reduced target 2050 STX supply (0.77% lower) and a reduced tail emission rate (50% lower).

# License and Copyright

This SIP is made available under the terms of the BSD-2-Clause license,
available at https://opensource.org/licenses/BSD-2-Clause.  This SIP’s copyright
is held by the Stacks Open Internet Foundation.

# Introduction

STX halvings were originally designed to happen every 4 years, similar to Bitcoin. The first Stacks halving is expected to take place at Bitcoin block 876,434, which is set to occur during Reward Cycle 100 in December 2024, cutting the STX block reward from 1,000 STX to 500 STX, thereby significantly altering the economic incentives of mining on the Stacks blockchain. At the same time, the Stacks network is going through two major upgrades/changes, both of which are highly dependent on economic incentives.

First, the role of Stackers is changing. The role of Stackers in the Nakamoto blockchain (SIP-021) differs from their role in the original Stacks blockchain in that they must now collectively sign Stacks blocks. This is required to prevent Stacks forks from arising, and to secure the chain tip before it can be fully anchored to the Bitcoin chain. This also means that Stackers must run and maintain signing nodes with high availability in order to ensure that blocks always reach the requisite signature threshold. The PoX payouts (SIP-007) granted to Stackers by miners provide a positive monetary incentive for Stackers to carry out this task.

Second, the release of the Nakamoto blockchain unblocks sBTC (SIP-028), a wrapped Bitcoin asset on the Stacks blockchain which benefits from Nakamoto’s newfound resistance to forks. Because inducing a chain reorganization (a reorg) in Nakamoto is at least as hard as doing so in the Bitcoin blockchain, applications can rely on Nakamoto to ensure that each sBTC token is backed 1:1 by a BTC token – there is no feasible way to double-spend sBTC through a Stacks blockchain reorg.

Because of how important both of these upgrades are to the future of the Stacks blockchain and the dependency of all blockchains on economic incentives for security, changing the incentives while the system is going through a transition could have negative impacts. In particular, given that miners bid BTC in order to win the STX coinbase reward (and that BTC is what provides PoX payouts for Signers), it is highly likely that a 50% reduction in the STX coinbase reward would lead to a corresponding 50% reduction in PoX payouts, thereby dramatically decreasing incentives for signers while Nakamoto and sBTC are gaining adoption. Additionally, as discussed in the 7th Avenue Group report [1][2], by reducing the gross value of the block rewards and corresponding PoX payouts, it is likely that some miners and signers may choose to cease their work on the Stacks blockchain, reducing competition and economics further.

While ultimately halvings do need to happen, for those reasons, it would be highly preferable to not change the economic incentives until both Nakamoto and sBTC have been live for some time, as well as to have reductions in the STX block reward happen at the same time as reductions in the BTC block reward given their links.

Therefore, this SIP proposes altering the token emission schedule to preserve the existing incentive structure while ensuring no increase in the 2050 target supply, and incorporating these principles:

* All STX holders would see a reduced 2050 target STX supply by 0.77%, thereby making STX more scarce
* All STX holders would see a reduced tail inflation (from 125 STX to 62.5 STX) after the final halving
* Stacks miners and signers’ economic incentives would remain consistent with the existing incentives for the next 16 months
* The new Stacks halving schedule would align with Bitcoin halvings starting in 2028 to strengthen the connection the Stacks L2 has to Bitcoin and also synchronize the economic adjustments of both assets, reducing changes in incentives for miners and signers at each halving, as further outlined in the Forum post [3]

# Specification

Applying these upgrades to the Stacks blockchain requires a consensus-breaking network upgrade, in this case, a hard fork. Like other such changes, this will require a new Stacks epoch. In this SIP, we will refer to this new epoch as Stacks 3.1.

The _current_ STX emission schedule is presented as follows.  Note that the **first STX halving is in December 2024**.  The tail emission after the final halving in 2032 would be 125 STX per block.

| Coinbase Reward Phase | Bitcoin Height | Approx Date | STX Supply at Block | STX Reward | Annual Inflation |
|--------------------|----------------|----------------------|-------------------|------------|-----------------|
| Current            | 870,100        | -                    | 1,552,452,847    | 1000       | -               |
| 1st                | 876,434        | Dec 2024             | 1,558,786,847    | 500 (50%)  | 3.37%          |
| 2nd                | 1,086,818      | Dec 2028             | 1,663,978,847    | 250 (50%)  | 1.58%          |
| 3rd                | 1,297,202      | Dec 2032             | 1,716,574,847    | 125 (50%)  | 0.77%          |
| -                  | 2,197,560      | Jan 2050 (17.08y)    | 1,829,119,597    | 125 (0%)   | 0.36%          |


The _proposed_ STX emission schedule is presented as follows.  In particular, this SIP proposes preserving the 1000 STX coinbase until April 2026.  After this, there would be a halving to 500 STX after two years, aligning the remaining Stacks halving block heights with Bitcoin's halving schedule. Four years later, emissions halve again to 125 STX, and the tail emission after the final halving in 2036 would be 62.5 STX. This brings the total supply in 2050 to 1,804,075,347, or about 0.77% lower than the original 1,818,000,000 estimate.

| Coinbase Reward Phase | Bitcoin Height | Approx Date           | STX Supply at Block | STX Reward | Annual Inflation |
|--------------------|----------------|---------------------|-------------------|------------|-----------------|
| Current            | 870,100        | -                   | 1,552,452,847    | 1000       | -               |
| 1st                | 945,000        | Apr 2026 (+1.33y)   | 1,627,352,847    | 500 (50%)  | 3.23%          |
| 2nd                | 1,050,000      | Apr 2028 (2y)       | 1,679,852,847    | 250 (50%)  | 1.57%          |
| 3rd                | 1,260,000      | Apr 2032 (4y)       | 1,732,352,847    | 125 (50%)  | 0.76%          |
| 4th                | 1,470,000      | Apr 2036 (4y)       | 1,758,602,847    | 62.5 (50%)   | 0.37%          |
| -                  | 2,197,560      | Jan 2050 (13.83y)   | 1,804,075,347    | 62.5 (0%)   | 0.18%          |


With these changes, miner incentives and PoX yield remain unchanged for another 16 months, which we believe is sufficient time for the nascent Nakamoto signer set to develop into a set of stable, professional block signers, and for the sBTC project to attract sufficient initial liquidity.

The model for both the current and proposed emissions schedules can be found in the SIP-029 Stacks Emission Model[4].

# Related Work

While many blockchain protocols implement token emission schedules with periodic reductions in block rewards, we are not aware of any precedent for modifying an emission schedule specifically to maintain economic incentives during major protocol upgrades.

# Backwards Compatibility

This change requires a hard fork of the Stacks blockchain

# Activation

## Voting Timeline

Voting will begin at bitcoin block height 870,750, which occurs ~ Sunday, November 17th, 2024.
Voting will conclude at bitcoin block height 872,750, which occurs ~ Sunday, December 1st, 2024.

## Activation

The SIP-029 STX emission schedule is designed to activate on Stacks 3.0 as defined in [SIP-021](https://github.com/stacksgov/sips/blob/main/sips/sip-021/sip-021-nakamoto.md).  The SIP-029 emission schedule will be active starting at bitcoin block height 875,000, which is in the middle of stacking cycle 99.

### Process of Activation

Users can vote to approve this SIP with either their locked/stacked STX or with unlocked/liquid STX, or both. The SIP voting page can be found at [stx.eco](https://stx.eco). The criteria for the stacker and non-stacker voting is as follows.

#### To Vote:

In order for this SIP to activate, the following criteria must be met:

- At least 80 million stacked STX must vote, with at least 80% of all stacked STX committed by voting must be in favor of the proposal (vote "yes").
- At least 80% of all liquid STX committed by voting must be in favor of the proposal (vote "yes").

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

All STX holders vote by sending Stacks dust to the corresponding Stacks address from the account where their Stacks are held (stacked or liquid). To simplify things, user's can create their votes by visiting the [stx.eco](https://stx.eco/) platform. Voting power is determined by a snapshot of the amount of STX (stacked and un-stacked) at the block height at which the voting started (preventing the same STX from being transferred between accounts and used to effectively double vote).

Solo stackers only can also vote by sending a bitcoin dust transaction (6000 sats) to the corresponding bitcoin address.

#### For Miners

There is only one criterion for miners to activate this SIP: they must mine the Stacks blockchain up to and past the end of the voting period (bitcoin block height 872,750). In all reward cycles between cycle 97 & 98 and the end of the voting period, PoX must activate.

# Reference Implementation

The reference implementation can be found at https://github.com/stacks-network/stacks-core/pull/5461.

# References

[1] Soslow, J (2023) Review of Mining Emissions and Risks of the Halving. Available at https://stx.is/emissions-report-1 [Verified 5 November 2024]

[2] Soslow, J (2023) Halving Proposals. Available at https://stx.is/emissions-report-1 [Verified 5 November 2024]

[3] Laughlin, B (2024) Aligning with Bitcoin Halving and Incentives after Nakamoto. [Online forum post] forum.stacks.org https://forum.stacks.org/t/aligning-with-bitcoin-halving-and-incentives-after-nakamoto/17668 [Verified 5 November 2024]

[4] Müffke, F & Corcoran, W (2024) SIP-029 Stacks Emission Model. [Online spreadsheet] docs.google.com https://docs.google.com/spreadsheets/d/1ZRQgQV99kWvcSjkmZWKgldflcB2ytaN6sjo2RiHcjnk/edit?gid=0#gid=0 [Verified 13 November 2024]
