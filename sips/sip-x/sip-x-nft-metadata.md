# Preamble

SIP Number: X

Title: Schema Definition for Metadata for Non-Fungible Tokens

Author: Friedger Müffke (mail@friedger.de)

Consideration: Technical

Type: Standard

Status: Draft

Created: 7 November 2021

License: CC0-1.0

Sign-off:

# Abstract

Non-fungible tokens or NFTs for short are digital assets registered on blockchain with unique identifiers and properties that distinguish them from each other. SIP-009 defines the trait for how ownership of an NFT is managed. This SIP aims to provide a flexible standard to attach metadata to NFTs, like descriptions or urls to digital files.

# License and Copyright

This SIP is made available under the terms of the Creative Commons CC0 1.0 Universal license, available at https://creativecommons.org/publicdomain/zero/1.0/
This SIP’s copyright is held by the Stacks Open Internet Foundation.

# Introduction

Tokens are digital assets registered on blockchain through a smart contract. A non-fungible token (NFT) is a token that is globally unique and can be identified through its unique identifier. In blockchains with smart contracts, including the Stacks blockchain, developers and users can use smart contracts to register and interact with non-fungible tokens.

Some use cases of NFTs are name registration, digital art, certification, media and entertainment, real-estate. They all require that users associate certain content with an NFT. In general, it is helpful for the users to have a name, sound, image that represents this content.

# Specification

Every SIP-X compliant smart contract in Stacks blockchain must implement one or more functions that return a resolvable/retrievable uri referencing metadata. The metadata provide information e.g. for displaying a digital asset to users. This type of function is named "metadata uri functions".

Appendix A contains a list of trait functions that must meet the following requirements for the return value. The appendix can be extended without changing the ratification status of this SIP.

## Return Value of Metadata URI Functions

The return value must be a `some` value if and only if the metadata reference an existing token, otherwise the value must be `none`. Appendix A specifies the exact meaning of "existing" for each function.

For existing tokens, the inner value of the return value must be a string representing a resolvable URI.

The schema of the resolvable URI is not specified and should be a well-known schema like `https`, `ar`, `ipfs`, `sia`. A `data` URI is also valid, however, the length is limited by this SIP.

If a metadata uri function expects a parameter of type `uint` that identifies a token and the resulting strings contains `{id}`, then the `{id}` part must be replaced by the identifier in decimal format given in the function call.

The resolved data of the URI must be a JSON blob.

## JSON scheme of Metadata

The JSON blob resolved through the uri must follow the following JSON schema.

If metadata were retrieved by a function call containing a token identifier and the string `{id}` exists in any JSON value, it MUST be replaced with the actual token id in decimal format, by all client software that follows this standard.

```
{
    "$schema": "http://json-schema.org/draft-07/schema#",
    "title": "Token Metadata",
    "type": "object",
    "required": ["version", "name"],
    "properties": {
        "version": {
            "type": number,
            "description": "Version of the JSON schema for metadata. For this SIP, the version number must be `1`."
        },
        "name": {
            "type": "string",
            "description": "Identifies the asset which this token represents"
        },
        "description": {
            "type": "string",
            "description": "Describes the asset which this token represents"
        },
        "image": {
            "type": "string",
            "description": "A URI pointing to a resource with mime type image/* representing the asset to which this token represents. Consider making any images at a width between 320 and 1080 pixels and aspect ratio between 1.91:1 and 4:5 inclusive. If the token represents a media file of different mime-type or of higher quality defined in property 'raw_media_file_uri', then this image should be used as preview image like a cover for music, or an low-res image."
        },
        "attributes": {
            "type": "array",
            "description": "Arbitrary attributes. Values may be strings, numbers, object or arrays."
            "items: {
                "type": "object",
                "required": ["value"],
                "properties": {
                    "display_type": "string",
                    "trait_type": "string",
                    "value": {"oneOf": [{"type": "object"}, {"type": "string"}, {"type": "number"}, {"type": "integer"}, {"type": "boolean"} {"type: "array"}},
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
                    "description": "The URI pattern to fetch localized data from. This URI should contain the substring `{locale}` which will be replaced with the appropriate locale value before sending the request. See section about localization for more rules"
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
        },
        "image_data": {
            "type": "string",
            "description": "Raw SVG image data. Deprecated. Use `properties.image_data`."
        },
        "external_url": {
            "type": "string",
            "description": "Url to view the item on a 3rd party web site. Deprecated. Use `properties.external_url`."
        },
        "animation_url": {
            "type": "string",
            "description": "URL to a multi-media attachment for the item. Deprecated. Use `properties.animation_url`."
        },
    }
}
```

The lengths of string values is not restricted. Nowadays, clients should be smart enough to deal with values of different lengths.

### Example

