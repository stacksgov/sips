# Preamble

SIP Number: 016

Title: Schema Definition for Metadata for Digital Assets

Author: Friedger Müffke (mail@friedger.de), Dan Trevino (dantrevino@gmail.com)

Consideration: Technical

Type: Standard

Status: Activation-in-Progress

Created: 7 November 2021

License: CC0-1.0

Sign-off: Jude Nelson (jude@stacks.org)

Layer: Traits

# Abstract

Non-fungible tokens - NFTs for short - are digital assets registered on
blockchain with unique identifiers and properties that distinguish them from
each other. SIP-009 defines the trait for how ownership of an NFT is managed.
Fungible tokens - FTs for short - are digital assets where each token can be
replaced by another token (see SIP-010). Semi-fungible tokens are digital assets
where each token has a unique identifier and is dividable into fungible parts
(see SIP-013). This SIP aims to provide a flexible standard to attach metadata
to NFTs, like descriptions or urls to digital files. The same standard is
applicable to fungible tokens.

# License and Copyright

This SIP is made available under the terms of the Creative Commons CC0 1.0
Universal license, available at
https://creativecommons.org/publicdomain/zero/1.0/ This SIP’s copyright is held
by the Stacks Open Internet Foundation.

# Introduction

Tokens are digital assets registered on blockchain through a smart contract. A
non-fungible token (NFT) is a token that is globally unique and can be
identified through its unique identifier. In blockchains with smart contracts,
including the Stacks blockchain, developers and users can use smart contracts to
register and interact with non-fungible tokens.

Some use cases of NFTs are name registration, digital art, certification, media
and entertainment, real-estate. They all require that users associate certain
content with an NFT. In general, it is helpful for the users to have a name,
sound, image that represents this content.

# Specification

Every SIP-016 compliant smart contract in the Stacks blockchain must implement
one or more functions that return a resolvable/retrievable URI referencing
metadata. The metadata provide information e.g. for displaying a digital asset
to users. This type of function is named "metadata URI functions".

Appendix A contains a list of trait functions that must meet the following
requirements for the return value. The appendix can be extended without changing
the ratification status of this SIP. Any changes to that appendix must be noted
in the changelog subsection.

## Return Value of Metadata URI Functions

The return value must be a `some` value if and only if the metadata reference an
existing token, otherwise the value must be `none`. Appendix A specifies the
exact meaning of "existing" for each function.

For existing tokens, the inner value of the return value must be a string
representing a resolvable URI.

The schema of the resolvable URI is not specified and should be a well-known
schema like `https`, `ar`, `ipfs`, `sia`. A `data` URI is also valid, however,
the length is limited by this SIP.

If a metadata URI function expects a parameter of type `uint` that identifies a
token and the resulting strings contain `{id}`, then the `{id}` part must be
replaced by the identifier in decimal format given in the function call.

The resolved data of the URI must be a JSON blob.

## JSON scheme of Metadata

The JSON blob resolved through the URI must follow the following JSON schema.

If metadata were retrieved by a function call containing a token identifier and
the string `{id}` exists in any JSON value, it MUST be replaced with the actual
token id in decimal format, by all client software that follows this standard.

```
{
    "$schema": "http://json-schema.org/draft-07/schema#",
    "title": "Token Metadata",
    "type": "object",
    "required": ["sip", "name"],
    "properties": {
        "sip": {
            "type": "number",
            "description": "SIP number that defines the JSON schema for metadata. For this SIP, the sip number must be `16`."
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
            "description": "A URI pointing to a resource with MIME type image/* representing the asset to which this token represents. Consider making any images at a width between 320 and 1080 pixels and aspect ratio between 1.91:1 and 4:5 inclusive. If the token represents a media file of different MIME type or of higher quality defined in property 'raw_media_file_uri', then this image should be used as preview image like a cover for music, or an low-res image."
        },
        "attributes": {
            "type": "array",
            "description": "Additional attributes of the token that are \"observable\". See section below. Values may be strings, numbers, object or arrays.",
            "items": {
                "type": "object",
                "required": ["trait_type", "value"],
                "properties": {
                    "display_type": {"type": "string"},
                    "trait_type": {"type": "string"},
                    "value": {"anyOf": [{"type": "object"}, {"type": "string"}, {"type": "number"}, {"type": "integer"}, {"type": "boolean"}, {"type": "array"}]}
                }
            }
        },
        "properties": {
            "type": "object",
            "description": "Additional other properties of the token. See section below. Values may be strings, numbers, object or arrays."
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
        }
    }
}
```

