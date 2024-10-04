import { poxAddressToBtcAddress, poxAddressToTuple } from '@stacks/stacking';
import axios from 'axios';
import { cvToJSON } from '@stacks/transactions';
import { writeFileSync } from 'fs';

const MULTISIG_POOL_VOTES_FILE = 'multisig-pool-votes.csv';
const MULTISIG_SOLO_VOTES_FILE = 'multisig-solo-votes.csv';

function convertVotesToCsv(votes) {
  const headers = 'voter,txid,for,power\n';
  const rows = votes.map(vote => 
    `${vote.voter},${vote.txid},${vote.for},${vote.power}`
  ).join('\n');
  
  return headers + rows;
}

const YES_STX_ADDRESS = "SPA17ZSXKXS4D8FC51H1KWQDFS31NM29SKZRTCF8";
const NO_STX_ADDRESS = "SP39DK8BWFM2SA0E3F6NA72104EYG9XB8NXZ91NBE";

const YES_BTC_ADDRESS = "399iMhKN9fjpPJLYHzieZA1PfHsFxijyVY";
const NO_BTC_ADDRESS = "31ssu69FmpxS6bAxjNrX1DfApD8RekK7kp";

const CYCLE_TO_CHECK_FOR = 90;

const GET_EVENTS_API_URL = `https://api.mainnet.hiro.so/extended/v1/tx/events`;
const POX_INFO_URL = `https://api.mainnet.hiro.so/v2/pox`;
const SIGNERS_IN_CYCLE_API_URL = (cycle) => `https://api.hiro.so/extended/v2/pox/cycles/${cycle}/signers`;
const POX_4_ADDRESS = 'SP000000000000000000002Q6VF78.pox-4';
const LIMIT = 100;

async function fetchData(offset) {
  try {
    const response = await axios.get(GET_EVENTS_API_URL, {
      params: {
        address: POX_4_ADDRESS,
        limit: LIMIT,
        offset: offset,
      },
    });

    return response.data.events;
  } catch (error) {
    if (error.response) {
      if (error.response.status !== 404) {
        await new Promise((resolve) => setTimeout(resolve, 10000));
        return fetchData(offset);
      } else {
        console.error(`Error: ${error}`);
      }
    } else {
      console.error(`Error: ${error}`);
    }
    return null;
  }
}

async function fetchAddressTransactionsStacks(offset, address) {
  try {
    const response = await axios.get(`https://api.hiro.so/extended/v2/addresses/${address}/transactions?limit=50&offset=${offset}`);

    return response.data.results;
  } catch (error) {
    if (error.response) {
      if (error.response.status === 429) {
        await new Promise((resolve) => setTimeout(resolve, 10000));
        return fetchAddressTransactionsStacks(offset, address);
      } else {
        console.error(`Error: ${error}`);
      }
    } else {
      console.error(`Error: ${error}`);
    }
    return null;
  }
}

async function fetchAddressTransactionsBitcoin(address) {
  try {
    const response = await axios.get(`https://mempool.space/api/address/${address}/txs`);

    return response.data;
  } catch (error) {
    if (error.response) {
      if (error.response.status === 429) {
        await new Promise((resolve) => setTimeout(resolve, 10000));
        return fetchAddressTransactionsBitcoin(address);
      } else {
        console.error(`Error: ${error}`);
      }
    } else {
      console.error(`Error: ${error}`);
    }
    return null;
  }
}

async function fetchPoxInfo() {
  try {
    const response = await axios.get(POX_INFO_URL);
    return response.data;
  } catch (error) {
    if (error.response) {
      if (error.response.status === 429) {
        await new Promise((resolve) => setTimeout(resolve, 10000));
        return fetchPoxInfo();
      } else {
        console.error(`Error fetching PoX info: ${error}`);
      }
    } else {
      console.error(`Error fetching PoX info: ${error}`);
    }
    return null;
  }
}

async function fetchSignersInCycle(cycle) {
  try {
    const response = await axios.get(SIGNERS_IN_CYCLE_API_URL(cycle));
    return response.data;
  } catch (error) {
    if (error.response) {
      if (error.response.status === 429) {
        await new Promise((resolve) => setTimeout(resolve, 10000));
        return fetchPoxInfo();
      } else {
        console.error(`Error fetching signers info: ${error}`);
      }
    } else {
      console.error(`Error fetching signers info: ${error}`);
    }
    return null;
  }
}

