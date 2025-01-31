// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {IDexcrow, LibFee, LibTransaction, LibAcceptance, LibConflict, LibVerdict} from "./interfaces/IDexcrow.sol";
import {TransfertManager} from "./TransfertManager.sol";

/// @custom:security-contact contact@stack3.dev
contract Dexcrow is
    IDexcrow,
    TransfertManager,
    OwnableUpgradeable,
    EIP712Upgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    using SignatureChecker for address;

    string private constant EIP712_NAME = "Dexcrow";
    string private constant EIP712_VERSION = "1";

    // max fee is 25%
    uint48 public constant MAX_FEES_BP = 25_00; // 25%

    // Define auto acceptance due to expiration
    bytes32 public constant AUTO_ACCEPTANCE = keccak256("AUTO_ACCEPTANCE");

    /// @notice transaction state.
    struct TransactionState {
        bytes32 acceptance; // acceptance hash
        bytes32 conflict; // conflict hash
        bytes32 verdict; // verdict hash
        uint256 vesting; // vesting time for payment claim => payment time + vesting_period. Also used to identify initiated payment
    }

    /// @custom:storage-location erc7201:dexcrow.storage.Dexcrow
    struct DexcrowStorage {
        // Mapping of transaction hash to transaction states
        mapping(bytes32 => TransactionState) _transactionStates;
        bytes32 _protocolFee;
        mapping(address => bytes32) _arbitratorFees;
    }

    // keccak256(abi.encode(uint256(keccak256("dexcrow.storage.Dexcrow")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant DexcrowStorageLocation = 0x8e2ea635dcce0e1b157648edd9da366936739fa3b4bfdcb2f7d3b5b148ca3700;

    function _getDexcrowStorage() private pure returns (DexcrowStorage storage $) {
        assembly {
            $.slot := DexcrowStorageLocation
        }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address owner_, LibFee.Fee calldata protocolFee_) public initializer {
        __Ownable_init(owner_);
        __EIP712_init(EIP712_NAME, EIP712_VERSION);
        __Pausable_init();
        __UUPSUpgradeable_init();

        _setProtocolFee(protocolFee_);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function _getProtocolFee() private view returns (bytes32) {
        DexcrowStorage storage $ = _getDexcrowStorage();
        return $._protocolFee;
    }

    function setProtocolFee(LibFee.Fee calldata protocolFee_) external onlyOwner whenNotPaused {
        _setProtocolFee(protocolFee_);
    }

    /// @dev Set the protocol fee. This fee is applied to all transactions.
    function _setProtocolFee(LibFee.Fee calldata protocolFee_) internal {
        require(protocolFee_.amount_bp > 0, "Dexcrow: fee is zero");
        require(protocolFee_.amount_bp <= MAX_FEES_BP, "Dexcrow: fee is greater than 25%");
        require(protocolFee_.recipient != address(0), "Dexcrow: recipient is zero address");
        require(protocolFee_.recipient != address(this), "Dexcrow: recipient is the contract address");

        DexcrowStorage storage $ = _getDexcrowStorage();
        $._protocolFee = LibFee.hash(protocolFee_);
        emit ProtocolFeeSet(protocolFee_);
    }

    function _getArbitratorFee(address arbitrator) private view returns (bytes32) {
        DexcrowStorage storage $ = _getDexcrowStorage();
        return $._arbitratorFees[arbitrator];
    }

    /// @dev Set an arbitrator fee. This fee is applied to all transactions for the designated arbitrator.
    function setArbitratorFee(address arbitrator, LibFee.Fee calldata arbitratorFee_) external whenNotPaused {
        require(msg.sender == arbitrator, "Dexcrow: only arbitrator can set his fee");
        require(arbitrator != address(0), "Dexcrow: arbitrator is zero address");
        require(arbitratorFee_.amount_bp > 0, "Dexcrow: fee is zero");
        require(arbitratorFee_.amount_bp <= MAX_FEES_BP, "Dexcrow: fee is greater than 25%");
        require(arbitratorFee_.recipient != address(0), "Dexcrow: recipient is zero address");
        require(arbitratorFee_.recipient != address(this), "Dexcrow: recipient is the contract address");

        DexcrowStorage storage $ = _getDexcrowStorage();
        $._arbitratorFees[arbitrator] = LibFee.hash(arbitratorFee_);
        emit ArbitratorFeeSet(arbitrator, arbitratorFee_);
    }

    /// @dev Get the transaction state for a given transaction hash.
    /// @param transactionHash the transaction hash to get the state for.
    function _getTransactionState(bytes32 transactionHash) private view returns (TransactionState storage) {
        DexcrowStorage storage $ = _getDexcrowStorage();
        return $._transactionStates[transactionHash];
    }

    /// @inheritdoc IDexcrow
    function settle(LibTransaction.Transaction calldata transaction, bytes calldata transactionSellerSignature)
        external
        whenNotPaused
    {
        bytes32 transactionHash = _hash(LibTransaction.hash(transaction));

        TransactionState storage $_state = _getTransactionState(transactionHash);
        require($_state.vesting == 0, "Dexcrow: Transaction already initiated");
        require(transaction.expiration_time > block.timestamp, "Dexcrow: Payment expired");

        // check fees
        bytes32 protocolFee = _getProtocolFee();
        bytes32 arbitratorFee = _getArbitratorFee(transaction.arbitrator);
        require(LibFee.hash(transaction.protocol_fee) == protocolFee, "Dexcrow: invalid protocol fee");
        require(LibFee.hash(transaction.arbitrator_fee) == arbitratorFee, "Dexcrow: invalid arbitrator fee");

        // verify signature and validate payment datas
        _verifySignature(transaction.seller, transactionHash, transactionSellerSignature);

        // update payment state
        $_state.vesting = block.timestamp + transaction.vesting_period;

        // process payment
        _doSettle(transaction);

        emit Settled(transactionHash, transaction);
    }

    /// @inheritdoc IDexcrow
    function claim(
        LibTransaction.Transaction calldata transaction,
        LibAcceptance.Acceptance calldata acceptance,
        bytes calldata buyerSignature
    ) external whenNotPaused {
        // compute hashes
        bytes32 transactionHash = _hash(LibTransaction.hash(transaction));
        bytes32 acceptanceHash;

        // retrieve transaction state
        TransactionState storage $_state = _getTransactionState(transactionHash);

        require($_state.vesting != 0, "Dexcrow: Transaction not initiated");
        require($_state.acceptance == bytes32(0), "Dexcrow: Transaction already accepted");
        require($_state.conflict == bytes32(0), "Dexcrow: Transaction in conflict");

        // check if vesting period is over
        if ($_state.vesting < block.timestamp) {
            // auto acceptance due to expiration
            acceptanceHash = AUTO_ACCEPTANCE;
        } else {
            // verify acceptance
            require(acceptance.from_address == transaction.buyer, "Dexcrow: invalid acceptance emitter");
            require(acceptance.transaction_hash == transactionHash, "Dexcrow: invalid acceptance transaction hash");

            // compute acceptance hash
            acceptanceHash = _hash(LibAcceptance.hash(acceptance));

            // verify acceptance signature
            if (msg.sender != acceptance.from_address) {
                _verifySignature(acceptance.from_address, acceptanceHash, buyerSignature);
            }
        }

        // update transaction state
        $_state.acceptance = acceptanceHash;

        // process claim payment
        _doClaim(transaction);

        emit Claimed(transactionHash, acceptanceHash, acceptance);
    }

    /// @inheritdoc IDexcrow
    function dispute(
        LibTransaction.Transaction calldata transaction,
        LibConflict.Conflict calldata conflict,
        bytes calldata conflictOriginatorSignature
    ) external whenNotPaused {
        // compute hashes
        bytes32 transactionHash = _hash(LibTransaction.hash(transaction));
        bytes32 conflictHash = _hash(LibConflict.hash(conflict));

        // retrieve payment state
        TransactionState storage $_state = _getTransactionState(transactionHash);

        require(
            conflict.from_address == transaction.buyer || conflict.from_address == transaction.seller,
            "Dexcrow: Invalid conflict issuer"
        );
        require(conflict.transaction_hash == transactionHash, "Dexcrow: Invalid conflict transaction hash");
        require($_state.vesting != 0, "Dexcrow: Transaction not initiated");
        require($_state.acceptance == bytes32(0), "Dexcrow: Transaction already claimed");
        require($_state.conflict == bytes32(0), "Dexcrow: Transaction already in conflict");
        require($_state.verdict == bytes32(0), "Dexcrow: Transaction already resolved");

        // verify conflict signature if caller not originator
        if (msg.sender != conflict.from_address) {
            _verifySignature(conflict.from_address, conflictHash, conflictOriginatorSignature);
        }

        // update transaction state
        $_state.conflict = conflictHash;

        emit Disputed(transactionHash, conflictHash, conflict);
    }

    /// @inheritdoc IDexcrow
    function resolve(
        LibTransaction.Transaction calldata transaction,
        LibVerdict.Verdict calldata verdict,
        bytes calldata verdictArbitrorSignature
    ) external whenNotPaused {
        // compute hashes
        bytes32 transactionHash = _hash(LibTransaction.hash(transaction));
        bytes32 verdictHash = _hash(LibVerdict.hash(verdict));

        // retrieve payment state
        TransactionState storage $_state = _getTransactionState(transactionHash);

        require($_state.vesting != 0, "Dexcrow: Transaction not initiated");
        require($_state.acceptance == bytes32(0), "Dexcrow: Transaction already claimed");
        require($_state.conflict != bytes32(0), "Dexcrow: Transaction not in conflict");
        require($_state.verdict == bytes32(0), "Dexcrow: Transaction already resolved");
        require($_state.conflict == verdict.conflict_hash, "Dexcrow: Invalid conflict hash");
        require(transaction.arbitrator == verdict.from_address, "Dexcrow: Invalid arbitrator");
        require(verdict.conflict_hash == $_state.conflict, "Dexcrow: Verdict conflict hash mismatch");

        // verify signature if not called by judge
        if (msg.sender != verdict.from_address) {
            _verifySignature(verdict.from_address, verdictHash, verdictArbitrorSignature);
        }

        // update payment state
        $_state.verdict = verdictHash;

        // process verdict
        _doResolve(transaction, verdict);

        emit Resolved(transactionHash, verdictHash, verdict);
    }

    /// @dev Compute the hash of a data structure following EIP-712 spec.
    /// @param dataHash_ the structHash(message) to hash
    function _hash(bytes32 dataHash_) private view returns (bytes32) {
        return _hashTypedDataV4(dataHash_);
    }

    /// @dev validate a signature originator. Handle EIP1271 and EOA signatures using SignatureChecker library.
    /// @param signer the expected signer address
    /// @param digest the digest hash supposed to be signed
    /// @param signature the signature to verify
    function _verifySignature(address signer, bytes32 digest, bytes calldata signature) private view {
        bool isValid = signer.isValidSignatureNow(digest, signature);
        require(isValid, "Dexcrow: invalid signature");
    }

    /// @dev Pause the protocol.
    function pause() external onlyOwner {
        _pause();
    }

    /// @dev Unpause the protocol.
    function unpause() external onlyOwner {
        _unpause();
    }
}
