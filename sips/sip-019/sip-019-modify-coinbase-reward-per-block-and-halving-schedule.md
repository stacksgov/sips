# Preamble

SIP Number: 019

Title: Modify Coinbase Reward per Block & Halving Schedule

Author: Xan Ditkoff (email: xan@daemontechnologies.co)

Consideration: Technical, Governance, Economics

Type: Standard

Status: Draft

Created: 20 April 2022

License: CC0-1.0

Sign-off: 

# Abstract
There are currently two ways the Stacks network rewards STX miners when they win a block: STX tokens as part of a “Coinbase reward” and STX tokens from transaction fees. The purpose of the Coinbase reward is to bootstrap and to provide an extra incentive for miners to secure the network in the early days, when transaction fees are not yet sufficient. 

For the first 10,000 blocks of the Stacks mainnet launch the coinbase reward was 2000 STX compared with 1000 STX today. This period coincided with significant interest from users and miners. Historically, the year 2050 STX supply has been reduced in the past (from 5B to 2B to 1.8B). This proposal calls for a slight increase in the year 2050 supply, and returning the current coinbase reward to 2000 STX until the next halving. 

# License and Copyright
This SIP is made available under the terms of the Creative Commons CC0 1.0 Universal license, available at https://creativecommons.org/publicdomain/zero/1.0/ This SIP’s copyright is held by the Stacks Open Internet Foundation.

# Introduction
Open membership blockchain based networks need to provide an economic incentive for miners to process transactions and provide security. Coinbase rewards are typically used to bootstrap this economic incentive in the early days of an open source network when transaction fees alone will not provide a sufficient incentive. Currently, the coinbase reward for the Stacks network is 1000 STX per block, with a halving schedule as follows:

<img width="659" alt="Screenshot 2022-05-16 at 2 35 35 PM" src="https://user-images.githubusercontent.com/31934541/168593660-d13311d9-2710-4202-bc9d-e41bf4d6c945.png">

For the first ten thousand blocks of Stacks 2.0, however, the coinbase reward was inflated to 2000 STX per block, and resulted in much more favorable STX mining and Stacking conditions. Since the purpose of a coinbase reward is to bootstrap the network in the early days, we propose increasing the coinbase reward and subsequently modifying the halving schedule.

# Modifications
This SIP proposes a change to the current STX coinbase reward, and therefore also a subsequent change to the halving schedule for the STX coinbase reward. The changes are as follows:

## STX Coinbase Reward
Change the current coinbase reward to 1600 STX per block. This change will remain in effect until the next halving for the Stacks network, which will occur roughly two years from the time of writing this draft.

## STX Halving Schedule
The current halving schedule for coinbase reward amounts are:
1000 STX per block are released in the first 4 years of mining
500 STX per block are released during the following 4 years
250 STX per block are released during the following 4 years
125 STX per block are released from then on indefinitely.

This proposal would modify the schedule to the following:
1600 STX per block are released from SIP acceptance until first halving (~2 years)
800 STX per block are released during the following 4 years
400 STX per block are released during the following 4 years
200 STX per block are released during the following 4 years
100 STX per block are released from then on indefinitely

# Effects on STX Inflation & 2050 Supply
The current cumulative mining mint results in a total circulating supply of approximately 1,810,745,848 STX tokens by January 2050. With the adoption of this proposal, the 2050 total circulating supply will increase by approximately 157 million STX tokens, to 1,967,777,098. Below is a visual comparison of the change.

<img width="639" alt="Screenshot 2022-05-16 at 2 32 16 PM" src="https://user-images.githubusercontent.com/31934541/168593836-985e5613-80c8-42b0-8649-d3e6f9d595a1.png">

<img width="641" alt="Screenshot 2022-05-16 at 2 25 14 PM" src="https://user-images.githubusercontent.com/31934541/168593867-f42714a0-4549-40e4-a0ad-fa15266ed269.png">

The resulting change to the annual inflation rate of the STX token is as follows:

<img width="584" alt="Screenshot 2022-05-16 at 2 31 51 PM" src="https://user-images.githubusercontent.com/31934541/168593918-ffa2282f-ed87-44c7-a1d2-257d32af5d0f.png">

# Related Work
[STX token supply model](https://docs.google.com/spreadsheets/d/1Z8Rf3w6xQHpOlf4XNRH6r2uCTyI5W2HXefSkC5pPqmU/edit?usp=sharing)

# Backwards Compatibility
Yes.

# Activation
The activation criteria for this SIP needs input and debate, and should ultimately be defined by the Stacks community. Given this changes the monetary supply of STX, it should have to hit a high bar in order to pass and be adopted.
