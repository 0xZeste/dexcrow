// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibBp} from "./LibBp.sol";

/// @custom:security-contact dev@deelit.net
library LibVerdict {
    using LibBp for uint256;

    bytes32 private constant VERDICT_TYPEHASH =
        keccak256("Verdict(address from_address,bytes32 conflict_hash,uint16 buyer_bp,uint16 seller_bp)");

    struct Verdict {
        address from_address; // address of the verdict issuer
        bytes32 conflict_hash; // hash of the conflict
        uint16 buyer_bp; // amount to refund for the buyer
        uint16 seller_bp; // amount to claim for the seller
    }

    function hash(Verdict memory verdict_) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                VERDICT_TYPEHASH, verdict_.from_address, verdict_.conflict_hash, verdict_.buyer_bp, verdict_.seller_bp
            )
        );
    }

    /// @dev Calculate the total amount of the verdict for the payer and the payee
    /// @param amount_ the total amount of the payment
    /// @param verdict_ the verdict details
    /// @return payerAmount the payer refund amount
    /// @return payeeAmount the payee claim amount
    function calculateAmounts(uint256 amount_, Verdict memory verdict_) internal pure returns (uint256, uint256) {
        uint256 bpSum = verdict_.buyer_bp + verdict_.seller_bp;
        assert(bpSum >= verdict_.buyer_bp); // overflow check

        require(bpSum == 10000, "LibVerdict: invalid bp sum");

        uint256 amount_buyer = amount_.bp(verdict_.buyer_bp);
        return (amount_buyer, amount_ - amount_buyer);
    }
}
