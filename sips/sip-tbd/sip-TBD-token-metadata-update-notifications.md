# Preamble

SIP Number: TBD

Title: Notifications for Token Metadata Updates

Author: Rafael Cárdenas (rafael@hiro.so), Matthew Little (matt@hiro.so)

Consideration: Technical

Type: Standard

Status: Draft

Created: 17 May 2022

License: GPL-3.0

Sign-off: TBD

Layer: Traits

# Abstract

As the use of tokens (fungible and non-fungible) has grown in popularity, Stacks developers have
found novel ways to define and use metadata to describe them. This rich data is commonly cached and
indexed for future use in applications such as marketplaces, statistics aggregators, and developer
tools like the [Stacks Blockchain API](https://github.com/hirosystems/stacks-blockchain-api).

Occasionally, however, this metadata needs to change for a number of reasons: artwork reveals, media
storage migrations, branding updates, etc. As of today, these changes do not have a standardized way
of being propagated through the network for indexers to refresh their cache, so the display of stale
metadata is a very common problem.

This SIP aims to define a simple mechanism for developers to notify the Stacks network when metadata
for a token has changed, so interested parties can refresh their cache and display up-to-date
information in their applications.

# Introduction

Smart contracts that declare NFTs and FTs conform to a standard set of traits used to describe each
token (see [SIP-009](../sip-009/sip-009-nft-standard.md) and
[SIP-010](../sip-010/sip-010-fungible-token-standard.md)). One of these traits is `get-token-uri`,
which should return a URI string that resolves to a token's metadata usually in the form of a JSON
file. There is currently no defined structure for this data, and it is not considered to be
immutable.

To illustrate a common use of `get-token-uri`, we'll look at the
[`SPSCWDV3RKV5ZRN1FQD84YE1NQFEDJ9R1F4DYQ11.newyorkcitycoin-token-v2`](https://explorer.stacks.co/txid/0x969192220b1c478ef9d18d1cd413d7c79fe02937a9b33af63d441bd5519d1715?chain=mainnet)
contract which declares the NewYorkCityCoin fungible token.

At the time of writing, the value returned by this contract for `get-token-uri` is the string:
```
"https://cdn.citycoins.co/metadata/newyorkcitycoin.json"
```
When this URI is resolved, it returns a JSON file with the following metadata:
```json
{
  "name": "NewYorkCityCoin",
  "description": "A CityCoin for New York City, ticker is NYC, Stack it to earn Stacks (STX)",
  "image": "https://cdn.citycoins.co/logos/newyorkcitycoin.png"
}
```
Even though the URI string is fixed, this file lives off-chain so it is concievable that its
contents could change at any point in the future. Additionally, this contract includes a way for its
owners to change this URI via a `var-set` function call:

```clarity
(define-data-var tokenUri (optional (string-utf8 256)) (some u"https://cdn.citycoins.co/metadata/newyorkcitycoin.json"))

;; set token URI to new value, only accessible by Auth
(define-public (set-token-uri (newUri (optional (string-utf8 256))))
  (begin
    (asserts! (is-authorized-auth) ERR_UNAUTHORIZED)
    (ok (var-set tokenUri newUri))
  )
)
```

This setup is very flexible for administrators, but it creates a complex problem for metadata
indexers which now need to figure out if (and when) they should re-index token contracts to avoid
displaying stale metadata in their applications.


## Metadata staleness

Within the Stacks ecosystem, there are a number of applications that need to index token metadata
and struggle with specific challenges caused by changed metadata. For example:

* An NFT marketplace, which needs to display a token's artwork for users to view.
  * Presenting a token's icon correctly is difficult given that the `get-token-uri` on-chain
    variable could change, the off-chain JSON file could change, and/or the image served by the URL
    could change.
* A [blockchain API](https://github.com/hirosystems/stacks-blockchain-api), which needs to serve FT
metadata to return account balances correctly.
  * Wallets require the on-chain decimals value in order to correctly send and receive tokens.
    Critical balance draining is possible when this property is zero at contract launch but updated
    later.

For indexing, developers usually run and maintain a background process that listens for new token
contracts deployed to the blockchain so they can immediately call on their metadata to save the
results. This works for new contracts, but it is insufficient for old ones that may change their
metadata after it has been processed.

To avoid staleness, some indexers resort to a cron-like periodic refresh of all tracked contracts,
but while this may work for individual applications, it does not provide a consistent experience for
Stacks users that may interact with different metadata-aware systems with different refresh periods.
This workaround also adds unnecessary network traffic and creates extra strain on public Stacks
nodes due to aggressively polling contract-read RPC endpoints.

## Metadata update notifications

To solve this problem reliably, contract administrators need a way to notify the network when they
have made changes to the metadata so any indexers may then perform a refresh just for that contract.

The proposed mechanism for these notifications leverages the [`print` Clarity
language function](https://docs.stacks.co/write-smart-contracts/language-functions#print). When
used, its output is bundled inside an event of type `contract_event`:

```json
{
  "type": "contract_event",
  "contract_event": {
    "contract_identifier": "<emitter contract>",
    "topic": "print",
    "value": "<print output>"
  }
}
```

This event is then attached to a transaction object and broadcasted when the same transaction is
included in a block or microblock.

This SIP proposes a standard message structure (similar to a notification payload) that would be
used through `print`. Existing metadata indexers would receive this event through the [Stacks node
event-emitter interface](https://github.com/stacks-network/stacks-blockchain/blob/master/docs/event-dispatcher.md#post-new_block),
parse its contents, and refresh any contracts that were updated.

# Specification

Notification messages for each token class are specified below. Token metadata update notifications
must be made via a contract call transaction to the [deployed reference
contract](https://explorer.stacks.co/txid/0xe92af2ea5c11e2e6fde4d31fd394de888070efff23bffad04465c549543abfa2?chain=mainnet)
or from a call to `print` within any other contract, including the token contract itself.

The message structure was designed to be reusable by other SIPs who wish to establish new
notification standards in the future (i.e. by varying the `notification` and `payload` key values).

## Fungible Tokens

When a contract needs to notify the network that metadata has changed for a **Fungible Token**, it
shall call `print` with a tuple with the following structure:

```clarity
{ notification: "token-metadata-update", payload: { token-class: "ft", contract-id: <token contract id> }}
```

| Key                   | Value                                                                  |
|-----------------------|------------------------------------------------------------------------|
| `notification`        | The string `"token-metadata-update"`                                   |
| `payload.token-class` | The string `"ft"`                                                      |
| `payload.contract-id` | The contract id (principal) of the contract that declared the token    |

## Non-Fungible Tokens

When a contract needs to notify the network that metadata has changed for a **Non-Fungible Token**,
it shall call `print` with a tuple with the following structure:

```clarity
{ notification: "token-metadata-update", payload: { token-class: "nft", token-ids: (list u100, u101), contract-id: <token contract id> }}
```

| Key                   | Value                                                                  |
|-----------------------|------------------------------------------------------------------------|
| `notification`        | The string `"token-metadata-update"`                                   |
| `payload.token-class` | The string `"nft"`                                                     |
| `payload.token-ids`   | A list with the uint token ids that need to be refreshed               |
| `payload.contract-id` | The contract id (principal) of the contract that declared the tokens   |

# Backwards compatibility

Developers who need to update metadata for contracts that were deployed before this SIP is activated
could deploy a new one with a function that broadcasts this message or use the deployed contract
described in [Reference Implementations](#reference-implementations).

# Activation

TBD

# Reference implementations

A [reference contract](./token-metadata-update-notify.clar) has been deployed to mainnet as
[`SP1H6HY2ZPSFPZF6HBNADAYKQ2FJN75GHVV95YZQ.token-metadata-update-notify`](https://explorer.stacks.co/txid/0xe92af2ea5c11e2e6fde4d31fd394de888070efff23bffad04465c549543abfa2?chain=mainnet).
It demonstrates how to send notifications for each token class and it is available for developers to
use for refreshing any existing or future token contract. If the SIP evolves to require a change to
this contract pre-activation, a new one will be deployed and noted here.

```clarity
;; token-metadata-update-notify
;;
;; Use this contract to notify token metadata indexers that an NFT or FT needs its metadata
;; refreshed.

(use-trait nft-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)
(use-trait ft-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)

;; Refresh the metadata for one or more NFTs from a specific contract.
(define-public (nft-metadata-update-notify (contract <nft-trait>) (token-ids (list 100 uint)))
  (ok (print
    {
      notification: "token-metadata-update",
      payload: {
        contract-id: contract,
        token-class: "nft",
        token-ids: token-ids
      }
    })))

;; Refresh the metadata for a FT from a specific contract
(define-public (ft-metadata-update-notify (contract <ft-trait>))
  (ok (print
    {
      notification: "token-metadata-update",
      payload: {
        contract-id: contract,
        token-class: "ft"
      }
    })))
```

The [Stacks Blockchain API](https://github.com/hirosystems/stacks-blockchain-api) will also add
compatibility for this standard while this SIP is being considered to demonstrate how indexers can
listen for and react to these notifications.