function parseStringToJSON(input) {
  function parseValue(value) {
    if (value.startsWith('(tuple')) return parseTuple(value);
    if (value.startsWith('(some')) return parseSome(value);
    if (value === 'none') return null;
    if (value.startsWith('u')) return parseInt(value.slice(1), 10);
    if (value.startsWith('0x')) return value;
    if (value.startsWith("'") && value.endsWith("'")) return value.slice(1, -1);
    if (value.startsWith("'")) return value.slice(1);
    if (value.startsWith('"') && value.endsWith('"')) return value.slice(1, -1);
    if (value.startsWith('"')) return value.slice(1);
    return value;
  }

  function parseTuple(value) {
    const obj = {};
    const tupleContent = value.slice(7, -1).trim();
    const entries = splitEntries(tupleContent);

    entries.forEach((entry) => {
      const spaceIndex = entry.indexOf(' ');
      const key = entry.slice(1, spaceIndex);
      const val = entry.slice(spaceIndex + 1).trim().slice(0, -1);
      obj[key] = parseValue(val);
    });

    return obj;
  }

  function parseSome(value) {
    const someContent = value.slice(5, -1).trim();
    return parseValue(someContent);
  }

  function splitEntries(content) {
    const entries = [];
    let bracketCount = 0;
    let startIdx = 0;

    for (let i = 0; i < content.length; i++) {
      if (content[i] === '(') bracketCount++;
      if (content[i] === ')') bracketCount--;
      if (bracketCount === 0 && (content[i] === ' ' || i === content.length - 1)) {
        entries.push(content.slice(startIdx, i + 1).trim());
        startIdx = i + 1;
      }
    }

    return entries;
  }

  function parseMain(input) {
    const mainContent = input.slice(4, -1).trim();
    if (mainContent.startsWith('(tuple')) return parseTuple(mainContent);
    const entries = splitEntries(mainContent);
    const result = {};

    entries.forEach((entry) => {
      const spaceIndex = entry.indexOf(' ');
      const key = entry.slice(1, spaceIndex);
      const val = entry.slice(spaceIndex + 1).trim().slice(0, -1);
      result[key] = parseValue(val);
    });

    return result;
  }

  return parseMain(input);
}

