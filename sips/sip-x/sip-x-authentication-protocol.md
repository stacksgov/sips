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

The private key for that public key is guarded and managed by a so-called authenticator. When a users visits the app, the app needs to communicate with the authenticator. The authenticator helps the user to choose a public key that should be shared with the application.

In addition to the public key, more information can be shared like email address or profile pictures. Some data can be shared publicly, other only with the application. In particular, a private key is derived by the authenticator that is specific to the application and to the user. This private key can be used by the application to access for example decentralized storage or sign messages in the name of the user of the application.

# Specification

The basic flow of the authentication between the application and the authenticator (aka wallet or agent of the user) is as follows:

1. Application creates app transit private key, signs an auth request with that key and sends the request to the Authenticator.
2. In the Authenticator, User authorizes sharing of public key, Authenticator derives app private key from request and updates the user's public profile if required.
3. Authenticator creates response with authorized data and sends response to the Application.
4. Application verifies signature against the app transit private key.

https://cogarius.medium.com/blockstack-world-tour-brussels-social-dapp-workshop-fb0ef887b55f

Requests and responses are signed json web tokens (JWT) following standard [RFC 7519](https://tools.ietf.org/html/rfc7519).

The header of any JWT must be

```
{
  "typ": "JWT",
  "alg": "ES256K"
}
```

The payloads for the authentication request and the response are specified in the following sections.

## Authentication Request

The authentication request is a JWT created by the application. It is signed by a private key that must be freshly generated. The key is called app transit key.

### Signed JWT

The payload must contain the following claims:

| Claim name             | Type   | Description                                                                                                                               |
| ---------------------- | ------ | ----------------------------------------------------------------------------------------------------------------------------------------- |
| jti                    | string | As defined in RFC7519                                                                                                                     |
| iat                    | string | As defined in RFC7519                                                                                                                     |
| exp                    | string | As defined in RFC7519                                                                                                                     |
| iss                    | string | Decentralized identifier defined in DID specification representing the user's account. See Appendix C for list of well-known DID methods. |
| public_keys            | array  | Single item list with the public key of the signer                                                                                        |
| domain_name            | string | The url of the application with schema.                                                                                                   |
| manifest_uri           | string | The url of the application manifest, usually domain_name + "/manifest.json"                                                               |
| redirect_uri           | string | The url that should receive the authentication response                                                                                   |
| do_not_include_profile | bool   |                                                                                                                                           |
| supports_hub_url       | bool   |                                                                                                                                           |
| scopes                 | array  | list of strings specifying the requested access to the user's account. See Appendix A for full list of scopes                             |
| version                | string | must be "2.0.0"                                                                                                                           |

### Verification

Authenticators should verify that the request has the following properties:

- expiration date (`exp`) is not in the past
- issuance date (`iat`) is in the past
- public keys length is 1
- public key (`public_keys[0]`) is same as the signer's key
- public key's stacks address is the same as the issuer
- manifest url is same origin as the app domain
- redirect url is same origin as the app domain

## User authorization

The authenticator manages the user' private keys. The protocol requires that keys are created from a deterministic wallet using [BIP-39](https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki).

The authenticator can offer the user a list of accounts. Each account corresponds to a change of the key derivation path by 1. This SIP does not specify how the wallet determines which accounts should be presented. Only requirement is that one account is selected. The selected index shall be called account index `n`.

Once the account index has been fixed, authenticator has to do the following operations:

- Update public profile (depending on requested scopes)
- Create authentication response

## Application Private Key

If the authentication request contains the scope `storage_write`, then the authenticator must create a private key that is specific for the requesting application. It must use the following algorithm:

1. Wallet salt: create the sha256 hash of the hex representation of the public key of derivation path (`m/888'/0'`)
1. Create sha256 hash of concatinated string of the `domain_name` from the request and the hex representation of the wallet salt.
1. Hash code: Create a hash code (as defined in Java and Javascript) from the hex representation of the hash, then apply bitwise `and` to the hash code and 0x7fffffff.
1. Use derivation path `m/888'/0'/n'/0'/_hash code_'` for the private key.

## Public Profile

Users who own a BNS username can publish a public profile with information about the account that owns the BNS username. The url of the publicly accessible profile is provided in the zone file of the BNS username. The process of attaching a zone file to a BNS username is part of name registration via the BNS contract.

The public profile is used during authentication when the authentication request contains the scope `publish_data`. The profile then contains public meta data about the application that other users can use to find data shared with them.

### Profile Storage

It is recommended to use the [gaia protocol](https://github.com/blockstack/gaia) to publish the public profile. In this case, the gaia bucket must be used that is owned by the data private key, i.e. using derivation path `m/888'/0'/n'` (where `n` is the selected account index starting with 0).

The profile must be stored as a JSON array containing a single JSON object with properties `token` and `decodedToken`. The values are a signed JWT token and its decoded representation.

### Signed JWT

The JWT must be signed by the private key of the stacks address that ownes the username of the select account. This should be the Stacks private key using the derivation path `m/44'/5757'/0'/0/n`. Some users might have used the data private key to register a username, therefore, authenticators must verify whether the username is owned by the signing private key at the time of signing.

The JWT payload must have the following claims:

| Claim   | Type   | Description                                                                                                    |
| ------- | ------ | -------------------------------------------------------------------------------------------------------------- |
| jti     | string | as defined by RFC 7519                                                                                         |
| iat     | string | as defined by RFC 7519                                                                                         |
| exp     | string | as defined by RFC 7519                                                                                         |
| subject | object | a json object with property `publicKey` containing the hex representation of the public key of the signing key |
| issuer  | object | same as subject                                                                                                |
| claim   | object | a json object containing data of the username owner mixed with meta data of applications used by the owner     |

#### Owner Data

Personal data must not be published by the authenticator without consent of the user. If published, the authenticator must provide a method to remove this data as well.

Examples of personal data are name and profile picture.

The owner data shall use a well-known schema. See Appendix B for recommended schemas.

#### Application Meta Data

If the application requested to share data publicly through the scope `publish_data`, then the authenticator has to publish the public profile with information about the application's gaia bucket location. This is the gaia bucket owned by the application private key. The location and the public key are published as entry of the profile property `appsMeta`. The key of the entry is the `domain name` of the authorization request and the value is a JSON object of the following schema:

```
{
    "$schema": "http://json-schema.org/draft-2020-12/schema",
    "type": "object",
    "title": "Public profile application meta data",
    "description": "Meta data for application specific storage",
    "default": {},
    "examples": [
        {
            "storage": "https://gaia.blockstack.org/hub/19xhuMssxAnLoa1yMTD7YNmhhaev5NBzv1/",
            "publicKey": "03f2dea6295f8e4e7b05e092e4a97ad1a113143f820b65d9e4990a10fd8fcb0b1d"
        }
    ],
    "required": [
        "storage",
        "publicKey"
    ],
    "properties": {
        "storage": {
            "$id": "#/properties/storage",
            "type": "string",
            "title": "Storage location",
            "description": "Url of the publicly readable gaia bucket owned by the application private key."
        },
        "publicKey": {
            "$id": "#/properties/publicKey",
            "type": "string",
            "title": "Public Key",
            "description": "Hex representation of the public key of the application private key."
        }
    },
    "additionalProperties": true
}
```

### Verification

Public profiles owned by users with a username can be looked up via the Stacks blockchain. The retrieved profile token was registered by the user. It must be verified that the token has the following properties:

- issuer's public key (`issuer.publicKey`) is the same as the signer's key.
- subject's public key (`subject.publicKey`) exists.
- profile (`claim`) exists.

## Authentication Response

The authentication response is a signed JWT that contains the requested and authorized data. The token is signed with the public key of the request signature, i.e. the app transit key.

The payload must contain the following claims:

| Claim name         | Type    | Description                                                                                                                                                                                                         |
| ------------------ | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| jti                | string  | As defined in RFC7519                                                                                                                                                                                               |
| iat                | string  | As defined in RFC7519                                                                                                                                                                                               |
| exp                | string  | As defined in RFC7519                                                                                                                                                                                               |
| iss                | string  | Decentralized identifier defined in DID specification representing the user's account.                                                                                                                              |
| private_key        | string  | Encrypted app private key for the provided domain. The key is encrypted with the public key of the app transit key.                                                                                                 |
| public_keys        | array   | Single item array containing the public key of the selected account in hex representation.                                                                                                                          |
| profile            | object  | Object containing properties of the users, the object schema should be well-known type of Appendix B. This can be the public profile of the selected account.                                                       |
| profile.stxAddress | object  | Object containing the user's stx address for mainnet and testnet in the form: `{mainnet: "S...", testnet: "S..."}`                                                                                                  |
| profile.apps       | object  | Deprecated; use appsMeta. Storage endpoints for user data of different apps index by app urls                                                                                                                       |
| profile.appsMeta   | object  | Information about user data of different apps. Property names are the domain name of the app. Each property value is an object of containing properties for `storage` and `publicKey`. See "Application Meta Data". |
| username           | string  | BNS username, owned by the first public key of `public_keys` claim. Can be the empty string                                                                                                                         |
| profile_url        | string  | Resolvable url of the public profile of the selected account.                                                                                                                                                       |
| core_token         | string? | Usually not used. Encrypted token to access a stacks node. The public key of the app transit key must be used for encryption.                                                                                       |
| email              | string? | User's email address. Can be null.                                                                                                                                                                                  |
| hub_url            | string  | User's storage hub url for the current app.                                                                                                                                                                         |
| blockstackAPIUrl   | string? | Deprecated. Url to the user's preferred authenticator                                                                                                                                                               |
| associationToken   | string  | Signed JWT to access gaia storage of a private gaia hub.                                                                                                                                                            |
| version            | string  | Version of this schema, must be "2.0.0"                                                                                                                                                                             |

### Verification

When the application received the authentication response it must verify that the token has the following properties:

- expiration date (`exp`) is not in the past
- issuance date (`iat`) is in the past
- public keys length is 1
- public key (`public_keys[0]`) is same as the signer's key
- public key's stacks address is the same as the issuer
- username if provided is owned by issuer

#### Usernames and DIDs

If the authentication response contains a username the username must be owned by the issuer.
The issuer of a JWT tokens is represented by a DID in claim `iss`. The DID has to be resolved to a public key and then the blockchain has to confirm that the username indeed is owned by the public key encoded as Stacks address.

## Transport Protocols

The communication between application and authenticator can happen in various ways. The subsections below define common transport protocols.

### Stacks Provider

Stacks Provider is a common interface used for web applications to communicate with the authenticator via a browser extension.

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

## Client Libraries

https://github.com/PravicaInc/wise-js

# Out of Scope

This SIP does not specify other communication between application and authenticator like transaction signing or message encryption.

## User collections

Collections are data items with well-defined schema, for example a collection of contacts (address book). Application can request access to these collection, the scope is defined as `collection._collection type_`. The Response will contain details about how to lookup collections. The collection type for scope `collection.contact` is defined in [blockstack-collections](https://github.com/blockstack/blockstack-collections).

Specification of user collections is out of scope of this SIP.

# Backwards Compatibility

The specification contains parts that are deprecated like the property `apps` in the public profile. These parts are for information only and are not normative. Versions of the authentication requests and responses older than 1.3.1 are considered deprecated and not covered by this SIP.

# Related Work

## Unstoppable Login

Unstoppable are domain names registered on Polygon blockchain. The login is similar to the HTTPS transport protocol. When a user visits an app and logs in with their domain, the app reads the domain and directs the user to the authorization server saved to that domain name.

It differs in the way how the user authorizes access to private information. The user authenticates and grants access to the information requested by signing a transaction with the key that owns their domain. The app receives an access token and an id token from the authorization server with the user’s contact information (e.g., email address).

See the [blog post by unstoppabledomains](https://unstoppabledomains.com/blog/login-with-unstoppable)

## DID auth

The generalized form the authentication flow is a cryptographic challenge where users and applications use [DIDs](https://www.w3.org/TR/did-core/) and where the details about the cryptography have to be looked up via a DID resolver. See for example [this article](https://medium.com/@sethisaab/what-is-did-auth-and-how-does-it-works-1e4884383a53).

# Activation

This SIP is activated if 3 authenticators support version 2.0.0 of the authentication requests and responses.

# Appendix A

Scopes in authentication requests

| Scope identifier | Description                                                 |
| ---------------- | ----------------------------------------------------------- |
| store_write      | Response must contain the app private key                   |
| email            | Response may contain selected email by the user             |
| publish_data     | Public profile must contain app information for data lookup |

# Appendix B

Well-known JSON schemas used for owner data in `claim` of public profile

| Canonical Url | Comment |
| https://schema.org/Person | Used for owners that are persons. Data shall contain values for `name` and `description`. Profile pictures must be named `avatar` in property `image.name` if provided as `ImageObject`.|

# Appendix C

Well-known DID methods

| DID method | Comment |
| did:btc | public keys are encoded in the DID directly using b58 encoding.|
| did:stacks:v2 | public keys are derived from the transaction of username registration, update or import. |
