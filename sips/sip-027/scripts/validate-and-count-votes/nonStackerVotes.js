import axios from "axios";
import { writeFileSync } from "fs";

const STX_ADDRESS = "SP3JP0N1ZXGASRJ0F7QAHWFPGTVK9T2XNXDB908Z.bde001-proposal-voting";
const MULTISIG_DAO_VOTES_FILE = 'multisig-dao-votes.csv';

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

function convertVotesToCsv(votes) {
  const headers = 'voter,txid,for,power\n';
  const rows = votes.map(vote => 
    `${vote.voter},${vote.txid},${vote.for},${vote.power}`
  ).join('\n');
  
  return headers + rows;
}

async function fetchAllData() {
  let moreData = true;
  let offset = 0;

  let noAmount = 0;
  let noCount = 0;

  let yesAmount = 0;
  let yesCount = 0;

  let daoVotesForCsv = [];

  while (moreData) {
    const data = await fetchAddressTransactionsStacks(offset, STX_ADDRESS);

    if (data && data.length > 0) {
      for (const entry of data) {
        if (entry.tx.burn_block_height >= 854950 && entry.tx.burn_block_height < 857050) {
          if (entry.tx.tx_status == "success" && entry.tx.tx_type == "contract_call" && entry.tx.contract_call.function_name == "vote" && entry.tx.contract_call.function_args[2].repr == "'SP3JP0N1ZXGASRJ0F7QAHWFPGTVK9T2XNXDB908Z.sip-027-multisig-transactions") {
            if (entry.tx.contract_call.function_args[1].repr == "true") {
              const amount = parseInt(entry.tx.contract_call.function_args[0].repr.slice(1));
              yesAmount += amount;
              yesCount++;
              daoVotesForCsv.push({
                voter: entry.tx.sender_address,
                txid: entry.tx.tx_id,
                for: true,
                power: amount,
              });
            } else if (entry.tx.contract_call.function_args[1].repr == "false") {
              const amount = parseInt(entry.tx.contract_call.function_args[0].repr.slice(1));
              noAmount += amount;
              noCount++;
              daoVotesForCsv.push({
                voter: entry.tx.sender_address,
                txid: entry.tx.tx_id,
                for: false,
                power: amount,
              });
            } else {
              console.log("Wrong data:", entry.tx.contract_call);
            };
          };
        };
      }
      offset += 50;
    } else {
      moreData = false;
    }
  }

  console.log("Amount against:", noAmount);
  console.log("Amount for:", yesAmount);
  console.log("Count against:", noCount);
  console.log("Count for:", yesCount);

  const daoVotesCsv = convertVotesToCsv(daoVotesForCsv);

  writeFileSync(MULTISIG_DAO_VOTES_FILE, daoVotesCsv);

  console.log('CSV files have been saved successfully.');
}

fetchAllData()