token101.json

```
{
  "version": 1,
  "name": "Foo #101",
  "image": "ipfs://somerandomecid",
  "attributes": [
     {
      "trait_type": "hair",
      "value": "red",
    },
    {
      "trait_type": "strength",
      "display_type": "number",
      "value": 99,
    },
  ],
  "properties": {
      "collection":  "Foo Collection",
      "total_supply":  "10000"
  },
  "localization": {
      "uri": "ipfs://somerandomcid/{locale}.json",
      "default": "en",
      "locales": ["en", "pt-BR", "de"]
  }
}
```

de.json

```
{
    "version": 1,
    "attributes: [
        {
          "trait_type": "Haare",
          "value": "rot",
        },
        {
          "trait_type": "Stärke",
          "display_type": "number",
          "value": 99,
        },
    ]
}
```

pt-BR.json

```
{
    "version": 1,
    "attritbutes: [
        {
          "trait_type": "cabelos",
          "value": "vermelho",
        },
        {
          "trait_type": "amido",
          "display_type": "number",
          "value": 99,
        },
    ]
}
```

### Properties

Common properties are described in appendix C. Properties of type object are usually described using the following schema:

```
{
    "$schema": "http://json-schema.org/draft-07/schema#",
    "title": "Token Metadata Property",
    "type": "object",
    "required": [],
    "properties": {
        "type": {
            "type": "string",
            "description": "type of the property"
        },
        "description": {
            "type": "string",
            "description": "description of the property"
        },
        "value": {
            "type": {"oneOf": [{"type": "object"}, {"type": "string"}, {"type": "number"}, {"type": "integer"}, {"type": "boolean"} {"type: "array"}},
            "description": "value of the property"
        }
    }
}
```

Example:

```
{
    "type": "string",
    "description": "Address of custodian key holder",
    "value": "Casa Inc., P.O. Box 20575, Charleston, S.C. 29413, United States."
}
```

### Attributes

Attributes describe addition elements of tokens that are "observable", usually represented in the image of the token.

In contrast, properties describe elements of tokens that are more abstract.

An attribute consists of a `trait_type` defining the name of the trait, `value` is the value of the trait, and `display_type` is a field indicating how you would like it to be displayed.

Appendix B describes type of attributes

## Localization

The localized data follow the same JSON schema with property `version` as required and all other properties as optional.

The localized data overwrite data provided in the default meta data JSON. The localized data can provide only partial data.

An array of localized `attributes` overwrites the whole list of default `attributes`.

A localized properties with partial data overwrites only the provided properties, the remaining default properties remain as default values.

# Using metadata in applications

Before presenting metadata to users, application developers should verify whether the metadata is compliant with the application's guidelines.

We remind implementation authors that the empty string for the token uri is a valid response. We also remind everyone that any smart contract can use the same metadata as other NFT contracts. It is out of the scope of this standard to define how a client may determine which smart contracts are is the original, well-known, canonical one.

## Graphical representation

The metadata of a token contain several properties that can be used to visually represent the token. It is recommended to use the first defined property of the following list:

1. `image`
2. `properties.image_data`
3. `image_data`

Rich representation should use ther first defined property of the following list:

1. `properties.animation_url`
2. `animation_url`

# Out of Scope

Accessiblity of content is not covered by the standard.

Properties other than resolvability of the token uri are out of scope. This implies that metadata might change over time (stability).

# Metadata functions

Some contracts have dedicated functions to provide metadata directly from the contract. This SIP does not define these functions.

## Existing Examples

Some early deployed contracts have metadata functions.

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

# Backwards Compatibility

This SIP defines meta data so that metadata for existing NFTs on other blockchains like Ethereum, Solana or WAX can be re-used for NFTs on the Stacks blockchain.

# Related Work

