#!/bin/bash

############################################################
# Script to extract all STX addresses that are delegating.
#
# Usage: ./extract-delegates.sh REWARD-CYCLE < DEBUG-LOG-FILE
############################################################

set -oue pipefail

FIRST_BLOCK=666050
REWARD_CYCLE_LENGTH=2100

# DEBG [1635816373.424732] [src/vm/functions/special.rs:81] [chains-coordinator] Handle special-case contract-call to QualifiedContractIdentifier { issuer: StandardPrincipalData(SP000000000000000000002Q6VF78), name: ContractName("pox") } delegate-stack-stx (which returned Response(ResponseData { committed: false, data: Int(3) }))
# DEBG [1635816373.394132] [src/vm/functions/special.rs:81] [chains-coordinator] Handle special-case contract-call to QualifiedContractIdentifier { issuer: StandardPrincipalData(SP000000000000000000002Q6VF78), name: ContractName("pox") } delegate-stack-stx (which returned Response(ResponseData { committed: true, data: Tuple(TupleData { type_signature: TupleTypeSignature { "lock-amount": uint, "stacker": principal, "unlock-burn-height": uint,}, data_map: {ClarityName("lock-amount"): UInt(6000000000000), ClarityName("stacker"): Principal(Standard(StandardPrincipalData(SP2G4JFB3WWBWPVGEDNBTMEVJB6DNDR468G0S03AX))), ClarityName("unlock-burn-height"): UInt(680750)} }) }))
#
# becomes
#
# ""
# {"address": "SP2G4JFB3WWBWPVGEDNBTMEVJB6DNDR468G0S03AX", "delegating": "1", "until": "680750"}
extract_delegate() {
   # stdin: a DEBUG-level logfile
   # stdout: JSON describing each PoX lock event
   gawk '
{
   addr_field = "";
   for (i = 38; i <= NF; i++) {
      if ($i != "") {
          addr_field = addr_field " " $i
      }
   }
   found = 0
   address = ""
   is_contract = match(addr_field, /QualifiedContractIdentifier \{ issuer: StandardPrincipalData\(([^)]+)\), name: ContractName\("([^"]+)"\)/, parts)
   if (is_contract) {
      address = parts[1] "." parts[2]
      found = 1
   }
   else {
      is_standard = match(addr_field, /Standard\(StandardPrincipalData\(([^)]+)\)\)/, parts)
      if (is_standard) {
         address = parts[1]
         found = 1
      }
   }

   found_lock_height = match(addr_field, /ClarityName\("unlock-burn-height"\): UInt\(([0-9]+)\)/, parts)
   if (found && found_lock_height) {
      printf "{\"address\":\"" address "\",\"type\":\"delegation\",\"until\":\"" parts[1] "\"}\n"
   }
}
'
}

grep 'Handle special-case contract-call' | grep 'delegate-stack-stx' | grep 'committed: true' | extract_delegate
