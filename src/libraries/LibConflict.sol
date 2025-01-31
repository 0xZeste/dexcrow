// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @custom:security-contact dev@deelit.net
library LibConflict {
    bytes32 private constant CONFLICT_TYPEHASH = keccak256("Conflict(address from_address,bytes32 transaction_hash)");

    struct Conflict {
        address from_address; // address of the conflict initiator
        bytes32 transaction_hash; // hash of the payment
    }

    function hash(Conflict calldata conflict_) internal pure returns (bytes32) {
        return keccak256(abi.encode(CONFLICT_TYPEHASH, conflict_.from_address, conflict_.transaction_hash));
    }
}
