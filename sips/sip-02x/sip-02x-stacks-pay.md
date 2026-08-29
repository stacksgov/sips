# Preamble

SIP Number: 029  
Title: Stacks Pay – A Payment-Request Standard for the Stacks Blockchain  
Author: [Dan Trevino @dantrevino](mailto:dantrevino@gmail.com)  
Type: Standard  
Status: Draft  
Created: 24 September 2024  
License: CC0-1.0  
Layer: Application  
Discussion-To: <https://github.com/stacksgov/sips>

---

## Abstract

**Stacks Pay** defines a URL-based payment-request format for the Stacks blockchain.  
By standardising how payment information is encoded, decoded, and displayed, it
guarantees that any wallet or application implementing this specification can
interoperate with any other.

Stacks Pay is *purely* an application-layer standard: it introduces **no** changes
to consensus, token emission, or on-chain data structures.  
Think of it as a shareable wrapper around an ordinary Stacks
transaction.

> **RFC 2119 terminology**  
> The key words **MUST**, **MUST NOT**, **REQUIRED**, **SHALL**, **SHALL NOT**,
> **SHOULD**, **SHOULD NOT**, **RECOMMENDED**, **MAY**, and **OPTIONAL** in this
> document are to be interpreted as described in [RFC 2119].

---

## 1 Introduction

Payment URIs already exist in Bitcoin (BIP-21), Lightning (BOLT-11/12) and
Ethereum (EIP-681).  Stacks lacks a comparable, wallet-agnostic standard.  Without one, merchants,
DApps, and wallets invent ad-hoc query strings that break as soon as a new field
appears.

Stacks Pay solves this by:

* using a **single URI scheme** (`web+stx://`) with Bech32m payloads;
* defining a **small set of operations** (`support`, `invoice`, `mint`);
* listing, for every operation, the **exact parameters that wallets honour**;
* requiring wallets to **ignore everything else**, giving future versions room
  to evolve without breaking existing software.

---

## 2 Common Parameter Types

| Name | Type / Format | Description |
|------|---------------|-------------|
| `recipient` | Stacks c32-address | Address that ultimately receives the payment. |
| `token` | **STX** \| SIP-010 contract address (`SP….<contract>`) | Asset used to pay.  When omitted wallets **MUST** default to **STX**. |
| `amount` | integer (string) | Amount in µSTX or in the smallest SIP-010 units. |
| `description` | UTF-8 string | Human-readable context shown to the payer. |
| `expiresAt` | ISO-8601 datetime (UTC) | After this moment wallets **MUST NOT** let the user broadcast. |
| `invoiceNumber` | free-form string | Merchant-supplied reference. |
| `dueDate` | ISO-8601 date | Informational; wallets **MAY** surface it. |
| `contractAddress` | `SP….<contract>` | SIP-009/-010 contract principal + name. |
| `functionName` | identifier | Clarity function to invoke in `contractAddress`. |

**Unknown parameters** – Any query key not listed as *Required* or *Optional*
for the selected `operation` **SHOULD** be ignored.  Implementations **MAY**
log or warn, but **MUST NOT** fail.

---

## 3 Operations

> All examples use the canonical scheme  
> `web+stxpay://<operation>?<query-string>` before Bech32m encoding.

### 3.1 `support`

Description of support operation here

| Category | Parameters |
|----------|------------|
| **Required** | `operation='support'`, `recipient` |
| **Optional** | `token`, `description`, `expiresAt`,`memo` |

*Wallet behaviour*

* Wallet **MUST** prompt the payer for the `amount`.
* Wallet **MAY** let the payer override the suggested `token`.

---

### 3.2 `invoice`

Description of invoice operation here

| Category | Parameters |
|----------|------------|
| **Required** | `operation='invoice'`, `recipient`, `token`, `amount` |
| **Optional** | `description`, `expiresAt`, `invoiceNumber`, `dueDate`, `memo` |

*Wallet behaviour*

* Wallet **MUST** pre-fill `amount` and **MUST NOT** allow changes unless the
  payer explicitly edits it.
* If `expiresAt` is present and in the past the wallet **MUST** refuse to
  broadcast.

---

### 3.3 `mint`

Description of mint operation here.

| Category | Parameters |
|----------|------------|
| **Required** | `operation='mint'`, `contractAddress`, `functionName='claim'`, `amount`, `token` |
| **Optional** | `description`, `expiresAt` `memo` |

*Wallet behaviour*

