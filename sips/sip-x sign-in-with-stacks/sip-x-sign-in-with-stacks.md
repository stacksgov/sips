# Preamble

SIP Number: X

Title: Sign In With Stacks

Author: Friedger Müffke (mail@friedger.de), Leo Pradel

Consideration: Technical

Type: Standard

Status: Draft

Created: 18 May 2022

License: CC0-1.0

Sign-off:

Layer: Applications

Discussions-To: https://github.com/stacksgov/sips

# Abstract

Web applications often provide their services only to authenticated users. In
Web2, this was done through username and password or federated logins. In Web3,
users can prove their digital identity by cryptographically signing that the
user ownes the private key associated with that digital identity.

SIP-018 defines the structure of signatures in general. This SIP defines the
message format that web applications and similar off-chain services should use for their users to sign.

# License and Copyright

This SIP is made available under the terms of the Creative Commons CC0 1.0 Universal license, available at https://creativecommons.org/publicdomain/zero/1.0/
This SIP’s copyright is held by the Stacks Open Internet Foundation.

# Introduction

# Specification

Sign-In with Stacks works as follows:

1. The wallet presents the user with a structured message as defined in SIP-018. The message is a clarity value of type `tuple` with the properties described below.
2. The signature is then presented to the server, which checks the signature’s validity and message content.
3. Additional fields, including expiration-time, not-before, request-id, chain-id, and resources may be incorporated as part of authentication for the session.
4. The server may further fetch data associated with the public key, the stacks address, or other data sources that may or may not be permissioned.

## Properties

| name            | type                        | description                                                                                                                                                                        |
| --------------- | --------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| domain           | (string-ascii 126)          | Must be the application's domain name (max 80) followed by ` wants you to sign in with your Stacks account`                                                                        |
| address         | string-ascii                   | The address of the signer in CAPI-10 format, including the chain id.                                                                                                                                                          |
| statement       | (string-ascii 80)           | (optional) Describes the terms and conditions the user agrees to by using the application.                                                                                         |
| uri             | (string-ascii 80)           | An RFC 3986 URI referring to the resource that is the subject of the signing (as in the subject of a claim).                                                                       |
| version         | string                        | is the current version of the message, which MUST be X for this specification.                                                                                                     |
| nonce           | (string-ascii 64)           | randomized token used to prevent replay attacks, at least 8 alphanumeric characters.                                                                                               |
| issued-at       | (string-ascii 27)           | The ISO 8601 datetime string of the current time.                                                                                                                                  |
| expiration-time | (string-ascii 27)           | (optional) The ISO 8601 datetime string that, if present, indicates when the signed authentication message is no longer valid.                                                     |
| not-before      | (string-ascii 27)           | (optional) The ISO 8601 datetime string that, if present, indicates when the signed authentication message will become valid.                                                      |
| request-id      | (string-ascii 64)           | an system-specific identifier that may be used to uniquely refer to the sign-in request.                                                                                           |
| resources       | (list 10 (string-ascii 80)) | (optional) A list of information or references to information the user wishes to have resolved as part of authentication by the relying party. They are expressed as RFC 3986 URIs |

## Presentation and Localization

TODO

# Related work

## Stacks Auth
The Stacks authentication protocol uses a signed JWT with data similar to this SIP to authenticate the user to the app. However, this signed token contains data that should not be shared outside the app without the users' consent.

## Ethereum EIP4361

[Ethereum EIP4361 standard](https://eips.ethereum.org/EIPS/eip-4361)

## DID Auth

[DID Auth Working
group](https://identity.foundation/working-groups/authentication.html)

[OpenID Connect for Verifiable Presentations](https://openid.net/specs/openid-connect-4-verifiable-presentations-1_0.html)

# Backwards Compatibility

Not applicable

# Activation

TODO
