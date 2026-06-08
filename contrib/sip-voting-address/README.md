# sip-address

Generate deterministic BTC and STX vote addresses for a given SIP number.

Each address embeds a human-readable ASCII payload (`yes-sip-N` / `no-sip-N`)
right-aligned in the 20-byte hash, making the vote intent verifiable on-chain.

## Usage

```
npm install
node sip-voting-address.js <sip-number>
```

Example:

```
$ node sip-voting-address.js 29
```
