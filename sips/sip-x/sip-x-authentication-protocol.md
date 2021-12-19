# Preamble

SIP Number: X

Title: Specification of the Authentication Protcol

Author: Friedger Müffke (mail@friedger.de)

Consideration: Technical

Type: Standard

Status: Draft

Created: 19 November 2021

License: CC0-1.0

Sign-off:

# Abstract

Decentralized application often require the authentication of their users. This SIP specifies a protocol between the application and an authenticator that results in a public key controlled by the user and a private key specific for the application for the user.

# License and Copyright

This SIP is made available under the terms of the Creative Commons CC0 1.0 Universal license, available at https://creativecommons.org/publicdomain/zero/1.0/
This SIP’s copyright is held by the Stacks Open Internet Foundation.

# Introduction

Decentralized application do not want to store credentials of their users. Instead users should be able to login using some kind of cryptographic proof that they control a public key.

The private key for that public key is guarded and managed by a so-called authenticator. When a users visits the app, the app needs to communicate with the authenticator. In the authenticator, the user can control which public key should be shared with the application.

In addition to the public key, more information can be shared like email address or profile pictures. In particular, a private key is derived by the authenticator specific for the application and for the user. This private key can be used by the application to access for example decentralized storage or sign messages in the name of the user of the application.

# Specification

## Authentication Flow

The basic flow of the authentication between the application and the authenticator (aka wallet or agent of the user) is as follows:

1. Application creates app transit private key, signs an auth request with that key and sends the request to the Authenticator.
2. In the Authenticator, User authorizes sharing of public key, Authenticator derives app private key from request.
3. Authenticator creates response with authorized data and sends response to the Application.
4. Application verifies signature against the app transit private key.

https://cogarius.medium.com/blockstack-world-tour-brussels-social-dapp-workshop-fb0ef887b55f

## Authentication Response

The authentication response is a signed JWT that contains the requests and authorized data. The token is signed with the app transit key.

### Public key and BNS Username

If the Stacks address representing the public key owns a BNS username, it is returned as part of the response. Other users can use the username to lookup metadata of other applications via the zonefile and the profile linked in the zonefile. The profile is signed with the private key belonging to the public key.

### App key derivation

### Profile

### App Meta Data

### Response Token Schema

The response is a signed json web token following standard [RFC 7519](https://tools.ietf.org/html/rfc7519).

A typical header is

```
{
  "typ": "JWT",
  "alg": "ES256K"
}
```

The payload must contain the following claims:

| Claim name         | Type    | Description                                                                                                                                                                                                 |
| ------------------ | ------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| jti                | string  | As defined in RFC7519                                                                                                                                                                                       |
| iat                | string  | As defined in RFC7519                                                                                                                                                                                       |
| exp                | string  | As defined in RFC7519                                                                                                                                                                                       |
| iss                | string  | Decentralized identifier defined in DID specification                                                                                                                                                       |
| private_key        | string  | App private key for the provided domain                                                                                                                                                                     |
| public_keys        | array   | Array of public keys owned by the user                                                                                                                                                                      |
| profile            | object  | Object containing properties of the users, the object schema should be well-known type, like `Person` or `Organisation` defined by schema.org                                                               |
| profile.stxAddress | object  | Object containing the user's stx address for mainnet and testnet in the form: `{mainnet: "S...", testnet: "S..."}`                                                                                          |
| profile.apps       | object  | Deprecated; use appsMeta. Storage endpoints for user data of different apps index by app urls                                                                                                               |
| profile.appsMeta   | object  | Information about user data of different apps. Property names are the domain name of the app. Each property value is an object of containing properties for `storage` and `publicKey`. See "App Meta Data". |
| username           | string  | BNS username, owned by the first public key of `public_keys` claim. Can be empty string                                                                                                                     |
| profile_url        | string  | Resolvable url of the user's profile.                                                                                                                                                                       |
| core_token         | string? |                                                                                                                                                                                                             |
| email              | string? | User's email address. Can be null.                                                                                                                                                                          |
| hub_url            | string  | User's storage hub url for the current app.                                                                                                                                                                 |
| blockstackAPIUrl   | string? | Deprecated. Url to the user's preferred authenticator                                                                                                                                                       |
| associationToken   | string  | Signed JWT to access gaia storage bucket of user's app data.                                                                                                                                                |
| version            | string  | Version of this schema, must be "1.3.1"                                                                                                                                                                     |

## Transport Protocol

The communication between application and authenticator can happen in various ways. It is defined by the transport protocol.

### Stacks Provider

Stacks Provider is a common interface used for web applications to communicate with the authenticator.

It provides functions to handle

1. authentication
2. transaction signing

https://github.com/hirosystems/connect/blob/main/packages/connect/src/types/provider.ts

### Deep Links

Wise app uses deep links to handle request on mobile devices

### Android Accounts

Android provides an open account management system.

Example implementation: https://github.com/openintents/calendar-sync/blob/master/app/src/main/java/org/openintents/calendar/common/accounts/GenericAccountService.kt

# Out of Scope

This SIP does not specify other flows between applications and authenticators like transaction signing or message encryption.

# Backwards Compatibility

# Related Work

## Unstoppabledomains auth

https://unstoppabledomains.com/blog/login-with-unstoppable

## DID auth

https://medium.com/@sethisaab/what-is-did-auth-and-how-does-it-works-1e4884383a53

# Implementations

## Libraries

https://github.com/blockstack/connect

https://github.com/fungible-systems/micro-stacks

https://github.com/PravicaInc/wise-js

## Authenticators

### Hiro Wallet

Hiro Wallet is a browser extension that handles authentication and transaction signing.

It uses a 24 mnemonic called SecretKey to derive private keys for different user accounts.

Each account owns one private key to handle stx tokens (wallet key) and one private key to access storage (data key).

The wallet key can own a BNS username.

https://github.com/blockstack/stacks-wallet-web

### Wise

https://github.com/PravicaInc/Wise

https://wiseapp.id

### Circles

https://github.com/blocoio/stacks-circles-app

# Activation

This SIP is activated if ..

# Appendix A

Transport protocols

```

```
