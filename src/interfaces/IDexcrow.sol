// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibTransaction} from "../libraries/LibTransaction.sol";
import {LibAcceptance} from "../libraries/LibAcceptance.sol";
import {LibConflict} from "../libraries/LibConflict.sol";
import {LibVerdict} from "../libraries/LibVerdict.sol";
import {LibFee} from "../libraries/LibFee.sol";

/// @title IDexcow interface
/// @author stack3dev
/// @notice Interface of the Dexcow escrow contract.
/// @dev This interface define the main functions of the Dexcrow contract.
/// @custom:security-contact contact@stack3.dev
interface IDexcrow {
    event Settled(bytes32 indexed transactionHash, LibTransaction.Transaction transaction);

    event Claimed(bytes32 indexed transactionHash, bytes32 indexed acceptanceHash, LibAcceptance.Acceptance acceptance);

    event Disputed(bytes32 indexed transactionHash, bytes32 indexed conflictHash, LibConflict.Conflict conflict);

    event Resolved(bytes32 indexed transactionHash, bytes32 indexed verdictHash, LibVerdict.Verdict verdict);

    event ProtocolFeeSet(LibFee.Fee protocolFee);

    event ArbitratorFeeSet(address indexed arbitrator, LibFee.Fee fee);

    /// @notice Set the protocol fee
    /// @param protocolFee_ The protocol fee
    /// @dev This function is used to set the protocol fee.
    function setProtocolFee(LibFee.Fee calldata protocolFee_) external;

    /// @notice Set an arbitrator fee
    /// @param arbitrator The arbitrator address
    /// @param arbitratorFee_ The arbitrator fee
    /// @dev This function is used to set an arbitrator fee.
    function setArbitratorFee(address arbitrator, LibFee.Fee calldata arbitratorFee_) external;

    /// @notice Settle a transaction
    /// @param transaction The transaction to settle into the escrow
    /// @param sellerSignature The signature of the seller
    /// @dev This function is used to settle a transaction into the escrow.
    function settle(LibTransaction.Transaction calldata transaction, bytes calldata sellerSignature) external;

    /// @notice Accept a transaction
    /// @param transaction The transaction to accept
    /// @param acceptance The acceptance of the buyer
    /// @param acceptanceBuyerSignature The signature of the buyer (optional if the buyer is the msg.sender)
    /// @dev This function is used to accept a transaction.
    function claim(
        LibTransaction.Transaction calldata transaction,
        LibAcceptance.Acceptance calldata acceptance,
        bytes calldata acceptanceBuyerSignature
    ) external;

    /// @notice Dispute a transaction
    /// @param transaction The transaction to dispute
    /// @param conflict The conflict of the buyer
    /// @param conflictOriginatorSignature The signature of the originator (optional if the originator is the msg.sender)
    /// @dev This function is used to dispute a transaction.
    function dispute(
        LibTransaction.Transaction calldata transaction,
        LibConflict.Conflict calldata conflict,
        bytes calldata conflictOriginatorSignature
    ) external;

    /// @notice Resolve a transaction
    /// @param transaction The transaction to resolve
    /// @param verdict The verdict of the arbitrator
    /// @param verdictArbitrorSignature The signature of the arbitrator (optional if the arbitrator is the msg.sender)
    /// @dev This function is used to resolve a transaction.
    function resolve(
        LibTransaction.Transaction calldata transaction,
        LibVerdict.Verdict calldata verdict,
        bytes calldata verdictArbitrorSignature
    ) external;
}
