#!/bin/bash

# NOTE: not tested.  Reconstructed from bash history.

LOGFILE="$1"
if [ -z "$LOGFILE" ]; then
   echo >&2 "Usage: $0 NODE-LOGFILE.out"
   exit 1
fi

# get PoX lockup and delegate-stack-stx events
grep -F '[chains-coordinator] PoX lock ' "$LOGFILE" > ./pox-lock.out
grep -F 'Handle special-case contract-call' "$LOGFILE" | grep 'delegate-stack-stx' > ./delegate-pox-lock.out

# extract log entries to JSON stacker records
./extract-stackers.sh 19 < ./pox-lock.out > stackers-19-raw.json
./extract-stackers.sh 20 < ./pox-lock.out > stackers-20.json

# consider stackers that only stacked in 19, not 20
echo -n "" > stackers-19.json
while read -r json; do
   addr="$(echo "$json" | jq -r -c '.address')"
   if ! grep -F "$addr" stackers-20.json >/dev/null; then
      echo "$json" >> stackers-19.json
   fi
done < ./stackers-19-raw.json

# extract log entries to JSON delegate records
./extract-delegates.sh < ./delegate-pox-lock.out | sort | uniq > delegating.json