NFTs are an established asset class on blockchains. Read for example [here](https://www.ledger.com/academy/what-are-nft).

## BNS

The Blockchain Naming System uses native non-fungible tokens. It does define metadata for a name through attachements. The schema for names owned by a person follows the definition of (schema.org/Person)[https://schema.org/Person]. This could be an alternative to token URIs.

## EIP 721 and 1155

Metadata for NFTs on Ethereum are defined in [EIP 721](https://eips.ethereum.org/EIPS/eip-721) and [EIP 1155](https://eips.ethereum.org/EIPS/eip-1155). The JSON schema for SIP-X has adopted the EIP 1155 schema with the following differences:

- substitution of `{id}` strings must use the decimal format not the hexdecimal, zero-padded format.

- properties of type object should use property `value` for the value, not property `description` as used by some EIP-1155 NFTs.

## Metaplex

The tool suite Metaplex for NFTs on Solana defines a [JSON schema](https://docs.metaplex.com/nft-standard#uri-json-schema). The properties `category` and `files` in Appendic C were inspired by that schema.

## Hedera

Hedera follows the same schema defined in [H-10](https://github.com/hashgraph/hedera-improvement-proposal/blob/master/HIP/hip-10.md).

# Activation

This SIP is activated if 10 contracts are deployed that follows this specification. This must happen before Bitcoin tip #750,000.

# Appendix A

List of trait function define in SIPs and specifications specific to these functions

| SIP and Trait Function Name                            | Definition of "existing"                                                                        | Additional Specification for Properties                                                                                                                                                                                    | Identifier Parameter |
| ------------------------------------------------------ | ----------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------- |
| SIP-009 nft-trait.get-token-uri                        | token must be minted and not burnt                                                              | NFTs belonging to a group of tokens should use property `properties.collection` of type `string` for the collection name. <br/> Optional property `properties.id` of type `integer` describes the identifier of the token. | 1st                  |
| SIP-X get-contract-uri                                 | always                                                                                          | `properties.items` of type array can be used to provide the metadata of all tokens belonging to the collection                                                                                                             | X                    |
| SIP-010 ft-trait.get-token-uri                         | always                                                                                          | The required property `decimals` of type `integer` must be the same number as `get-decimals`.                                                                                                                              | X                    |
| SIP-013 sip013-semi-fungible-token-trait.get-token-uri | token must be minted and not burnt, no requirements on the number of fungible part of the token |                                                                                                                                                                                                                            | 1st                  |

# Appendix B

Attribute types

| Type    | Display types                                | Additional Properties | Comment                  |
| ------- | -------------------------------------------- | --------------------- | ------------------------ |
| Numeric | `number`, `boost_percentage`, `boost_number` | `max_value`           |                          |
| Date    | `date`                                       |                       | As unix timestamp in UTC |
| String  | empty                                        |                       |                          |

# Appendic C

Common Properties with predefined types.

| Name                            | Type      | Description                                                                                                                                                                                                                                                                                                                                                         |
| ------------------------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `collection`                    | `string`  | collection name the token belongs to. See also Appendix A.                                                                                                                                                                                                                                                                                                          |
| `decimals`                      | `integer` | number of decimals. See also Appendix A.                                                                                                                                                                                                                                                                                                                            |
| `id`                            | `integer` | identifier for NFTs. See also Appendix A.                                                                                                                                                                                                                                                                                                                           |
| `created`                       | `integer` | creation date of the token in unix timestamp                                                                                                                                                                                                                                                                                                                        |
| `symbol`                        | `string`  | token symbol                                                                                                                                                                                                                                                                                                                                                        |
| `total_supply`                  | `integer` | number of total supply, e.g. minted tokens                                                                                                                                                                                                                                                                                                                          |
| `ip_document_uri`               | `string`  | link to document about intellectual property (IP) rights                                                                                                                                                                                                                                                                                                            |
| `external_url`                  | `string`  | url that will view the token on an external site                                                                                                                                                                                                                                                                                                                    |
| `raw_media_file_uri`            | `string`  | uri of the media represented by the token                                                                                                                                                                                                                                                                                                                           |
| `raw_media_file_type`           | `string`  | mime-type of the media represented by the token                                                                                                                                                                                                                                                                                                                     |
| `raw_media_file_signature`      | `string`  | signature of the media file represented by the token                                                                                                                                                                                                                                                                                                                |
| `raw_media_file_signature_type` | `string`  | signature type of the media represented by the token, e.g. SHA-256                                                                                                                                                                                                                                                                                                  |
| `animation_url`                 | `string`  | url to a multi-media attachment for the item. Application might use this to display the token in a richer way than the image of the `image` property. Application might support media types like GLTF, GLB, WEBM, MP4, M4V, OGV, and OGG, MP3, WAV, and OGA as well as HTML. The query `?ext={file_extension}` can be used to provide information on the file type. |
| `image_data`                    | `string`  | raw SVG image data.                                                                                                                                                                                                                                                                                                                                                 |
| `category`                      | `string`  | category of the associated media file, e.g. `image`, `video`, `audio`, `vr`, `html`.                                                                                                                                                                                                                                                                                |
| `files`                         | `array`   | list of all associated files, represented as `{uri: string, type: string, signature: string, signature_type: string}`.                                                                                                                                                                                                                                              |
| `creators`                      | `array`   | list of creators and their shares, represented as `{address: string, share: integer}`. Shares are represented as percentage. The sum of shares of all creators must add up to 100. Shares can be used to define royalties.                                                                                                                                          |
| `seed`                          | `string`  | hex string represented the DNA of the NFT. The seed is usually stored on-chain, it might be contained in the metadata for convenience.                                                                                                                                                                                                                              |