* The active wallet address is used as the receiver.
* `amount` **MAY** represent a mint-price; if zero or absent the wallet builds a
  zero-STX transaction.
*  The wallet **MUST** call `contractAddress.functionName` with any additional
   Clarity arguments encoded in the payload (future extension).

---

### 3.4 Custom Operations

Applications **MAY** register vendor-specific operations using the prefix
`custom:` (e.g. `custom:subscription`).  
Wallets that do not recognise the tag **SHOULD** show a warning and **MAY**
refuse to continue.

---

## Token Types and Amount Specification

### Supported Token Types

The token parameter indicates the type of token for the payment and MUST be one of:

**'STX'**: For payments using the native STX token.
- Amount MUST be specified in micro-STX (uSTX)
- 1 STX = 1,000,000 uSTX

**A valid SIP-010 contract address**: For payments using SIP-010 compliant fungible tokens.
- Format: `CONTRACT_PRINCIPLE.CONTRACT_NAME`
- Amount MUST be specified in the token's base unit as defined by its `decimals` field

### Amount Base Unit Requirement

All amount values in StacksPay URLs MUST be specified in the token's smallest unit (base unit):

**For STX:**
- Use micro-STX (uSTX) as the base unit
- 1 STX = 1,000,000 uSTX
- Examples:
  - `amount=1000000` = 1 STX
  - `amount=500000` = 0.5 STX
  - `amount=1` = 0.000001 STX

**For SIP-010 Tokens:**
- Use the token's base unit as defined by its `decimals` field
- Base unit = 10^decimals
- Examples:
  - Token with 6 decimals: `amount=1000000` = 1 token
  - Token with 18 decimals: `amount=1000000000000000000` = 1 token
  - Token with 0 decimals: `amount=1` = 1 token

### Rationale

This approach ensures:
1. **Precision**: No floating-point arithmetic errors
2. **Blockchain Compatibility**: Matches how Stacks transactions work internally
3. **Consistency**: Same pattern that Bitcoin (satoshis) and Stacks (uSTX) utilize in their transaction handling
4. **Universal Support**: Works with any SIP-010 token regardless of decimal places

### Implementation Notes

**For Wallet Developers:**
- Convert base units to human-readable format for display
- Example: Show "1 STX" instead of "1000000 uSTX" to users
- Validate that amounts don't exceed token supply limits

**For Application Developers:**
- Use helper functions to convert from human units to base units
- Example: `STXToMicroSTX(1)` returns `1000000`
- Always validate decimal places match the token specification

## URL Scheme & Encoding

### Data Format
StacksPay uses a structured query string format that is then Bech32m encoded to ensure data integrity and compatibility across platforms.

### Encoding Process

1. **Query String Assembly**: Parameters are assembled as URL query parameters according to operation-specific requirements: `<operation>?<parameter1>=<value1>&<parameter2>=<value2>...`

Example: `invoice?recipient=SP2RTE7F21N6GQ6BBZR7JGGRWAT0T5Q3Z9ZHB9KRS&token=STX&amount=1000`

2. **Bech32m Encoding**: The complete query string is encoded using Bech32m with:
- Human-readable part (HRP): `stxpay`
- Encoding limit: 512
- Result: `stxpay1wajky2mnw3u8qcte8ghj76twwehkjcm98ahhq...`

3. **Protocol Prefix**: Add the protocol scheme to create the final shareable URL: `web+stx:stxpay1wajky2mnw3u8qcte8ghj76twwehkjcm98ahhq...`

### Decoding Process

1. **Protocol Validation**: Verify the URL starts with `web+stx:`
2. **Extract Encoded Data**: Remove the `web+stx:` prefix
3. **Bech32m Decoding**: Decode using expected HRP `stxpay`
4. **Parameter Parsing**: Parse the resulting query string to extract operation and parameters

### Encoding Requirements

Implementations MUST:
- Use Bech32m encoding with human-readable part (HRP) set to `stxpay`
- Validate checksums during decoding
- Support both uppercase and lowercase encoded strings
- Reject URLs with invalid Bech32m encoding
- Reject URLs with incorrect HRP
- Validate all required parameters for the specified operation

Implementations SHOULD:
- Use uppercase for QR code generation for better scanning reliability
- Use lowercase for text-based sharing
- Provide meaningful error messages for common mistakes

Implementations MAY:
- Support visual formatting (spaces/line breaks) in long encoded strings for readability
- Provide error correction suggestions for malformed URLs

### Error Handling

Decoders MUST handle the following error cases:
- Invalid protocol prefix
- Malformed Bech32m encoding
- Incorrect HRP
- Missing required parameters
- Invalid parameter values

