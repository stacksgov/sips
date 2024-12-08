import { poxAddressToBtcAddress, poxAddressToTuple } from "@stacks/stacking";
import axios from "axios";
import { cvToJSON, hexToCV } from "@stacks/transactions";
import { writeFileSync } from "fs";

const VOTES_FILE = "votes.csv";

const START_HEIGHT = 870750;
const END_HEIGHT = 872750;
const STACKS_TIP_ID_HASH =
  "d06985e2f68036d51a67ac6341161a99c6879570fe20830561ed398c68a9dc52";

function convertVotesToCsv(votes) {
  const headers = "voter,txid,for,stacked_power,unstacked_power\n";
  const rows = votes
    .map(
      (vote) =>
        `${vote.voter},${vote.txid},${vote.for},${vote.stacked_power},${vote.unstacked_power}`
    )
    .join("\n");

  return headers + rows;
}

const YES_STX_ADDRESS = "SP00000000001WPAWSDEDMQ0B9J76GZNR3T";
const NO_STX_ADDRESS = "SP000000000006WVSDEDMQ0B9J76NCZPNZ";

const YES_BTC_ADDRESS = "11111111111mdWK2VXcrA1e7in77Ux";
const NO_BTC_ADDRESS = "111111111111ACW5wa4RwyeKgtEJz3";

const CYCLE_TO_CHECK_FOR = 97;

const API_KEY = process.env.HIRO_API_KEY;

const ACCOUNT_INFO_API_URL = (account) =>
  `https://api.mainnet.hiro.so/v2/accounts/${account}`;
const GET_EVENTS_API_URL = `https://api.mainnet.hiro.so/extended/v1/tx/events`;
const POX_INFO_URL = `https://api.mainnet.hiro.so/v2/pox`;
const SIGNERS_IN_CYCLE_API_URL = (cycle) =>
  `https://api.hiro.so/extended/v2/pox/cycles/${cycle}/signers`;
const POX_4_ADDRESS = "SP000000000000000000002Q6VF78.pox-4";
const LIMIT = 50;

