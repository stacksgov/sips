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

[Bitcoin Ordinal Inscriptions](https://docs.ordinals.com/inscriptions.html) have exploded in
popularity ever since they were first proposed. One of their main applications is the decentralized
and censorship-resistant storage of arbitrary data in the Bitcoin blockchain, a feature which is
most commonly used by artists and token creators to store artwork or metadata.

Given that the Stacks network has a very close relationship to Bitcoin

This SIP defines a simple URI format that Stacks developers can use to make a reference to content
stored in a Bitcoin Ordinal Inscription so it can be used in applications, token metadata, etc.

# Introduction

A URI, or _Uniform Resource Identifier_, is a string of characters used to identify a resource on
the internet. It provides a way to uniquely identify a resource, such as a web page, a file, an
image, or any other resource accessible via a network. URIs are used to address and access resources
in various contexts, such as in web browsers, APIs, and other software applications.

IPFS, Arweave are common storage places for Token metadata

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

The Inscription ID URIs all begin with `ord://i/` and have two variants:

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

x

# Backwards compatibility

x

# Activation

x

# Reference implementations

x
