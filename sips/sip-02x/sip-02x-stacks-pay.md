## Preamble

SIP Number: to be assigned

Title: Stacks Pay: A Payment Request Standard for Stacks Blockchain Payments

Author: [Dan Trevino @dantrevino] <dantrevino@gmail.com>

Consideration: Technical

Type: Standard

Status: Draft

Created: 2024-09-24

License: CC0-1.0: Creative Commons CC0 1.0 Universal

Sign-off: 

## Abstract

This SIP proposes a payment request standard, **Stacks Pay**, for the Stacks blockchain. The standard aims to enable secure, efficient, and flexible payment interactions between payers and recipients by defining a unified method for creating and processing payment requests. By standardizing the structure and parameters of payment requests, Stacks Pay ensures interoperability between wallets and applications within the Stacks ecosystem.

## License and Copyright
This SIP is made available under the terms of the Creative Commons CC0 1.0 Universal license, available at https://creativecommons.org/publicdomain/zero/1.0/ This SIP’s copyright is held by the Stacks Open Internet Foundation.

## Motivation

As the Stacks ecosystem grows, there's an increasing demand for a standardized method to request and process payments. Currently, there is no unified standard for creating and handling payment requests on the Stacks blockchain, which leads to fragmentation and inconsistent user experiences. Existing payment request standards in other ecosystems offer features like reusable payment requests and enhanced security, but no such standard exists for Stacks.

**Stacks Pay** addresses this gap by introducing a payment request standard tailored specifically for the Stacks blockchain. The standard simplifies the process of sending and receiving payments, enhances interoperability among wallets and applications, and increases security by providing mechanisms to tie transactions back to payment requests.

## Specification

### Overview

Stacks Pay defines a standardized method for creating and processing payment requests on the Stacks blockchain using a URL scheme to encode necessary payment information. This allows wallets and applications to parse and handle payments consistently.

### Payment Parameters

A Stacks Pay payment request **MUST** include the following parameters:

- **`recipient`**: The Stacks address of the payment recipient.
- **`token`**: The type of token used for payment. This **MUST** be either `'STX'` or `'SIP10'`.
- **`description`**: A description providing context for the payment.
- **`spId`**: A unique identifier for the payment request (Stacks Pay ID).

Optional parameters:

- **`amount`**: The amount to be paid, in micro-STX or token units. If not provided, the payer **MUST** enter the amount.
- **`contractAddress`**: The contract principal and contract name, separated by a '.'. This field is **REQUIRED** if `token` is `'SIP10'`.
- **`functionName`**: The contract function name (e.g., `transfer`, `mint`). This field is **REQUIRED** if `token` is `'SIP10'`.

### Token Types

The `token` parameter indicates the type of token for the payment and **MUST** be one of:

- `'STX'`: For payments using the native STX token.
- `'SIP10'`: For payments using SIP-010 compliant fungible tokens.

### URL Scheme

The Stacks Pay URL scheme **MUST** use the custom protocol `stxpay://`, followed by an `operation` and query parameters encoding the payment details.

**Format:**

```
stxpay://<operation>?recipient=<recipient>&token=<token>&description=<description>&spId=<spId>[&amount=<amount>][&contractAddress=<contractAddress>][&functionName=<functionName>]
```

- **`operation`**: Specifies the type of action or transaction. It **MUST** be included and be a string value.
- **Query Parameters**: The payment parameters are appended as URL-encoded query parameters.

**Example:**

```
stxpay://pay?recipient=SP3FBR...&token=STX&description=Payment%20for%20Services&spId=3KMf8...&amount=1000
```

### Operation Field

The `operation` field **MUST** specify the type of action to be performed. Standard operation types include:

- **`'pay'`**: Initiates a standard payment with specified parameters.
- **`'donate'`**: Allows the payer to specify the amount.
- **`'subscribe'`**: Initiates a subscription or recurring payment.
- **`'invoice'`**: Represents a payment request for an invoice.

Wallets and applications **MUST** recognize and correctly process these standard operation types.

### Encoding and Decoding

Stacks Pay URLs **MUST** be encoded using **Bech32m encoding** with the human-readable part (HRP) set to `'stx'`. This ensures compatibility and data integrity, making it suitable for QR codes and platforms with URL limitations.

### Including `spId` in the Memo Field

To associate a transaction with its payment request, the `spId` **MUST** be included in the transaction's memo field.

- **Generating `spId`**: The `spId` **MUST** be a unique identifier generated using a cryptographically secure random number generator and encoded efficiently (e.g., using Base58 encoding) to fit within the 34-byte memo field limit.
- **Including in Memo**: When constructing the transaction, the payer's wallet **MUST** include the `spId` in the memo field. The memo field **MUST NOT** exceed 34 bytes.

### Variable Amounts and Donations

- If the `amount` parameter is not specified (e.g., for donations), wallets **MUST** prompt the user to enter the desired amount before proceeding.
- Applications **SHOULD** validate the entered amount to prevent errors or fraudulent transactions.

### Security Considerations

