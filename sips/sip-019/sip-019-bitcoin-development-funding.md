# Preamble

SIP Number: 019

Title: Fund Bitcoin Development

Author: Ludo Galabru <ludo@hiro.so>

Consideration: Technical

Type: Consensus

Status: Draft

Created: 2 May 2022

License: CC0-1.0

Sign-off: 

Discussions-To: https://github.com/stacksgov/sips

# Abstract

This document evaluates the consequences of turning the tokens being 
burnt for minting Stacks into a source of funding for its base chain. 

# Introduction

The Stacks chain exists thanks to the base chain it anchors its blocks
to. The PoX does reward the nodes building this chain, but does not help
consolidating the development of this base chain.

The Stacks chain launched in January 2021. Since then, the chain saw a 
total of 32 PoX cycles.
In the PoX design, a theoritical total of 4000 slots can be allocated.
When looking at the details of the past cycles, the following can be observed:

| Cycle # | Reserved slots | Vacant slots | BTX committed | Amount of BTC burnt |
| - | ----- | ---- | ---| ----|
| 1 | 1,332 | 2668 | 14 | 9.338 |
| 2 | 2,158 | 1842 | 28 | 12.894 |
| 3 | 2,991 | 1009 | 63 | 15.89175 |
| 4 | 3,479 | 521 | 61 | 7.94525 |
| 5 | 3,649 | 351 | 38 | 3.3345 |
| 6 | 3,715 | 285 | 57 | 4.06125 |
| 7 | 3,709 | 291 | 59 | 4.29225 |
| 8 | 3,729 | 271 | 48 | 3.252 |
| 9 | 3,497 | 503 | 37 | 4.65275 |
| 10 | 3,664 | 336 | 31 | 2.604 |
| 11 | 3,757 | 243 | 44 | 2.673 |
| 12 | 3,572 | 428 | 46 | 4.922 |
| 13 | 3,551 | 449 | 48 | 5.388 |
| 14 | 3,707 | 293 | 48 | 3.516 |
| 15 | 3,844 | 156 | 50 | 1.95 |
| 16 | 3,864 | 136 | 50 | 1.7 |
| 17 | 3,791 | 209 | 48 | 2.508 |
| 18 | 3,657 | 343 | 49 | 4.20175 |
| 19 | 3,781 | 219 | 55 | 3.01125 |
| 20 | 3,562 | 438 | 56 | 6.132 |
| 21 | 3,870 | 130 | 55 | 1.7875 |
| 22 | 3,686 | 314 | 70 | 5.495 |
| 23 | 3,822 | 178 | 69 | 3.0705 |
| 24 | 3,755 | 245 | 72 | 4.41 |
| 25 | 3,654 | 346 | 71 | 6.1415 |
| 26 | 3,787 | 213 | 60 | 3.195 |
| 27 | 3,701 | 299 | 56 | 4.186 |
| 28 | 3,638 | 362 | 46 | 4.163 |
| 29 | 3,685 | 315 | 55 | 4.33125 |
| 30 | 3,899 | 101 | 54 | 1.3635 |
| 31 | 3,673 | 327 | 46 | 3.7605 |

Assuming that the data from stacking.club is correctly collected, over the last 31 cycles, looking exclusively at "vacant PoX slots", an approximate total of 146 BTC were burnt.

The goal of this SIP and the discussions around it, is to evaluate wether or not turning the process of burning BTC for vacant slots could be turned into crypto donations for fuelling the dvelopment of Bitcoin.

In a more sophisticated version, these funds could be sent to a multisig administrated by a DAO / smart-contract, but in its most naive version, the Bitcoin core development team address could be used (instead of the 0x00 burn address) when Stacks miners are processing vacant PoX slots.
