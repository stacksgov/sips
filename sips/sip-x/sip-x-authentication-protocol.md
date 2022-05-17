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

Decentralized application often require the authentication of their users. This SIP specifies a protocol between the application and an authenticator that results in the exchange of a public key controlled by the user and a private key specific for the application for the user.

# License and Copyright

This SIP is made available under the terms of the Creative Commons CC0 1.0 Universal license, available at https://creativecommons.org/publicdomain/zero/1.0/
This SIP’s copyright is held by the Stacks Open Internet Foundation.

# Introduction

Decentralized application do not want to store credentials of their users. Instead users should be able to login using some kind of cryptographic proof that they control a public key.

The private key for that public key is guarded and managed by a so-called authenticator. When a users visits the app, the app needs to communicate with the authenticator. The authenticator helps the user to choose a public key that should be shared with the application.

In addition to the public key, more information can be shared like email address or profile pictures. Some data can be shared publicly, other only with the application. In particular, a private key is derived by the authenticator that is specific to the application and to the user. This private key can be used by the application for example to access decentralized storage detailed in the response or sign messages in the name of the user of the application.

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
| iss                    | string | Decentralized identifier defined in DID specification representing the app transit public key. See Appendix C for list of well-known DID methods. |
| public_keys            | array  | Single item list with the public key of the signer                                                                                        |
| domain_name            | string | The url of the application with schema.                                                                                                   |
| manifest_uri           | string | The url of the application manifest, usually domain_name + "/manifest.json"                                                               |
| redirect_uri           | string | The url that should receive the authentication response                                                                                   |
| do_not_include_profile | bool   |                                                                                                                                           |
| supports_hub_url       | bool   |                                                                                                                                           |
| scopes                 | array  | list of strings specifying the requested access to the user's account. See Appendix A for full list of scopes                             |
| state                  | any    | value to be echoed in the auth response                                                                                                   |
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

The authenticator manages the user' private keys. The protocol requires that keys are created from a deterministic wallet using [BIP-32](https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki).

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

Users can create a public profile that is shared with the application or other users. It contains information similar to a profile of social media. The profile is a self-signed document that can be shared and verified off-chain.

Users who own a BNS username can publish their public profile under their BNS username. The url of the publicly accessible profile is provided in the zone file of the BNS username. The process of attaching a zone file to a BNS username is part of name registration via the BNS contract.

The public profile is used during authentication when the authentication request contains the scope `publish_data`. The profile then contains public meta data about the application that other users can use to find data shared with them.

### Profile Storage

