Here is a formatted README.md for your LivePass Protocol smart contract:

# LivePass Protocol

Decentralized Event Ticketing System  
**Version:** 2.0.0

---

## Overview

LivePass Protocol is a Clarity smart contract for decentralized event ticketing on the Stacks blockchain. It enables event organizers to mint, list, and manage NFT-based event passes, while allowing users to buy, sell, and transfer tickets securely.

---

## Features

- NFT-based event passes (`livepass`)
- Minting, listing, updating, and delisting of passes
- Marketplace for buying and selling passes
- Royalty fee distribution to creators
- Access control for admin functions
- Metadata storage for event details
- Standard read-only views for querying state

---

## Contract Structure

- **NFT Core:** Defines the `livepass` non-fungible token.
- **State Variables:** Tracks initialization, owner, creator, royalty fee, and total minted passes.
- **Maps:** 
  - `pass-data`: Stores metadata for each pass.
  - `marketplace`: Stores listing price for each pass.
- **Validation:** Ensures valid IDs, users, strings, and event dates.
- **Admin Functions:** Set creator and royalty fee.
- **Minting:** Only the owner can mint new passes.
- **Marketplace:** List, update, delist, and buy passes.
- **Transfer:** Secure transfer of passes between users.
- **Views:** Query holders, metadata, marketplace, and protocol state.

---

## Usage

### Initialization

```clarity
(initialize)
```
Initializes the protocol. Only callable once.

### Minting a Pass

```clarity
(mint-pass id recipient title event-date location uri)
```
Mints a new event pass NFT to a recipient.

### Listing a Pass

```clarity
(list-pass id price)
```
Lists a pass for sale on the marketplace.

### Buying a Pass

```clarity
(buy-pass id)
```
Purchases a listed pass, transferring STX and NFT.

### Transferring a Pass

```clarity
(transfer id sender recipient)
```
Transfers a pass from sender to recipient.

### Admin Functions

- `set-creator (who principal)`
- `set-royalty (bps uint)`

---

## Error Codes

| Code   | Meaning             |
|--------|---------------------|
| u100   | Unauthorized        |
| u101   | Not initialized     |
| u102   | Already initialized |
| u103   | Not holder          |
| u104   | Not listed          |
| u105   | Already listed      |
| u106   | Zero price          |
| u107   | Invalid BPS         |
| u108   | Self purchase       |
| u109   | Not found           |
| u110   | Bad input           |
| u111   | Invalid ID          |
| u112   | Invalid principal   |

---

## Development

- **Contract:** Livepass-Protocol.clar
- **Tests:** Livepass-Protocol.test.ts
- **Config:** Clarinet.toml, settings

---

## License

MIT

---

For more details, see the contract source and test files.