### Examples

**Invoice Operation:**

```
Original: invoice?recipient=SP2RTE7F21N6GQ6BBZR7JGGRWAT0T5Q3Z9ZHB9KRS&token=STX&amount=1000
Encoded: stxpay1qpzry9x8gf2tvdw0s3jn54khce6mua7lmqqqxw4tcy8w6tpdf5qq5g5tnyv9xx6myvf5hgurjd4hhq...
Final URL: web+stx:stxpay1qpzry9x8gf2tvdw0s3jn54khce6mua7lmqqqxw4tcy8w6tpdf5qq5g5tnyv9xx6myvf5hgurjd4hhq...
```

**Support Operation:**

```
Original: support?recipient=SP2RTE7F21N6GQ6BBZR7JGGRWAT0T5Q3Z9ZHB9KRS&description=Tip%20for%20great%20content
Encoded: stxpay1qpzgk5q8getf3ts3jn54khce6mua7lmqqqxw4tcy8w6tpdf5qq6x2cvn4dahx2mrvd9xycr6ve5...
Final URL: web+stx:stxpay1qpzgk5q8getf3ts3jn54khce6mua7lmqqqxw4tcy8w6tpdf5qq6x2cvn4dahx2mrvd9xycr6ve5...
```


### Custom Operations

Applications **MAY** define custom operations for specific use cases.

Custom operation types **MUST** be prefixed to prevent naming conflicts (e.g., `'custom-example'`).

**Handling Unrecognized Operations**: If a wallet encounters an unrecognized operation type, it **SHOULD**:

- **Warn the User**: Inform the user that the operation type is unrecognized.

- **Provide Safe Defaults**: Default to a standard payment flow if possible.

- **Fail Gracefully**: Prevent unexpected behavior or security risks.
---

## 5 Security Considerations

* **Post-conditions** – Wallets **SHOULD** add appropriate post-conditions
limiting the transferred asset/amount.
* **Parameter validation** – All fields **MUST** be type-checked and length-checked.
* **Memo privacy** – Memos are on-chain; wallets **MUST NOT** write sensitive data.

---

## 6 Implementation Guidance

### 6.1 Wallets **MUST**

* Handle `web+stxpay:` links (and QR codes) end-to-end.
* Enforce `expiresAt` if present.
* Default missing `token` to **STX**.
* Ignore unknown parameters.

### 6.2 Merchants **SHOULD**

* Generate URIs server-side or via libraries listed below.
* Display them as QR codes or clickable links.
* Regenerate a fresh `expiresAt` for time-sensitive invoices.

### 6.3 Reference Implementations

| Language | Repository |
|----------|------------|
| TypeScript | <https://github.com/dantrevino/stacks-pay-js> |
| Python | <https://github.com/dantrevino/stacks-pay-py> |
| Rust | <https://github.com/dantrevino/stacks-pay-rs> |

Each library demonstrates URI construction, Bech32m encoding/decoding, and
basic validation.

---

## 7 Ratification Criteria

1. SIP accepted by governance.  
2. At least one reference implementation passes test-vectors.  
3. A major wallet releases Stacks Pay support.  
4. Ten independent merchants (or two payment-service providers) adopt it.

---

## 8 Economics

Stacks Pay does not alter consensus rules or tokenomics; however, easier
payments may increase transaction throughput, miner fees, and the
utility of STX and SIP-010 assets.

---

## 9 Related Work

* SIP-010 Fungible Tokens  
* BIP-21 (URI scheme)  
* BOLT-11 / BOLT-12 (Lightning invoices)  
* EIP-681 (Ethereum payment URIs)

---

### References

* RFC 2119 – Key words for use in RFCs to Indicate Requirement Levels  
* Bech32m – BIP-350 specification  
* SIP-009 – Non-Fungible Token Standard (for `mint` contract references)

## Appendix

### Why change the protocol scheme and encoding human readable part?

The original SIP specified used `web+stxpay` as the protocol scheme and `stx` as the human readable part of the encoding.  While this seemed reasonable to me, we have the opportunity to make the user experience potentially better if future Stacks protocols are defined to be used along with the web2 world.

`web+stx` as the protocol scheme sets the stage for future Stacks protocols that serve different needs, but could each be easily identified as 'Stacks' protocols by the use of a common scheme. When writing out the un-encoded uri, `stxpay` indicates that this is a StacksPay uri.  And together, they make the protocol uri, and hopefully future protocols more easily identifiable.

