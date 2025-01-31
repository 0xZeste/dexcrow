// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @custom:security-contact dev@deelit.net
library LibAcceptance {
    bytes32 private constant ACCEPTANCE_TYPEHASH =
        keccak256("Acceptance(address from_address,bytes32 transaction_hash)");

    struct Acceptance {
        address from_address; // address of the judge
        bytes32 transaction_hash; // hash of accepted the payment
    }

    function hash(Acceptance calldata acceptance_) internal pure returns (bytes32) {
        return keccak256(abi.encode(ACCEPTANCE_TYPEHASH, acceptance_.from_address, acceptance_.transaction_hash));
    }
}
