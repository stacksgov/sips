
# Preamble

SIP Number: X

Title: Specification of the Wallet Protcol

Author: Friedger Müffke (mail@friedger.de)

Consideration: Technical

Type: Standard

Status: Draft

Created: 20 January 2022

License: CC0-1.0

Sign-off:

# Abstract

Decentralized application do not handle private keys of users. Instead users have wallets that manage private keys, authentication, message signing etc. This SIP specifies a ways to exchange messages between applications and wallets and how to agree on one.

# License and Copyright

This SIP is made available under the terms of the Creative Commons CC0 1.0 Universal license, available at https://creativecommons.org/publicdomain/zero/1.0/
This SIP’s copyright is held by the Stacks Open Internet Foundation.

# Introduction

Decentralized applications, _dApps_, do not want to store credentials of their users. Instead users use a trusted wallet that manages the user's private keys savely. Therefore, applications needs a way to communicate with the user's wallet e.g. for requesting signatured of a transaction, authentication or message signing.

Different transport protocols for exchanging messages between applications and wallets have been established in the web3 ecosystem. In the following sections the transport protocols are described and a standardized way how to agree on a transport protocol is defined.

# Specification

## Transport Protocols

The communication between application and authenticator can happen in various ways. The subsections below define common transport protocols.

### Stacks Provider

The _Stacks Provider_ is a common interface exposed to dApps as a JavaScript object, often injected by a Web Extension.

It provides functions to handle

1. authentication
2. transaction signing

https://github.com/hirosystems/connect/blob/main/packages/connect/src/types/provider.ts

The function `authenticationRequest` expects the JWT of the authentication request as parameter and must return the authentication response as encoded JWT.

This transport protocol is implemented by the [Hiro Wallet web extension](https://github.com/blockstack/stacks-wallet-web/). Examples for client libraries are [Connect](https://github.com/blockstack/connect) and [Micro Stacks](https://github.com/fungible-systems/micro-stacks).

### HTTPS

Authentication requests can be sent via HTTPS to a hosted authenticator. The encoded JWT of the request must be set as query parameter `authRequest` when calling the url of the authenticator.

The authentication request must contain a redirect url. The authenticator must open this url with the authentication response as encoded JWT in the query parameter `authResponse`.

This transport protocol is implemented by the Blockstack Browser and the Stacks cli.

### App Links

On mobile devices, applications can use app links/deep links to send authentication requests and receive the response. They must use the same query parameters for the authentication requests and responses as the HTTPS protocol, i.e. `authRequest` and `authResponse`.

This transport protocol is implemented by the following authenticator apps:

- [Wise app](https://github.com/PravicaInc/wise-js) and client library[wise-js](https://github.com/PravicaInc/wise-js)
- [Circles app](https://github.com/blocoio/stacks-circles-app) for Android.

### Android Accounts

Android provides an open account management system. An authenticator can make use of it and provide an account service that application can use to authenticate and to access content providers of the user.

The communication happens via Android Intents. The used data uris must use the query parameters `authRequest` and `authResponse`.

Proof of concept implementation in [OI Calendar](https://github.com/openintents/calendar-sync/blob/master/app/src/main/java/org/openintents/calendar/common/accounts/GenericAccountService.kt).


## Transport Protocol Selection
