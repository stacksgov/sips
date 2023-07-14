## Producer Set Selection

The producer set selection for term _N_ occurs during term _N-2_. Similar to the leader block commitments used in the current miner selection process, as defined in [SIP-001](https://github.com/stacksgov/sips/blob/main/sips/sip-001/sip-001-burn-election.md) and amended in [SIP-007](https://github.com/stacksgov/sips/blob/main/sips/sip-007/sip-007-stacking-consensus.md), would-be producers issue a Bitcoin transaction known as a producer set transfer.

### Producer Set Enrollments

Producer set enrollments have the same constraints on the Bitcoin transaction's inputs as PoX leader block commitments. Specifically, the first input of this Bitcoin operation must originate from the same address as the second output of the [VRF key registration](https://github.com/stacksgov/sips/blob/main/sips/sip-001/sip-001-burn-election.md#leader-vrf-key-registrations). The first output of a producer set enrollment must be an `OP_RETURN` with the following data:

```
            0      2  3     7    11    15    19                         80
            |------|--|-----|-----|-----|-----|-------------------------|
             magic  op set   set   key   key       padding
                       block txoff block txoff
```

Where `op = @` and:

- `set_block` is the burn block height of the final block announced in the previous term, N-3. This ensures that the enrollment is only accepted if it is processed during the correct term.
- `set_txoff` is the vtxindex for the final block announced in the previous term, N-3.
- `key_block` is the burn block height of this producer's VRF key registration
- `key_txoff` is the vtxindex for this producer's VRF key registration

The subsequent output(s) in this transaction are the PoX outputs:

1. If the producer set enrollment is in a reward cycle, then outputs 1 through 20 must go to the chosen PoX recipients.
   - Recipients are chosen as described in "Stacking Consensus Algorithm" in SIP-007, using the final block announcement of term N-3 as the source: addresses are chosen without replacement, by using the sortition hash, mixed with the burn header hash of the final block announcement from term N-3 as the seed for the ChaCha12 pseudorandom function to select 20 addresses. Since a producer set term lasts 10 Bitcoin blocks, there are 20 PoX recipients, 2 per Bitcoin block, to maintain the same number of reward slots and payment frequency.
   - The order of these outputs does not matter.
   - Each of these outputs must receive the same amount of BTC.
   - If the number of remaining addresses in the reward set, N, is less than 20, then the producer set enrollment must burn BTC by including (20-N) burn outputs
2. Otherwise, the second output must be a burn address.

### Censorship Resistance

The producer set enrollments for set _N_ can be included in any of the 10 Bitcoin blocks in producer set _N-2_. This makes it extremely difficult for a Bitcoin miner to censor these transactions, since to do so, they would need to control all 10 Bitcoin blocks in that term.

### Selecting Producers

Would-be producers with valid producer set enrollments in term _N-2_ are eligible to be included in the producer set for term _N_. The total number of producers in a set needs to be limited to prevent coinbase payouts from including too many accounts, as this could slow down event processing and even open a new DoS vector. This cap will also prevent the block-signing process from becoming too expensive. To this end, the total amount of BTC spent in the outputs described in "Producer Set Enrollments" is used to select the producer set. Would-be producers are ranked by these BTC expenditures, and the top 100 will be selected for the producer set.

_TODO: Think more about the rollover of credits for would-be producers that were not in the top 100. Is this necessary to avoid disadvantaging small miners? Does this open another DoS attack? Maybe it should have some minimum amount, some maximum number of consecutive terms that credits can rollover, and/or some maximum number of producers._

## Producer Rewards

During a term, producers in the set are eligible to receive a portion of the coinbase rewards and transaction fees for blocks they produce. Since a term is defined as 10 Bitcoin blocks, the coinbase reward is equal to 10 times the coinbase as defined in **_<which SIP defines this?>_**. This amount is distributed to all producers in the set proportionally, based on the percentage of the total BTC spent in the producer set enrollments. All producers receive their portion of the coinbase, regardless of whether or not they signed the blocks produced by the set. The coinbase transaction should be the first transaction in a term.

The producer set is then incentivized to continue producing blocks throughout the term by the transaction fees. Transaction fees are paid only to producer set participants who signed the blocks produced. For each block, _B_, the total BTC spent by all signers block _B_ is computed, then the transaction fees for all transactions in block _B_ are distributed proportionally based on BTC spent by each signer in their producer set enrollment.

**\*Question:** Does this incentivize some kind of race to submit a block to the stackers to sign, before all of the producers have had a chance to sign it (after 67% have signed)?\*