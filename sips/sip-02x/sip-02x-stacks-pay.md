## Preamble

SIP Number: to be assigned

Title: Stacks Pay: A Payment Request Standard for Stacks Blockchain Payments

Author: Dan Trevino <dantrevino@gmail.com>

Consideration: Technical

Type: Standard

Status: Draft

Created: 24 September 2024

Layer: Application

License: CC0-1.0: Creative Commons CC0 1.0 Universal

Discussion-To: https://github.com/stacksgov/sips

Sign-off:

## Abstract

**Stacks Pay** is a proposed payment request standard for the Stacks blockchain. The standard aims to create easy, secure bundles of transaction information that can be seamlessly shared off-chain, simplifying payment interactions between payers and recipients by providing a standardized method for encoding, decoding, and processing payment requests. By standardizing the structure and parameters of payment requests, Stacks Pay ensures interoperability between wallets and applications within the Stacks ecosystem.

This proposal does not require any changes to the current operation of the Stacks blockchain. Instead, consider these as convenience methods for wrapping existing Stacks transaction information, making them easily shareable.

### License and Copyright

This SIP’s copyright is held by the Stacks Open Internet Foundation. This SIP is made available under the terms of the Creative Commons CC0 1.0 Universal license, available at [https://creativecommons.org/publicdomain/zero/1.0/](https://creativecommons.org/publicdomain/zero/1.0/)

### Terminology

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document should be interpreted according to RFC 2119.

## Introduction

The Stacks ecosystem requires a standardized protocol for payment request generation and processing to support its growing adoption. While established blockchain ecosystems have implemented payment request standards that enable features such as request reusability, metadata handling, and cryptographic verification, Stacks currently lacks such a protocol. This absence of a unified standard compels developers to implement custom solutions, risking ecosystem fragmentation through incompatible implementations and inconsistent payment flows.

**Stacks Pay** addresses this gap by introducing a payment request standard tailored specifically for the Stacks blockchain. The standard simplifies the process of sending and receiving payments, enhances interoperability among wallets and applications, and increases security by providing mechanisms to tie transactions back to payment requests.

Stacks Pay does _not_ define smart contracts that may be used to facilitate specific functions, like subscriptions or NFT mints. Stacks Pay is strictly focused on defining the transaction payment information structure and encoding.

## Operations

Stacks Pay defines several standard operations that specify the type of payment action to be performed. Each operation type has specific required and optional parameters.

### `support`

**Function**: An open-ended, reusable request. Allows the payer to specify the amount and optionally the token, suitable for donations, tips, or gifts.

**Required Parameters:**

- operation: 'support'

- recipient: A valid Stacks address.

- If the token parameter is not 'STX', the functionName defaults to 'transfer' by the wallet.

**Optional Parameters:**

- token: Either 'STX' or a valid SIP-010 contract address. If not provided, defaults to 'STX'.

- description: MAY be included to provide additional context for the payment request.

- expiresAt: MAY be included; wallets MUST NOT process payment requests past the expiry time.

- memo: MAY be included; MUST NOT include personal information.

**Parameters to Ignore:**

- amount, contractName, dueDate, functionName, invoiceNumber. Wallets MUST ignore these parameters if present.

### `invoice`

**Function:** Represents a payment request, such as an invoice for P2P payments or product purchases.

**Required Parameters:**

- operation: 'invoice'

- recipient: A valid Stacks address.

- token: MUST be either 'STX' or a valid SIP-010 contract address.

- amount: The amount to be paid.

**Optional Parameters:**

- description: MAY be included to provide context for the payment request.

- expiresAt: MAY be included; if included, wallets MUST NOT process payment requests past the expiry time.

- invoiceNumber: MAY be included as an identifier.

- dueDate: MAY be included.

- memo: MAY be included. MUST NOT include personal information.

**Parameters to Ignore:**

contractName, functionName: Wallets MUST ignore these parameters if present.

### `mint`

**Function:** Represents a non-fungible token minting request.

**Required Parameters:**

- operation: 'mint'

- contractName: A valid SIP-009 contract address.

- functionName: A public contract function, typically `mint` or `claim`

- token: MUST be either 'STX' or a valid SIP-010 contract name.

- amount: The amount to be paid.

**Optional Parameters:**

- recipient: MAY be included; if present, MUST be a valid Stacks address. The NFT will be minted for the specified address.

- description: MAY be included to provide context for the payment request

- expiresAt: MAY be included. If included wallets MUST NOT process links after the expiry date/time.

- invoiceNumber: MAY be included by the link creator to track individual requests.

- memo: MAY be included. MUST NOT include personal information.

**Parameters to Ignore:**

- contractName, functionName, dueDate: Wallets MUST ignore these parameters if present.

### Custom Operations

Applications **MAY** define custom operations for specific use cases. Custom operation types **MUST** be prefixed to prevent naming conflicts (e.g., `'custom-example'`).

- **Handling Unrecognized Operations**: If a wallet encounters an unrecognized operation type, it **SHOULD**:

- **Warn the User**: Inform the user that the operation type is unrecognized.

- **Provide Safe Defaults**: Default to a standard payment flow if possible.

- **Fail Gracefully**: Prevent unexpected behavior or security risks.

### Parameter Table (summary)

| Operation | token | recipient | amount | description | memo | expiresAt | contractName | functionName | dueDate |
| --------- | ----- | --------- | ------ | ----------- | ---- | --------- | ------------ | ------------ | ------- |
| support   | O     | R         | I      | O           | O    | I         | I            | I            | I       |
| invoice   | R     | R         | R      | O           | O    | O         | I            | I            | O       |
| mint      | I     | O         | R      | O           | O    | O         | R            | R            | I       |
| custom    | O\*   | O\*       | O\*    | O\*         | O\*  | O\*       | O\*          | O\*          | O\*     |

```
R - required
O - optionalas determined
I - ignored
O* - custom links are defined on a per application basis
```

### Token Types

The `token` parameter indicates the type of token for the payment and **MUST** be one of:

- 'STX': For payments using the native STX token.

- A valid SIP-010 contract address: For payments using SIP-010 compliant fungible tokens.

Note: SIP-010 contract addresses should be in the format `CONTRACT_PRINCIPLE`.`CONTRACT_NAME`, without the associated contract identifier.

### URL Scheme

The Stacks Pay URL scheme **MUST** use the custom protocol `web+stx:`, followed by bech32m encoding of an `operation` and query parameters encoding the payment details with `stx` as the human readable part (hrp) of the encoding. The order of the parameters does not matter.

**Format:**

Format of the url string prior to encoding:

`<operation>?recipient=<recipient>&token=<token>&amount=<amount>[&additional_params]`

For example, here is the unencoded url using 'STX' token:

`invoice?recipient=SP3FBR...&token=STX&amount=1000&description=Payment%20for%20Services`

And here is an example using the SIP-010 Nothing Token:

`invoice?operation=invoice&recipient=SP3FBR...&token=SP32AEEF6WW5Y0NMJ1S8SBSZDAY8R5J32NBZFPKKZ.nope&amount=1000&description=Payment+for+services`

- **`operation`**: Specifies the type of action or transaction. It **MUST** be included and be a string value.

- **Query Parameters**: The payment parameters are appended as URL-encoded query parameters. See specific operation types for which are included for which operations.

Example encoded Stack Pay url:

`stx1wajky2mnw3u8qcte8ghj76twwehkjcm98ahhqetjv96xjmmw845kuan0d93k2fnjv43kjurfv4h8g02n2qe9y4z9xarryv2wxer4zdjzgfd9yd62gar4y46p2sc9gd23xddrjkjgggu5k5jnye6x76m9dc74x4zcyesk6mm4de6r6vfsxqczver9wd3hy6tsw35k7m3a2pshjmt9de6zken0wg4hxetjwe5kxetnyejhsurfwfjhxst585erqv3595cnytfnx92ryve9xdqn2wf9xdqn2w26juk65n`

And here is an example final encoded URL suitable for sharing as a link or QR Code.

`web+stx:stx1wajky2mnw3u8qcte8ghj76twwehkjcm98ahhqetjv96xjmmw845kuan0d9...`

### Encoding and Decoding

Stacks Pay URLs **MUST** be encoded using **Bech32m encoding** with the human-readable part (HRP) set to `'stx'` and a `limit` of 512. This ensures compatibility and data integrity, making it suitable for QR codes and platforms with URL limitations.

### Variable Amounts and Donations

- If the `amount` parameter is not specified (e.g., for donations), wallets **MUST** prompt the user to enter the desired amount before proceeding.

- Applications **SHOULD** validate the entered amount to prevent errors or fraudulent transactions.

### Security Considerations

- **Use of Post Conditions**: Applications **SHOULD** use Post Conditions in all asset transfers to ensure that only the intended assets and amounts are transferred.

- **Data Validation**: Wallets and applications **MUST** validate all parameters to prevent injection attacks or malformed data.

- **Token Handling**: Applications **MUST** handle different token types appropriately, ensuring the correct token is used in the transaction.

- **Memo Field Privacy**: Sensitive information **MUST NOT** be included in the memo field, as it is visible to the public.

### Backwards Compatibility

Stacks Pay is a new specification and does not require changes to the core operation of the Stacks blockchain or protocol-level upgrades. Transactions submitted via Stacks Pay remain fully compatible with the Stacks blockchain. However, wallets and applications that do not implement Stacks Pay will not recognize or process Stacks Pay URLs or payment requests.

## Implementation

### Wallet Integration

Wallets that support Stacks Pay **MUST** implement the following:

- **URL Handling**: Recognize and parse `web+stx:` Bech32m-encoded URLs.

- **Parameter Extraction**: Extract payment parameters according to the specification.

- **Operation Handling**: Support standard operation types and handle custom operations appropriately.

- **User Interface**: Present a user interface that displays payment details and allows the user to confirm or cancel the payment.

- **Token Support**: Handle payments in STX and SIP-010 fungible tokens, interacting with smart contracts as required.

- **Use of Post Conditions**: Include appropriate Post Conditions in transactions involving asset transfers.

- **Error Handling**: Provide informative error messages if the URL is invalid or if required parameters are missing.

### Merchant Integration

Merchants and service providers can integrate Stacks Pay into their platforms by:

- **Generating Payment Requests**: Creating Stacks Pay URLs with all required parameters.

- **Sharing Payment Requests**: Displaying the Stacks Pay URL as a QR code or hyperlink.

- **Processing Payments**: Monitoring incoming transactions and verifying payments.

### Application Integration

Applications facilitating payments can incorporate Stacks Pay by:

- **Providing Payment Links**: Generating Stacks Pay URLs for sharable transactions.

- **Guiding Payment Flows**: Implementing payment flows that guide users through the payment process using Stacks Pay URLs.

- **Handling SIP-010 Tokens**: Interacting with token smart contracts when handling SIP-010 tokens.

## Reference Implementation

A reference implementation of the Stacks Pay standard is available to assist developers in integrating the specification into their applications. The implementations cover multiple programming languages to cater to different development environments.

### Source Code

The reference implementations can be found at the following repositories:

- **TypeScript**: [stacks-pay-js](https://github.com/dantrevino/stacks-pay-js)

- **Python**: [stacks-pay-py](https://github.com/dantrevino/stacks-pay-py)

- **Rust**: [stacks-pay-rs](https://github.com/dantrevino/stacks-pay-rs)

These repositories contain source code demonstrating how to generate and parse Stacks Pay URLs, handle Bech32m encoding, in accordance with the specification.

## Ratification

This SIP is considered ratified after:

1.  **SIP Approval and Community Review**: The SIP undergoes formal review and approval by the designated Stacks governance bodies and is discussed publicly to gather feedback.

2.  **Reference Implementation**: At least one reference implementation of the Stacks Pay standard is developed and made publicly available.

3.  **Wallet Support**: At least one widely-used Stacks wallet implements support for the Stacks Pay URL scheme.

4.  **Merchant Adoption**: At least ten merchants or two service providers integrate Stacks Pay into their sales processes.

5.  **Documentation**: Comprehensive documentation is provided, including integration guides and code examples.

## Economics

While Stacks Pay is an application-level standard that does not require changes to the core operation of the Stacks blockchain or affect token emission, its adoption can have indirect economic impacts on the Stacks ecosystem. These potential economic considerations include:

- **Increased Transaction Volume**: Simplifying payment requests may lead to more transactions, increasing total transaction fees collected by miners and enhancing network security.

- **Enhanced Token Utility**: Improved payment mechanisms can increase the utility and demand for STX and SIP-010 tokens, which may affect their market value.

- **Ecosystem Growth**: Standardizing payment requests can attract more merchants and users to the Stacks ecosystem, fostering economic growth.

- **Business Opportunities**: Developers and businesses may find new opportunities to create services that utilize Stacks Pay, contributing to the overall health and diversity of the ecosystem.

## Links

### Related Work

- **SIP-009: Non-fungible Tokens**: Defines the standard for non-fungible tokens on the Stacks blockchain.

- **SIP-010: Fungible Tokens**: Defines the standard for fungible tokens on the Stacks blockchain.

- **Bitcoin Payment Protocol (BIP 21)**: A URI scheme for Bitcoin payments, inspiring the use of a custom URI scheme in Stacks Pay.

- **Lightning Network Invoices (BOLT-11 and BOLT-12)**: Specify invoice formats for the Lightning Network, supporting features like reusable payment requests and enhanced security. Stacks Pay draws inspiration from these protocols in supporting variable amounts and reusable payment requests.

- **BOLT-11**: Defines a standard for Lightning Network invoices, enabling off-chain transactions with detailed payment information.

- **BOLT-12**: Introduces offers and invoices that enhance privacy and functionality over BOLT-11, allowing for more flexible payment requests.

- **Ethereum EIP-681**: A standard for representing Ethereum payment requests as URIs, which influences the design of the Stacks Pay URL scheme.

### Additional Resources

- [RFC 2119 - Key words for use in RFCs to Indicate Requirement Levels](https://www.ietf.org/rfc/rfc2119.txt)

- [SIP-009 Specification](https://github.com/stacksgov/sips/blob/main/sips/sip-009/sip-009-nft-standard.md)

- [SIP-010 Specification](https://github.com/stacksgov/sips/blob/main/sips/sip-010/sip-010-fungible-token-standard.md)

- [Bech32m Specification](https://github.com/bitcoin/bips/blob/master/bip-0350.mediawiki)

- [BOLT-11 Specification](https://github.com/lightning/bolts/blob/master/11-payment-encoding.md)

- [BOLT-12 Specification](https://github.com/lightning/bolts/blob/master/12-offer-encoding.md)
