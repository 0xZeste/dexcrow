## Dexcrow - NOT PRODUCTION READY

Dexcrow is an escrow smart-contract for EVM blockchains.
Build on top of openzeppelin library, it provide an gaz efficient interface for managing escrow transactions. 
It ensures that funds are securely held until the conditions of the agreement are met.

3 parties are involved: Buyer, Seller, and Arbitrator.

- **Buyer**: The party purchasing goods or services.
- **Seller**: The party providing goods or services.
- **Arbitrator**: The neutral party that resolves disputes between the Buyer and Seller.

The **Buyer** and **Seller** can open a dispute if there is a disagreement regarding the transaction. In the case of a dispute, the **Arbitrator** has the authority to decide how the funds are dispatched, ensuring a fair resolution for both parties.


The transaction is defined following this EIP712 structure définition : 

```
struct Transaction {
    // Subject of the transaction
    bytes32 object_hash;

    // Transaction participants
    address buyer;
    address seller;
    address arbitrator;

    // Payment details (Payment(address refund_address,address destination_address,uint256 amount,address token_address))
    Payment payment;

    // Fees details (Fee(address recipient,uint48 amount_bp))
    Fee protocol_fee;
    Fee arbitrator_fee;

    // Transaction scheduling details
    uint256 expiration_time;
    uint256 vesting_period;
}
```

## Built with Foundry

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Dexcrow.s.sol:DexcrowScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
