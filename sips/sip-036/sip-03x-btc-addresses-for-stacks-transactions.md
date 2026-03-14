# SIP-0XX: Bitcoin Addresses for Stacks transactions 

## **Preamble**

SIP Number: 036   
Title: BTC Addresses for Stacks Transactions   
Authors: Larry Salibra [larry@newinternetlabs.com](mailto:larry@newinternetlabs.com) (New Internet Labs Limited)
Consideration: Technical   
Type: Standard   
Status: Draft   
Created: 2025-06-xx   
License: BSD-2-Clause   
Sign-off:   
Layer: API/RPC   
Discussions-To: [https://forum.stacks.org/t/proposing-bitcoin-addresses-for-stacks/17910?u=larry](https://forum.stacks.org/t/proposing-bitcoin-addresses-for-stacks/17910?u=larry)   
Requires: None   
Replaces: None   
Superceded-By: None

## **Abstract**

This SIP proposes the adoption of Bitcoin address formats (P2PKH and P2WPKH) as the standard user-facing address format for Stacks network transactions, including those involving sBTC. Currently, Stacks transactions use a unique address format distinct from that of Bitcoin. Aligning with Bitcoin's established address formats aims to reduce user friction, improve the user experience for Bitcoin users interacting with sBTC and the Stacks layer, and enhance the perception of sBTC as a Layer 2 Bitcoin solution. This change is intended to be implemented at the developer tool, library, and application level without requiring consensus changes to the Stacks blockchain.

## **Copyright**

This SIP is made available under the terms of the BSD-2-Clause license, available at [https://opensource.org/licenses/BSD-2-Clause](https://opensource.org/licenses/BSD-2-Clause). This SIP’s copyright is held by New Internet Labs Limited.

## **Introduction**

sBTC is designed to make Bitcoin programmable and enable faster transactions, positioning it as a significant component in the growth of decentralized finance and payments on Bitcoin. However, the current Stacks-specific address format presents a barrier to adoption for existing Bitcoin users, who are accustomed to Bitcoin's native address formats. Building wallets to handle both stacks addresses and bitcoin addresses currently requires duplication of user interface components and send/receive user flows. The resulting user interfaces can lead to confusion and a less intuitive user experience. Other Layer 2 solutions have faced similar UX challenges. The core problem this SIP addresses is the user experience friction caused by requiring Bitcoin users to use a non-Bitcoin address format when interacting with sBTC.  
   
**The proposal is to enable the use of standard Bitcoin addresses (legacy P2PKH and native SegWit P2WPKH) for sending and receiving sBTC and other Stacks-based assets.** This would allow sBTC to look and function more like Bitcoin from a user's perspective, leveraging existing user familiarity and tools, such as bitcoin payment QR codes and payment flows. The goal is to make interacting with sBTC as seamless as interacting with Bitcoin on the base layer, thereby encouraging broader adoption.

## **Specification**

The proposed change involves modifications at the application and library level, not the consensus layer of the Stacks blockchain.

### **Address Display**

User-facing applications (wallets, exchanges, explorers) MUST display Stacks account addresses as a Bitcoin native SegWit (P2WPKH) format by default. Support for display of legacy P2PKH format MAY also be included if necessary, but is generally discouraged.

### **Address Input and Resolution**

* Developer tools and libraries (e.g., Stacks.js) MUST be updated to accept Bitcoin addresses (both P2PKH and P2WPKH) as valid input for recipient addresses in transactions.  
  * These applications and tools will need to convert the provided Bitcoin address back to its corresponding Stacks address format (which encodes the same HASH160 of the public key) before constructing and broadcasting transactions or interacting with Clarity smart contracts.  
  * A proof-of-concept for converting between Stacks addresses and Bitcoin addresses (P2PKH and P2WPKH) is available at: [https://github.com/newinternetlabs/stx2btc/blob/master/src/lib.rs](https://github.com/newinternetlabs/stx2btc/blob/master/src/lib.rs)

### **Mechanics of conversion** 

Stacks addresses, legacy Bitcoin P2PKH addresses (starting with "1"), and native SegWit P2WPKH addresses (starting with "bc1") all encode the HASH160 of a public key. This shared underlying data structure makes the proposed conversion feasible. 

The technical details of this conversion are as follows:

#### Core Components and Referenced Standards for Conversion

**HASH160:** A 20-byte hash. The process for generating a HASH160 (typically SHA-256 followed by RIPEMD-160 of a public key) is a standard Bitcoin procedure.

**Version Byte (Stacks):** An 8-bit unsigned integer that distinguishes between different types or networks for Stacks addresses. For C32 encoding purposes, this value must be less than 32\.

**Crockford Base32:** The encoding scheme used for parts of the Stacks address, defined by Douglas Crockford at [https://www.crockford.com/base32.html](https://www.crockford.com/base32.html).

**Bitcoin Native SegWit (P2WPKH) Address Format:** Defined in BIP-0173 (Bech32).

**Bitcoin Legacy (P2PKH) Address Format:** Encoded using Base58Check.

**Checksum (Stacks):** A 4-byte checksum specific to the Stacks C32 Check Encoding.

#### Stacks Address Format Details

A Stacks address conforms to:

**Prefix:**   
The character 'S'.

**C32 Encoded Part:**   
Generated using a "C32 Check Encoding" process which takes a Stacks version byte and a payload (the 20-byte HASH160). It produces a string including the C32-encoded version, C32-encoded payload, and a C32-encoded 4-byte checksum. The checksum is the first 4 bytes of: `SHA256(SHA256(version_byte || HASH160_payload))`.

#### C32 Check Encoding and Decoding (Stacks Specific)

This process uses Crockford Base32 encoding.

##### C32 Check Encoding (Payload, Version) \-\> C32 String with Embedded Checksum

1. **Input:**  
   `payload_bytes:` The 20-byte HASH160.  
   `version_byte:` An 8-bit unsigned integer (value \< 32).

2. **Checksum Calculation:**  
   a. Concatenate: `data_to_hash = version_byte || payload_bytes`.  
   b. Calculate `hash1 = SHA256(data_to_hash)`.  
   c. Calculate `hash2 = SHA256(hash1)`.  
   d. `checksum_bytes = first_4_bytes(hash2)`.

3. **Crockford Base32 Encoding:**  
   a. Encode the `version_byte` into a single Crockford Base32 character (`c32_version_char`).  
   b. Encode the `payload_bytes` into a Crockford Base32 string (`c32_payload_string`).  
   c. Encode the `checksum_bytes` into a Crockford Base32 string (`c32_checksum_string`).

4. **Output:**   
   Concatenate: `c32_version_char + c32_payload_string + c32_checksum_string`.

##### C32 Check Decoding (C32 String) \-\> (Payload, Version)

1. **Input:** `c32_check_encoded_string`.  
2. **Crockford Base32 Decoding:**  
   a. Decode the first character to get the version\_byte.  
   b. Decode the remaining part of the string into a raw byte sequence.  
   c. From this raw byte sequence, the last N bytes (where N is the C32-decoded length of the 4-byte raw checksum) are the `decoded_checksum_bytes`. The preceding bytes are the `decoded_payload_bytes` (the HASH160).  
     
3. **Checksum Verification**:  
   a. Re-calculate an `expected_checksum_bytes` using the `decoded_payload_bytes` and the `version_byte` (as per C32 Check Encoding step 2).  
   b. Compare `decoded_checksum_bytes` with `expected_checksum_bytes`.

4. **Output:** If checksums match, return `decoded_payload_bytes` and `version_byte`. Otherwise, indicate an error.

##### Conversion Process: Stacks Address to Bitcoin Address (P2WPKH or P2PKH)

1. **Decode Stacks Address to HASH160:**  
   a. Validate the Stacks address starts with 'S'.  
   b. Remove the 'S' prefix.  
   c. Perform C32 Check Decoding on the remaining string to get the Stacks `version_byte` and the 20-byte HASH160.  
2. **Encode HASH160 to Target Bitcoin Address Format:**  
   For P2WPKH (Native SegWit): Encode the HASH160 according to BIP-0173. Use a SegWit version byte of 0\.

   For P2PKH (Legacy): Encode the HASH160 using Base58Check encoding. Use the appropriate Bitcoin version byte for P2PKH.

#####  Conversion Process: Bitcoin Address (P2WPKH or P2PKH) to Stacks Address

1. **Decode Bitcoin Address to HASH160:**  
   For P2WPKH (Native SegWit): Decode according to BIP-0173. Verify SegWit version byte is 0\.

For P2PKH (Legacy): Decode using Base58Check decoding.  
Encode HASH160 to Stacks Address:  
a. Select the appropriate Stacks `version_byte`.  
b. Perform C32 Check Encoding using the HASH160 and the Stacks `version_byte`.  
c. Prepend 'S' to the result.

### **Preventing Accidental Sends to Unaware Wallets** 

To mitigate the risk of users sending sBTC or other Stacks assets to Bitcoin addresses whose wallets do not yet support sBTC or other Stacks assets (and therefore cannot "see" or manage the assets), an extension to the Bitcoin URI standard ([BIP-21](https://github.com/bitcoin/bips/blob/master/bip-0021.mediawiki)) SHOULD be considered. This could involve:

* A new optional parameter in the Bitcoin URI (e.g., `stx=1`) to indicate that the QR code or payment request supports receiving sBTC on the Stacks network.  
* Wallets initiating sBTC sends could check for this parameter. If absent, they should display a warning to the user, informing  them that the recipient's wallet might not recognize the sBTC transaction, even if the underlying Bitcoin address is valid.

### **Principals in smart contracts**

Principals in smart contracts will, in the absence of a future SIP (see “Future Work”), continue to use the Stacks Address format. As such, developer tools, applications and wallets should convert Bitcoin addresses specified as principals for smart contracts to their corresponding Stacks Address, when appropriate.

### **Derivation paths**

Wallets supporting both layer 1 bitcoin and Stacks transactions SHOULD continue to use the BIP-44 cointype (5757) for Stacks when generating the derivation path for addresses. Wallets should provide support for checking the layer 1 bitcoin BIP-44 cointype (0) for Stacks assets and sweeping them to the equivalent Stacks BIP-44 cointype.

## **Related Work**

### **Bitcoin Address Formats**

This proposal leverages existing Bitcoin address standards, specifically P2PKH (Pay-to-Public-Key-Hash) and P2WPKH (Pay-to-Witness-Public-Key-Hash).

### **Lightning Network**

The Lightning Network uses its own invoice format (BOLT11), which is different from on-chain Bitcoin addresses. This SIP aims to avoid introducing a new, distinct standard for sBTC addresses, learning from the friction this can cause.

### **Multi-network Asset Support on Exchanges**

Many cryptocurrency exchanges already support transferring the same asset (e.g., USDT, USDC) across multiple blockchain networks, often using the native address format of each respective network. This demonstrates a precedent for users managing assets at the same conceptual "address" (derived from the same key) but on different networks. This SIP proposes a similar user experience for Bitcoin and sBTC.

## **Backwards Compatibility**

This proposal is designed to be backwards compatible at the consensus layer, as no changes to the Stacks blockchain protocol itself are required.

* Existing Stacks addresses will continue to function.  
* The changes primarily affect client-side software (wallets, libraries, dApps).  
* Applications can choose to implement support for Bitcoin addresses gradually.  
* Users who prefer to use the existing Stacks address format can continue to do so.  
* Smart contracts and on-chain logic will continue to use the underlying Stacks address format. The conversion to/from Bitcoin addresses will happen at the application/library layer before interacting with contracts.

## **Activation**

This SIP will be considered activated once the following conditions are met:

1. **Updated Libraries**: Key Stacks developer libraries (e.g., Stacks.js or its successors) are updated to:  
   * Accept P2PKH and P2WPKH Bitcoin addresses as input for transaction recipients.  
   * Provide utility functions to convert Stacks addresses to P2WPKH Bitcoin addresses for display purposes.  
   * Provide utility functions to resolve P2PKH/P2WPKH Bitcoin addresses back to Stacks addresses.  
2. **Wallet Adoption**: At least two major Stacks wallets have implemented support for:  
   * Displaying user account addresses in P2WPKH Bitcoin format.  
   * Allowing users to send sBTC (and other Stacks assets) to P2PKH and P2WPKH Bitcoin addresses.  
   * Implementing a warning mechanism (as described in the Specification section or similar) when sending sBTC to a Bitcoin address if sBTC support by the recipient cannot be confirmed.  
3. **Explorer Adoption**: At least one major Stacks block explorer is updated to:  
   * Allow searching by P2PKH/P2WPKH Bitcoin addresses.  
   * Display account information using the P2WPKH Bitcoin address format as an option.  
4. **Community Endorsement**: The proposal receives positive feedback and endorsement from the Stacks developer community and key stakeholders, indicated by discussion on the Stacks forum and other relevant channels.

The Stacks Foundation and core developers are encouraged to support and promote these changes within the ecosystem. No specific on-chain voting mechanism is required for activation, as this is a standard for client-side implementations. Progress will be tracked via updates to the SIP and community announcements.

## **Future Work**

### **Derivation paths**

In anticipation of limitations imposed by some hardware wallet manufacturers, this SIP recommends that wallets use the Stacks BIP-44 cointype (5757) for derivation paths. A future SIP combined with coordination with hardware wallet manufacturers could define support for using Bitcoin’s BIP-44 cointype and/or a new cointype that supports any bitcoin layer.

### **Additional support for multisig and taproot addresses**

This SIP only introduces support for the single-signature legacy Bitcoin addresses and P2WPKH native SegWit format.  A future SIP could introduce support for bitcoin multisig addresses and taproot addresses

### **Changes in Stacks core, smart contracts and APIs**

This SIP only discusses backwards-compatible changes to the accepted and displayed address formats at the developer tool, application and library level. A future SIP could introduce changes in Stacks core, and the Stacks smart contract system and APIs.

## **Reference Implementations**

* Proof-of-concept rust library for address conversion: [https://github.com/newinternetlabs/stx2btc/blob/master/src/lib.rs](https://github.com/newinternetlabs/stx2btc/blob/master/src/lib.rs)  
* Proof-of-concept typescript wallet implementing sbtc transfers with bitcoin addresses:  
  [https://github.com/newinternetlabs/sbtc-with-btc-addresses](https://github.com/newinternetlabs/sbtc-with-btc-addresses)

