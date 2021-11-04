#!/bin/bash

###########################################################################################################
#
# Vote tallying script for SIP 012
# 
# Everyone who has called `stack-stx` or `delegate-stack-stx` in the prior two full reward cycles from
# the vote tallying block is eligible to cast a vote.  People who stacked other peoples' STX via the
# latter vote on behalf of the STX they represent.
#
# Votes are weighted by stacked STX.  The number of votes a stacker has is equal to the number of STX 
# they stacked in the last full reward cycle in which they stacked.
#
# Votes are cast by sending Bitcoin transactions.  A well-formed voting transaction will have at least one
# UTXO which pays a dust amount of BTC to either a "yes" address or a "no" address.  The "yes" address is
# 111111111111111111112czxoHN, and the "no" address is 111111111111111111112kmzDG2.
#
# Votes are tallied from the `stacking-state` data map in the `.pox` smart contract, by means of calling
# the read-only function `get-stacker-info`.  There are two ways to obtain the  stacker address argument:
# 
# * The stacker's voting transaction's scriptSig is generated directly from the stacker address.  In this 
#   case, the address is calculated from the public key(s) in the scriptSig.
# 
# * The stacker's voting transaction's scriptSig is generated from the PoX reward address.  In this case,
#   this script looks up the corresponding stacker address from a given CSV table generated from the 
#   blockchain's stacking event stream.
#
# Once the stacker address is known, the number of locked STX is queried from the `stacking-state` map and
# added to the global "yes" or "no" tallies.
#
###########################################################################################################
#
# To run this script, you will need:
# * a fully-sync'ed bitcoin node, with:
#   * txindex=1 set in its config file
#   * the "yes" and "no" address' UTXOs tracked
# * a fully-sync'ed stacks node
# * a list of stacker addresses taken from the node's event stream
# * a recent version of the node.js CLI
# * Node.js packages `bitcoinjs-lib`, `c32check`, and `@stacks/transactions` installed to your NODE_PATH
# * the binaries `bitcoin-cli`, `jq`, `grep`, `date`, and `xargs`
#
# Usage: ./count-votes TABULATION_DIR CHAIN_TIP_HASH < STACKERS.TXT
#
# For reward cycle 19, you can use the file 'stackers-19-only.txt' for STACKERS.TXT and
# 4933b0b002a854a9ca7305166238d17be018ce54e415530540aa7e620e9cd86d for TIP.
#
# For reward cycle 20, you can use the file 'stackers-20.txt' for STACKERS.TXT and
# 7ae943351df455aab1aa69ce7ba6606f937ebab5f34322c982227cd9e0322176 for TIP.
#
###########################################################################################################
#
# To use this script to tabulate SIP 012's votes, you need to gather the list of Stackers for a given
# reward cycle that could count towards the vote.  In SIP 012, this means that if a Stacker is 
# present in either of the two prior full reward cycles, then their *latest* quantity of STX Stacked
# needs to be considered (and they should not be counted in an earlier reward cycle's tabulation).
# Given SIP 012's timeline, this means considering Stackers in reward cycles 19 and 20.  If a Stacker
# Stacked in both, then only the STX Stacked in reward cycle 20 is considered.
# 
# Examples:
#
# *If Alice Stacked 100,000 STX in the earlier reward cycle, but 50,000 STX in the later reward cycle,
# she would be excluded from the tabulation of the earlier reward cycle and only included in the later
# reward cycle.
#
# * If Bob Stacked 100,000 STX in the earlier reward cycle, and did not Stack in the later reward cycle,
# then his 100,000 STX would be considered in the earlier reward cycle's tabulation.  He would not be
# considered in the later reward cycle's tabulation.
#
# * If Charles Stacked 100,000 STX in the later reward cycle, but did not Stack in the earlier reward cycle,
# then his 100,000 STX would be considered in the later reward cycle's tabulation.  He would not be considered
# in the earlier reward cycle's tabulation.
#
# By running this script with the list of eligible Stackers in the earlier and later full reward cycles, you
# can take the resulting tabulations of both reward cycles and add them together to get the final vote tabulation.
#
###########################################################################################################

TESTNET=0
BITCOIN_CONF=/etc/bitcoin/bitcoin.conf
STX_NODE="http://localhost:20443"
POX_ADDR="SP000000000000000000002Q6VF78"

YES_ADDR="111111111111111111112czxoHN"
NO_ADDR="111111111111111111112kmzDG2"

if [ $TESTNET -ne 0 ]; then
   POX_ADDR="ST000000000000000000002AMW42H" 
   YES_ADDR="mfWxJ45yp2SFn7UciZyNpvDKrzbjYw8w7S"
   NO_ADDR="mfWxJ45yp2SFn7UciZyNpvDKrzbjhQ15VR"
fi

set -oue pipefail

bitcoin_cli() {
   # Run bitcoin-cli with default settings
   #
   # $@: bitcoin-cli args
   # stdin: none
   # stdout: bitcoin-cli command output
   # stderr: bitcoin-cli error message
   # return: 0 on success, nonzero on error
   bitcoin-cli -conf="$BITCOIN_CONF" "$@"
}

get_utxos() {
   # Get the UTXOs for an address
   #
   # $1: Bitcoin address
   # stdin: none
   # stdout: JSON-encoded unspents from the address
   # stderr: bitcoin-cli error message
   # return: 0 on success, nonzero on error
   local address="$1"
   bitcoin_cli listunspent 0 1000000 "[\"$address\"]"
}

get_scriptSigs() {
   # Decode UTXOs into scriptSigs
   #
   # stdin: JSON-encoded unspent outputs as an array of objects
   # stdout: newline-separated list of scriptSig JSON objects in the form of '{ "hex": ..., "asm": ... "address": ...}'.  "address" is optional.
   # stderr: none
   # return: 0 on success, nonzero on error
   local txid=""
   local vout=0
   local json=""
   local scriptPubKey=""
   local address=""
   jq -r '.[].txid' | while read -r txid; do
       json="$(bitcoin_cli getrawtransaction "$txid" 1)"

       # if this is a segwit tx, go and get the tx that funded it
       # to find the segwit-over-p2sh address (if it exists)
       if [ "$(echo "$json" | jq -r -c '.vin[0].txinwitness')" != "null" ]; then
          txid="$(echo "$json" | jq -r -c '.vin[0].txid')"
          vout="$(echo "$json" | jq -r -c '.vin[0].vout')"
          json="$(bitcoin_cli getrawtransaction "$txid" 1)"
          scriptPubKey="$(echo "$json" | jq -r -c ".vout[$vout].scriptPubKey")"
          if [ "$(echo "$scriptPubKey" | jq -r -c '.type')" = "scripthash" ]; then
             address="$(echo "$scriptPubKey" | jq -r -c '.addresses[0]')"
             if [ "$address" != "null" ]; then
                 echo "{\"hex\": \"00\", \"asm\": \"00\", \"address\": \"$address\"}"
             fi
          fi
       else
           bitcoin_cli getrawtransaction "$txid" 1 | jq -r -c '.vin[0].scriptSig'
       fi
   done
}

