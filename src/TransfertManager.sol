// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {LibFee} from "./libraries/LibFee.sol";
import {LibTransaction} from "./libraries/LibTransaction.sol";
import {LibVerdict} from "./libraries/LibVerdict.sol";
import {LibConflict} from "./libraries/LibConflict.sol";

/// @custom:security-contact contact@stack3.dev
abstract contract TransfertManager is ContextUpgradeable {
    using Math for uint256;
    using SafeERC20 for IERC20;
    using Address for address payable;

    /// @dev allow the contract to receive native currency
    receive() external payable {}

    /// @dev Process to the payment of an offer. The payment is stored by the contract.
    /// @param transaction the payment and offer details
    function _doSettle(LibTransaction.Transaction calldata transaction) internal {
        if (transaction.payment.token_address == address(0)) {
            _doSettleNative(transaction);
        } else {
            _doSettleErc20(IERC20(transaction.payment.token_address), transaction);
        }
    }

    /// @dev Process to the transaction of an offer in native currency. The payment is stored by the contract.
    /// @param transaction the payment and offer details
    function _doSettleNative(LibTransaction.Transaction calldata transaction) private {
        (uint256 protocolFeeAmount, uint256 arbitratorFeeAmount, uint256 totalFees) = _calculateFees(transaction);
        (bool success, uint256 amountWithFees) = transaction.payment.amount.tryAdd(totalFees);
        assert(success);

        // native currency payment
        require(msg.value >= amountWithFees, "TransfertManager: not enough value");

        // transfer the fee amount to the contract
        _collectFee(transaction.protocol_fee.recipient, protocolFeeAmount);
        _collectFee(transaction.arbitrator_fee.recipient, arbitratorFeeAmount);

        // refund the excess
        uint256 rest = msg.value - amountWithFees;
        if (rest > 0) {
            payable(_msgSender()).sendValue(rest);
        }
    }

    function _calculateFees(LibTransaction.Transaction calldata transaction)
        private
        pure
        returns (uint256 protocolFeeAmount, uint256 arbitratorFeeAmount, uint256 totalFees)
    {
        // calculate the fees
        protocolFeeAmount = LibFee.calculateFee(transaction.payment.amount, transaction.protocol_fee.amount_bp);
        arbitratorFeeAmount = LibFee.calculateFee(transaction.payment.amount, transaction.arbitrator_fee.amount_bp);
        (bool success, uint256 calcTotalFees) = protocolFeeAmount.tryAdd(arbitratorFeeAmount);
        assert(success);

        totalFees = calcTotalFees;
    }

    /// @dev Process to the transaction in ERC20. The payment is stored by the contract.
    /// @param token the token address
    /// @param transaction the transaction details
    function _doSettleErc20(IERC20 token, LibTransaction.Transaction calldata transaction) private {
        (uint256 protocolFeeAmount, uint256 arbitratorFeeAmount, uint256 totalFees) = _calculateFees(transaction);
        (bool success, uint256 amountWithFees) = transaction.payment.amount.tryAdd(totalFees);
        assert(success);

        // verify allowance
        uint256 allowance = token.allowance(_msgSender(), address(this));
        require(allowance >= amountWithFees, "TransfertManager: allowance too low");

        // process the payment
        _collectFeeErc20From(token, _msgSender(), transaction.arbitrator_fee.recipient, protocolFeeAmount);
        _collectFeeErc20From(token, _msgSender(), transaction.protocol_fee.recipient, arbitratorFeeAmount);

        token.safeTransferFrom(_msgSender(), address(this), transaction.payment.amount);
    }

    /// @dev Procces to the claim of a payment. The payment is released to the payee.
    /// @param transaction the payment and offer details
    function _doClaim(LibTransaction.Transaction calldata transaction) internal {
        // compute amount to claim regarding the fees
        uint256 amount = transaction.payment.amount;
        address payable payee = payable(transaction.payment.destination_address);

        if (transaction.payment.token_address == address(0)) {
            // native currency payment
            payee.sendValue(amount);
        } else {
            // ERC20 payment
            IERC20 token = IERC20(transaction.payment.token_address);
            token.safeTransfer(payee, amount);
        }
    }

    /// @dev Process to the resolution of a conflict. The payment is transferred to the granted party.
    /// @param transaction the payment and offer details
    /// @param verdict the verdict details
    function _doResolve(LibTransaction.Transaction calldata transaction, LibVerdict.Verdict calldata verdict)
        internal
    {
        // check the verdict amount
        (uint256 buyerAmount, uint256 sellerAmount) = LibVerdict.calculateAmounts(transaction.payment.amount, verdict);

        // define payee and payer
        address payable payee = payable(transaction.payment.destination_address);
        address payable payer = payable(transaction.payment.refund_address);

        // transfer the amounts
        if (transaction.payment.token_address == address(0)) {
            // native currency payment
            payee.sendValue(buyerAmount);
            payer.sendValue(sellerAmount);
        } else {
            // ERC20 payment
            IERC20 token = IERC20(transaction.payment.token_address);
            token.safeTransfer(payee, buyerAmount);
            token.safeTransfer(payer, sellerAmount);
        }
    }

    /// @dev Internal function to collect the fee
    /// @param recipient the recipient of the fee
    /// @param feeAmount the fee amount to collect
    function _collectFee(address recipient, uint256 feeAmount) internal {
        payable(recipient).sendValue(feeAmount);
    }

    /// @dev Internal function to collect the fee in ERC20 from a specific address
    /// @param token the token to collect the fee in
    /// @param from the address to collect the fee from
    /// @param recipient the recipient of the fee
    /// @param feeAmount the fee amount to collect
    function _collectFeeErc20From(IERC20 token, address from, address recipient, uint256 feeAmount) internal {
        token.safeTransferFrom(from, recipient, feeAmount);
    }
}