async function fetchData(offset) {
  try {
    const response = await axios.get(GET_EVENTS_API_URL, {
      params: {
        address: POX_4_ADDRESS,
        limit: LIMIT,
        offset: offset,
      },
      headers: {
        "x-api-key": API_KEY,
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
    const response = await axios.get(
      `https://api.hiro.so/extended/v2/addresses/${address}/transactions`,
      {
        params: {
          limit: LIMIT,
          offset: offset,
        },
        headers: {
          "x-api-key": API_KEY,
        },
      }
    );

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
    const response = await axios.get(
      `https://mempool.space/api/address/${address}/txs`
    );

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
    const response = await axios.get(POX_INFO_URL, {
      headers: {
        "x-api-key": API_KEY,
      },
    });
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

async function fetchAccountInfo(address) {
  try {
    const response = await axios.get(ACCOUNT_INFO_API_URL(address), {
      params: {
        tip: STACKS_TIP_ID_HASH,
        proof: 0,
      },
      headers: {
        "x-api-key": API_KEY,
      },
    });
    const unlocked = BigInt(response.data.balance);
    const locked = BigInt(response.data.locked);

    return {
      locked: Number(locked),
      unlocked: Number(unlocked),
    };
  } catch (error) {
    if (error.response) {
      if (error.response.status === 429) {
        await new Promise((resolve) => setTimeout(resolve, 10000));
        return fetchAccountInfo(address);
      } else {
        console.error(`Error fetching account info: ${error}`);
      }
    } else {
      console.error(`Error fetching account info: ${error}`);
    }
    return null;
  }
}

function getStackerForBtcAddress(address, allEvents) {
  const addressDeserialized = cvToJSON(poxAddressToTuple(address));
  const version = addressDeserialized.value.version.value;
  const hashbytes = addressDeserialized.value.hashbytes.value;

  for (const entry of allEvents) {
    if (
      entry.contract_log &&
      entry.contract_log.value.repr.includes(version) &&
      entry.contract_log.value.repr.includes(hashbytes)
    ) {
      const printValue = hexToCV(entry.contract_log.value.hex);
      const result = cvToJSON(printValue);
      console.log(address, printValue);
      const name = result.value.value.name.value;

      if (name == "stack-stx") {
        return result.value.value.stacker.value;
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

  // while (moreData) {
  //   const data = await fetchData(offset);

  //   if (data && data.length > 0) {
  //     for (const entry of data) {
  //       allEvents.push(entry);
  //     }
  //     offset += LIMIT;
  //   } else {
  //     moreData = false;
  //   }
  // }

  offset = 0;
  moreData = true;
  const ADDRESSES = [];

  console.log("Fetching data for YES address", YES_STX_ADDRESS);
  while (moreData) {
    const data = await fetchAddressTransactionsStacks(offset, YES_STX_ADDRESS);

    if (data && data.length > 0) {
      for (const entry of data) {
        if (
          entry.tx.burn_block_height >= START_HEIGHT &&
          entry.tx.burn_block_height < END_HEIGHT
        ) {
          ADDRESSES.push({
            address: entry.tx.sender_address,
            time: entry.tx.burn_block_time,
            nonce: entry.tx.nonce,
            vote: "yes",
            txid: entry.tx.tx_id,
          });
        }
      }
      offset += LIMIT;
    } else {
      moreData = false;
    }
  }

  offset = 0;
  moreData = true;

  console.log("Fetching data for NO address", NO_STX_ADDRESS);
  while (moreData) {
    const data = await fetchAddressTransactionsStacks(offset, NO_STX_ADDRESS);

    if (data && data.length > 0) {
      for (const entry of data) {
        if (
          entry.tx.burn_block_height >= START_HEIGHT &&
          entry.tx.burn_block_height < END_HEIGHT
        ) {
          ADDRESSES.push({
            address: entry.tx.sender_address,
            time: entry.tx.burn_block_time,
            nonce: entry.tx.nonce,
            vote: "no",
            txid: entry.tx.tx_id,
          });
        }
      }
      offset += LIMIT;
    } else {
      moreData = false;
    }
  }

  console.log("Fetching data for YES BTC address", YES_BTC_ADDRESS);
  const btcYesData = await fetchAddressTransactionsBitcoin(YES_BTC_ADDRESS);
  if (btcYesData && btcYesData.length > 0) {
    for (const entry of btcYesData) {
      if (entry.status.confirmed == true) {
        if (
          entry.status.block_height >= START_HEIGHT &&
          entry.status.block_height < END_HEIGHT
        ) {
          ADDRESSES.push({
            btcAddress: entry.vin[0].prevout.scriptpubkey_address,
            address: getStackerForBtcAddress(
              entry.vin[0].prevout.scriptpubkey_address,
              allEvents
            ),
            time: entry.status.block_time,
            nonce: null,
            vote: "yes",
            txid: entry.txid,
          });
        }
      }
    }
  }

  console.log("Fetching data for NO BTC address", NO_BTC_ADDRESS);
  const btcNoData = await fetchAddressTransactionsBitcoin(NO_BTC_ADDRESS);
  if (btcNoData && btcNoData.length > 0) {
    for (const entry of btcNoData) {
      if (entry.status.confirmed == true) {
        if (
          entry.status.block_height >= START_HEIGHT &&
          entry.status.block_height < END_HEIGHT
        ) {
          ADDRESSES.push({
            btcAddress: entry.vin[0].prevout.scriptpubkey_address,
            address: getStackerForBtcAddress(
              entry.vin[0].prevout.scriptpubkey_address,
              allEvents
            ),
            time: entry.status.block_time,
            nonce: null,
            vote: "no",
            txid: entry.txid,
          });
        }
      }
    }
  }

  ADDRESSES.sort((a, b) => {
    if (a.time === b.time) {
      return a.nonce - b.nonce;
    }
    return a.time - b.time;
  });

  let totalVotes = 0;
  let yesVotes = 0;
  let noVotes = 0;
  let totalStackedAmountYes = 0;
  let totalStackedAmountNo = 0;
  let totalUnlockedAmountYes = 0;
  let totalUnlockedAmountNo = 0;

  let votesForCsv = [];

  const verifiedAddresses = new Set();

  for (const { address, btcAddress, vote, txid } of ADDRESSES) {
    if (verifiedAddresses.has(address)) {
      console.log("This address already voted!", address);
      continue;
    }

    if (address !== "Could not find BTC address") {
      verifiedAddresses.add(address);
    } else {
      console.log("Could not find Stacks address for BTC address", btcAddress);
      continue;
    }

    let accountInfo = await fetchAccountInfo(address);
    if (accountInfo === null) return;

    totalVotes++;
    votesForCsv.push({
      voter: btcAddress !== undefined ? btcAddress : address,
      txid: txid,
      for: vote === "yes" ? true : false,
      stacked_power: accountInfo.locked,
      unstacked_power: accountInfo.unlocked,
    });
    console.log(address, btcAddress ? btcAddress : "", vote, accountInfo);

    if (vote === "yes") {
      yesVotes++;
      totalStackedAmountYes += accountInfo.locked;
      totalUnlockedAmountYes += accountInfo.unlocked;
    } else if (vote === "no") {
      noVotes++;
      totalStackedAmountNo += accountInfo.locked;
      totalUnlockedAmountNo += accountInfo.unlocked;
    }
  }

  console.log(
    "Blocks left of cycle",
    poxInfo.current_cycle.id + ":",
    poxInfo.next_cycle.blocks_until_prepare_phase
  );
  console.log("Total number of votes (unique addresses):", totalVotes);
  console.log("Number of YES votes:", yesVotes);
  console.log("Number of NO votes:", noVotes);
  console.log("Amount stacked YES:", totalStackedAmountYes / 1000000 + " STX");
  console.log(
    "Amount un-stacked YES:",
    totalUnlockedAmountYes / 1000000 + " STX"
  );
  console.log("Amount stacked NO:", totalStackedAmountNo / 1000000 + " STX");
  console.log(
    "Amount un-stacked NO:",
    totalUnlockedAmountNo / 1000000 + " STX"
  );

  const votesCsv = convertVotesToCsv(votesForCsv);

  writeFileSync(VOTES_FILE, votesCsv);

  console.log("CSV files have been saved successfully.");
}

fetchAllData();