btc_addr_to_stx_addr() {
   # Convert a Bitcoin address to a Stacks address
   #
   # $1: bitcoin address
   # stdin: none
   # stdout: the Stacks address
   # stderr: none
   # return: 0 on success, nonzero on error
   local btc_addr="$1"

   echo "
c32 = require('c32check');
console.log(c32.b58ToC32(\"$btc_addr\"))
" | node - 2>/dev/null
}

pubkey_to_btc_addr() {
   # Convert a public key to a Bitcoin address
   #
   # $1: secp256k1 public key
   # stdin: none
   # stdout: the Stacks address
   # stderr: none
   # return: 0 on success, nonzero on error
   local pubkey="$1"
   
   echo "
const bitcoin = require('bitcoinjs-lib');
const pubkey = Buffer.from(\"$pubkey\", \"hex\");
const { address } = bitcoin.payments.p2pkh({ pubkey });
console.log(address);
" | node - 2>/dev/null
}

make_btc_addr() {
   # Make a bitcoin address from a hex-encoded version byte and hash160
   #
   # $1: hex-encoded version byte
   # $2: hex-encoded hash bytes
   # stdin: none
   # stdout: the address
   # stderr: none
   # return: 0 on success, nonzero on error
   local version="$1"
   local hashbytes="$2"

   echo "
c32 = require('c32check');
var btc_version = \"$version\";
var btc_hashbytes = \"$hashbytes\";
var c32_version = 0;
if (btc_version === '01') {
   c32_version = c32.versions.mainnet.p2pkh;
}
else if (btc_version == '05') {
   c32_version = c32.versions.mainnet.p2sh;
}
else if (btc_version == '6f') {
   c32_version = c32.versions.testnet.p2pkh;
}
else if (btc_version == 'c4') {
   c32_version = c32.versions.testnet.p2sh;
}
else {
   throw 'Unknown bitcoin address'
}
var c32addr = c32.c32address(c32_version, btc_hashbytes);
console.log(c32.c32ToB58(c32addr))
" | node - 2>/dev/null
}

decode_scriptSig() {
   # Decode a scriptSig into its Stacks and Bitcoin addresses
   #
   # $1: scriptSig JSON object with .hex and .asm fields
   # stdin: none
   # stdout: a JSON object containing the Bitcoin and Stacks addresses
   # stderr: none
   # return: 0 on success; 1 if the address could not be decoded
   local scriptSig="$1"
   local asm=""
   local last_asm_field=""
   local p2sh_json=""
   local btc_address=""
   local stx_address=""

   # if address is given directly, just use it
   btc_address="$(echo "$scriptSig" | jq -rc '.address')"
   if [ "$btc_address" = "null" ]; then

      # verify that we got an asm field that isn't empty
      asm="$(echo "$scriptSig" | jq -r '.asm')"
      if [ -z "$asm" ]; then
         return 0
      fi

      # get last field in the 'asm' representation.
      # it could be the script of a p2sh, or
      # it could be the public key of a p2pkh.
      last_asm_field="$(echo "$asm" | sed -r 's/^.+ ([^ ]+)$/\1/g')"
      p2sh_json="$(bitcoin_cli decodescript "$last_asm_field")"

      if [ "$(echo "$p2sh_json" | jq -r '.type')" = "multisig" ]; then
         # last_asm_field is indeed a multisig script. Extract the Bitcoin address for it.
         btc_address="$(echo "$p2sh_json" | jq -r '.p2sh')"

      elif [ "$(echo "$p2sh_json" | jq -r '.type')" = "nonstandard" ]; then
         # last_asm_field was maybe a public key? It's definitely not a segwit address
         btc_address="$(pubkey_to_btc_addr "$last_asm_field")"
      else
         # segwit -- should have gotten an address passed to us already
         return 0
      fi
   fi

   stx_address="$(btc_addr_to_stx_addr "$btc_address")"
   echo "{\"btc\":\"$btc_address\",\"stx\":\"$stx_address\"}"
   return 0
}

list_stx_voters() {
   # Enumerate the list of potential voters' STX and BTC addresses, given a vote address
   #
   # $1: vote address
   # stdin: none
   # stdout: list of newline-separated JSON objects with both BTC and STX addresses of those who voted by sending to this address
   # stderr: none
   # return: 0 on success, nonzero on error
   local vote_addr="$1"
   local scriptSig=""
   get_utxos "$vote_addr" | get_scriptSigs | while read -r scriptSig; do
      decode_scriptSig "$scriptSig"
   done
}

stx_addr_to_clarity_principal() {
   # Convert a STX address into a serialized Clarity principal
   #
   # $1: a standard stx address
   # stdin: none
   # stdout: a serialized Clarity value representing the principal
   # stderr: none
   # return: 0 on success, nonzero on error
   local stx_addr="$1"
   echo "
c32 = require('c32check');
const decoded = c32.c32addressDecode(\"$stx_addr\");
console.log( \"0x05\" + Buffer.from([decoded[0]]).toString(\"hex\") + decoded[1] )
" | node -
}

stx_addr_to_delegate_state_key() {
   # Convert a STX address into a the serialized Clarity tuple value `{ stacker: $stx_addr }`
   #
   # $1: a stx address
   # stdin: none
   # stdout: a serialized Clarity value representing the Clarity value `{ stacker: $1 }`
   # stderr: none
   # return: 0 on success, nonzero on error
   local stx_addr="$1"
   echo "
c32 = require('c32check');
const decoded = c32.c32addressDecode(\"$stx_addr\");
var stacker_tuple = '';
stacker_tuple += '0c';              // tuple type ID
stacker_tuple += '00000001';        // 32-bit tuple length
stacker_tuple += '07';              // length of 'stacker'
stacker_tuple += Buffer.from('stacker').toString('hex');    // 'stacker' as hex
stacker_tuple += '05';              // standard principal ID
stacker_tuple += Buffer.from([decoded[0]]).toString('hex'); // principal address version
stacker_tuple += decoded[1];        // principal bytes
console.log(stacker_tuple)
" | node -
}

decode_clarity_value() {
   # Decode a serialized Clarity value, optionally pulling out a specific field.
   # Uses @stacks/transactions.
   #
   # $1: the clarity hex string to decode
   # $2: the Javascript path to the data within the decoded value to print
   # stdin: none
   # stdout: the data at the end of the decoded value
   # stderr: none
   # return: 0 on success, nonzero on error
   local clarity_hex="$1"
   local path="$2"
   echo "
stxtx = require('@stacks/transactions');
const decoded = stxtx.deserializeCV(\"$clarity_hex\");
console.log(decoded.$path);
" | node -
}

pox_version_to_btc_version() {
   # Convert a pox-addr's version byte from .pox into a Bitcoin version byte.
   # 
   # $1: PoX address version byte
   # stdin: none
   # stdout: corresponding BTC version byte
   # stderr: none
   # return: 0 on success; 1 on failure
   local pox_version="$1"
   if [ "$pox_version" = "00" ]; then
      if [ $TESTNET -ne 0 ]; then
         echo "6f"
      else
         echo "01"
      fi
   elif [ "$pox_version" = "01" ] || [ "$pox_version" = "02" ] || [ "$pox_version" = "03" ]; then
      if [ $TESTNET -ne 0 ]; then
         echo "c4"
      else
         echo "05"
      fi
   else
      return 1
   fi

   return 0
}

is_stacker_delegating() {
   # Determine if a given stacker is delegating to someone else
   #
   # $1: stx address
   # $2: current burnchain block height
   # $3: (optional) chain tip to use, so as to query historic state
   # stdin: none
   # stdout: "1" if so, "0" if not
   # stderr: none
   # return: 0 on success; nonzero on error
   local stx_addr="$1"
   local cur_burn_ht="$2"
   local tip="$3"
   local url=""
   local body=""
   local body_len=0
   local delegate_value=""
   local until_burn_ht_type=""
   local until_burn_ht=""
   local delegating=0

   # check delegate status
   url="$STX_NODE/v2/map_entry/$POX_ADDR/pox/delegation-state?proof=0"
   if [ -n "$tip" ]; then
      url="$url&tip=$tip"
   fi

   body="\"$(stx_addr_to_delegate_state_key "$stx_addr")\""
   body_len=${#body}

   delegate_value="$(echo "$body" | \
     curl -s -X POST -H "content-type: application/json" -H "content-length: $body_len" --data-binary @- "$url")"

   delegate_value="$(echo "$delegate_value" | jq -r -c ".data")"

   delegating=1
   if [ "$delegate_value" = "0x09" ]; then
      # not delegating
      delegating=0
   else
      # maybe delegating -- check expiration
      until_burn_ht_type="$(decode_clarity_value "$delegate_value" "value.data['until-burn-ht'].type")"
      if [ "$until_burn_ht_type" = "10" ]; then
         # Some expiration
         until_burn_ht="$(decode_clarity_value "$delegate_value" "value.data['until-burn-ht'].value.value")"
         if (( "$(echo "$until_burn_ht" | tr -d 'n')" < "$cur_burn_ht" )); then
            # delegation expired
            delegating=0
         fi
      fi
   fi

   echo "$delegating"
}

get_stacker_info() {
   # Query the stacks node for a stacker's information - namely, its PoX address and number of uSTX stacked.
   #
   # $1: a standard stx address
   # $2: current burnchain block height
   # $3: (optional) chain tip to use, so as to query historic stacking state
   # stdin: none
   # stdout: a JSON object representing the number of uSTX stacked, the STX address, and the PoX address (if this stacker is stacked), or an empty string if not
   # stderr: none
   # return: 0 on success, nonzero on error
   local stx_addr="$1"
   local cur_burn_ht="$2"
   local tip="$3"
   local body=""
   local body_len=0
   local url="$STX_NODE/v2/contracts/call-read/$POX_ADDR/pox/get-stacker-info"
   local clarity_value=""
   local amount_stacked=""
   local pox_addr_version=""
   local pox_addr_hashbytes=""
   local pox_addr=""
   local delegating=0

   if [ -n "$tip" ]; then
      url="$url?tip=$tip"
   fi

   body="
{
   \"sender\": \"SP31DA6FTSJX2WGTZ69SFY11BH51NZMB0ZW97B5P0.get-info\",
   \"arguments\": [
       \"$(stx_addr_to_clarity_principal "$stx_addr")\"
   ]
}
"
   body_len=${#body}
   clarity_value="$(echo "$body" | \
      curl -s -X POST -H "content-type: application/json" -H "content-length: $body_len" --data-binary @- "$url")"
   
   clarity_value="$(echo "$clarity_value" | jq -r -c ".result")"

   if [ "$clarity_value" = "0x09" ]; then
      # this is a none
      echo -n ""
   else
      # check delegate status
      delegating="$(is_stacker_delegating "$stx_addr" "$cur_burn_ht" "$tip")"
      if [ "$delegating" = "0" ]; then
         # stacker is not delegating, so is eligible to vote
         amount_stacked="$(decode_clarity_value "$clarity_value" "value.data['amount-ustx'].value.toString()")"
         pox_addr_version="$(decode_clarity_value "$clarity_value" "value.data['pox-addr'].data.version.buffer.toString('hex')")"
         pox_addr_version="$(pox_version_to_btc_version "$pox_addr_version")"
         pox_addr_hashbytes="$(decode_clarity_value "$clarity_value" "value.data['pox-addr'].data.hashbytes.buffer.toString('hex')")"
         pox_addr="$(make_btc_addr "$pox_addr_version" "$pox_addr_hashbytes")"
   
         echo "{\"pox_address\":\"$pox_addr\",\"stx_address\":\"$stx_addr\",\"ustx\":\"$amount_stacked\"}"
      else
         # delegating -- can't vote
         echo -n ""
      fi
   fi
}

get_stacker_vote() {
   # Determine how many uSTX a stacker voted with, and whether or not it was "Yes" or "No"
   # 
   # $1: address mode -- are we querying by STX or BTC address?
   # $2: the address
   # $3: path to the 'yes' vote addresses
   # $4: path to the 'no' vote addresses
   # $5: path to the stackers.json file
   # $6: path to list of addresses that voted
   # stdin: none
   # stdout: a JSON object describing the stacker address, PoX address, amount voted, vote choice, and which address voted
   # stderr: none
   # return: 0 on success, nonzero on error
   local addr_mode="$1"
   local select_addr="$2"
   local yes_votes_path="$3"
   local no_votes_path="$4"
   local stackers_path="$5"
   local already_voted_path="$6"
   local stacker_addr=""
   local pox_addr=""
   local json=""
   local vote=""
   local ustx=0
   local voted_ustx=0
   local voted_yes=0
   local voted_no=0

   if [ "$addr_mode" = "stx" ]; then
      stacker_addr="$select_addr"

      # what was the PoX address for this stacker?
      json="$(grep -F "$stacker_addr" "$stackers_path" | head -n1 || true)"
      if [ -z "$json" ]; then
         # didn't vote
         return 0
      fi

      pox_addr="$(echo "$json" | jq -r -c '.pox_address' 2>/dev/null || true)"
      if [ -z "$pox_addr" ]; then
         # no pox address
         return 0
      fi
   elif [ "$addr_mode" = "btc" ]; then
      pox_addr="$select_addr"

      # what is the first STX address for this PoX addr?
      json="$(grep -F "$pox_addr" "$stackers_path" | head -n1 || true)"
      if [ -z "$json" ]; then
         # didn't vote
         return 0
      fi

      stacker_addr="$(echo "$json" | jq -r -c '.stx_address' 2>/dev/null || true)"
      if [ -z "$stacker_addr" ]; then
         # no STX address
         return 0
      fi
   fi

   # must have not already voted
   touch "$already_voted_path"
   if [ -n "$(grep -E "$stacker_addr|$pox_addr" "$already_voted_path" || true)" ]; then
      return 0
   fi

   # voted yes?
   if [ -n "$(grep -E "$stacker_addr|$pox_addr" "$yes_votes_path" || true)" ]; then
      voted_yes=1
      vote="yes"
   fi

   # voted no?
   if [ -n "$(grep -E "$stacker_addr|$pox_addr" "$no_votes_path" || true)" ]; then
      voted_no=1
      vote="no"
   fi

   # must have voted on exactly one choice
   if [ $voted_yes -eq 0 ] && [ $voted_no -eq 0 ]; then
      # no vote
      return 0
   fi

   if [ $voted_yes -eq 1 ] && [ $voted_no -eq 1 ]; then
      # voted both ways; doesn't count
      return 0
   fi
   
   # tally *all* STX bound by this PoX address
   voted_ustx="$(grep -F "$pox_addr" "$stackers_path" | (
      local total_ustx=""
      while read -r json; do
         ustx="$(echo "$json" | jq -r -c '.ustx')"
         if [ -n "$ustx" ]; then
            total_ustx=$((total_ustx + ustx))
         fi
      done
      echo "$total_ustx" )
   )"

   # mark as having voted.
   # be sure to invalidate both the PoX and STX addresses.
   # if the stacker voted with the PoX address, then invalidate all associated STX addresses too.
   grep -E "$stacker_addr|$pox_addr" "$yes_votes_path" >> "$already_voted_path" || true
   grep -E "$stacker_addr|$pox_addr" "$no_votes_path" >> "$already_voted_path" || true

   echo "{\"pox_address\":\"$pox_addr\",\"vote\":\"$vote\",\"ustx\":\"$voted_ustx\"}"
   return 0
}

tabulate_vote() {
   # Count up how many votes were received in total for 'yes' and 'no'
   # 
   # stdin: newline-separated JSON blocks containing '.vote' and '.ustx'
   # stdout: a JSON object containing 'yes' and 'no'
   # stderr: none
   # return: 0 on success, nonzero on error
   local yes_votes=0
   local no_votes=0
   local json=""
   local vote_result=""
   local vote_ustx=""
   while IFS= read -r json; do
      vote_result="$(echo "$json" | jq -r '.vote')"
      vote_ustx="$(echo "$json" | jq -r '.ustx')"
      if [[ "$vote_result" = "yes" ]]; then
         yes_votes=$((yes_votes + vote_ustx))
      elif [[ "$vote_result" = "no" ]]; then
         no_votes=$((no_votes + vote_ustx))
      else
         echo >&2 "Invalid vote in \"$json\""
      fi
   done

   echo "{\"yes\":\"$yes_votes\",\"no\":\"$no_votes\"}"
}

deps_check() {
   # Make sure all binary dependencies are available.
   #
   # stdin: none
   # stdout: none
   # stderr: none
   # return: 0 on success; exits on failure
   for cmd in bitcoin-cli jq grep date xargs node; do
      if ! command -v "$cmd" >/dev/null 2>&1; then
         echo >&2 "FATAL: could not find \"$cmd\" in PATH"
         exit 1
      fi
   done

   # make sure node packages are available
   if ! echo "
const c32 = require('c32check');
const btc = require('bitcoinjs-lib');
const stx = require('@stacks/transactions');
" | node; then
       echo >&2 "FATAL: missing node packages c32check, bitcoinjs-lib, and/or @stacks/transactions"
       exit 1
    fi

    return 0
}

main() {
   # Main entry point of the script.  Tabulates a "yes/no" vote for the reward cycle that is currently
   # ongoing as of a given chain tip hash.
   #
   # $1: working directory to use
   # $2: chaintip of vote tally block
   # stdin: a list of Stackers for this vote tally
   # stdout: a JSON object with the sums of the "yes" and "no" votes
   # stderr: none
   # return: 0 on success, nonzero on error
   local work_dir="$1"
   local tip="$2"
   local stacker_addrs_path="$work_dir/input.txt"
   local yes_votes_path="$work_dir/yes-addrs.json"
   local no_votes_path="$work_dir/no-addrs.json"
   local stacker_path="$work_dir/stackers.json"
   local votes_path="$work_dir/votes.json"
   local all_votes_path="$work_dir/.all-votes.json"
   local already_voted_path="$work_dir/.already_voted.json"
   local cur_burn_ht=0
   local vote_json=""
   local btc_addr=""
   local stx_addr=""

   deps_check

   mkdir -p "$work_dir"
   
   echo -n "" > "$stacker_addrs_path"
   echo -n "" > "$votes_path"
   echo -n "" > "$already_voted_path"

   # copy stdin to a file so we can reuse it
   while read -r stacker_address; do
      echo "$stacker_address" >> "$stacker_addrs_path"
   done

   if ! [ -f "$yes_votes_path" ]; then
      echo >&2 "Obtaining 'yes' votes..."
      list_stx_voters "$YES_ADDR" > "$yes_votes_path"
   fi

   if ! [ -f "$no_votes_path" ]; then
      echo >&2 "Obtaining 'no' votes..."
      list_stx_voters "$NO_ADDR" > "$no_votes_path"
   fi

   if ! [ -f "$stacker_path" ]; then 
      echo >&2 "Obtaining stacker info as of $tip..."
      cur_burn_ht="$(curl -s "$STX_NODE/v2/info" | jq -r -c '.burn_block_height')"
      while read -r stx_addr; do
         get_stacker_info "$stx_addr" "$cur_burn_ht" "$tip" >> "$stacker_path"
      done < "$stacker_addrs_path"
   fi

   # get each stacker's vote.
   # first, consider all voting transactions' BTC addresses, since these could be PoX addresses, and could count for many Stackers.
   # second, consider all voting transactions' STX addresses, since the ones that haven't voted now represent Stackers who voted from their Stacking address
   cat "$yes_votes_path" "$no_votes_path" > "$all_votes_path"
   while read -r vote_json; do
      btc_addr="$(echo "$vote_json" | jq -r -c '.btc')"
      get_stacker_vote "btc" "$btc_addr" "$yes_votes_path" "$no_votes_path" "$stacker_path" "$already_voted_path" >> "$votes_path"
   done < "$all_votes_path"

   while read -r vote_json; do
      stx_addr="$(echo "$vote_json" | jq -r -c '.stx')"
      get_stacker_vote "stx" "$stx_addr" "$yes_votes_path" "$no_votes_path" "$stacker_path" "$already_voted_path" >> "$votes_path"
   done < "$all_votes_path"

   # tabulate votes
   tabulate_vote < "$votes_path"
}

###############################################################
# 
# Unit tests
#
###############################################################

assert_eq() {
   if [[ "$1" != "$2" ]]; then
      echo ""
      echo >&2 "left: \"$1\""
      echo >&2 "right: \"$2\""
      exit 1
   fi
}

test_btc_addr_to_stx_addr() {
   echo -n "test_btc_addr_to_stx_addr..."
   assert_eq "SP3M89DCQMWX7ZQF588H0EP8TYWG1AWMF3DAG30VH" "$(btc_addr_to_stx_addr "1NCSkK5HovkD4Bq8pLertRN4U7CJnZjJk2")"
   assert_eq "ST3M89DCQMWX7ZQF588H0EP8TYWG1AWMF3D5DZR06" "$(btc_addr_to_stx_addr "n2iQ3NAGcxBTqJJkXudEiLaPL6o1kjaUBU")"
   echo "ok"
}

test_pubkey_to_btc_addr() {
   echo -n "test_pubkey_to_btc_addr..."
   assert_eq "1NCSkK5HovkD4Bq8pLertRN4U7CJnZjJk2" "$(pubkey_to_btc_addr "020c49a083d703a4db64e4e26ad5f3ab1ae2def84fdd902e99a4bd7bdcbc2b35fc")"
   assert_eq "1Mz2nSAg6qYTKxxnbfgJ8Snt6WtEJK3u7j" "$(pubkey_to_btc_addr "040c49a083d703a4db64e4e26ad5f3ab1ae2def84fdd902e99a4bd7bdcbc2b35fc8fa79a7a4e262f66b9482b1f3ce20444af8bf32449a981e4d9e2b52502bdd354")"
   echo "ok"
}

test_make_btc_addr() {
   echo -n "test_make_btc_addr..."
   assert_eq "1J9pXQrKMDNkRJWbDTSiEASiL76GeWKVck" "$(make_btc_addr "01" "bc25232837a04fd94a491cf2bbc51f59ed80d1dd")"
   assert_eq "3JqqSxLku7h8WUD2LZ7JenoeUdNzBNEDH6" "$(make_btc_addr "05" "bc25232837a04fd94a491cf2bbc51f59ed80d1dd")"
   assert_eq "mxfmpTwJAEp1CQzCw2R645f3C6gydDtwxS" "$(make_btc_addr "6f" "bc25232837a04fd94a491cf2bbc51f59ed80d1dd")"
   assert_eq "2NAQ3WhGnWaCUiFqa1gjBGjnugyb9zA1DRo" "$(make_btc_addr "c4" "bc25232837a04fd94a491cf2bbc51f59ed80d1dd")"
   echo "ok"
}

test_get_scriptSig() {
   echo -n "test_get_scriptSig..."

   # segwit-over-p2sh
   assert_eq '{"hex": "00", "asm": "00", "address": "3HASeAxLLZQJTbGDTSyfxbJXLtnUF8K1Dw"}' "$(echo '[{"txid": "13c2d9af1bc99b96e4c03f428be7580eeb1d745980a9e946dece7947c153e81f"}]' | get_scriptSigs)"

   # p2pkh
   assert_eq '{"asm":"304402206d333b3ced3f75d1de0cd89450231b2a636965a8a9bc457115f48d34b63c917a022079f49c2cea06ced80e871b55e009b30585de92302fda820c3ae37b596d3d75d2[ALL] 02cd8737f57117705588c8ab282664e76e93217f8c953653905edcba2bc1be1ae9","hex":"47304402206d333b3ced3f75d1de0cd89450231b2a636965a8a9bc457115f48d34b63c917a022079f49c2cea06ced80e871b55e009b30585de92302fda820c3ae37b596d3d75d2012102cd8737f57117705588c8ab282664e76e93217f8c953653905edcba2bc1be1ae9"}' "$(echo '[{"txid": "9412c01065dedaa5e4767aca5e6e6f0b1e542147823d6428f6bbb418e6c33e57"}]' | get_scriptSigs)"

   echo "ok"
}

test_decode_scriptSig() {
    echo -n "test_decode_scriptSig..."
    
    local json=""
    json="$(decode_scriptSig '{"asm":"0 304402206af58d064c5cfb4128367d3fb7393527117bc98166fe6c736e84b513be9933ad02204b3da3d246b2e1d72dc993ccfb09626c3b066d7e43bcccc24e8f376fccb6bc06[ALL] 3045022100ba8ce4d5d4a568f50f3cf7868d9dce687f1dbacfc98b8ea4c66722be6e35654a0220147da24ca66f553b39627ace2be658701ba36a42fc725565c79a608a37197113[ALL] 5221031e5b50460922bfcea36dda0d45452af7b743e96ba01150d24d890f1878abd0d52103ff1f5fcb32a17fb645887180364a864df3e442ab838330dbd72f93199de305be52ae","hex":"0047304402206af58d064c5cfb4128367d3fb7393527117bc98166fe6c736e84b513be9933ad02204b3da3d246b2e1d72dc993ccfb09626c3b066d7e43bcccc24e8f376fccb6bc0601483045022100ba8ce4d5d4a568f50f3cf7868d9dce687f1dbacfc98b8ea4c66722be6e35654a0220147da24ca66f553b39627ace2be658701ba36a42fc725565c79a608a3719711301475221031e5b50460922bfcea36dda0d45452af7b743e96ba01150d24d890f1878abd0d52103ff1f5fcb32a17fb645887180364a864df3e442ab838330dbd72f93199de305be52ae"}')"
    
    assert_eq "38CCKFZqyTZVx8DFUsBWKsoB4zLUVQ3H9Z" "$(echo "$json" | jq -r -c '.btc')"
    assert_eq "SM13NAZFKN7YDX7Z2S9V89YQ835BZ27FPVXYDH7GE" "$(echo "$json" | jq -r -c '.stx')"

    json="$(decode_scriptSig '{"asm": "3045022100e224ce381ae121cb59bcdbab86e2a06f9c2f288558dd4771bec72947bf2340b602204dcf2ba336b9209ae86d7468c5172b0459b004c66923e68fcb6d3f08c318a524[ALL] 035180521b9c167493d41ea30e7c2dc9c35b2a003d39317a20ccde837fb268b8df", "hex": "483045022100e224ce381ae121cb59bcdbab86e2a06f9c2f288558dd4771bec72947bf2340b602204dcf2ba336b9209ae86d7468c5172b0459b004c66923e68fcb6d3f08c318a5240121035180521b9c167493d41ea30e7c2dc9c35b2a003d39317a20ccde837fb268b8df"}')"
    
    assert_eq "16sAXi1jxhxKCfY84hubDdnFNaAhqd5t49" "$(echo "$json" | jq -r -c '.btc')"
    assert_eq "SP105ARDW7EQTFTFMYNGMKJTA9JYFHF0FFMW9K815" "$(echo "$json" | jq -r -c '.stx')"

    echo "ok"
}

test_stx_addr_to_clarity_principal() {
   echo -n "test_stx_addr_to_clarity_principal..."

   assert_eq "0x0516c8b2df71cedcdf5f32dcf2228976b0e7f5ba7231" "$(stx_addr_to_clarity_principal "SP34B5QVHSVEDYQSJVKS252BPP3KZBEKJ67SAYQCD")"
   assert_eq "0x051447557df3a9fcde9fe2ca7684fae81957f11df6df" "$(stx_addr_to_clarity_principal "SM13NAZFKN7YDX7Z2S9V89YQ835BZ27FPVXYDH7GE")"

   echo "ok"
}

test_stx_addr_to_delegate_state_key() {
   echo -n "test_stx_addr_to_delegate_state_key..."

   assert_eq "0c0000000107737461636b657205168dab0d2ba8086e74b88f7f7cf7ab9fb418d87c3e" "$(stx_addr_to_delegate_state_key "SP26TP39BN046WX5RHXZQSXXBKYT1HP3W7VNASJ4P")"

   echo "ok"
}

test_decode_clarity_value() {
   echo -n "test_decode_clarity_value..."

   assert_eq "12291711000000n" "$(decode_clarity_value "0x0a0c000000040b616d6f756e742d7573747801000000000000000000000b2de3115dc01266697273742d7265776172642d6379636c65010000000000000000000000000000000f0b6c6f636b2d706572696f64010000000000000000000000000000000c08706f782d616464720c00000002096861736862797465730200000014bc25232837a04fd94a491cf2bbc51f59ed80d1dd0776657273696f6e020000000101" "value.data['amount-ustx'].value")"
   assert_eq "01" "$(decode_clarity_value "0x0a0c000000040b616d6f756e742d7573747801000000000000000000000b2de3115dc01266697273742d7265776172642d6379636c65010000000000000000000000000000000f0b6c6f636b2d706572696f64010000000000000000000000000000000c08706f782d616464720c00000002096861736862797465730200000014bc25232837a04fd94a491cf2bbc51f59ed80d1dd0776657273696f6e020000000101" "value.data['pox-addr'].data.version.buffer.toString('hex')")"
   assert_eq "bc25232837a04fd94a491cf2bbc51f59ed80d1dd" "$(decode_clarity_value "0x0a0c000000040b616d6f756e742d7573747801000000000000000000000b2de3115dc01266697273742d7265776172642d6379636c65010000000000000000000000000000000f0b6c6f636b2d706572696f64010000000000000000000000000000000c08706f782d616464720c00000002096861736862797465730200000014bc25232837a04fd94a491cf2bbc51f59ed80d1dd0776657273696f6e020000000101" "value.data['pox-addr'].data.hashbytes.buffer.toString('hex')")"
   
   echo "ok"
}

test_bitcoin_ping() {
   echo -n "test_bitcoin_ping..."
   bitcoin_cli ping
   echo "ok"
}

test_is_stacker_delegating() {
   echo -n "test_is_stacker_delegating..."

   local ret=""
   local cur_burn_ht=0
   local tip="22ac907019619fe9ae4e4ef5100740ecbf1b95510caccfb59fb71053e85bd783"
   
   cur_burn_ht="$(curl -s $STX_NODE/v2/info | jq -r -c '.burn_block_height')"

   # this one is delegating
   ret="$(is_stacker_delegating "SPRPW92SBDC982QJDPHAAXN3DGKV798CRM0ZWX63" "$cur_burn_ht" "$tip")"
   assert_eq "$ret" "1"

   # this one is not
   ret="$(is_stacker_delegating "SM12TJXJEQQER0EWX6783RWH1R8YZG3M9SBQVDFH" "$cur_burn_ht" "$tip")"
   assert_eq "$ret" "0"

   # this one isn't stacking
   ret="$(is_stacker_delegating "SP2E8N3T3TJP2D9YQZ41PY7X0ZFNQA8PZZ9RES24G" "$cur_burn_ht" "$tip")"
   assert_eq "$ret" "0"

   echo "ok"
}

test_get_stacker_info() {
   echo -n "test_get_stacker_info..."
   
   local json=""
   local cur_burn_ht=0
   local tip="22ac907019619fe9ae4e4ef5100740ecbf1b95510caccfb59fb71053e85bd783"
   
   cur_burn_ht="$(curl -s $STX_NODE/v2/info | jq -r -c '.burn_block_height')"

   # multisig
   json="$(get_stacker_info "SM21NR8W96KGG4YCFXRHZ6EAR2PAY3NS0MQ3FK95T" "$cur_burn_ht" "$tip")"

   assert_eq "SM21NR8W96KGG4YCFXRHZ6EAR2PAY3NS0MQ3FK95T" "$(echo "$json" | jq -r -c '.stx_address')"
   assert_eq "3JqqSxLku7h8WUD2LZ7JenoeUdNzBNEDH6" "$(echo "$json" | jq -r -c '.pox_address')"
   assert_eq "12291711000000" "$(echo "$json" | jq -r -c '.ustx')"

   # singlesig
   json="$(get_stacker_info "SM12TJXJEQQER0EWX6783RWH1R8YZG3M9SBQVDFH" "$cur_burn_ht" "$tip")"

   assert_eq "SM12TJXJEQQER0EWX6783RWH1R8YZG3M9SBQVDFH" "$(echo "$json" | jq -r -c '.stx_address')"
   assert_eq "1AvrGwwtm5acsbVEaeHk7FkAbQh2FJgfSn" "$(echo "$json" | jq -r -c '.pox_address')"
   assert_eq "15000000000000" "$(echo "$json" | jq -r -c '.ustx')"

   # someone who isn't stacking
   json="$(get_stacker_info "SP2E8N3T3TJP2D9YQZ41PY7X0ZFNQA8PZZ9RES24G" "$cur_burn_ht" "$tip")"
   assert_eq "" "$json"

   # someone who delegated with no deadline
   json="$(get_stacker_info "SPRPW92SBDC982QJDPHAAXN3DGKV798CRM0ZWX63" "$cur_burn_ht" "$tip")"
   assert_eq "" "$json"

   echo "ok"
}

test_get_stacker_vote() {
   echo -n "test_get_stacker_vote..."
   
   local json=""
   local test_dir="/tmp/sip012-vote-count/test/test_get_stacker_vote"
   if [ -d "$test_dir" ]; then 
      mv "$test_dir" "$test_dir.bak.$(date +%s)"
   fi

   mkdir -p "$test_dir"

   # mock yes votes
   cat > "$test_dir/yes.txt" <<EOF
{"btc":"1PDKpmhYBVrv4XTBHZ2rGkuwweysNvom5R","stx":"SP3STEY6JEYREF8Y023T82740V5B6DBE7QBCR4FMK"}
{"btc":"18MnxXFqf8kt4exiZcU6RMLEcuyZP9w4rP","stx":"SP18BF40VF19V5YM4GCZCZH5G0P95963BHEGCCSB1"}
{"btc":"19qtkM3DsLD6di4AxFF3UQhsCqdeGMeeRS","stx":"SP1GG0ASZE7BJDJDDEEBYNM3FGZWZHW7MXN87NBY5"}
{"btc":"161AHK9MADzbjtq9KmgQDV5yFztVmpM4At","stx":"SP2S1TVYFQV12RDNAT5JKC0NB0Y58TYCV2SRP1H4H"}
{"btc":"12mb6aPVSJUNA6KxBLAKTKL8dXgn9y1XMZ","stx":"SP9PDRYYX44THVQM2BG214ZDAQ6ZAG380BXJN0J8"}
{"btc":"1E3zCmpSSy5MFPWe8YCUuS7kYua5yDMPp7","stx":"SP27JMDXYQ79WWZ7QVJ99NZ0QPGF8VY45NDCVTXPY"}
{"btc":"1LhPVRPowv9fDzzpKg3ku4GQrAq5HpChFE","stx":"SP3C0VKAMZTBKYDEBG0BGSCS64EM425N2PN7QQZ8A"}
{"btc":"1LhPVRPowv9fDzzpKg3ku4GQrAq5HpChFE","stx":"SP3QXB26B01E5P6WZN7KAMFDHBCSPKTKR8X6RZ3M9"}
EOF

   # mock no votes
   cat > "$test_dir/no.txt" <<EOF
{"btc":"1LjDBXmKw5wToyrEaWR2eDUXTkEwak9iZq","stx":"SP3C6C1V8M20ZH035TBQSG584DBHTFQ96E0TYSXWX"}
{"btc":"1MLb822dHgS1isLav6wL1wAQDhVPF8KcKV","stx":"SP3FHDSPQ837S9PJ24FNRJD4W98TYR58PSVYGB3HN"}
{"btc":"131hPM4nFpfoxm1FXCjq9VuqS1yoxGCWUL","stx":"SPB13XN7RHHST7RDNQCM0HGN7EDT9NEFA85P719W"}
{"btc":"1HEnYSz7bT8WgzBnnJHbbNoiXRNwCDV8tL","stx":"SP2S1TVYFQV12RDNAT5JKC0NB0Y58TYCV2SRP1H4H"}
{"btc":"12mb6aPVSJUNA6KxBLAKTKL8dXgn9y1XMZ","stx":"SP2TTHFH4FS6TRDEAZPQBCSRY1P6XFWWTNS2FV888"}
EOF

   # mock stackers
   # #1 voted with their STX address
   # #2 voted with their BTC address
   # #3 didn't vote
   # #4 is #1 but voting with their BTC address
   # #5 is #2 but voting with their STX address
   # #6 voted twice, via their STX address
   # #7 voted twice, via their BTC address
   # #8 and #9 are pooling with the same PoX address
   cat > "$test_dir/stackers.json" <<EOF
{"stx_address": "SP3STEY6JEYREF8Y023T82740V5B6DBE7QBCR4FMK", "pox_address": "1JqvPcVGsv5HxKwRnrpJizmTrihgmtSztk", "ustx": "200"}
{"stx_address": "SP35N8ZBAANK3886HHEDJ6MMXEM58VJENHWH80PD5", "pox_address": "1LjDBXmKw5wToyrEaWR2eDUXTkEwak9iZq", "ustx": "100"}
{"stx_address": "SP30H7BJWABGSMTS5F5NTVTBVKZPFCDB218PPS9HK", "pox_address": "15NqmwLcQ9TX136A2ejRQzt3LoL5H8WwzH", "ustx": "600"}
{"stx_address": "SP30YGE0QD3H8S8R6JKWPH0VKJY5WCRKCZDZ3FPE1", "pox_address": "1PDKpmhYBVrv4XTBHZ2rGkuwweysNvom5R", "ustx": "3"}
{"stx_address": "SP3STEY6JEYREF8Y023T82740V5B6DBE7QBCR4FMK", "pox_address": "16ecPjRJgaiEv81DcVewZm1qchkUrXtfk7", "ustx": "200"}
{"stx_address": "SP2S1TVYFQV12RDNAT5JKC0NB0Y58TYCV2SRP1H4H", "pox_address": "1MD2VpS3kxDNTcPjARZPXPJTYeucVD3nm6", "ustx": "5"}
{"stx_address": "SP35AF3G0M2GFA34S8R3VT0PRHQW563D4FH80JMCH", "pox_address": "12mb6aPVSJUNA6KxBLAKTKL8dXgn9y1XMZ", "ustx": "6"}
{"stx_address": "SP3QXB26B01E5P6WZN7KAMFDHBCSPKTKR8X6RZ3M9", "pox_address": "1LhPVRPowv9fDzzpKg3ku4GQrAq5HpChFE", "ustx": "1000"}
{"stx_address": "SP3C0VKAMZTBKYDEBG0BGSCS64EM425N2PN7QQZ8A", "pox_address": "1LhPVRPowv9fDzzpKg3ku4GQrAq5HpChFE", "ustx": "3000"}
EOF

   # mock already-voted
   touch "$test_dir/.already-voted.json"

   # voter #1 -- voted with STX address
   json="$(get_stacker_vote "stx" "SP3STEY6JEYREF8Y023T82740V5B6DBE7QBCR4FMK" "$test_dir/yes.txt" "$test_dir/no.txt" "$test_dir/stackers.json" "$test_dir/.already-voted.json")"
   assert_eq "yes" "$(echo "$json" | jq -r -c '.vote')"
   assert_eq "200" "$(echo "$json" | jq -r -c '.ustx')"

   # voter #2 -- voted with PoX address
   json="$(get_stacker_vote "stx" "SP35N8ZBAANK3886HHEDJ6MMXEM58VJENHWH80PD5" "$test_dir/yes.txt" "$test_dir/no.txt" "$test_dir/stackers.json" "$test_dir/.already-voted.json")"
   assert_eq "no" "$(echo "$json" | jq -r -c '.vote')"
   assert_eq "100" "$(echo "$json" | jq -r -c '.ustx')"

   # voter #3 -- didn't vote
   json="$(get_stacker_vote "stx" "SP30H7BJWABGSMTS5F5NTVTBVKZPFCDB218PPS9HK" "$test_dir/yes.txt" "$test_dir/no.txt" "$test_dir/stackers.json" "$test_dir/.already-voted.json")"
   assert_eq "" "$json"

   # voter #4 -- voted already via PoX address
   json="$(get_stacker_vote "stx" "SP30YGE0QD3H8S8R6JKWPH0VKJY5WCRKCZDZ3FPE1" "$test_dir/yes.txt" "$test_dir/no.txt" "$test_dir/stackers.json" "$test_dir/.already-voted.json")"
   assert_eq "" "$json"
   
   # voter #5 -- voted already via STX address
   json="$(get_stacker_vote "stx" "SP3STEY6JEYREF8Y023T82740V5B6DBE7QBCR4FMK" "$test_dir/yes.txt" "$test_dir/no.txt" "$test_dir/stackers.json" "$test_dir/.already-voted.json")"
   assert_eq "" "$json"

   # voter #6 -- voted both ways via STX
   json="$(get_stacker_vote "stx" "SP2S1TVYFQV12RDNAT5JKC0NB0Y58TYCV2SRP1H4H" "$test_dir/yes.txt" "$test_dir/no.txt" "$test_dir/stackers.json" "$test_dir/.already-voted.json")"
   assert_eq "" "$json"

   # voter #7 -- voted both ways via BTC
   json="$(get_stacker_vote "stx" "SP35AF3G0M2GFA34S8R3VT0PRHQW563D4FH80JMCH" "$test_dir/yes.txt" "$test_dir/no.txt" "$test_dir/stackers.json" "$test_dir/.already-voted.json")"
   assert_eq "" "$json"

   # voter #8 and #9 are pooling
   json="$(get_stacker_vote "stx" "SP3C0VKAMZTBKYDEBG0BGSCS64EM425N2PN7QQZ8A" "$test_dir/yes.txt" "$test_dir/no.txt" "$test_dir/stackers.json" "$test_dir/.already-voted.json")"
   assert_eq "yes" "$(echo "$json" | jq -r -c '.vote')"
   assert_eq "4000" "$(echo "$json" | jq -r -c '.ustx')"
   
   json="$(get_stacker_vote "stx" "SP3QXB26B01E5P6WZN7KAMFDHBCSPKTKR8X6RZ3M9" "$test_dir/yes.txt" "$test_dir/no.txt" "$test_dir/stackers.json" "$test_dir/.already-voted.json")"
   assert_eq "" "$json"

   # do it again but with BTC
   rm "$test_dir/.already-voted.json"
   
   # voter #1 -- voted with PoX address
   json="$(get_stacker_vote "btc" "1PDKpmhYBVrv4XTBHZ2rGkuwweysNvom5R" "$test_dir/yes.txt" "$test_dir/no.txt" "$test_dir/stackers.json" "$test_dir/.already-voted.json")"
   assert_eq "yes" "$(echo "$json" | jq -r -c '.vote')"
   assert_eq "3" "$(echo "$json" | jq -r -c '.ustx')"

   # voter #2 -- voted with PoX address
   json="$(get_stacker_vote "btc" "1LjDBXmKw5wToyrEaWR2eDUXTkEwak9iZq" "$test_dir/yes.txt" "$test_dir/no.txt" "$test_dir/stackers.json" "$test_dir/.already-voted.json")"
   assert_eq "no" "$(echo "$json" | jq -r -c '.vote')"
   assert_eq "100" "$(echo "$json" | jq -r -c '.ustx')"

   # voter #3 -- didn't vote
   json="$(get_stacker_vote "btc" "15NqmwLcQ9TX136A2ejRQzt3LoL5H8WwzH" "$test_dir/yes.txt" "$test_dir/no.txt" "$test_dir/stackers.json" "$test_dir/.already-voted.json")"
   assert_eq "" "$json"

   # voter #4 -- voted already via PoX address
   json="$(get_stacker_vote "stx" "SP30YGE0QD3H8S8R6JKWPH0VKJY5WCRKCZDZ3FPE1" "$test_dir/yes.txt" "$test_dir/no.txt" "$test_dir/stackers.json" "$test_dir/.already-voted.json")"
   assert_eq "" "$json"
   
   # already voted via PoX address (#1)
   json="$(get_stacker_vote "btc" "1PDKpmhYBVrv4XTBHZ2rGkuwweysNvom5R" "$test_dir/yes.txt" "$test_dir/no.txt" "$test_dir/stackers.json" "$test_dir/.already-voted.json")"
   assert_eq "" "$json"
   
   # voter #5 -- voted already via PoX address
   json="$(get_stacker_vote "stx" "SP3STEY6JEYREF8Y023T82740V5B6DBE7QBCR4FMK" "$test_dir/yes.txt" "$test_dir/no.txt" "$test_dir/stackers.json" "$test_dir/.already-voted.json")"
   assert_eq "" "$json"
   
   # already voted via PoX address (the above STX address)
   json="$(get_stacker_vote "btc" "1JqvPcVGsv5HxKwRnrpJizmTrihgmtSztk" "$test_dir/yes.txt" "$test_dir/no.txt" "$test_dir/stackers.json" "$test_dir/.already-voted.json")"
   assert_eq "" "$json"

   # voter #6 -- voted both ways via STX
   json="$(get_stacker_vote "btc" "1HEnYSz7bT8WgzBnnJHbbNoiXRNwCDV8tL" "$test_dir/yes.txt" "$test_dir/no.txt" "$test_dir/stackers.json" "$test_dir/.already-voted.json")"
   assert_eq "" "$json"
   
   # voter #6 -- voted both ways via STX
   json="$(get_stacker_vote "btc" "1MD2VpS3kxDNTcPjARZPXPJTYeucVD3nm6" "$test_dir/yes.txt" "$test_dir/no.txt" "$test_dir/stackers.json" "$test_dir/.already-voted.json")"
   assert_eq "" "$json"

   # voter #7 -- voted both ways via BTC
   json="$(get_stacker_vote "btc" "12mb6aPVSJUNA6KxBLAKTKL8dXgn9y1XMZ" "$test_dir/yes.txt" "$test_dir/no.txt" "$test_dir/stackers.json" "$test_dir/.already-voted.json")"
   assert_eq "" "$json"

   # voter #8 and #9 are pooling
   json="$(get_stacker_vote "btc" "1LhPVRPowv9fDzzpKg3ku4GQrAq5HpChFE" "$test_dir/yes.txt" "$test_dir/no.txt" "$test_dir/stackers.json" "$test_dir/.already-voted.json")"
   assert_eq "yes" "$(echo "$json" | jq -r -c '.vote')"
   assert_eq "4000" "$(echo "$json" | jq -r -c '.ustx')"
   
   json="$(get_stacker_vote "btc" "1LhPVRPowv9fDzzpKg3ku4GQrAq5HpChFE" "$test_dir/yes.txt" "$test_dir/no.txt" "$test_dir/stackers.json" "$test_dir/.already-voted.json")"
   assert_eq "" "$json"

   echo "ok"
}

test_tabulate_vote() {
   echo -n "test_tabulate_vote..."
  
   local json="" 
   
   json="$(printf "{\"ustx\":\"100\",\"vote\":\"yes\"}\n{\"ustx\":\"200\",\"vote\":\"yes\"}\n{\"ustx\":\"10\",\"vote\":\"no\"}\n{\"ustx\":\"20\",\"vote\":\"no\"}\n{\"ustx\":\"1000\",\"vote\":\"nope\"}\n" | tabulate_vote 2>/dev/null)"
   assert_eq "300" "$(echo "$json" | jq -r -c '.yes')"
   assert_eq "30" "$(echo "$json" | jq -r -c '.no')"

   echo "ok"
}

test_main() {
   echo -n "test_main..."
   
   local json=""
   local result=""
   local test_dir="/tmp/sip012-vote-count/test/test_main"
   local tip="22ac907019619fe9ae4e4ef5100740ecbf1b95510caccfb59fb71053e85bd783"
   if [ -d "$test_dir" ]; then 
      mv "$test_dir" "$test_dir.bak.$(date +%s)"
   fi

   mkdir -p "$test_dir"

   # mock yes votes
   cat > "$test_dir/yes-addrs.json" <<EOF
{"btc":"1PDKpmhYBVrv4XTBHZ2rGkuwweysNvom5R","stx":"SP3STEY6JEYREF8Y023T82740V5B6DBE7QBCR4FMK"}
{"btc":"18MnxXFqf8kt4exiZcU6RMLEcuyZP9w4rP","stx":"SP18BF40VF19V5YM4GCZCZH5G0P95963BHEGCCSB1"}
{"btc":"19qtkM3DsLD6di4AxFF3UQhsCqdeGMeeRS","stx":"SP1GG0ASZE7BJDJDDEEBYNM3FGZWZHW7MXN87NBY5"}
{"btc":"161AHK9MADzbjtq9KmgQDV5yFztVmpM4At","stx":"SP2S1TVYFQV12RDNAT5JKC0NB0Y58TYCV2SRP1H4H"}
{"btc":"12mb6aPVSJUNA6KxBLAKTKL8dXgn9y1XMZ","stx":"SP9PDRYYX44THVQM2BG214ZDAQ6ZAG380BXJN0J8"}
{"btc":"1E3zCmpSSy5MFPWe8YCUuS7kYua5yDMPp7","stx":"SP27JMDXYQ79WWZ7QVJ99NZ0QPGF8VY45NDCVTXPY"}
{"btc":"1LhPVRPowv9fDzzpKg3ku4GQrAq5HpChFE","stx":"SP3C0VKAMZTBKYDEBG0BGSCS64EM425N2PN7QQZ8A"}
{"btc":"1LhPVRPowv9fDzzpKg3ku4GQrAq5HpChFE","stx":"SP3QXB26B01E5P6WZN7KAMFDHBCSPKTKR8X6RZ3M9"}
EOF

   # mock no votes
   cat > "$test_dir/no-addrs.json" <<EOF
{"btc":"1LjDBXmKw5wToyrEaWR2eDUXTkEwak9iZq","stx":"SP3C6C1V8M20ZH035TBQSG584DBHTFQ96E0TYSXWX"}
{"btc":"1MLb822dHgS1isLav6wL1wAQDhVPF8KcKV","stx":"SP3FHDSPQ837S9PJ24FNRJD4W98TYR58PSVYGB3HN"}
{"btc":"131hPM4nFpfoxm1FXCjq9VuqS1yoxGCWUL","stx":"SPB13XN7RHHST7RDNQCM0HGN7EDT9NEFA85P719W"}
{"btc":"1HEnYSz7bT8WgzBnnJHbbNoiXRNwCDV8tL","stx":"SP2S1TVYFQV12RDNAT5JKC0NB0Y58TYCV2SRP1H4H"}
{"btc":"12mb6aPVSJUNA6KxBLAKTKL8dXgn9y1XMZ","stx":"SP2TTHFH4FS6TRDEAZPQBCSRY1P6XFWWTNS2FV888"}
EOF

   # mock stackers
   # #1 voted with their STX address, but because we count BTC addresses first, this one won't get counted.
   # #2 voted with their BTC address, and gets counted
   # #3 didn't vote
   # #4 is #1 but voting with their BTC address. Because BTC gets counted first, its vote counts (not the one with the STX vote).
   # #5 is #2 but voting with their STX address. Because the BTC vote got counted earlier, this vote won't count.
   # #6 voted twice, via their STX address, and won't count
   # #7 voted twice, via their BTC address, and won't count
   # #8 and #9 are pooling with the same PoX address, and will count as a single unit
   cat > "$test_dir/stackers.json" <<EOF
{"stx_address": "SP3STEY6JEYREF8Y023T82740V5B6DBE7QBCR4FMK", "pox_address": "1JqvPcVGsv5HxKwRnrpJizmTrihgmtSztk", "ustx": "200"}
{"stx_address": "SP35N8ZBAANK3886HHEDJ6MMXEM58VJENHWH80PD5", "pox_address": "1LjDBXmKw5wToyrEaWR2eDUXTkEwak9iZq", "ustx": "100"}
{"stx_address": "SP30H7BJWABGSMTS5F5NTVTBVKZPFCDB218PPS9HK", "pox_address": "15NqmwLcQ9TX136A2ejRQzt3LoL5H8WwzH", "ustx": "600"}
{"stx_address": "SP30YGE0QD3H8S8R6JKWPH0VKJY5WCRKCZDZ3FPE1", "pox_address": "1PDKpmhYBVrv4XTBHZ2rGkuwweysNvom5R", "ustx": "3"}
{"stx_address": "SP3STEY6JEYREF8Y023T82740V5B6DBE7QBCR4FMK", "pox_address": "16ecPjRJgaiEv81DcVewZm1qchkUrXtfk7", "ustx": "200"}
{"stx_address": "SP2S1TVYFQV12RDNAT5JKC0NB0Y58TYCV2SRP1H4H", "pox_address": "1MD2VpS3kxDNTcPjARZPXPJTYeucVD3nm6", "ustx": "5"}
{"stx_address": "SP35AF3G0M2GFA34S8R3VT0PRHQW563D4FH80JMCH", "pox_address": "12mb6aPVSJUNA6KxBLAKTKL8dXgn9y1XMZ", "ustx": "6"}
{"stx_address": "SP3QXB26B01E5P6WZN7KAMFDHBCSPKTKR8X6RZ3M9", "pox_address": "1LhPVRPowv9fDzzpKg3ku4GQrAq5HpChFE", "ustx": "1000"}
{"stx_address": "SP3C0VKAMZTBKYDEBG0BGSCS64EM425N2PN7QQZ8A", "pox_address": "1LhPVRPowv9fDzzpKg3ku4GQrAq5HpChFE", "ustx": "3000"}
EOF

   # extract stackers
   jq -r -c '.stx_address' < "$test_dir/stackers.json" > "$test_dir/.stackers.txt"

   result="$(main "$test_dir" "$tip" < "$test_dir/.stackers.txt")"
   assert_eq "4003" "$(echo "$result" | jq -r -c '.yes')"
   assert_eq "100" "$(echo "$result" | jq -r -c '.no')"

   echo "ok"
}


run_local_tests() {
   deps_check
   test_btc_addr_to_stx_addr
   test_pubkey_to_btc_addr
   test_make_btc_addr
   test_stx_addr_to_delegate_state_key
   test_stx_addr_to_clarity_principal
   test_decode_clarity_value
   test_get_stacker_vote
   test_tabulate_vote
   test_main
}

run_bitcoin_tests() {
   deps_check
   test_bitcoin_ping
   test_get_scriptSig
   test_decode_scriptSig
}

run_stacks_tests() {
   deps_check
   test_get_stacker_info
}

run_tests() {
   run_local_tests
   run_bitcoin_tests
   run_stacks_tests
}

###############################################################
# 
# Entry point
#
###############################################################

set +u
if [ -z "$TEST" ]; then
   TEST=""
fi
set -u

if [ -n "$TEST" ]; then
   run_tests
   exit 0
fi

main "$@"
