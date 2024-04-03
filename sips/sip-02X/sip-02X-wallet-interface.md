# Preamble

SIP Number: `To be assigned`

Title: Integration of a Modern Stacks Wallet Interface Standard

Authors: [janniks](https://github.com/janniks), [kyranjamie](https://github.com/kyranjamie), [aryzing](https://github.com/aryzing), [m-aboelenein](https://github.com/m-aboelenein)

Type: Standard

Status: Draft

Created: 10 October 2023

License: BSD 2-Clause

# OPEN QUESTIONS

<!-- todo: remove section before merge -->

- [ ] Should a global single `window.` object be used, or should provider discovery be handled complely differently?
- [ ] Rename `stx_transferFt` to include SIP010 somewhere?
- [ ] Should listeners have params? (e.g. txid for tx mined event)

# Abstract

This SIP proposes the integration of the standard into the Stacks blockchain's "Connect" and "Auth" system.
The goal is to replace the current Connect interface, primarily used by web applications to connect with browser extensions and mobile apps, with a more straightforward protocol.
The proposal consists mainly of standardizing JSON compatible interfaces for use with wallet interfaces.

# Motivation

The current Connect system, which has evolved since the Blockstack era, is primarily utilized by web applications for interfacing with wallets.
However, many aspects of the existing "Connect" and "Auth" libraries are no longer required, leading to unnecessary complexity and brittleness in wallet connectivity.

Recent attempts to standardize the interface have sparked valuable discussions but have not culminated in a ratified standard, largely due to the stable state of the existing system.
This SIP aims to address these issues by adopting the WBIPs standards, which offer a more suitable RPC-style interface for modern web applications.
The simplified protocol will allow integration without heavy dependencies (like Auth) and provider a more extendable interface for wallets.

Additionally, this SIP is motivated by the increased traffic of Ordinal inscriptions on Bitcoin and the Stacks ecosystem growing closers to Bitcoin.
The community has recognized the need for a more unified approach to wallet connectivity (e.g. Bitcoin and PSBTs for previously Stacks-only wallets).
By adopting the new standard, we aim to align the community towards a common and modern protocol for wallet interaction in web applications.
Importantly, the decision to use an existing standard (rather than designing a new one or reworking Auth) is intentional — to avoid further division or split ownership within the community.

There was an attempt to re-use existing standards/protocols from other ecosystems via the WBIPs working group — but no consensus was found that was a perfect fit or had enough traction for the larger layer-2 ecosystem.
So this SIP aims to capture the important features for the Stacks ecosystem, with a focus on extensibility.

# Specification

The proposed changes are listed as follows:

Specify JSON-RPC 2.0 compatible methods and payloads for wallet interaction.
These can be used via a browser object (i.e., via the `window.btc.request` method) or similar interfaces like WalletConnect.

# Backwards Compatibility

The implementation of this proposal is not necessarily backward compatible.
However, wallets implementing the new standard are advised to maintain the previous system to support legacy applications during a transition period.
Existing applications using the current Auth system should continue to operate, but immediate changes are recommended once this SIP is ratified.
The Connect library should go live with the new standard, once most major wallets have adopted the new standard.

# Implementation

## Notes on Serialization

These methods are based on JSON-RPC 2.0 for serialization.
To adhere to a generic serializability, the following notes are given.
Enums are serialized as human-readable strings.
BigInts are serialized as numbers, strings, or anything that can be parsed by the JavaScript BigInt constructor.
Bytes are serialized as hex-encoded strings (without a 0x prefix).
Predefined formats from previous SIPs are used where applicable.
Addresses are serialized as Stacks c32-encoded strings.
Clarity values, post-conditions, and transactions are serialized to bytes (defined by SIP-005) and used as hex-encoded strings.

## Methods

This section defines the available methods, their parameters, and result structure.
Parameters should be considered recommendations for the wallet.
The user/wallet may choose to ignore/override them.
Optional params are marked with a `?`.

Methods can be namespaced under `stx_` if used in more generic settings and other more Ethereum inspired domains.
In other cases (e.g. WalletConnect), the namespace may already be given by meta-data (e.g. a `chainId` field) and can be omitted.
On the predominant `StacksProvider` global object, the methods can be used without a namespace, but wallets may add namespaced aliases for convenience.

#### Common definitions

The following definitions can be used in multiple methods (mainly for transfer and transaction methods).

`params`

- `address?`: `string` address, Stacks c32-encoded, defaults to wallets current address
- `network?`: `'mainnet' | 'testnet' | 'regtest' | 'mocknet'`
- `fee?`: `number | string` BigInt constructor compatible value
- `nonce?`: `number | string` BigInt constructor compatible value
- `attachment?`: `string` hex-encoded
- `anchorMode?`: `'on-chain' | 'off-chain' | 'any'`
- `postConditions?`: `PostCondition[]`, defaults to `[]`
- `postConditionMode?`: `'allow' | 'deny'`
- `sponsored?`: `boolean`, defaults to `false`
- ~~`appDetails`~~ _removed_
- ~~`onFinish`~~ _removed_
- ~~`onCancel`~~ _removed_

`where`

- `PostCondition`: `string | object` hex-encoded or JSON representation

---

### Method `stx_transferStx`

> **Comment**: This method doesn't take post-conditions.

`params`

- `recipient`: `string` address, Stacks c32-encoded
- `amount`: `number | string` BigInt constructor compatible value
- `memo?`: `string`, defaults to `''`

`result`

- `txid`: `string` hex-encoded
- `transaction`: `string` hex-encoded raw transaction

### Method `stx_transferFt`

`params`

- `recipient`: `string` address, Stacks c32-encoded
- `asset`: `string` address, Stacks c32-encoded, with contract name suffix
- `amount`: `number | string` BigInt constructor compatible value

`result`

- `txid`: `string` hex-encoded
- `transaction`: `string` hex-encoded raw transaction

### Method `stx_transferNft`

`params`

- `recipient`: `string` address, Stacks c32-encoded
- `asset`: `string` address, Stacks c32-encoded, with contract name suffix
- `assetId`: `ClarityValue`

`where`

- `ClarityValue`: `string | object` hex-encoded or JSON representation

`result`

- `txid`: `string` hex-encoded
- `transaction`: `string` hex-encoded raw transaction

### Method `stx_callContract`

`params`

- `contract`: `string.string` address with contract name suffix, Stacks c32-encoded
- `functionName`: `string`
- `functionArgs`: `ClarityValue[]`, defaults to `[]`

`where`

- `ClarityValue`: `string | object` hex-encoded or JSON representation

`result`

- `txid`: `string` hex-encoded
- `transaction`: `string` hex-encoded raw transaction

### Method `stx_deployContract`

`params`

- `name`: `string`
- `clarityCode`: `string` Clarity contract code
- `clarityVersion?`: `number`

`result`

- `txid`: `string` hex-encoded
- `transaction`: `string` hex-encoded raw transaction

### Method `stx_signTransaction`

`params`

- `transaction`: `string` hex-encoded raw transaction

`result`

- `transaction`: `string` hex-encoded raw transaction (signed)

### Method `stx_signMessage`

`params`

- `message`: `string`

`result`

- `signature`: `string` hex-encoded
- `publicKey`: `string` hex-encoded

### Method `stx_signStructuredMessage`

`params`

- `message`: `string` Clarity value, hex-encoded
- `domain`: `string` hex-encoded (defined by SIP-018)

`result`

- `signature`: `string` hex-encoded
- `publicKey`: `string` hex-encoded

### Method `stx_getAddresses`

`result`

- `addresses`: `{}[]`
  - `address`: `string` address, Stacks c32-encoded
  - `publicKey`: `string` hex-encoded

### Method `stx_getAccounts`

> **Comment**: This method is similar to `stx_getAddresses`.
> It was added to provide better backwards compatibility for applications using Gaia.

`result`

- `accounts`: `{}[]`
  - `address`: `string` address, Stacks c32-encoded
  - `publicKey`: `string` hex-encoded
  - `gaiaHubUrl`: `string` URL
  - `gaiaAppKey`: `string` hex-encoded

### Method `stx_updateProfile`

`params`

- `profile`: `object` Schema.org Person object

`result`

- `profile`: `object` updated Schema.org Person object

## Listeners

In addition to the request interface, event listeners may be provided via the `.listen` method.
Wallets may provide a `.unlisten` method to remove listeners.

- `provider.listen(event: string, listener: (...args: any[]) => void): void`
- `provider.unlisten(event: string, listener: (...args: any[]) => void): void`

### Event `accountsChanged`

`listener: (accounts: {}[]) => void`

> `accounts` as defined above in `stx_getAccounts`.
> The first account is considered the default account (and may be the only "active" account in a wallet).

## Error Codes

Errors thrown by request methods should match existing JSON-RPC 2.0 error codes.
This way, the user or an intermediary library can handle them in a standardized way.
Otherwise, no additional error codes are defined in this SIP.

## JSON Representations

While discussing this SIP, it has become clear that the current Stacks.js representation is confusing to developers.
Rather, a better solution would be human-readable — for example, rely on string literal enumeration, rather than magic values, which need additional lookups.
Relying on soley a hex-encoded also poses difficulties when building Stacks enabled web applications.

### Clarity values

Proposed below is an updated interface representation for Clarity primitives for use in Stacks.js and JSON compatible environments.

> **Comment**: For encoding larger than JS `Number` big integers, `string` is used.

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
  value: object // Clarity value
}
```

`0x08` `err` (aka "response err")

```ts
{
  type: 'err',
  value: object // Clarity value
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
  value: object // Clarity value
}
```

`0x0b` `list`

```ts
{
  type: 'list',
  value: object[] // Array of Clarity values
}
```

`0x0c` `tuple`

```ts
{
  type: 'tuple',
  value: Record<string, object> // Record of Clarity values
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

### Post-conditions

`0x00` STX

```ts
{
  type: 'stx-postcondition',
  address: string | `${string}.${string}`, // Stacks c32-encoded, with optional contract name suffix
  condition: 'eq' | 'gt' | 'gte' | 'lt' | 'lte',
  amount: string // `bigint` compatible, amount in micro-STX
}
```

`0x01` Fungible token

```ts
{
  type: 'ft-postcondition',
  address: string | `${string}.${string}`, // Stacks c32-encoded, with optional contract name suffix
  condition: 'eq' | 'gt' | 'gte' | 'lt' | 'lte',
  asset: `${string}.${string}::${string}` // Stacks c32-encoded address, with contract name suffix, with asset suffix
  amount: string // `bigint` compatible, amount in lowest integer denomination of fungible token
}
```

`0x02` Non-fungible token

```ts
{
  type: 'nft-postcondition',
  address: string | `${string}.${string}`, // Stacks c32-encoded, with optional contract name suffix
  condition: 'sent' | 'not-sent',
  asset: `${string}.${string}::${string}` // address with contract name suffix with asset suffix, Stacks c32-encoded
  assetId: object, // Clarity value
}
```

### Test vectors

Listed below are some examples of the potentially unclear representations:

- `u12` = `{ type: "uint", value: "12" }`
- `0xbeaf` = `{ type: "ascii", value: "hello there" }`
- `"hello there"` = `{ type: "ascii", value: "hello there" }`
- `(list 4 8)` =
  ```
  {
    type: "list",
    value: [
      { type: "int", value: "4"},
      { type: "int", value: "8"},
    ]
  }
  ```
- `(err u4)` =
  ```
  {
    type: "err",
    value: { type: "uint", value: "4"},
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

## Provider registration

Wallets can register their aliased provider objects according to WBIP-004.

# Ratification

This SIP is considered ratified after at least two major wallets in the Stacks ecosystem have implemented and launched the new standard.

# Links

WBIPs

> Documents worked out in the working group with Leather, Xverse, and others.

- [WBIP-001: Wallet API JSON RPC](https://wbips.netlify.app/wbips/WBIP001)
- [WBIP-002: Namespaces](https://wbips.netlify.app/wbips/WBIP002)
- [WBIP-002: Batching](https://wbips.netlify.app/wbips/WBIP007)

Discussions

- [Wallet JSON RPC API, Request Accounts #2378](https://github.com/leather-wallet/extension/pull/2378)
- [Sign-in with stacks #70](https://github.com/stacksgov/sips/pull/70)
- [Add API to request addresses #2371](https://github.com/leather-wallet/extension/issues/2371)
- [SIP for Wallet Protocol #59](https://github.com/stacksgov/sips/pull/59)
- [SIP for Authentication Protocol #50](https://github.com/stacksgov/sips/pull/50)

References

- [WebBTC Request Standard](https://balls.dev/webbtc/extendability/extending/)
- [WBIPs](https://wbips.netlify.app/wbips)
- [Xverse WalletConnect JSON API](https://docs.xverse.app/wallet-connect/reference/api_reference)
- [Schema.org Person](https://schema.org/Person)
