// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library LibPayment {
    bytes32 private constant PAYMENT_TYPEHASH =
        keccak256("Payment(address refund_address,address destination_address,uint256 amount,address token_address)");

    struct Payment {
        address refund_address;
        address destination_address;
        uint256 amount;
        address token_address;
    }

    function hash(Payment calldata payment) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                PAYMENT_TYPEHASH,
                payment.refund_address,
                payment.destination_address,
                payment.amount,
                payment.token_address
            )
        );
    }
}