- **Use of Post Conditions**: Applications **SHOULD** use Post Conditions in asset transfers to ensure that only the intended assets and amounts are transferred.
- **Data Validation**: Wallets and applications **MUST** validate all parameters to prevent injection attacks or malformed data.
- **Token Handling**: Applications **MUST** handle different token types appropriately, ensuring the correct token is used in the transaction.
- **Memo Field Privacy**: Sensitive information **MUST NOT** be included in the memo field, as it is publicly visible.

## Backwards Compatibility

Stacks Pay is a new specification and does not require changes to the core operation of the Stacks blockchain or protocol-level upgrades. Transactions submitted via Stacks Pay remain fully compatible with the Stacks blockchain. However, wallets and applications that do not implement Stacks Pay will not recognize or process Stacks Pay URLs or payment requests.

## Implementation

### Wallet Integration

Wallets that support Stacks Pay **MUST** implement the following:

- **URL Handling**: Recognize and parse `stxpay://` URLs, including Bech32m-encoded URLs.
- **Parameter Extraction**: Extract payment parameters according to the specification.
- **Operation Handling**: Support standard operation types and handle custom operations appropriately.
- **User Interface**: Present a user interface that displays payment details and allows the user to confirm or cancel the payment.
- **Memo Field Inclusion**: Include the `spId` in the transaction's memo field.
- **Token Support**: Handle payments in STX and SIP-010 fungible tokens, interacting with smart contracts as required.
- **Use of Post Conditions**: Include appropriate Post Conditions in transactions involving asset transfers.
- **Error Handling**: Provide informative error messages if the URL is invalid or if required parameters are missing.

### Merchant Integration

Merchants and service providers can integrate Stacks Pay into their platforms by:

- **Generating Payment Requests**: Creating Stacks Pay URLs with all required parameters and a unique `spId`.
- **Sharing Payment Requests**: Displaying the Stacks Pay URL as a QR code or hyperlink.
- **Processing Payments**: Monitoring incoming transactions, extracting `spId`s from memo fields, and verifying payments.

### Application Integration

Applications facilitating payments can incorporate Stacks Pay by:

- **Providing Payment Links**: Generating Stacks Pay URLs for transactions.
- **Guiding Payment Flows**: Implementing payment flows that guide users through the payment process using Stacks Pay URLs.
- **Handling SIP-010 Tokens**: Interacting with token smart contracts when handling SIP-010 tokens.
- **Ensuring Security**: Generating and storing `spId`s securely and complying with privacy regulations.

## Ratification

This SIP is considered ratified after:

1. **SIP Approval and Community Review**: The SIP undergoes formal review and approval by the designated Stacks governance bodies and is discussed publicly to gather feedback.
2. **Reference Implementation**: At least one reference implementation of the Stacks Pay standard is developed and made publicly available.
3. **Wallet Support**: At least one widely-used Stacks wallet implements support for the Stacks Pay URL scheme.
4. **Merchant Adoption**: At least ten merchants or two service providers integrate Stacks Pay into their platforms.
5. **Documentation**: Comprehensive documentation is provided, including integration guides and code examples.

## Economics

While Stacks Pay is an application-level standard that does not require changes to the core operation of the Stacks blockchain or affect token emission, its adoption can have indirect economic impacts on the Stacks ecosystem. These potential economic considerations include:

- **Increased Transaction Volume**: Simplifying payment requests may lead to more transactions, increasing total transaction fees collected by miners and enhancing network security.
- **Enhanced Token Utility**: Improved payment mechanisms can increase the utility and demand for STX and SIP-010 tokens, potentially affecting their market value.
- **Ecosystem Growth**: Standardizing payment requests can attract more merchants and users to the Stacks ecosystem, fostering economic growth.
- **Business Opportunities**: Developers and businesses may find new opportunities to create services around Stacks Pay, contributing to the overall health and diversity of the ecosystem.

## Links

### Related Work

- **SIP-010: Fungible Tokens**: Defines a standard interface for fungible tokens on the Stacks blockchain.

- **Bitcoin Payment Protocol (BIP 21)**: A URI scheme for Bitcoin payments, inspiring the use of a custom URI scheme in Stacks Pay.

- **Lightning Network Invoices (BOLT-11 and BOLT-12)**: Specify invoice formats for the Lightning Network, supporting features like reusable payment requests and enhanced security. Stacks Pay draws inspiration from these protocols in supporting variable amounts and reusable payment requests.

  - **BOLT-11**: Defines a standard for Lightning Network invoices, enabling off-chain transactions with detailed payment information.
  
  - **BOLT-12**: Introduces offers and invoices that enhance privacy and functionality over BOLT-11, allowing for more flexible payment requests.

- **Ethereum EIP-681**: A standard for representing Ethereum payment requests as URIs, which influences the design of the Stacks Pay URL scheme.

### Additional Resources

- [RFC 2119 - Key words for use in RFCs to Indicate Requirement Levels](https://www.ietf.org/rfc/rfc2119.txt)

- [Bech32m Specification](https://github.com/bitcoin/bips/blob/master/bip-0350.mediawiki)

- [SIP-010: Fungible Tokens](https://github.com/blockstack/SIPs/blob/master/sips/sip-010/sip-010.md)

- [BOLT-11 Specification](https://github.com/lightning/bolts/blob/master/11-payment-encoding.md)

- [BOLT-12 Specification](https://github.com/lightning/bolts/blob/master/12-offer-encoding.md)