It is recommended to use the [gaia protocol](https://github.com/blockstack/gaia) to publish the public profile. In this case, the gaia bucket must be used that is owned by the data private key, i.e. using derivation path `m/888'/0'/n'` (where `n` is the selected account index starting with 0).

The profile must be stored as a JSON array containing a single JSON object with properties `token` and `decodedToken`. The values are a signed JWT token and its decoded representation.

### Data Model

The public profile is represented as a [verifiable credential](https://www.w3.org/TR/vc-data-model) using the new type `PublicProfileCredential`.

The public profile credential must have the following properties:

| Property | Type   | Description                                                                                                                   |
| -------- | ------ | ----------------------------------------------------------------------------------------------------------------------------- |
| profile  | object | a json object of the public profile. Common profiles types are `Person`, `Organisation`, `Software` as defined on schema.org. |
| appsMeta | object | public meta data of used apps, see below.                                                                                     |
| api      | object | information about apis like gaia storage, to be used by applications for the user.                                            |

#### Profile

The profile describes the user. Personal data must not be published by the authenticator without consent of the user. If published, the authenticator must provide a method to remove this data as well.

Examples of personal data are name and profile picture.

The profile shall use a well-known schema. See Appendix B for recommended schemas.

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

#### APIs

User might want to share API endpoints and configurations with applications and other users. The following properties are supported:

| Property      | Type   | Description                                               |
| ------------- | ------ | --------------------------------------------------------- |
| gaiaHubConfig | object | config for the user's gaia hub, with property `urlPrefix` |
| gaiaHubUrl    | string | The write url of the hub                                  |

### Proof Format

The verifiable credential must be encoded as a signed JWT.

The JWT must be signed by the private key of the stacks address that ownes the username of the select account. This should be the Stacks private key using the derivation path `m/44'/5757'/0'/0/n`. Some users might have used the data private key to register a username, therefore, authenticators must verify whether the username is owned by the signing private key at the time of signing.

The JWT payload must have the following claims:

| Claim | Type   | Description                                        |
| ----- | ------ | -------------------------------------------------- |
| jti   | string | as defined by RFC 7519                             |
| iat   | string | as defined by RFC 7519                             |
| exp   | string | as defined by RFC 7519                             |
| sub   | string | the user                                           |
| iss   | string | the user                                           |
| vc    | object | a json object containing the verifiable credential |

### Example

```json
{
  "jti": "https://gaia.blockstack.org/hub/1KFHE7w8BhaENAswwryaoccDb6qcT6DbYY/profile.json",
  "iat": "2021-10-15T21:18:18.984Z",
  "exp": "2022-10-15T21:18:18.984Z",
  "sub": "did:key:z6MkpTHR8VNsBxYAAWHut2Geadd9jSwuBV8xRoAnwWsdvktH",
  "iss": "did:key:z6MkpTHR8VNsBxYAAWHut2Geadd9jSwuBV8xRoAnwWsdvktH",
  "vc": {
    "@context": [
      "https://www.w3.org/2018/credentials/v1",
      "https://www.stacks.org/2022/credentials/public-profile/v1"
    ],
    "type": ["VerifiableCredential", "PublicProfileCredential"],
    "credentialSubject": {
      "profile": {
        "@type": "Person",
        "@context": "http://schema.org",
        "name": "Anon",
        "description": "Stacks user",
        "image": [
          {
            "@type": "ImageObject",
            "name": "avatar",
            "contentUrl": "https://gaia.blockstack.org/hub/1CK6KHY6MHgYvmRQ4PAafKYDrg1ejbH1cE/avatar"
          }
        ]
      },
      "api": {
        "gaiaHubConfig": {
          "url_prefix": "https://gaia.blockstack.org/hub/"
        },
        "gaiaHubUrl": "https://hub.blockstack.org"
      },
      "appsMeta": {
        "https://app.sigle.io": {
          "storage": "https://gaia.blockstack.org/hub/13bzweCrgqiTr9BjzaEq8uRU7F7TisxLDc/",
          "publicKey": "0352a6b06db78dda5581a778f59fe45c5b3afe7f0e854644cdff6d9c841d3305cd"
        }
      }
    }
  }
}
```

### Verification

Public profiles owned by users with a username can be looked up via the Stacks blockchain. The retrieved verifiable credential was registered by the user. The usual verification for VCs must be applied.

## Authentication Response

The authentication response is a signed JWT that contains the requested and authorized data. The token is signed with the public key of the request signature, i.e. the app transit key.

The payload must contain the following claims:

| Claim name        | Type    | Description                                                                                                                                                                                                         |
| ----------------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| jti               | string  | As defined in RFC7519                                                                                                                                                                                               |
| iat               | string  | As defined in RFC7519                                                                                                                                                                                               |
| exp               | string  | As defined in RFC7519                                                                                                                                                                                               |
| iss               | string  | Decentralized identifier defined in DID specification representing the user's account.                                                                                                                              |
| private_key       | string  | Encrypted app private key for the provided domain. The key is encrypted with the public key of the app transit key.                                                                                                 |
| public_keys       | array   | Single item array containing the public key of the selected account in hex representation.                                                                                                                          |
| profile           | object  | Object containing properties of the users, the object schema should be well-known type of Appendix B. This can be the public profile of the selected account.                                                       |
| apps_meta         | object  | Information about user data of different apps. Property names are the domain name of the app. Each property value is an object of containing properties for `storage` and `publicKey`. See "Application Meta Data". |
| username          | string  | BNS username, owned by the first public key of `public_keys` claim. Can be the empty string                                                                                                                         |
| stx_address       | object  | Object containing the user's stx address for mainnet and testnet in the form: `{mainnet: "S...", testnet: "S..."}                                                                                                   |
| profile_url       | string  | Resolvable url of the public profile of the selected account.                                                                                                                                                       |
| core_token        | string? | Usually not used. Encrypted token to access a stacks node. The public key of the app transit key must be used for encryption.                                                                                       |
| email             | string? | User's email address. Can be null.                                                                                                                                                                                  |
| hub_url           | string  | User's storage hub url for the current app accessible with the app private key.                                                                                                                                     |
| association_token | string  | Signed JWT to access gaia storage of a private gaia hub.                                                                                                                                                            |
| state             | any     | value echoed from the auth request                                                                                                                                                                                  |
| version           | string  | Version of this schema, must be "2.0.0"                                                                                                                                                                             |

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

## Comparison of used JSON objects

Three JSON object are specified in this document: Authentication Request, Authentication Response, Public Profile.

| Property | Authentication Request | Authentication Response | Public Profile                                                                                                     |
| -------- | ---------------------- | ----------------------- | ------------------------------------------------------------------------------------------------------------------ |
| Format   | JWT                    | JWT                     | JSON document with property `token` with a JWT as value and property `decodedToken` with the decoded JWT as value. |
| Issuer   | `iss`: app transit key | `iss`: wallet key       | `iss`: wallet key                                                                                                  |

The Authentication Request and Authentication Response are used for communication between authentication and application only and are called auth messages.

The Public Profile is a self-signed [Verifiable Credential](https://www.w3.org/TR/vc-data-model/).

# Out of Scope

## More Message Types

This SIP does not specify other communication between application and authenticator like transaction signing or message encryption.

## Transport Protocols

This SIP does not specify the transport portocol of the messages, how the messages are exchanged. Furthermore, the SIP does not specify the way how application and authenticator find an agreement on the transport protocol.

## User Collections

Collections are data items with well-defined schema, for example a collection of contacts (address book). Application can request access to these collection, the scope is defined as `collection._collection type_`. The Response will contain details about how to lookup collections. The collection type for scope `collection.contact` is defined in [blockstack-collections](https://github.com/blockstack/blockstack-collections).

Specification of user collections is out of scope of this SIP.

# Backwards Compatibility

The specification contains parts that are deprecated like the property `apps` in the public profile. These parts are for information only and are not normative. Versions of the authentication requests and responses older than 1.3.1 are considered deprecated and not covered by this SIP.

## Upgrade from 1.3.1 to 2.0.0

The following changes from version 1.3.1 to 2.0.0 require updates of the existing wallets

- The public profile is a verifiable credential and must be signed by the owner of the username of the selected account.
- The authentication response must be signed by the same key as the public profile.
- The issuer of a JWT should be given as DID using the DID method `did:stacks:v2`.
- The following properties of the authentication response have been renamed:
  - hubUrl -> `hub_url`
  - associationToken -> `association_token`
  - profile.stxAddress -> `stx_address`
- The following property of the authentication request and response has been added:
  - `state`

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
| did:pkh:btc | User's stacks address in base58 encoding|
| did:stacks:v2 | Public keys are derived from the transaction of username registration, update or import. Only for users with usernames. |