examples:

`web+stx:stxpay.....` <- Oh look! A StacksPay uri 

`web+stx:stxfoo....` <- Oh look! A StacksFoo uri 

`web+stx:stxbar....` <- Oh look! A StacksBar uri 

### Why a 'mint' operation?

In the interest of starting with low hanging fruit and providing utility to the most users, an NFT mint function seems the obvious choice.  And while, as @leopradel pointed out, there is no 'mint' function defined in SIP-009 (nft-mint is a clarity function), the reality is that Gamma's \([https://gamma.io](https://gamma.io)\) smart contracts are the defacto standard here.  Following their lead and implementing a simple, structured 'mint' operation that calls Gamma's nft 'claim' function allows us to specify a controllable, easy-to-use, and useful smart contract payment function while limiting the attack surface area that general smart contract calls would open up. User education is still required here as malicious apps can always leverage fake contracts to steal from users, or even large DEXes. 


### Integration Simplicity

#### Comparison to Other Blockchain Payment Standards

Stacks Pay is designed to be significantly easier to integrate than traditional blockchain payment flows:

#### Integration Effort Comparison

| Integration Aspect | Ethereum/Web3 | Stacks Pay | Effort Reduction |
|-------------------|---------------|------------|------------------|
| Setup complexity | High (provider, contracts) | Low (single package) | 80% less |
| Code required | 50-100+ lines | 3-10 lines | 90% less |
| Wallet integration | Complex (multiple protocols) | Simple (URL/QR) | 85% less |
| Error handling | Extensive (gas, reverts, etc.) | Minimal (URL validation) | 75% less |
| Testing required | High (multiple networks) | Low (URL generation) | 70% less |

**Ethereum/EVM Integration Complexity:**
- Requires web3 provider setup and wallet connection
- Complex smart contract interactions with gas estimation
- Manual transaction building and signing
- Multiple confirmation states to handle
- Network-specific configuration (mainnet, testnets, L2s)

**Stacks Pay Integration:**
- Single npm package: `npm install stacks-pay`
- Generate payment URL in 3 lines of code
- No wallet connection required for URL generation
- Works with any Stacks-compatible wallet
- Network-agnostic URL format

#### Integration Examples

**Creating a payment request (Merchant side):**
```typescript
import { encodeStacksPayURL } from 'stacks-pay';

const paymentURL = encodeStacksPayURL({
  operation: 'invoice',
  recipient: 'SP2RTE7F21N6GQ6BBZR7JGGRWAT0T5Q3Z9ZHB9KRS',
  token: 'STX',
  amount: '1000',
  description: 'Coffee purchase'
});

// Result: Ready-to-share URL or QR code
```

**Processing payments (User side):**
- User clicks link or scans QR code
- Wallet opens with pre-filled transaction details
- User confirms payment
- Transaction processes on Stacks blockchain


#### Developer Experience Benefits

1. **No Blockchain Expertise Required**: Developers can integrate cryptocurrency payments without understanding smart contracts or gas mechanics
2. **Universal Compatibility**: Works with any application that can generate URLs or QR codes
3. **Offline Generation**: Payment requests can be created without blockchain connection
4. **Social Media Friendly**: URLs can be shared via email, SMS, social media, or embedded in websites
5. **Mobile-First**: Optimized for mobile wallet scanning and one-tap payments

#### Real-World Integration Scenarios

**E-commerce Platform:**

```typescript
// Add to checkout flow
const checkoutURL = encodeStacksPayURL({
  operation: 'invoice',
  recipient: process.env.MERCHANT_ADDRESS,
  token: 'STX',
  amount: cart.total.toString(),
  description: `Order #${order.id}`
});

// Display as QR code or payment button

```

**Donation Button:**

```typescript
// Reusable donation link
const donationURL = encodeStacksPayURL({
  operation: 'support',
  recipient: 'SP2RTE7F21N6GQ6BBZR7JGGRWAT0T5Q3Z9ZHB9KRS',
  description: 'Support our project'
});
// Amount left blank for user to specify
```

**NFT Marketplace:**

```typescript
// Dynamic minting
const mintURL = encodeStacksPayURL({
  operation: 'mint',
  contractName: 'SP123...my-nft-collection',
  functionName: 'mint',
  token: 'STX',
  amount: '500',
  description: 'Mint NFT #1234'
});

```

This integration simplicity enables rapid adoption across diverse use cases, from simple tip jars to complex marketplace integrations, without requiring specialized blockchain development expertise.