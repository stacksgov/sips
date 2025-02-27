## Preamble

SIP Number: `030`

Title: Integration of a Modern Stacks Wallet Interface Standard

Authors: [aryzing](https://github.com/aryzing), [janniks](https://github.com/janniks), [kyranjamie](https://github.com/kyranjamie), [m-aboelenein](https://github.com/m-aboelenein)

Consideration: Technical

Type: Standard

Status: Draft

Created: 10 October 2023

License: BSD 2-Clause

## Abstract

This SIP proposes common RPC methods to use for the Stacks blockchain's "Connect" and "Auth" systems.
The goal is to replace the current Connect interface, primarily used by web applications to connect with browser extensions and mobile apps with a more straightforward protocol.
This proposal's goal is to standardize JSON compatible interfaces for use with wallet interfaces.

# License and Copyright

This SIP is made available under the terms of the BSD-2-Clause license, available at https://opensource.org/licenses/BSD-2-Clause.
This SIP’s copyright is held by the Stacks Open Internet Foundation.

## Introduction

The current Connect system[^15], which has existed for several years, is primarily utilized by web applications for interfacing with wallets.
However, many aspects of the existing "Connect" and "Auth" libraries are no longer required, leading to unnecessary complexity (e.g., wrapping RPC payloads in jsontokens) and lack of clear definitions (e.g., undefined serialization for non-JSON compatible data structures) in wallet connectivity.

Recent attempts[^21][^22][^23][^24][^25][^26] to standardize the interface have sparked valuable discussions but have not culminated in a ratified standard, largely due to the stable state of the existing system.
This SIP aims to address these issues by adopting the WBIPs standards[^11], which offer a more suitable RPC-style interface for modern web applications.
The simplified protocol will allow integration without heavy dependencies (like Auth) and provide a more extendable interface for wallets.

Additionally, this SIP is motivated by the increased traffic of Ordinal inscriptions on Bitcoin and upcoming integrations like sBTC that require standardized Stacks and Bitcoin transaction signing capabilities in wallets.
The community has recognized the need for a more unified approach to wallet connectivity (e.g. Bitcoin and PSBTs for previously Stacks-only wallets).
By adopting the new standard, we aim to align the community towards a common and modern protocol for wallet interaction in web applications.
Importantly, the decision to use an existing standard (rather than designing a new one or reworking Auth) is intentional — to avoid further division or split ownership within the community.

There was an attempt to re-use existing standards/protocols from other ecosystems via the WBIPs working group[^11][^26] — but no consensus was found that was a perfect fit or had enough traction for the larger layer-2 ecosystem.
So this SIP aims to capture the important features for the Stacks ecosystem, with a focus on extensibility.

## Specification

The proposed changes are listed as follows:

- Use [JSON-RPC 2.0](https://www.jsonrpc.org/specification) as the underlying protocol for wallet interaction.
- Specify compatible RPC methods and payloads for wallet interaction.
- Define a recommended provider object and its discovery mechanism.

> **Note**: The methods can be used via the mentioned browser object (i.e., via the `window.WalletProvider.request` method), but also through similar interfaces like WalletConnect.

### Notes on Serialization

To ensure serializability, consider these notes:

- Enums are serialized as human-readable strings.
- BigInts are serialized as numbers, strings, or anything that can be parsed by the JavaScript BigInt constructor.
- Bytes are serialized as hex-encoded strings (without a 0x prefix).
- Predefined formats from previous SIPs are used where applicable.
- Addresses are serialized as Stacks c32-encoded strings.
- Clarity values, post-conditions, and transactions may be serialized to bytes (defined by SIP-005) and used as hex-encoded strings.

### Methods

This section defines the available methods, their parameters, and result structure.
Parameters should be considered only as recommendations for the wallet, and the user/wallet may choose to ignore or override them.

> Note: Optional params are marked with a `?`.

Methods can be namespaced under `stx_` if used in more generic settings and other more Ethereum inspired domains.
In other cases (e.g. `WalletConnect`), the namespace may already be given by metadata (e.g. a `chainId` field) and can be omitted.

##### General parameters (for transaction methods)

The following definitions can be used in the transaction methods.

> **Note**: The types `PostCondition` and `ClarityValue` are used in the below definitions.
> They are defined later in this document under [JSON Representations](#json-representations).

Parameter properties

- `address?`: `string` address, Stacks c32-encoded, defaults to wallets current address
- `network?`: `'mainnet' | 'testnet' | 'regtest' | 'devnet' | 'mocknet' | NetworkId`
  - where `NetworkId extends string` and can be a network identifier, which already exists in the wallet (e.g. a URL or network name)
- `fee?`: `number | string` BigInt constructor compatible value
- `nonce?`: `number | string` BigInt constructor compatible value
- `postConditions?`: `PostCondition[]`, defaults to `[]`
  - where `PostCondition` is `string | object` hex-encoded or JSON representation
- `postConditionMode?`: `'allow' | 'deny'`
- `sponsored?`: `boolean`, defaults to `false`
- `broadcast?`: boolean whether transaction is to be broadcast, defaults to `true`
- ~~`attachment?`~~ _removed_
- ~~`appDetails`~~ _removed_
- ~~`onFinish`~~ _removed_
- ~~`onCancel`~~ _removed_

---

#### Method `stx_transferStx`

> **Comment**: This method doesn't take post-conditions.

Parameter properties

- `recipient`: `string` address, Stacks c32-encoded
- `amount`: `number | string` BigInt constructor compatible value
- `memo?`: `string`, defaults to `''`

Result properties

- `txid`: `string` hex-encoded
- `transaction`: `string` hex-encoded raw transaction

#### Method `stx_transferSip10Ft`

Parameter properties

- `recipient`: `string` address, Stacks c32-encoded
- `asset`: `string` address, Stacks c32-encoded, with contract name suffix
- `amount`: `number | string` BigInt constructor compatible value

Result properties

- `txid`: `string` hex-encoded
- `transaction`: `string` hex-encoded raw transaction

#### Method `stx_transferSip9Nft`

Parameter properties

- `recipient`: `string` address, Stacks c32-encoded
- `asset`: `string` address, Stacks c32-encoded, with contract name suffix
- `assetId`: `ClarityValue`

`where`

- `ClarityValue`: `string | object` hex-encoded or JSON representation

Result properties

- `txid`: `string` hex-encoded
- `transaction`: `string` hex-encoded raw transaction

#### Method `stx_callContract`

Parameter properties

- `contract`: `string.string` address with contract name suffix, Stacks c32-encoded
- `functionName`: `string`
- `functionArgs`: `ClarityValue[]`, defaults to `[]`
  - where `ClarityValue` is `string | object` hex-encoded or JSON representation

Result properties

- `txid`: `string` hex-encoded
- `transaction`: `string` hex-encoded raw transaction

#### Method `stx_deployContract`

Parameter properties

- `name`: `string`
- `clarityCode`: `string` Clarity contract code
- `clarityVersion?`: `number`

Result properties

- `txid`: `string` hex-encoded
- `transaction`: `string` hex-encoded raw transaction

#### Method `stx_signTransaction`

Parameter properties

- `transaction`: `string` hex-encoded raw transaction
- `broadcast?`: `boolean` whether transaction is to be broadcast, defaults to `false`

Result properties

- `transaction`: `string` hex-encoded raw transaction (signed)

#### Method `stx_signMessage`

Parameter properties

- `message`: `string`

Result properties

- `signature`: `string` hex-encoded
- `publicKey`: `string` hex-encoded

#### Method `stx_signStructuredMessage`

Parameter properties

- `message`: `ClarityValue`
  - where `ClarityValue` is `string | object` hex-encoded or JSON representation
- `domain`: `ClarityTupleValue`
  - where `ClarityTupleValue` (defined by SIP-018) is a Clarity "tuple" as `string | object` hex-encoded or JSON representation

Result properties

- `signature`: `string` hex-encoded
- `publicKey`: `string` hex-encoded

#### Method `stx_getAddresses`

> **Note**: This method can be used similarly to legacy "connect" methods, where the first account selection also acts as an approval of the site/domain.

Result properties

- `addresses`: `{}[]`
  - `address`: `string` address, Stacks c32-encoded
  - `publicKey`: `string` hex-encoded
  - `network?`: `string` network identifier

#### Method `stx_getAccounts`

> **Comment**: This method is similar to `stx_getAddresses`.
> It was added to provide better backwards compatibility for applications using Gaia.

> **Note**: This method can be used similarly to legacy "connect" methods, where the first account selection also acts as an approval of the site/domain.

Result properties

- `accounts`: `{}[]`
  - `address`: `string` address, Stacks c32-encoded
  - `publicKey`: `string` hex-encoded
  - `gaiaHubUrl`: `string` URL
  - `gaiaAppKey`: `string` hex-encoded

#### Method `stx_getNetworks`

Result properties

- `active`: `string` network identifier
- `networks`: `{}[]`
  - `id`: `string`
  - `chainId`: `number`
  - `transactionVersion`: `number`

#### Method `stx_updateProfile`

Parameter properties

- `profile`: `object` Schema.org Person object[^13]

Result properties

- `profile`: `object` updated Schema.org Person object[^13]

### Listeners

In addition to the request interface, event listeners may be provided via the `.listen` method.

- `provider.listen(event: string, listener: (...args: any[]) => void): Function`

> `provider.listen` should return a "unlisten" function, which can be called to remove the listener.

The event name should be closer to nouns than verbs and doesn't use the `on` prefix from DOM naming conventions.

#### Event `stx_accountChange`

- `listener: (accounts: {}[]) => void`

> `accounts` as defined above in `stx_getAccounts`.
> The first account is considered the default account (and may be the only "active" account in a wallet).

#### Event `stx_networkChange`

- `listener: (data: GetNetworksResult) => void`
  - where `GetNetworksResult` matches the `stx_getNetworks` result type

> This event may be emitted when the active network changes and on first load of the wallet/site.

### Error Codes

Errors thrown by request methods should match existing JSON-RPC 2.0 error codes.
This way, the user or an intermediary library can handle them in a standardized way.

#### Standard JSON-RPC Error Codes

- **-32700**: Parse Error - Invalid JSON received by server while parsing
- **-32600**: Invalid Request - Invalid Request object
- **-32601**: Method Not Found - Method not found/available
- **-32602**: Invalid Params - Invalid method parameters
- **-32603**: Internal Error - Internal JSON-RPC error

#### Implementation-Defined Wallet Error Codes

Implementation-defined wallet errors range from `-32099` to `-32000`.

- **-32000**: User Rejection - User rejected the request
- **-32001**: Method Address Mismatch - Address mismatch for the requested method
- **-32002**: Method Access Denied - Access denied for the requested method

#### Custom Error Codes

Custom error codes outside the JSON-RPC error code range using the `-31099` to `-31000` range.

- **-31000**: Unknown Error - Unknown external error (does not originate from the wallet)
- **-31001**: User Canceled - User canceled the request (may not originate from the wallet)

### JSON Representations

For historical reasons, a Stacks.js internal representation, based on the Stacks core code, has been used in serialized payloads to wallets.
These representations are not human-readable and thus make debugging difficult.
A better solution would be to rely on string literal enumeration, rather than magic values, which need additional lookups.
Relying on solely on hex-encoding also poses difficulties when building Stacks enabled web applications.

#### Clarity values

Clarity values should be represented in the following format for use in Stacks.js and JSON compatible environments:

> **Comment**: For encoding larger than JS `Number` big integers, `string` is used with `bigint` any compatible values.

> `ClarityValue` is `string | object` hex-encoded or JSON representation of any of the below Clarity values.

`0x00` `int`

```ts
{
  type: 'int',
  value: string // `bigint` compatible
}
```

`0x01` `uint`

```ts
{
  type: 'uint',
  value: string // `bigint` compatible
}
```

`0x02` `buffer`

```ts
{
  type: 'buffer',
  value: string // hex-encoded string
}
```

`0x03` `bool` `true`

```ts
{
  type: 'true',
}
```

`0x04` `bool` `false`

```ts
{
  type: 'false',
}
```

`0x05` `address` (aka "standard principal")

```ts
{
  type: 'address',
  value: string // Stacks c32-encoded
}
```

`0x06` `contract` (aka "contract principal")

```ts
{
  type: 'contract',
  value: `${string}.${string}` // Stacks c32-encoded, with contract name suffix
}
```

`0x07` `ok` (aka "response ok")

```ts
{
  type: 'ok',
  value: ClarityValue // Clarity value
}
```

`0x08` `err` (aka "response err")

```ts
{
  type: 'err',
  value: ClarityValue // Clarity value
}
```

`0x09` `none` (aka "optional none")

```ts
{
  type: 'none',
}
```

`0x0a` `some` (aka "optional some")

```ts
{
  type: 'some',
  value: ClarityValue // Clarity value
}
```

`0x0b` `list`

```ts
{
  type: 'list',
  value: ClarityValue[] // Array of Clarity values
}
```

`0x0c` `tuple`

```ts
{
  type: 'tuple',
  value: Record<string, ClarityValue> // Record of Clarity values
}
```

`0x0d` `ascii`

```ts
{
  type: 'ascii',
  value: string // ASCII-compatible string
}
```

`0x0e` `utf8`

```ts
{
  type: 'utf8',
  value: string
}
```

#### Post-conditions

`0x00` STX

```ts
{
  type: 'stx-postcondition',
  address: 'origin' | string | `${string}.${string}`, // Stacks c32-encoded, with optional contract name suffix
  condition: 'eq' | 'gt' | 'gte' | 'lt' | 'lte',
  amount: string // `bigint` compatible, amount in micro-STX
}
```

`0x01` Fungible token

```ts
{
  type: 'ft-postcondition',
  address: 'origin' | string | `${string}.${string}`, // Stacks c32-encoded, with optional contract name suffix
  condition: 'eq' | 'gt' | 'gte' | 'lt' | 'lte',
  asset: `${string}.${string}::${string}` // Stacks c32-encoded address, with contract name suffix, with asset suffix
  amount: string // `bigint` compatible, amount in lowest integer denomination of fungible token
}
```

`0x02` Non-fungible token

```ts
{
  type: 'nft-postcondition',
  address: 'origin' | string | `${string}.${string}`, // Stacks c32-encoded, with optional contract name suffix
  condition: 'sent' | 'not-sent',
  asset: `${string}.${string}::${string}` // address with contract name suffix with asset suffix, Stacks c32-encoded
  assetId: ClarityValue, // Clarity value
}
```

#### Test vectors

Listed below are some examples of the potentially unclear representations:

- `u12` = `{ type: "uint", value: "12" }`
- `0xbeaf` = `{ type: "ascii", value: "hello there" }`
- `"hello there"` = `{ type: "ascii", value: "hello there" }`
- `(list 4 8)` =
  ```
  {
    type: "list",
    value: [
      { type: "int", value: "4" },
      { type: "int", value: "8" },
    ]
  }
  ```
- `(err u4)` =
  ```
  {
    type: "err",
    value: { type: "uint", value: "4" },
  }
  ```
- "sends more than 10000 uSTX" =
  ```
  {
    type: "stx-postcondition",
    address: "STB44HYPYAT2BB2QE513NSP81HTMYWBJP02HPGK6",
    amount: "10000",
    condition: "gt"
  }
  ```
- "does not send the `12` TKN non-fungible token" =
  ```
  {
    type: "ntf-postcondition",
    address: "STB44HYPYAT2BB2QE513NSP81HTMYWBJP02HPGK6.vault"
    asset: "STB44HYPYAT2BB2QE513NSP81HTMYWBJP02HPGK6.tokencoin::tkn",
    assetId: { type: "uint", value: "12" }
    condition: "not-sent"
  }
  ```

### Provider registration

Applications may hardcode known wallets, i.e. store their provider name.
Libraries may use discovery mechanisms like the WBIP-004[^3] standard or Wallet Standard[^14].

Using a shared global object between multiple wallets is discouraged.
The historical `window.StacksProvider` object has led to issues in the past, where overwriting the same object has led to undefined wallet registration behavior.

## Reference Implementations

The following git tags provide examples of how the new standard can be implemented in TypeScript, as well as validation libraries:

- [Leather Wallet — JSON RPC](https://github.com/leather-io/mono/blob/bf81686cd1ab6ee6c8f830f345c2093485de176c/packages/rpc/src/index.ts#L130-L150)
- [Leather Wallet — Method Schema](https://github.com/leather-io/mono/blob/aefd3e56e2d865fbf041ccebea0add21ca321941/packages/rpc/src/methods/stacks/stx-call-contract.ts#L20-L21)

## Backwards Compatibility

The implementation of this proposal is not necessarily backward compatible.
Notably, app-specific private keys for domains have been removed from the connect protocol, but can still be accessed via the `gaiaAppKey` field in `stx_getAccounts`.

Wallets implementing the new standard may maintain the previous system to support legacy applications during a transition period or indefinitely.
Existing applications using the current Auth system should continue to operate, but immediate changes are recommended once this SIP is ratified.

## Activation

This SIP is considered _Ratified_ after at least two wallet providers with significant user adoption (> 10,000 monthly active users) have implemented and launched the new standard.

Once wallets have implemented the new standard, tooling (e.g. Stacks Connect[^15]) can be updated to support the new standard as well.
This SIP is not consensus breaking, thus the timeline for activation is not tied to Stacks releases.

## Related Work

This SIP is designed as a replacement for the existing Connect system[^15], due to the issues mentioned above.

The standard builds on top of the following work: the webbtc `.request` standard[^10], Wallet Standard[^14], and WBIPs[^11].
This SIP is meant to be compatible with various use cases and is meant as a formal specification to unify and drive forward the wallet RPC ecosystem.

### Auth

One of the core libraries referenced in this proposal is often called "Auth", which is packaged within the existing Stacks "Connect" libraries[^15], as well as separately as `@stacks/auth` on npm.
This Auth system is a legacy Blockstack library, which was never specified in a SIP.
It relies on wrapping RPC payloads in jsontokens.

While Auth served as an essential building block for the legacy Blockstack system, its assumptions are no longer strictly necessary.
By using a simpler JSON-RPC 2.0–based approach for wallet connectivity, this SIP removes the need for Auth.

## Appendix

<!-- WBIPs -->

> WBIPs documents partially worked on in the working group with Leather, Xverse, and others.

[^1]: [WBIP-001: Wallet API JSON RPC](https://wbips.netlify.app/wbips/WBIP001)
[^2]: [WBIP-002: Namespaces](https://wbips.netlify.app/wbips/WBIP002)
[^3]: [WBIP-004: Registration](https://wbips.netlify.app/wbips/WBIP004)
[^4]: [WBIP-007: Batching](https://wbips.netlify.app/wbips/WBIP007)

<!-- Discussions -->

[^21]: [Wallet JSON RPC API, Request Accounts #2378](https://github.com/leather-wallet/extension/pull/2378)
[^22]: [Sign-in with stacks #70](https://github.com/stacksgov/sips/pull/70)
[^23]: [Add API to request addresses #2371](https://github.com/leather-wallet/extension/issues/2371)
[^24]: [SIP for Wallet Protocol #59](https://github.com/stacksgov/sips/pull/59)
[^25]: [SIP for Authentication Protocol #50](https://github.com/stacksgov/sips/pull/50)
[^26]: [Wallet client API](https://github.com/stacksgov/sips/issues/117)

<!-- References -->

[^10]: [WebBTC Request Standard](https://balls.dev/webbtc/extendability/extending/)
[^11]: [WBIPs](https://wbips.netlify.app)
[^12]: [Xverse WalletConnect JSON API](https://docs.xverse.app/wallet-connect/reference/api_reference)
[^13]: [Schema.org Person](https://schema.org/Person)
[^14]: [Wallet Standard](https://github.com/wallet-standard/wallet-standard)
[^15]: [Stacks Connect](https://github.com/hirosystems/connect)
