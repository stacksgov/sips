# Preamble

SIP Number: `To be assigned`

Title: Integration of WebBTC Request Standard for Stacks Wallets

Authors: [janniks](https://github.com/janniks), `todo`

Type: Standard

Status: Draft

Created: 10 October 2023

License: BSD 2-Clause

# Abstract

This SIP proposes the integration of the WebBTC request standard into the Stacks blockchain's Connect system. The goal is to replace the current Connect interface, primarily used by web applications to connect with browser extensions and mobile apps, with a more streamlined and efficient protocol.

# Motivation

The current Connect system, which has evolved since the Blockstack era, is now primarily utilized by web applaications for interfacing with wallets. However, many aspects of the existing "Connect" and "Auth" libraries are no longer required, leading to unnecessary complexity and brittleness in wallet connectivity.

Recent attempts to standardize the interface have sparked valuable discussions but have not culminated in a ratified standard, largely due to the stable state of the existing system. This SIP aims to address these issues by adopting the WebBTC request standard, which offers a more suitable RPC-style interface for modern web applications.

Additionally, this SIP is motivated by the increased traffic of Ordinal inscriptions on Bitcoin and the Stacks ecosystem growing closers to Bitcoin. The community has recognized the need for a more unified approach to wallet connectivity. Recently, diverging viewpoints and disagreements on methodologies have hindered progress. By adopting the WebBTC request standard, we aim to align the community towards a common, efficient, and modern protocol for wallet interaction in web applications. Importantly, the decision to use an existing standard rather than inventing a new one is intentional, to avoid further division or split ownership within the community.

# Specification

The proposed changes are as follows:

Integration of WebBTC Request Standard: The WebBTC request standard will be adopted to replace the current Connect system. This standard provides a flexible RPC-style interface for web applications to interact with wallets.
The RPC payload is also standardized on its own for use in various contexts.

Backward Compatibility for Wallets: Wallets are encouraged to implement the new WebBTC request interface. To maintain backward compatibility, wallets may choose to retain the previous system alongside the new interface. This approach ensures uninterrupted service for applications that have not yet migrated to the new standard.
Detailed Implementation Guidelines: Detailed guidelines and best practices for integrating the WebBTC request standard will be provided. This includes technical specifications, sample code, and migration strategies for both web applications and wallet providers.
Rationale

The adoption of the WebBTC request standard is driven by the need for a more robust and simplified connection protocol between web applications and wallets. This standard provides a modernized approach that aligns with current web development practices, offering better performance, security, and ease of use.

# Backwards Compatibility

The implementation of this proposal is not necessarily backward compatible.
However, wallets implementing the new standard are advised to maintain the previous system to support legacy applications during a transition period.
Existing applications using the current Auth system should continue to operate, but immediate changes are recommended once this SIP is ratified.

# Implementation

## Notes on Serialization

The WebBTC request standard is inspired by JSON-RPC 2.0 for serialization.
To adhere to a generic serializability, the following notes are given.
Enums are serialized as humand-readable strings.
BigInts are serialized as numbers, strings, or anything else that can be parsed by the JavaScript BigInt constructor.
Bytes are serialized as hex-encoded strings (without the 0x prefix).
Predefined formats from previous SIPs are used where applicable.
Addresses are serialized as Stacks c32-encoded strings.
Clarity values, post-conditions, and transactions are serialized to bytes (defined by SIP-005) and used as hex-encoded strings.

## Methods

This section defines the available methods, their parameters, and result structure.
Parameters should be considered recommendations for the wallet.
The user/wallet may choose to ignore/override them.
Optional params are marked with a `?`.

Methods can be namespaced under `stx_` if used in settings like WebBTC (see WBIP-002).
In other cases (e.g. WalletConnect), the namespace may already be given by meta-data (e.g. a `chainId` field) and can be omitted.

### Method Independent

#### Transfer & Transaction Definitions

`params`

- `network?`: `'mainnet' | 'testnet' | 'regtest' | 'mocknet'`
- `fee?`: `number | string` (anything parseable by the BigInt constructor)
- `nonce?`: `number | string` (anything parseable by the BigInt constructor)
- `attachment?`: `string` hex-encoded
- `anchoreMode?`: `'onChainOnly' | 'offChainOnly' | 'any'`
- `postConditionMode?`: `'allow' | 'deny'`
- `postConditions?`: `PostCondition[]`, defaults to `[]`
- `sponsored?`: `boolean`, defaults to `false`
- `sender?`: `string` address, Stacks c32-encoded
- ~~`appDetails`~~ _removed_
- ~~`onFinish`~~ _removed_
- ~~`onCancel`~~ _removed_

`where`

- `PostCondition`: `string` hex-encoded

### `transferStx`

`params`

- `recipient`: `string` address, Stacks c32-encoded
- `amount`: `number | string` (anything parseable by the BigInt constructor)
- `memo?`: `string`, defaults to `''`

`result`

- `txid`: `string` hex-encoded
- `transaction`: `string` hex-encoded

### `transferFt`

`todo: haven't existed yet, should we add them?`

### `transferNft`

`todo: haven't existed yet, should we add them?`

### `contractCall`

`params`

- `contractAddress`: `string` address, Stacks c32-encoded
- `contractName`: `string`
- `functionName`: `string`
- `functionArgs`: `ClarityValue[]`, defaults to `[]`

`where`

- `ClarityValue`: `string` hex-encoded

`result`

- `txid`: `string` hex-encoded
- `transaction`: `string` hex-encoded

### `contractDeploy`

`params`

- `contractName`: `string`
- `codeBody`: `string` Clarity contract code
- `clarityVersion?`: `number`

`result`

- `txid`: `string` hex-encoded
- `transaction`: `string` hex-encoded

### `signTransaction`

`params`

- `transaction`: `string` hex-encoded

`result`

- `transaction`: `string` hex-encoded (signed)

### `signMessage`

`params`

- `message`: `string`

`result`

- `signature`: `string` hex-encoded
- `publicKey`: `string` hex-encoded

### `signStructuredMessage`

`params`

- `message`: `string` Clarity value, hex-encoded
- `domain?`: `string` hex-encoded (defined by SIP-018)

> `domain` can be optional if the wallet (e.g. browser extension) can infer it from the origin of the request.

### `updateProfile`

`params`

- `profile`: `object` Schema.org Person object

`result`

- `profile`: `object` updated Schema.org Person object

## Provider Registration

Wallets can register their aliased provider objects according to WBIP-004.

# Ratification

This SIP is considered ratified after at least two major wallets in the Stacks ecosystem have implemented and launched the new standard.

# Commentary

The Connect library should be updated to utilize the new standard, once Leather and Xverse have adopted the new standard.
The existing Connect interfaces should be kept compatible to provide a transition without breaking the interface.

# Links

Discussions

- [Wallet JSON RPC API, Request Accounts #2378](https://github.com/leather-wallet/extension/pull/2378)
- [Sign-in with stacks #70](https://github.com/stacksgov/sips/pull/70)
- [Add API to request addresses #2371](https://github.com/leather-wallet/extension/issues/2371)
- [SIP for Wallet Protocol #59](https://github.com/stacksgov/sips/pull/59)
- [SIP for Authentication Protocol #50](https://github.com/stacksgov/sips/pull/50)

References

- [WebBTC Request Standard](https://balls.dev/webbtc/extendability/extending/)
- [WBIPs](https://webbtc.netlify.app/wbips)
- [Xverse WalletConnect JSON API](https://docs.xverse.app/wallet-connect/reference/api_reference)
- [Schema.org Person](https://schema.org/Person)

`todo: any other relevant references`
