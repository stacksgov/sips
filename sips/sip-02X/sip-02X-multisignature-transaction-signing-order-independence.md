# Preamble

SIP Number: 02X

Title: Multisignature transaction signing order independence

Author: Vladislav Bespalov <https://github.com/fess-v>

Consideration: Technical

Type: Standard

Status: Draft

Created: 30 April 2023

License: CC0-1.0

Sign-off: -

# Abstract

Multisig transactions require multiple private keys to sign off on a transaction before it can be executed on the Stacks network. For example, a Stacks wallet may require the use of two out of three private keys to authorize a transaction. This means that multiple parties involved in the transaction must agree to the terms of the transaction and sign off on it before the funds can be transferred. Multisig transactions offer an additional layer of security and control over Stacks transactions, making them an essential tool for anyone looking to safeguard their funds.

For these transactions to be genuinely flexible and useful for common users, DAOs, dApps, and Stacks ecosystem projects, it is essential for signatures to be order-independent. Current restrictions on signature orders impede the emergence of multisignature solutions. Implementing this feature will result in an easier user experience and increased security when using Multisig wallets within the Stacks ecosystem. This will provide a user-friendly approach for multiple parties to cooperate in a secure environment to participate in Staking STX, Treasury Management for DAOs, and interact with dApps.

# License and Copyright

This SIP is made available under the terms of the Creative Commons CC0 1.0 Universal license, available at https://creativecommons.org/publicdomain/zero/1.0/
This SIP’s copyright is held by the Stacks Open Internet Foundation.

# Frontend signature examples

An example of a random signing order can be found below and the full code in this _[issue](https://github.com/hirosystems/stacks.js/issues/1487)_.

```javascript
  const transaction = await makeUnsignedSTXTokenTransfer({
      recipient,
      amount,
      network,
      fee,
      nonce,
      memo,
      numSignatures: 2,
      publicKeys: pubKeyStrings,
    });

  const signer = new TransactionSigner(transaction);
  signer.signOrigin(privKeys[2]);
  signer.appendOrigin(pubKeys[0]);
  signer.signOrigin(privKeys[1]);
```

# Related Links

- _[Stacks.js signature order issue](https://github.com/hirosystems/stacks.js/issues/1487)_
- _[Stacks blockchain signature order issue](https://github.com/stacks-network/stacks-blockchain/issues/2622)_

# Backwards Compatibility

Fully compatible with the previous strict signature order logic