The length of string values is not restricted. Nowadays, clients should be smart
enough to deal with values of different lengths. Note, that the [sitemap
protocol](https://www.sitemaps.org/protocol.html) and many search engines
support only URLs with less than 2048 characters.

### Example

token101.json

```
{
  "sip": 16,
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
    "sip": 16,
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
    "sip": 16,
    "attributes: [
        {
          "trait_type": "cabelos",
          "value": "vermelho",
        },
        {
          "trait_type": "força",
          "display_type": "number",
          "value": 99,
        },
    ]
}
```

### Properties

Common properties of tokens are described in appendix C. Properties of type
`object` are usually described using the following schema:

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

Attributes describe additional elements of tokens that are "observable", usually
represented in the associated image or digital asset of the token. In contrast,
`properties` describe elements of tokens that are more abstract and not visible
in the associated image of the token.

Images of NFTs often have a limited set of traits and each trait has a limited
number of possible values. These values are represented as attributes in the
metadata. They can be used to calculate a score for each NFT in the collection
that could define the rarity of the NFT.

An `attribute` consists of a `trait_type` defining the name of the trait, e.g.
"hair". The `value` is the value of the trait, e.g. "red". The `display_type` is
a field indicating how the trait value should be displayed, e.g. on a
marketplace. If `display_type` is omitted, then `string` is used as default
display type.

Appendix B describes the possible types and display types of attributes.

## Localization

The localized data follow the same JSON schema with property `sip` as required
and all other properties as optional.

The localized data overwrite data provided in the default metadata JSON. The
localized data can provide only partial data.

An array of localized `attributes` overwrites the whole list of default
`attributes`.

A localized properties with partial data overwrites only the provided
properties; the remaining default properties remain as default values.

# Using metadata in applications

An application like a marketplace uses metadata to present tokens to users.
Before doing so, application developers should verify whether the metadata is
compliant with their own application's guidelines, e.g. forbidding bad language
in names or unsuitable images.

We remind implementation authors that the empty string for the token URI is a
valid response. We also remind everyone that any smart contract can use the same
metadata as other NFT contracts. It is out of the scope of this standard to
define how a client may determine which smart contracts are the original,
well-known, canonical ones.

## Graphical representation

The metadata of a token contain several properties that can be used to visually
represent the token. It is recommended to consider the first defined property of
the following ordered list:

1. `image`
2. `properties.image_data`
3. `image_data`

A rich representation should use the first defined property of the following
list:

1. `properties.animation_url`
2. `animation_url`

# Out of Scope

Accessiblity of content is not covered by the standard.

Properties other than resolvability of the token URI are out of scope. This
implies that metadata might change over time (stability).

# Metadata functions

Some contracts have dedicated functions to provide some metadata directly
without resolving the token URI. This is usually necessary, if other contracts
need to use the token metadata. This SIP does not define signatures for these
functions.

Examples of contracts with metadata functions are listed below:

**Boom**

The [NFT contract for
Boom](https://explorer.stacks.co/txid/0x423d113e14791f5d60f5efbee19bbb05cf5e68d84bcec4e611f2c783b08d05aa?chain=mainnet)
implements a variation of this trait using similar naming, but returning other
types than response types.

The function signatures for metadata are:

- `(get-boom-meta () {uri: (string-ascii 35), name: (string-ascii 16),
  mime-type: (string-ascii 9)})` and
- `(get-meta? uint {series-id: uint, number: uint, name: (string-utf8 80), uri:
  (string-ascii 2048), mime-type: (string-ascii 129), hash: (buff 64)})`

**Badges**

The [badges
contract](https://explorer.stacks.co/txid/0xb874ddbb4a602c22bb5647c7a2f8bfcafbbca7c0c663a175f2270ef3665f33de?chain=mainnet)
defines metadata for nfts.

The function signatures for metadata are:

- `(get-badge-meta () {uri: (string-ascii 78111)})` and
- `(get-meta? (uint) (optional {user: principal}))`

# Backwards Compatibility

This SIP defines metadata so that metadata for existing NFTs on other
blockchains like Ethereum, Solana or WAX can be re-used for NFTs on the Stacks
blockchain.

# Related Work

NFTs are an established asset class on blockchains. Read for example
[here](https://www.ledger.com/academy/what-are-nft).

## BNS

The Blockchain Naming System uses native non-fungible tokens. It does define
metadata for a name through attachements. The schema for names owned by a person
follows the definition of (schema.org/Person)[https://schema.org/Person]. This
could be an alternative to token URIs.

## EIP 721 and 1155

Metadata for NFTs on Ethereum are defined in [EIP
721](https://eips.ethereum.org/EIPS/eip-721) and [EIP
1155](https://eips.ethereum.org/EIPS/eip-1155). The JSON schema for SIP-016 has
adopted the EIP 1155 schema with the following differences:

- substitution of `{id}` strings must use the decimal format not the hexdecimal,
  zero-padded format.

- properties of type object should use property `value` for the value, not
  property `description` as used by some EIP-1155 NFTs.

## Metaplex

The tool suite Metaplex for NFTs on Solana defines a [JSON
schema](https://docs.metaplex.com/nft-standard#uri-json-schema). The properties
`category` and `files` in Appendic C were inspired by that schema.

## Hedera

Hedera follows the same schema defined in
[H-10](https://github.com/hashgraph/hedera-improvement-proposal/blob/master/HIP/hip-10.md).

# Activation

This SIP is activated if 10 contracts are deployed that follows this
specification. This must happen before Bitcoin tip #750,000.

# Appendix A

List of trait function define in SIPs and specifications specific to these
functions

| SIP and Trait Function Name                            | Definition of "existing"                                                                        | Additional Specification for Properties                                                                                                                                                                                    | Identifier Parameter |
| ------------------------------------------------------ | ----------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------- |
| SIP-009 nft-trait.get-token-uri                        | token must be minted and not burnt                                                              | NFTs belonging to a group of tokens should use property `properties.collection` of type `string` for the collection name. <br/> Optional property `properties.id` of type `integer` describes the identifier of the token. | 1st                  |
| SIP-016 get-contract-uri                               | always                                                                                          | `properties.items` of type array can be used to provide the metadata of all tokens belonging to the collection                                                                                                             | X                    |
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
| `animation_url`                 | `string`  | url to a multi-media attachment for the item. Application might use this to display the token in a richer way than the image of the `image` property. Application might support media types like GLTF, GLB, WEBM, MP4, M4V, OGV, and OGG, MP3, WAV, and OGA as well as HTML. The query `?ext={file_extension}` can be used to provide information on the file type. |
| `artist_name`                   | `string`  | name of the artist, mainly used as attribution.                                                                                                                                                                                                                                                                                                                     |
| `category`                      | `string`  | category of the associated media file, e.g. `image`, `video`, `audio`, `vr`, `html`.                                                                                                                                                                                                                                                                                |
| `collection`                    | `string`  | collection name the token belongs to. See also Appendix A.                                                                                                                                                                                                                                                                                                          |
| `collection_image`              | `string`  | url to an image representing the collection.                                                                                                                                                                                                                                                                                                                        |
| `created`                       | `integer` | creation date of the token in unix timestamp                                                                                                                                                                                                                                                                                                                        |
| `creators`                      | `array`   | list of creators and their shares, represented as `{address: string, share: integer}`. Shares are represented as percentage. The sum of shares of all creators must add up to 100. Shares can be used to define royalties.                                                                                                                                          |
| `decimals`                      | `integer` | number of decimals. See also Appendix A.                                                                                                                                                                                                                                                                                                                            |
| `external_url`                  | `string`  | url that will view the token on an external site                                                                                                                                                                                                                                                                                                                    |
| `files`                         | `array`   | list of all associated files, represented as `{uri: string, type: string, signature: string, signature_type: string}`.                                                                                                                                                                                                                                              |
| `id`                            | `integer` | identifier for NFTs. See also Appendix A.                                                                                                                                                                                                                                                                                                                           |
| `image_data`                    | `string`  | raw SVG image data.                                                                                                                                                                                                                                                                                                                                                 |
| `ip_document_uri`               | `string`  | link to document about intellectual property (IP) rights                                                                                                                                                                                                                                                                                                            |
| `raw_media_file_signature`      | `string`  | signature of the media file represented by the token                                                                                                                                                                                                                                                                                                                |
| `raw_media_file_signature_type` | `string`  | signature type of the media represented by the token, e.g. SHA-256                                                                                                                                                                                                                                                                                                  |
| `raw_media_file_type`           | `string`  | MIME type of the media represented by the token                                                                                                                                                                                                                                                                                                                     |
| `raw_media_file_uri`            | `string`  | uri of the media represented by the token                                                                                                                                                                                                                                                                                                                           |
| `seed`                          | `string`  | a string representing of the uniqueness of the NFT, like a DNA. The seed is usually stored on-chain, but it might be contained in this metadata for convenience.                                                                                                                                                                                                                              |
| `symbol`                        | `string`  | token symbol                                                                                                                                                                                                                                                                                                                                                        |
| `total_supply`                  | `integer` | number of total supply, e.g. minted tokens                                                                                                                                                                                                                                                                                                                          |