function getEventsForAddress(address, allEvents) {
  let events = [];
  let isDelegator = false;
  let delegatedTo = [];
  let isSoloStacker = false;

  for (const entry of allEvents) {
    if (entry.contract_log.value.repr.includes(address)) {
      const result = parseStringToJSON(entry.contract_log.value.repr);
      if (result.name == "stack-stx") {
        events.push({
          name: result.name,
          stacker: result.stacker,
          startCycle: result.data["start-cycle-id"],
          endCycle: result.data["end-cycle-id"],
          poxAddress: result.data["pox-addr"] != null ? 
            poxAddressToBtcAddress(
              parseInt(result.data["pox-addr"].version, 16),
              Uint8Array.from(Buffer.from(result.data["pox-addr"].hashbytes.slice(2), 'hex')),
              'mainnet',
            ) :
            null,
          signerKey: result.data["signer-key"],
          amountUstx: result.data["lock-amount"],
        });
        isSoloStacker = true;
      } else if (result.name == "stack-extend") {
        events.push({
          name: result.name,
          stacker: result.stacker,
          startCycle: result.data["start-cycle-id"],
          endCycle: result.data["end-cycle-id"],
          poxAddress: result.data["pox-addr"] != null ? 
            poxAddressToBtcAddress(
              parseInt(result.data["pox-addr"].version, 16),
              Uint8Array.from(Buffer.from(result.data["pox-addr"].hashbytes.slice(2), 'hex')),
              'mainnet',
            ) :
            null,
        });
      } else if (result.name == "stack-increase") {
        events.push({
          name: result.name,
          stacker: result.stacker,
          startCycle: result.data["start-cycle-id"],
          endCycle: result.data["end-cycle-id"],
          poxAddress: result.data["pox-addr"] != null ? 
            poxAddressToBtcAddress(
              parseInt(result.data["pox-addr"].version, 16),
              Uint8Array.from(Buffer.from(result.data["pox-addr"].hashbytes.slice(2), 'hex')),
              'mainnet',
            ) :
            null,
          amountUstx: result.data["total-locked"],
        });
      } else if (result.name == "delegate-stx") {
        events.push({
          name: result.name,
          stacker: result.stacker,
          amountUstx: result.data["amount-ustx"],
          startCycle: result.data["start-cycle-id"],
          endCycle: result.data["end-cycle-id"],
          poxAddress: result.data["pox-addr"] != null ? 
            poxAddressToBtcAddress(
              parseInt(result.data["pox-addr"].version, 16),
              Uint8Array.from(Buffer.from(result.data["pox-addr"].hashbytes.slice(2), 'hex')),
              'mainnet',
            ) :
            null,
        });
        if (result.stacker === address) {
          isDelegator = true;
          delegatedTo.push(result.data["delegate-to"]);
        }
      } else if (result.name == "revoke-delegate-stx") {
        events.push({
          name: result.name,
          stacker: result.stacker,
          startCycle: result.data["start-cycle-id"],
          endCycle: result.data["end-cycle-id"],
        });
      } else if (result.name == "delegate-stack-stx") {
        events.push({
          name: result.name,
          stacker: result.data.stacker,
          amountUstx: result.data["lock-amount"],
          startCycle: result.data["start-cycle-id"],
          endCycle: result.data["end-cycle-id"],
          poxAddress: result.data["pox-addr"] != null ? 
            poxAddressToBtcAddress(
              parseInt(result.data["pox-addr"].version, 16),
              Uint8Array.from(Buffer.from(result.data["pox-addr"].hashbytes.slice(2), 'hex')),
              'mainnet',
            ) :
            null,
        });
      } else if (result.name == "delegate-stack-extend") {
        events.push({
          name: result.name,
          stacker: result.data.stacker,
          startCycle: result.data["start-cycle-id"],
          endCycle: result.data["end-cycle-id"],
          poxAddress: result.data["pox-addr"] != null ? 
            poxAddressToBtcAddress(
              parseInt(result.data["pox-addr"].version, 16),
              Uint8Array.from(Buffer.from(result.data["pox-addr"].hashbytes.slice(2), 'hex')),
              'mainnet',
            ) :
            null,
        });
      } else if (result.name == "delegate-stack-increase") {
        events.push({
          name: result.name,
          stacker: result.data.stacker,
          startCycle: result.data["start-cycle-id"],
          endCycle: result.data["end-cycle-id"],
          increaseBy: result.data["increase-by"],
          totalLocked: result.data["total-locked"],
          poxAddress: result.data["pox-addr"] != null ? 
            poxAddressToBtcAddress(
              parseInt(result.data["pox-addr"].version, 16),
              Uint8Array.from(Buffer.from(result.data["pox-addr"].hashbytes.slice(2), 'hex')),
              'mainnet',
            ) :
            null,
        });
      } else if (result.name == "stack-aggregation-commit-indexed" || result.name == "stack-aggregation-commit") {
        events.push({
          name: result.name,
          amountUstx: result.data["amount-ustx"],
          cycle: result.data["reward-cycle"],
          poxAddress: result.data["pox-addr"] != null ? 
            poxAddressToBtcAddress(
              parseInt(result.data["pox-addr"].version, 16),
              Uint8Array.from(Buffer.from(result.data["pox-addr"].hashbytes.slice(2), 'hex')),
              'mainnet',
            ) :
            null,
          signerKey: result.data["signer-key"],
        });
      } else if (result.name == "stack-aggregation-increase") {
        events.push({
          name: result.name,
          amountUstx: result.data["amount-ustx"],
          cycle: result.data["reward-cycle"],
          rewardCycleIndex: result.data["reward-cycle-index"],
          poxAddress: result.data["pox-addr"] != null ? 
            poxAddressToBtcAddress(
              parseInt(result.data["pox-addr"].version, 16),
              Uint8Array.from(Buffer.from(result.data["pox-addr"].hashbytes.slice(2), 'hex')),
              'mainnet',
            ) :
            null,
        });
      };
    };
  };

  return {events, isDelegator, delegatedTo, isSoloStacker};
}

