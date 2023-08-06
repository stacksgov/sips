# Preamble

SIP Number: TBD

Title: Standard URI Definition for Bitcoin Ordinal Inscriptions

Author: Rafael Cárdenas <rafael@hiro.so>, Jason Schrader <jason@joinfreehold.com>

Consideration: Technical

Type: Standard

Status: Draft

Created: 6 August 2023

License: GPL-3.0

Sign-off:

Layer: Applications

# Abstract

One of the main use cases of [Bitcoin Ordinal
Inscriptions](https://docs.ordinals.com/inscriptions.html) is the decentralized and
censorship-resistant storage of arbitrary data in the Bitcoin blockchain, a feature which is most
commonly used by artists and token creators to store artwork or metadata.

Given that the Stacks network has a very close relationship to Bitcoin, Stacks developers are
looking for a standardized way to reference the contents of inscriptions to use within their smart
contracts or applications.

This SIP defines a simple URI format that Stacks developers can use to make such a reference so that
content can be used in applications, token metadata, etc. This format supports referencing an
inscription by its Inscription ID, Inscription number, Satoshi ordinal number, and Satoshi name.

# Introduction

Stacks developers usually need to reference external resources from within their Clarity smart
contracts or their Stacks applications. For example, [SIP-010 defines a `get-token-uri`
function](https://github.com/stacksgov/sips/blob/main/sips/sip-010/sip-010-fungible-token-standard.md#token-uri)
that allows them to reference an off-chain JSON file which provides metadata for a Fungible Token.

Instead of keeping these files in centralized servers, developers choose to use storage protocols
like as IPFS or Arweave to save this data to ensure the decentralized storage, authenticity,
permanence, and accessibility of its contents.

Ever since Bitcoin Ordinal Inscriptions became popular, however, developers identified its use as an
improved storage protocol that immediately replicates stored contents across all the Bitcoin network
once included in a block. This provides a significant advantage over IPFS or Arweave which depend on
other factors for reliable content replication.

As such, Stacks developers have been looking for a standardized way to reference inscriptions as an
off-chain storage mechanism. They could use inscriptions to store token metadata JSON files,
artwork, or other resources.

This SIP proposes a URI (_Uniform Resource Identifier_) format that Stacks developers can use in
their smart contracts or application code to instruct other applications, chain indexers, or network
participants to retrieve and use the contents of the referenced Bitcoin Ordinal Inscription.

# Specification

There are four equivalent URI formats that can be used to reference the content of a Bitcoin Ordinal
Inscription from the Stacks network. Every one of them conforms to the same structure:

```
ord://<scope>/<identifier>
```

* `ord:` is the Ordinals URI scheme.
* `<scope>` must be `i` or `s`. It defines if the `<identifier>` should be parsed as an Inscription
  (`i`) or a Satoshi (`s`).
* `<identifier>` is an arbitrary value that contains a unique ID for an Inscription or a Satoshi
  depending on the value of `<scope>`. These identifiers never change once the inscription is
  created, regardless of transfers.

Examples for each format are defined below.

## Inscription URI

Inscription ID URIs begin with `ord://i/` and have two variants:

### Inscription ID URI

```
ord://i/ca7e4261f3d695810903d06565ac3555828fcdf4a583506d5df1b91e8eb561c3i0
```

Uses the unique `Inscription ID` as the identifier.

### Inscription number URI

```
ord://i/643494
```

Uses the inscription `number` as the identifier. Cursed inscriptions can also be referenced with
this format, however, developers should keep in mind that numbers for cursed inscriptions are not
guaranteed to be immutable:

```
ord://i/-76400
```

## Satoshi URI

Satoshi ID URIs begin with `ord://s/` and have two variants:

### Satoshi ordinal number URI

```
ord://s/1916693226919379
```

Uses the satoshi's `ordinal number` as the identifier.

### Satoshi name URI

```
ord://s/agstomwlzrq
```

Uses the satoshi's `ordinal name` as the identifier.

## Retrieving inscription content from URIs

Developers may use any public or private service or API to retrieve the contents of an inscription
from a URI.

For example, given the URI
`ord://i/ca7e4261f3d695810903d06565ac3555828fcdf4a583506d5df1b91e8eb561c3i0`, the following (non-exhaustive list of) services could be used by extracting the `<identifier>` and inserting it in any of the following valid URLs:

* Hiro's Ordinals API: https://api.hiro.so/ordinals/inscriptions/ca7e4261f3d695810903d06565ac3555828fcdf4a583506d5df1b91e8eb561c3i0/content
* Ordinals.com: https://ordinals.com/content/ca7e4261f3d695810903d06565ac3555828fcdf4a583506d5df1b91e8eb561c3i0
* Ord.io: https://www.ord.io/preview/ca7e4261f3d695810903d06565ac3555828fcdf4a583506d5df1b91e8eb561c3i0?type=image/png&raw=true

# Related work

An alternative to standardizing inscription URIs is to keep absolute URLs to one of the many public
Bitcoin indexer services such as the ones mentioned above.

The obvious disadvantage of this is that if that any of these services ever goes down, the URL is
broken and manual steps have to be taken to replace it with a newer valid URL.

# Activation

This SIP will be activated when the following conditions are met:

* At least 10 Stacks smart contracts make use of this URI format.
* At least 5 Stacks applications or indexers support the use of these URIs to retrieve inscription
  contents.

If the Stacks blockchain reaches block height 250000 and the above has not happened, this SIP will
be considered rejected.

# Reference implementations

x
