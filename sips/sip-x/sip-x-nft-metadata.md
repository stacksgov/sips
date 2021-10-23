# Preamble

SIP Number: X

Title: Schema Definition for Metadata for Non-Fungible Tokens

Author: Friedger Müffke (mail@friedger.de)

Consideration: Technical

Type: Standard

Status: Draft

Created: 20 October 2021

License: CC0-1.0

Sign-off:

# Abstract

Non-fungible tokens or NFTs for short are digital assets registered on blockchain with unique identifiers and properties that distinguish them from each other. SIP-009 defines the trait for how ownership of an NFT is managed. This SIP aims to provide a flexible standard to attach metadata to NFTs, like descriptions or urls to digital files.

# License and Copyright

This SIP is made available under the terms of the Creative Commons CC0 1.0 Universal license, available at https://creativecommons.org/publicdomain/zero/1.0/
This SIP’s copyright is held by the Stacks Open Internet Foundation.

# Introduction

Tokens are digital assets registered on blockchain through a smart contract. A non-fungible token (NFT) is a token that is globally unique and can be identified through its unique identifier. In blockchains with smart contracts, including the Stacks blockchain, developers and users can use smart contracts to register and interact with non-fungible tokens.

Some use cases of NFTs are name registration, digital art, certification, media and enternainment, real-estate. They all require that users associate certain content with an NFT. In general, it is helpful for the users to have a name, sound, image that represents this content.

# Specification

Every SIP-X compliant smart contract in Stacks blockchain must be SIP-009 compliant and must meet the following requirements for the return value of function `get-token-uri`:

## Return Value of `get-token-uri`

The return value must be a `some` value if and only if the provided parameter `id` is the key of an NFT that was minted and not burnt, otherwise the value must be `none`.

For minted and not burnt NFTs, the inner value of the return value must be a string representing a resolvable URI. For string containing `{id}`, the `{id}` part must be replaced by the id in decimal format given in the function call.

The resolved data must be a JSON blob.

## JSON scheme of Metadata

The JSON blob resolved through the token uri must follow the following JSON schema. If the string `{id}` exists in any JSON value, it MUST be replaced with the actual token id in decimal format, by all client software that follows this standard.

```
{
    "$schema": "http://json-schema.org/draft-07/schema#",
    "title": "Token Metadata",
    "type": "object",
    "required": ["version", "name", "image"],
    "properties": {
        "version": {
            "type": number,
            "description": "Version of the JSON schema for NFT metadata. For this SIP, the version number must be `1`."
        },
        "name": {
            "type": "string",
            "description": "Identifies the asset to which this token represents"
        },
        "description": {
            "type": "string",
            "description": "Describes the asset to which this token represents"
        },
        "image": {
            "type": "string",
            "description": "A URI pointing to a resource with mime type image/* representing the asset to which this token represents. Consider making any images at a width between 320 and 1080 pixels and aspect ratio between 1.91:1 and 4:5 inclusive."
        },
        "attributes": {
            "type": "array",
            "description": "Arbitrary NFT attributes. Values may be strings, numbers, object or arrays."
            "items: {
                "type": "object",
                "properties": {
                    "display_type": "string",
                    "trait_type": "string",
                    "value": {"oneOf": [{"type": "object"}, {"type": "string"},{"type: "array"}},
                }
            }
        },
        "properties": {
            "type": "object",
            "description": "Arbitrary properties. Values may be strings, numbers, object or arrays."
        },
        "localization": {
            "type": "object",
            "required": ["uri", "default", "locales"],
            "properties": {
                "uri": {
                    "type": "string",
                    "description": "The URI pattern to fetch localized data from. This URI should contain the substring `{locale}` which will be replaced with the appropriate locale value before sending the request."
                },
                "default": {
                    "type": "string",
                    "description": "The locale of the default data within the base JSON"
                },
                "locales": {
                    "type": "array",
                    "description": "The list of locales for which data is available. These locales should conform to those defined in the Unicode Common Locale Data Repository (http://cldr.unicode.org/)."
                }
            }
        }
    }
}
```

The lengths of string values is not restricted. Nowadays, clients should be smart enough to deal with values of different lengths.

### Examples

# Using NFT metadata in applications

Before presenting metadata to users, application developers should verify whether the metadata is compliant with the application's guidelines.

We remind implementation authors that the empty string for the token uri is a valid response. We also remind everyone that any smart contract can use the same metadata as other NFT contracts. It is out of the scope of this standard to define how a client may determine which smart contracts are is the original, well-known, canonical one.

# Out of Scope

Accessiblity of content is not covered by the standard.

Properties other than resolvability of the token uri are out of scope. This implies that metadata might change over time (stability).

# Related Work

NFTs are an established asset class on blockchains. Read for example [here](https://www.ledger.com/academy/what-are-nft).

## BNS

The Blockchain Naming System uses native non-fungible tokens. It does define metadata for a name through attachements. The schema for names owned by a person follows the definition of (schema.org/Person)[https://schema.org/Person]. This could be an alternative to token URIs.

## EIP 721 and 1155

Metadata for NFTs on Ethereum are defined in [EIP 721](https://eips.ethereum.org/EIPS/eip-721) and [EIP 1155](https://eips.ethereum.org/EIPS/eip-1155). The JSON schema for SIP-X has adopted the EIP 1155 schema with the following differences:

- substitution of `{id}` strings must use the decimal format not the hexdecimal, zero-padded format.

# Backwards Compatibility

## Meta data functions

Some contracts have dedicated functions to provide metadata.

### Boom

The [NFT contract for Boom](https://explorer.stacks.co/txid/0x423d113e14791f5d60f5efbee19bbb05cf5e68d84bcec4e611f2c783b08d05aa?chain=mainnet) implements a variation of this trait using similar naming, but returning other types than response types.

The function signatures for metadata are:

- `(get-boom-meta () {uri: (string-ascii 35), name: (string-ascii 16), mime-type: (string-ascii 9)})` and
- `(get-meta? uint {series-id: uint, number: uint, name: (string-utf8 80), uri: (string-ascii 2048), mime-type: (string-ascii 129), hash: (buff 64)})`

### Badges

The [badges contract](https://explorer.stacks.co/txid/0xb874ddbb4a602c22bb5647c7a2f8bfcafbbca7c0c663a175f2270ef3665f33de?chain=mainnet) defines metadata for nfts.

The function signatures for metadata are:

- `(get-badge-meta () {uri: (string-ascii 78111)})` and
- `(get-meta? (uint) (optional {user: principal}))`

### Beeple

# Activation

This SIP is activated if 5 contracts are deployed that use the same trait that follows this specification. This must happen before Bitcoin tip #750,000.