function getStackerForBtcAddress(address, allEvents) {
  let print = false;
  if (address == "bc1p7l2cywf6qr9gwca3vsv6mwdlkfl3f7agw9kdm98re7jmn087q86suc2lpk" || address == "bc1p6dm28490l7yxl935yplp2pd92psj5yt82sfp2tpqc93ah3u6gges97q9sw") {
    print = true;
  };
  const addressDeserialized = cvToJSON(poxAddressToTuple(address));
  const version = addressDeserialized.value.version.value;
  const hashbytes = addressDeserialized.value.hashbytes.value;

  for (const entry of allEvents) {
    if (entry.contract_log.value.repr.includes(version) && entry.contract_log.value.repr.includes(hashbytes)) {
      if (print == true) {
        console.log(address, entry);
      }
      const result = parseStringToJSON(entry.contract_log.value.repr);
      if (result.name == "stack-stx") {
        return result.stacker;
      }
    }
  }

  return "Could not find BTC address";
}

async function fetchAllData() {
  const poxInfo = await fetchPoxInfo();
  if (poxInfo === null) return;

  let offset = 0;
  let moreData = true;
  let allEvents = [];

  while (moreData) {
    const data = await fetchData(offset);

    if (data && data.length > 0) {
      for (const entry of data) {
        allEvents.push(entry);
      }
      offset += LIMIT;
    } else {
      moreData = false;
    }
  }

  offset = 0;
  moreData = true;
  const ADDRESSES = [];

  // 854,950 until 857,050

  while (moreData) {
    const data = await fetchAddressTransactionsStacks(offset, YES_STX_ADDRESS);

    if (data && data.length > 0) {
      for (const entry of data) {
        if (entry.tx.burn_block_height >= 854950 && entry.tx.burn_block_height < 857050) {
          ADDRESSES.push({
            address: entry.tx.sender_address,
            time: entry.tx.burn_block_time,
            nonce: entry.tx.nonce,
            vote: "yes",
            txid: entry.tx.tx_id,
          });
        };
      }
      offset += 50;
    } else {
      moreData = false;
    }
  }

  offset = 0;
  moreData = true;

  while (moreData) {
    const data = await fetchAddressTransactionsStacks(offset, NO_STX_ADDRESS);

    if (data && data.length > 0) {
      for (const entry of data) {
        if (entry.tx.burn_block_height >= 854950 && entry.tx.burn_block_height < 857050) {
          ADDRESSES.push({
            address: entry.tx.sender_address,
            time: entry.tx.burn_block_time,
            nonce: entry.tx.nonce,
            vote: "no",
            txid: entry.tx.tx_id,
          });
        };
      }
      offset += 50;
    } else {
      moreData = false;
    }
  }

  const btcYesData = await fetchAddressTransactionsBitcoin(YES_BTC_ADDRESS);
  if (btcYesData && btcYesData.length > 0) {
    for (const entry of btcYesData) {
      if (entry.status.confirmed == true) {
        if (entry.status.block_height >= 854950 && entry.status.block_height < 857050) {
          ADDRESSES.push({
            btcAddress: entry.vin[0].prevout.scriptpubkey_address,
            address: getStackerForBtcAddress(entry.vin[0].prevout.scriptpubkey_address, allEvents),
            time: entry.status.block_time,
            nonce: null,
            vote: "yes",
            txid: entry.txid,
          });
        };
      };
    }
  }

  const btcNoData = await fetchAddressTransactionsBitcoin(NO_BTC_ADDRESS);
  if (btcNoData && btcNoData.length > 0) {
    for (const entry of btcNoData) {
      if (entry.status.confirmed == true) {
        if (entry.status.block_height >= 854950 && entry.status.block_height < 857050) {
          ADDRESSES.push({
            btcAddress: entry.vin[0].prevout.scriptpubkey_address,
            address: getStackerForBtcAddress(entry.vin[0].prevout.scriptpubkey_address, allEvents),
            time: entry.status.block_time,
            nonce: null,
            vote: "no",
            txid: entry.txid,
          });
        };
      };
    }
  }

  ADDRESSES.sort((a, b) => {
    if (a.time === b.time) {
      return a.nonce - b.nonce;
    }
    return a.time - b.time;
  });

  // SM3QS5GHTHQ7HZ1P04XWQJXK5B5HN1V24BEMWM7Q9 and SM14HV23Z50KK8WBK84C3KPJG78EZWPHYHQB584NQ are counted as valid votes - voted with pool reward address, no time left to do STX

  let totalVotes = 2; // SM3QS5GHTHQ7HZ1P04XWQJXK5B5HN1V24BEMWM7Q9 + SM14HV23Z50KK8WBK84C3KPJG78EZWPHYHQB584NQ
  let validVotes = 2; // SM3QS5GHTHQ7HZ1P04XWQJXK5B5HN1V24BEMWM7Q9 + SM14HV23Z50KK8WBK84C3KPJG78EZWPHYHQB584NQ
  let yesVotes = 2; // SM3QS5GHTHQ7HZ1P04XWQJXK5B5HN1V24BEMWM7Q9 + SM14HV23Z50KK8WBK84C3KPJG78EZWPHYHQB584NQ
  let noVotes = 0;
  let yesVotesInvalid = 0;
  let noVotesInvalid = 0;
  let notStacking = 0;
  let notStackingInCycle = 0;

  let soloStackerVotes = 0;
  let delegatorVotes = 2; // SM3QS5GHTHQ7HZ1P04XWQJXK5B5HN1V24BEMWM7Q9 + SM14HV23Z50KK8WBK84C3KPJG78EZWPHYHQB584NQ
  let totalSoloStackerAmountYes = 0;
  let totalDelegatedAmountYes = 29819000000000 + 20000000000000; // SM3QS5GHTHQ7HZ1P04XWQJXK5B5HN1V24BEMWM7Q9 + SM14HV23Z50KK8WBK84C3KPJG78EZWPHYHQB584NQ
  let totalSoloStackerAmountNo = 0;
  let totalDelegatedAmountNo = 0;

  let soloStackerVotesForCsv = [];
  let poolStackerVotesForCsv = [];

  const verifiedAddresses = [];

  for (const {address, btcAddress, vote, txid} of ADDRESSES) {
    console.log("Processing PoX data for", btcAddress !== undefined ? btcAddress : address + ":");

    if (address == "SM3QS5GHTHQ7HZ1P04XWQJXK5B5HN1V24BEMWM7Q9" || address == "SM14HV23Z50KK8WBK84C3KPJG78EZWPHYHQB584NQ") {
      continue;
    };

    if (verifiedAddresses.includes(address)) {
      console.log("This address already voted!");
      console.log();
      continue;
    };

    if (address !== "Could not find BTC address") {
      verifiedAddresses.push(address);
    };

    let {events, isDelegator, delegatedTo, isSoloStacker} = getEventsForAddress(address, allEvents);

    let wasStacking = false;
    let stackingSignerKey = null;
    let delegatedAmount = 0;
    let stackedAmount = 0;

    totalVotes++;

    if (isDelegator === true) {
      for (const delegator of delegatedTo) {
        events = getEventsForAddress(delegator, allEvents).events;
        events.reverse();

        let delegations = new Map();
        let acceptedDelegations = new Map();
        let committedDelegations = new Map();

        let wasAccepted = false;
        let acceptedToAddress;
        let wasCommitted = false;

        let delegatedAmountLocal = 0;

        for (const event of events) {
          const { name, stacker, startCycle, endCycle, poxAddress, amountUstx, increaseBy, totalLocked, cycle, signerKey } = event;
  
          switch (name) {
            case 'delegate-stx':
              delegations.set(stacker, { startCycle, endCycle, poxAddress, amountUstx });
              break;
            case 'revoke-delegate-stx':
              delegations.delete(stacker);
              break;
            case 'delegate-stack-stx':
              acceptedDelegations.set(stacker, [{ startCycle, endCycle, poxAddress, amountUstx }]);
              break;
            case 'delegate-stack-extend':
              if (acceptedDelegations.has(stacker)) {
                const existingList = acceptedDelegations.get(stacker);
                const lastEntry = existingList[existingList.length - 1];
      
                lastEntry.endCycle = endCycle;
                acceptedDelegations.set(stacker, existingList);
              }
              break;
            case 'delegate-stack-increase':
              if (acceptedDelegations.has(stacker)) {
                const existingList = acceptedDelegations.get(stacker);
                const lastEntry = existingList[existingList.length - 1];
      
                if (lastEntry.amountUstx + increaseBy === totalLocked) {
                  if (lastEntry.startCycle === startCycle) {
                    lastEntry.amountUstx += increaseBy;
                  } else {
                    const newEntry = {
                      startCycle: startCycle,
                      endCycle: lastEntry.endCycle,
                      poxAddress: lastEntry.poxAddress,
                      amountUstx: lastEntry.amountUstx + increaseBy,
                    };

                    lastEntry.endCycle = startCycle;
                    existingList.push(newEntry);
                  }
                  acceptedDelegations.set(stacker, existingList);
                }
              }
              break;
            case 'stack-aggregation-commit':
            case 'stack-aggregation-commit-indexed':
              if (poxAddress) {
                if (!committedDelegations.has(poxAddress)) {
                  committedDelegations.set(poxAddress, [{ startCycle: cycle, endCycle: cycle + 1, amountUstx, signerKey }]);
                } else {
                  const existingList = committedDelegations.get(poxAddress);
                  existingList.push({
                    startCycle: cycle,
                    endCycle: cycle + 1,
                    amountUstx,
                    signerKey,
                  });
                  committedDelegations.set(poxAddress, existingList);
                }
              }
              break;
            case 'stack-aggregation-increase':
              if (poxAddress) {
                const existingList = committedDelegations.get(poxAddress);
                if (existingList) {
                  const entry = existingList.find(e => e.startCycle === cycle);
                  if (entry) {
                    entry.amountUstx += amountUstx;
                  }
                }
              }
              break;
          }
        }

        acceptedDelegations.forEach((value, key) => {
          if (key == address) {
            for (const acceptation of value) {
              if (acceptation.startCycle <= CYCLE_TO_CHECK_FOR && acceptation.endCycle > CYCLE_TO_CHECK_FOR) {
                wasAccepted = true;
                acceptedToAddress = acceptation.poxAddress;
                delegatedAmountLocal += acceptation.amountUstx;
                break;
              }
            }
          }
        });

        committedDelegations.forEach((value, key) => {
          if (key === acceptedToAddress) {
            for (const commitment of value) {
              if (commitment.startCycle == CYCLE_TO_CHECK_FOR) {
                wasCommitted = true;
                stackingSignerKey = commitment.signerKey;
                break;
              }
            }
          }
        });

        if (wasAccepted === true && wasCommitted === true) {
          wasStacking = true;
          delegatedAmount += delegatedAmountLocal;
        }
      }
    } else if (isSoloStacker === true) {
      events.reverse();

      let soloStacking = new Map();

      for (const event of events) {
        const { name, stacker, startCycle, endCycle, poxAddress, signerKey, amountUstx } = event;

        switch (name) {
          case 'stack-stx':
            if (!soloStacking.has(stacker)) {
              soloStacking.set(stacker, [{ startCycle, endCycle, poxAddress, signerKey, amountUstx }]);
            } else {
              const existingList = soloStacking.get(stacker);
              existingList.push({ startCycle, endCycle, poxAddress, signerKey, amountUstx });
              soloStacking.set(stacker, existingList);
            }
            break;
          case 'stack-extend':
            if (soloStacking.has(stacker)) {
              const existingListExtend = soloStacking.get(stacker);
              const lastEntryExtend = existingListExtend[existingListExtend.length - 1];

              if (lastEntryExtend.endCycle === startCycle) {
                lastEntryExtend.endCycle = endCycle;
                soloStacking.set(stacker, existingListExtend);
              }
            }
            break;
          case 'stack-increase':
            if (soloStacking.has(stacker)) {
              const existingList = soloStacking.get(stacker);
              const lastEntry = existingList[existingList.length - 1];

              if (lastEntry.startCycle === startCycle) {
                lastEntry.amountUstx = amountUstx;
              } else {
                const newEntry = {
                  startCycle: startCycle,
                  endCycle: lastEntry.endCycle,
                  poxAddress: lastEntry.poxAddress,
                  signerKey: signerKey,
                  amountUstx: amountUstx,
                };
  
                lastEntry.endCycle = startCycle;
                existingList.push(newEntry);
              }
              soloStacking.set(stacker, existingList);
            }
            break;
        }
      }

      soloStacking.forEach((value, key) => {
        for (const stack of value) {
          if (stack.startCycle <= CYCLE_TO_CHECK_FOR && stack.endCycle > CYCLE_TO_CHECK_FOR) {
            wasStacking = true;
            stackingSignerKey = stack.signerKey;
            stackedAmount += stack.amountUstx;
            break;
          }
        }
      });
    } else {
      console.log("This address is neither a solo stacker, nor a delegator");
      notStacking++;
      if (vote === "yes") {
        yesVotesInvalid++;
      } else if (vote === "no") {
        noVotesInvalid++;
      };
      console.log();
      continue;
    }

    if (wasStacking === true) {
      console.log("This address was a stacker in cycle", CYCLE_TO_CHECK_FOR);
    } else {
      console.log("This address was not a stacker in cycle", CYCLE_TO_CHECK_FOR);
      notStackingInCycle++;
      if (vote === "yes") {
        yesVotesInvalid++;
      } else if (vote === "no") {
        noVotesInvalid++;
      };
      continue;
    };

    let wasActive = false;

    const signersInCycle = (await fetchSignersInCycle(CYCLE_TO_CHECK_FOR)).results;
    for (const signer of signersInCycle) {
      if (signer.signing_key === stackingSignerKey) {
        wasActive = true;
      }
    }

    if (wasActive === true) {
      console.log("The vote of this address is valid");
      console.log(delegatedAmount, stackedAmount);
      validVotes++;

      if (vote === "yes") {
        yesVotes++;
        totalDelegatedAmountYes += delegatedAmount || 0;
        totalSoloStackerAmountYes += stackedAmount || 0;
      } else if (vote === "no") {
        noVotes++;
        totalDelegatedAmountNo += delegatedAmount || 0;
        totalSoloStackerAmountNo += stackedAmount || 0;
      };

      if (isDelegator === true) {
        delegatorVotes++;
        poolStackerVotesForCsv.push({
          voter: btcAddress !== undefined ? btcAddress : address,
          txid: txid,
          for: vote === "yes" ? true : false,
          power: delegatedAmount || 0 + stackedAmount || 0,
        });
      };

      if (isSoloStacker === true) {
        soloStackerVotes++;
        soloStackerVotesForCsv.push({
          voter: btcAddress !== undefined ? btcAddress : address,
          txid: txid,
          for: vote === "yes" ? true : false,
          power: delegatedAmount || 0 + stackedAmount || 0,
        });
      }
    } else {
      if (vote === "yes") {
        yesVotesInvalid++;
      } else if (vote === "no") {
        noVotesInvalid++;
      };
      console.log("This vote is invalid");
    };

    console.log();
  }

  console.log("Blocks left of cycle", poxInfo.current_cycle.id + ":", poxInfo.next_cycle.blocks_until_prepare_phase);
  console.log("Total number of votes (unique addresses):", totalVotes);
  console.log("Number of invalid votes:", totalVotes - validVotes);
  console.log("Number of valid votes:", validVotes);
  console.log("Number of valid YES votes:", yesVotes);
  console.log("Number of valid NO votes:", noVotes);
  console.log("Number of invalid YES votes:", yesVotesInvalid);
  console.log("Number of invalid NO votes:", noVotesInvalid);
  console.log("Number of invalid votes (address not stacking at all):", notStacking);
  console.log("Number of invalid votes (address not stacking in cycle 90):", notStackingInCycle);
  console.log("Out of the valid votes,", delegatorVotes, "were delegators, and", soloStackerVotes, "were solo stackers.");
  console.log("Amount delegated YES:", totalDelegatedAmountYes / 1000000 + " STX");
  console.log("Amount solo stacked YES:", totalSoloStackerAmountYes / 1000000 + " STX");
  console.log("Amount delegated NO:", totalDelegatedAmountNo / 1000000 + " STX");
  console.log("Amount solo stacked NO:", totalSoloStackerAmountNo / 1000000 + " STX");

  const poolVotesCsv = convertVotesToCsv(poolStackerVotesForCsv);
  const soloVotesCsv = convertVotesToCsv(soloStackerVotesForCsv);

  writeFileSync(MULTISIG_POOL_VOTES_FILE, poolVotesCsv);
  writeFileSync(MULTISIG_SOLO_VOTES_FILE, soloVotesCsv);

  console.log('CSV files have been saved successfully.');
}

fetchAllData();
