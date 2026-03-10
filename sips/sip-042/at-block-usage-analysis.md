# Historical `at-block` Usage Data

This directory contains supplemental historical data for SIP-042 on mainnet contract calls that used `at-block` at least once during the one-year period ending February 16, 2026. The data spans Stacks blocks 700,000 through 6,588,934.

## Files
- `at-block-direct-contracts.csv`
  - One row per contract that directly executes `at-block`
  - Column:
    - `contract`
- `at-block-indirect-contract-callers.csv`
  - One row per observed indirect relationship where a contract calls another contract that internally executes `at-block`
  - Columns:
    - `caller_contract`
    - `called_contract`

## Summary

Observed over the study period:
- Contracts that execute `at-block` directly: 124
- Unique deployer addresses behind those contracts: 38
- Contracts that indirectly depend on `at-block`: 96
- Unique deployer addresses behind those caller contracts: 18
- Unique deployer addresses across both sets: 41

## Notes

- "Direct" usage means the listed contract itself contains and executes `at-block`.
- "Indirect" usage means the listed caller contract invokes a contract that internally executes `at-block`.
- These files are provided as historical reference data to support discussion of SIP-042.
