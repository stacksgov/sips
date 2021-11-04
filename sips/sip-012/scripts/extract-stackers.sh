#!/bin/bash

############################################################
# Script to extract all STX addresses that are stacking
# in a particular reward cycle, given access to a node's
# debug log file.
#
# Usage: ./extract-stackers REWARD-CYCLE < DEBUG-LOG-FILE
############################################################

set -oue pipefail

FIRST_BLOCK=666050
REWARD_CYCLE_LENGTH=2100

# DEBG [1635829849.697968] [src/chainstate/stacks/db/accounts.rs:298] [chains-coordinator] PoX lock 604260000 uSTX (new balance 6104) until burnchain block height 689150 for Standard(StandardPrincipalData(SP2WGGG8E7NVFA0W4YZ87M6R09TNJ33CEBAXB9QPB))
#
# becomes
#
# {"locked":"604260000","until":"689150","address":"SP2WGGG8E7NVFA0W4YZ87M6R09TNJ33CEBAXB9QPB"}
#
# log lines for contracts that do locking are ignored, since they don't get counted.
extract_stacker() {
   # stdin: a DEBUG-level logfile
   # stdout: JSON describing each PoX lock event
   grep -v 'Contract' | sed -r 's/.+ PoX lock ([0-9]+) uSTX \(new balance [0-9]+\) until burnchain block height ([0-9]+) for [^\(]+\([^\(]+\(([^\)]+)\)\)$/{"locked":"\1","until":"\2","address":"\3"}/g'
}

block_height_to_reward_cycle() {
   # $1: burnchain block height
   # stdin: none
   # stdout: reward cycle
   local block_height="$1"
   echo $(( ($block_height - $FIRST_BLOCK) / $REWARD_CYCLE_LENGTH ))
}

stacking_in_reward_cycle() {
   # $1: reward cycle number
   # stdin: output from extract_stacker
   # stdout: the JSON blobs that are stacking within this reward cycle
   local target_reward_cycle="$1"
   local json=""
   local reward_cycle=0
   local first_block=0
   local until_ht=0

   while IFS= read -r json; do
      until_ht="$(echo "$json" | jq -rc '.until')"
      reward_cycle="$(block_height_to_reward_cycle "$until_ht")"

      # echo >&2 "Until reward cycle $reward_cycle: $json"

      if (( "$reward_cycle" > "$target_reward_cycle" )); then
         echo "$json"
      fi
   done
   return 0
}

target_reward_cycle="$1"
extract_stacker | stacking_in_reward_cycle "$target_reward_cycle"
