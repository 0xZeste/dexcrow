// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibPayment} from "./LibPayment.sol";
import {LibFee} from "./LibFee.sol";

library LibTransaction {
    bytes32 private constant TRANSACTION_TYPEHASH = keccak256(
        "Transaction(bytes32 object_hash,address buyer,address seller,address arbitrator,Payment payment,Fee protocol_fee,Fee arbitrator_fee,uint256 expiration_time,uint256 vesting_period)"
    );

    struct Transaction {
        // Subject of the transaction
        bytes32 object_hash;
        // Transaction participants
        address buyer;
        address seller;
        address arbitrator;
        // Transaction payment details
        LibPayment.Payment payment;
        // Transaction fees details
        LibFee.Fee protocol_fee;
        LibFee.Fee arbitrator_fee;
        // Transaction scheduling details
        uint256 expiration_time;
        uint256 vesting_period;
    }

    function hash(Transaction calldata transaction) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                TRANSACTION_TYPEHASH,
                transaction.object_hash,
                transaction.buyer,
                transaction.seller,
                transaction.arbitrator,
                LibPayment.hash(transaction.payment),
                LibFee.hash(transaction.protocol_fee),
                LibFee.hash(transaction.arbitrator_fee),
                transaction.expiration_time,
                transaction.vesting_period
            )
        );
    }
}
