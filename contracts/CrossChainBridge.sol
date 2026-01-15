// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title CrossChainBridge
 * @notice Bridge for cross-chain collateral (Ethereum Mainnet <-> Mantle)
 * @dev For mainnet only - allows NFTs and RWAs on Ethereum to be used as collateral on Mantle
 */
contract CrossChainBridge is AccessControl, ReentrancyGuard {
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");
    bytes32 public constant LOAN_CORE_ROLE = keccak256("LOAN_CORE_ROLE");

    enum AssetType { ERC20, ERC721, ERC1155 }
    enum LockStatus { Locked, Released, Seized }

    struct CrossChainLock {
        address owner;
        address ethereumAsset;
        uint256 tokenIdOrAmount;
        AssetType assetType;
        bytes32 ethereumTxHash;
        LockStatus status;
        uint256 lockedAt;
        uint256 releasedAt;
        address releaseTo;
    }

    struct AssetConfig {
        bool isSupported;
        AssetType assetType;
        address mantleRepresentation;  // Wrapped version on Mantle (if exists)
        bool requiresProof;
    }

    // State
    mapping(bytes32 => CrossChainLock) public locks;  // lockId => lock details
    mapping(address => AssetConfig) public supportedAssets;  // ethereum asset => config
    mapping(address => bytes32[]) public userLocks;
    
    uint256 public minConfirmations = 12;  // Ethereum block confirmations required
    uint256 public lockCounter;
    
    // Relayer consensus
    mapping(bytes32 => mapping(address => bool)) public relayerVotes;  // lockId => relayer => voted
    mapping(bytes32 => uint256) public voteCount;
    uint256 public requiredRelayers = 2;  // 2 of 3 relayers must confirm

    event CollateralLocked(
        bytes32 indexed lockId,
        address indexed owner,
        address ethereumAsset,
        uint256 tokenIdOrAmount,
        bytes32 ethereumTxHash
    );

    event CollateralReleased(
        bytes32 indexed lockId,
        address indexed recipient,
        bytes32 mantleTxHash
    );

    event CollateralSeized(
        bytes32 indexed lockId,
        address indexed seizedBy
    );

    event RelayerVoted(bytes32 indexed lockId, address indexed relayer);
    event AssetSupported(address indexed ethereumAsset, AssetType assetType);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(RELAYER_ROLE, msg.sender);
    }

    // ============ Lock Verification ============

    /**
     * @notice Verify cross-chain lock from Ethereum
     * @dev Called by LoanCore when user creates cross-chain collateral loan
     */
    function verifyLock(
        address owner,
        address ethereumAsset,
        uint256 tokenIdOrAmount,
        bytes32 ethereumTxHash,
        bytes calldata proof
    ) external onlyRole(LOAN_CORE_ROLE) returns (bool) {
        require(supportedAssets[ethereumAsset].isSupported, "Asset not supported");
        require(ethereumTxHash != bytes32(0), "Invalid tx hash");

        bytes32 lockId = keccak256(abi.encodePacked(
            owner,
            ethereumAsset,
            tokenIdOrAmount,
            ethereumTxHash,
            block.timestamp
        ));

        // Check if already processed
        require(locks[lockId].owner == address(0), "Lock already exists");

        // In production, verify Merkle proof or relay signature
        // For now, trust if proof is non-empty
        require(proof.length > 0, "Proof required");

        locks[lockId] = CrossChainLock({
            owner: owner,
            ethereumAsset: ethereumAsset,
            tokenIdOrAmount: tokenIdOrAmount,
            assetType: supportedAssets[ethereumAsset].assetType,
            ethereumTxHash: ethereumTxHash,
            status: LockStatus.Locked,
            lockedAt: block.timestamp,
            releasedAt: 0,
            releaseTo: address(0)
        });

        userLocks[owner].push(lockId);
        lockCounter++;

        emit CollateralLocked(lockId, owner, ethereumAsset, tokenIdOrAmount, ethereumTxHash);

        return true;
    }

    /**
     * @notice Relayer submits lock confirmation from Ethereum
     * @dev Multiple relayers must confirm for consensus
     */
    function confirmLock(
        address owner,
        address ethereumAsset,
        uint256 tokenIdOrAmount,
        bytes32 ethereumTxHash
    ) external onlyRole(RELAYER_ROLE) nonReentrant returns (bytes32) {
        bytes32 lockId = keccak256(abi.encodePacked(
            owner,
            ethereumAsset,
            tokenIdOrAmount,
            ethereumTxHash,
            block.timestamp  // Include timestamp for uniqueness
        ));

        require(!relayerVotes[lockId][msg.sender], "Already voted");

        relayerVotes[lockId][msg.sender] = true;
        voteCount[lockId]++;

        emit RelayerVoted(lockId, msg.sender);

        // If enough confirmations, create lock
        if (voteCount[lockId] >= requiredRelayers) {
            if (locks[lockId].owner == address(0)) {
                locks[lockId] = CrossChainLock({
                    owner: owner,
                    ethereumAsset: ethereumAsset,
                    tokenIdOrAmount: tokenIdOrAmount,
                    assetType: supportedAssets[ethereumAsset].assetType,
                    ethereumTxHash: ethereumTxHash,
                    status: LockStatus.Locked,
                    lockedAt: block.timestamp,
                    releasedAt: 0,
                    releaseTo: address(0)
                });

                userLocks[owner].push(lockId);
                lockCounter++;

                emit CollateralLocked(lockId, owner, ethereumAsset, tokenIdOrAmount, ethereumTxHash);
            }
        }

        return lockId;
    }

    // ============ Release Functions ============

    /**
     * @notice Release collateral back to owner or transfer to lender
     * @dev Called by LoanCore on repayment or default
     */
    function releaseTo(
        address ethereumAsset,
        address recipient,
        uint256 tokenIdOrAmount,
        address caller
    ) external onlyRole(LOAN_CORE_ROLE) returns (bool) {
        // Find the lock
        bytes32 lockId = _findUserLock(caller, ethereumAsset, tokenIdOrAmount);
        require(lockId != bytes32(0), "Lock not found");

        CrossChainLock storage lock = locks[lockId];
        require(lock.status == LockStatus.Locked, "Not locked");

        lock.status = LockStatus.Released;
        lock.releasedAt = block.timestamp;
        lock.releaseTo = recipient;

        // In production, would initiate Ethereum unlock transaction via relayers
        // Emit event that relayers listen to
        bytes32 mantleTxHash = keccak256(abi.encodePacked(lockId, recipient, block.timestamp));
        
        emit CollateralReleased(lockId, recipient, mantleTxHash);

        return true;
    }

    /**
     * @notice Seize collateral on default
     */
    function seizeCollateral(bytes32 lockId, address seizedBy) 
        external 
        onlyRole(LOAN_CORE_ROLE) 
    {
        CrossChainLock storage lock = locks[lockId];
        require(lock.status == LockStatus.Locked, "Not locked");

        lock.status = LockStatus.Seized;
        lock.releasedAt = block.timestamp;
        lock.releaseTo = seizedBy;

        emit CollateralSeized(lockId, seizedBy);
    }

    // ============ Helper Functions ============

    function _findUserLock(
        address user,
        address ethereumAsset,
        uint256 tokenIdOrAmount
    ) internal view returns (bytes32) {
        bytes32[] memory userLockIds = userLocks[user];
        
        for (uint256 i = 0; i < userLockIds.length; i++) {
            CrossChainLock memory lock = locks[userLockIds[i]];
            if (lock.ethereumAsset == ethereumAsset &&
                lock.tokenIdOrAmount == tokenIdOrAmount &&
                lock.status == LockStatus.Locked) {
                return userLockIds[i];
            }
        }
        
        return bytes32(0);
    }

    // ============ View Functions ============

    function getLock(bytes32 lockId) external view returns (CrossChainLock memory) {
        return locks[lockId];
    }

    function getUserLocks(address user) external view returns (bytes32[] memory) {
        return userLocks[user];
    }

    function isAssetSupported(address ethereumAsset) external view returns (bool) {
        return supportedAssets[ethereumAsset].isSupported;
    }

    function getLockStatus(bytes32 lockId) external view returns (LockStatus) {
        return locks[lockId].status;
    }

    // ============ Admin Functions ============

    /**
     * @notice Add supported Ethereum asset
     */
    function supportAsset(
        address ethereumAsset,
        AssetType assetType,
        address mantleRepresentation,
        bool requiresProof
    ) external onlyRole(ADMIN_ROLE) {
        require(ethereumAsset != address(0), "Invalid asset");

        supportedAssets[ethereumAsset] = AssetConfig({
            isSupported: true,
            assetType: assetType,
            mantleRepresentation: mantleRepresentation,
            requiresProof: requiresProof
        });

        emit AssetSupported(ethereumAsset, assetType);
    }

    function removeAssetSupport(address ethereumAsset) external onlyRole(ADMIN_ROLE) {
        supportedAssets[ethereumAsset].isSupported = false;
    }

    function setMinConfirmations(uint256 _minConfirmations) external onlyRole(ADMIN_ROLE) {
        require(_minConfirmations >= 6, "Too low");
        minConfirmations = _minConfirmations;
    }

    function setRequiredRelayers(uint256 _required) external onlyRole(ADMIN_ROLE) {
        require(_required > 0 && _required <= 10, "Invalid count");
        requiredRelayers = _required;
    }

    function grantLoanCoreRole(address loanCore) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(loanCore != address(0), "Invalid address");
        _grantRole(LOAN_CORE_ROLE, loanCore);
    }
}