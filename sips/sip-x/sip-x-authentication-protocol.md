# Preamble

SIP Number: X

Title: Specification of Authentication Protcol

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

The private key for that public key is guarded by a so-called authenticator. When a users visits the app, the app needs to communicate with the authenticator. In the authenticator, the user can control which public key should be shared with the application. 

In addition, to the public key more information can be shared like email address or profile pictures. In particular, a private key is derived by the authenticator specific for the application and for the user. This private key can be used by the application to access for example decentralized storage or sign messages in the name of the user of the application.

# Specification

## Authentication Flow

### StacksAuthenticationProvider

### Transport Protocol

## Authentication Result Object

### Public key 

### App key derivation

### Profile

# Out of Scope

# Backwards Compatibility

# Related Work

## Unstoppabledomains auth

## DID auth

# Activation

This SIP is activated if ..

# Appendix A

Transport protocols