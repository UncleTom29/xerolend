// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Groth16 Verifier Interface
 */
interface IGroth16Verifier {
    function verifyProof(
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[] calldata input
    ) external view returns (bool);
}

/**
 * @title PrivacyModule
 * @notice Production-grade ZK proof verification for private loans
 */
contract PrivacyModule is AccessControl, ReentrancyGuard {
    
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant LOAN_CORE_ROLE = keccak256("LOAN_CORE_ROLE");

    enum ProofType {
        CollateralValue,
        LoanAmount,
        InterestRate,
        Reputation,
        Ownership,
        SelectiveDisclosure
    }

    struct Commitment {
        bytes32 commitment;
        address creator;
        uint256 timestamp;
        ProofType proofType;
        bool isVerified;
        bool isUsed;
    }

    struct Nullifier {
        bytes32 nullifier;
        uint256 timestamp;
        address user;
        bool isUsed;
    }

    struct ProofVerification {
        bytes32 proofHash;
        bytes32 commitment;
        address verifier;
        uint256 timestamp;
        bool isValid;
    }

    struct PrivacySettings {
        bool hideAmount;
        bool hideCollateral;
        bool hideInterestRate;
        bool hideParties;
        bool allowSelectiveDisclosure;
    }

    struct VerifierConfig {
        address verifierAddress;
        bool isActive;
        uint256 minPublicInputs;
        uint256 maxPublicInputs;
    }

    // Efficient tracking
    struct Stats {
        uint256 totalCommitments;
        uint256 verifiedCommitments;
        uint256 usedCommitments;
        uint256 totalNullifiers;
        uint256 failedVerifications;
    }

    // State
    mapping(bytes32 => Commitment) public commitments;
    mapping(bytes32 => Nullifier) public nullifiers;
    mapping(bytes32 => ProofVerification) public proofVerifications;
    mapping(address => bytes32[]) public userCommitments;
    mapping(address => bytes32[]) public userNullifiers;
    mapping(uint256 => PrivacySettings) public loanPrivacySettings;
    mapping(ProofType => VerifierConfig) public verifiers;
    
    Stats public stats;
    uint256 public proofValidityPeriod = 1 hours;

    event CommitmentCreated(bytes32 indexed commitment, address indexed creator, ProofType proofType);
    event ProofVerified(bytes32 indexed proofHash, bytes32 indexed commitment, bool isValid);
    event NullifierUsed(bytes32 indexed nullifier, address indexed user);
    event VerifierConfigured(ProofType indexed proofType, address verifier);
    event SelectiveDisclosureGranted(bytes32 indexed commitment, address indexed recipient);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(VERIFIER_ROLE, msg.sender);
    }

    // ============ Verifier Configuration ============

    function setVerifier(
        ProofType proofType,
        address verifierAddress,
        uint256 minInputs,
        uint256 maxInputs
    ) external onlyRole(ADMIN_ROLE) {
        require(verifierAddress != address(0), "Invalid verifier");
        require(maxInputs >= minInputs, "Invalid input range");

        verifiers[proofType] = VerifierConfig({
            verifierAddress: verifierAddress,
            isActive: true,
            minPublicInputs: minInputs,
            maxPublicInputs: maxInputs
        });

        emit VerifierConfigured(proofType, verifierAddress);
    }

    // ============ Commitment Functions ============

    function createCommitment(
        bytes32 commitment,
        ProofType proofType
    ) external nonReentrant returns (bytes32) {
        require(commitment != bytes32(0), "Invalid commitment");
        require(commitments[commitment].timestamp == 0, "Commitment exists");

        commitments[commitment] = Commitment({
            commitment: commitment,
            creator: msg.sender,
            timestamp: block.timestamp,
            proofType: proofType,
            isVerified: false,
            isUsed: false
        });

        userCommitments[msg.sender].push(commitment);
        stats.totalCommitments++;

        emit CommitmentCreated(commitment, msg.sender, proofType);
        return commitment;
    }

    // ============ ZK Proof Verification ============

    /**
     * @notice Verify Groth16 proof with proper parsing
     */
    function verifyGroth16Proof(
        bytes32 commitment,
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[] calldata publicInputs
    ) external onlyRole(VERIFIER_ROLE) nonReentrant returns (bool) {
        Commitment storage comm = commitments[commitment];
        require(comm.timestamp > 0, "Commitment not found");
        require(!comm.isVerified, "Already verified");

        VerifierConfig memory config = verifiers[comm.proofType];
        require(config.isActive, "Verifier not configured");
        require(
            publicInputs.length >= config.minPublicInputs &&
            publicInputs.length <= config.maxPublicInputs,
            "Invalid public inputs"
        );

        // Verify commitment is in public inputs
        require(publicInputs[0] == uint256(commitment), "Commitment mismatch");

        // Call Groth16 verifier
        IGroth16Verifier verifier = IGroth16Verifier(config.verifierAddress);
        bool isValid = verifier.verifyProof(a, b, c, publicInputs);

        bytes32 proofHash = keccak256(abi.encodePacked(a, b, c, publicInputs));

        if (isValid) {
            comm.isVerified = true;
            stats.verifiedCommitments++;
        } else {
            stats.failedVerifications++;
        }

        proofVerifications[proofHash] = ProofVerification({
            proofHash: proofHash,
            commitment: commitment,
            verifier: msg.sender,
            timestamp: block.timestamp,
            isValid: isValid
        });

        emit ProofVerified(proofHash, commitment, isValid);
        return isValid;
    }

    /**
     * @notice Verify collateral value proof
     */
    function verifyCollateralProof(
        bytes32 commitment,
        uint256 minValue,
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[] calldata publicInputs
    ) external onlyRole(VERIFIER_ROLE) nonReentrant returns (bool) {
        require(publicInputs.length >= 2, "Missing public inputs");
        require(publicInputs[1] >= minValue, "Value below minimum");

        return this.verifyGroth16Proof(commitment, a, b, c, publicInputs);
    }

    /**
     * @notice Verify reputation proof with nullifier
     */
    function verifyReputationProof(
        bytes32 commitment,
        bytes32 nullifier,
        uint256 threshold,
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[] calldata publicInputs
    ) external onlyRole(VERIFIER_ROLE) nonReentrant returns (bool) {
        require(!nullifiers[nullifier].isUsed, "Nullifier already used");
        require(publicInputs.length >= 3, "Missing public inputs");
        require(publicInputs[1] == uint256(nullifier), "Nullifier mismatch");
        require(publicInputs[2] >= threshold, "Below threshold");

        bool isValid = this.verifyGroth16Proof(commitment, a, b, c, publicInputs);

        if (isValid) {
            nullifiers[nullifier] = Nullifier({
                nullifier: nullifier,
                timestamp: block.timestamp,
                user: msg.sender,
                isUsed: true
            });

            userNullifiers[msg.sender].push(nullifier);
            stats.totalNullifiers++;

            emit NullifierUsed(nullifier, msg.sender);
        }

        return isValid;
    }

    /**
     * @notice Verify selective disclosure proof
     */
    function verifySelectiveDisclosure(
        bytes32 commitment,
        address recipient,
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[] calldata publicInputs
    ) external nonReentrant returns (bool) {
        Commitment storage comm = commitments[commitment];
        require(comm.creator == msg.sender, "Not commitment creator");
        require(comm.isVerified, "Commitment not verified");
        require(recipient != address(0), "Invalid recipient");
        require(publicInputs.length >= 2, "Missing public inputs");
        require(publicInputs[1] == uint256(uint160(recipient)), "Recipient mismatch");

        VerifierConfig memory config = verifiers[ProofType.SelectiveDisclosure];
        require(config.isActive, "Disclosure verifier not configured");

        IGroth16Verifier verifier = IGroth16Verifier(config.verifierAddress);
        bool isValid = verifier.verifyProof(a, b, c, publicInputs);

        if (isValid) {
            emit SelectiveDisclosureGranted(commitment, recipient);
        }

        return isValid;
    }

    // ============ Batch Verification ============

    function batchVerifyProofs(
        bytes32[] calldata commitmentList,
        uint256[2][] calldata aList,
        uint256[2][2][] calldata bList,
        uint256[2][] calldata cList,
        uint256[][] calldata publicInputsList
    ) external onlyRole(VERIFIER_ROLE) nonReentrant returns (bool[] memory) {
        require(
            commitmentList.length == aList.length &&
            aList.length == bList.length &&
            bList.length == cList.length &&
            cList.length == publicInputsList.length,
            "Length mismatch"
        );

        bool[] memory results = new bool[](commitmentList.length);

        for (uint256 i = 0; i < commitmentList.length; i++) {
            try this.verifyGroth16Proof(
                commitmentList[i],
                aList[i],
                bList[i],
                cList[i],
                publicInputsList[i]
            ) returns (bool result) {
                results[i] = result;
            } catch {
                results[i] = false;
                stats.failedVerifications++;
            }
        }

        return results;
    }

    // ============ Privacy Settings ============

    function setLoanPrivacySettings(
        uint256 loanId,
        bool hideAmount,
        bool hideCollateral,
        bool hideInterestRate,
        bool hideParties,
        bool allowSelectiveDisclosure
    ) external onlyRole(LOAN_CORE_ROLE) {
        loanPrivacySettings[loanId] = PrivacySettings({
            hideAmount: hideAmount,
            hideCollateral: hideCollateral,
            hideInterestRate: hideInterestRate,
            hideParties: hideParties,
            allowSelectiveDisclosure: allowSelectiveDisclosure
        });
    }

    // ============ Commitment Management ============

    function useCommitment(bytes32 commitment) 
        external 
        onlyRole(LOAN_CORE_ROLE) 
    {
        require(commitments[commitment].isVerified, "Not verified");
        require(!commitments[commitment].isUsed, "Already used");

        commitments[commitment].isUsed = true;
        stats.usedCommitments++;
    }

    // ============ View Functions ============

    function isCommitmentValid(bytes32 commitment) external view returns (bool) {
        Commitment memory comm = commitments[commitment];
        return comm.timestamp > 0 && 
               comm.isVerified && 
               !comm.isUsed &&
               block.timestamp - comm.timestamp < proofValidityPeriod;
    }

    function getStats() external view returns (Stats memory) {
        return stats;
    }

    function getCommitment(bytes32 commitment) external view returns (Commitment memory) {
        return commitments[commitment];
    }

    function isNullifierUsed(bytes32 nullifier) external view returns (bool) {
        return nullifiers[nullifier].isUsed;
    }

    function getUserCommitments(address user) external view returns (bytes32[] memory) {
        return userCommitments[user];
    }

    function getVerifierConfig(ProofType proofType) external view returns (VerifierConfig memory) {
        return verifiers[proofType];
    }

    // ============ Admin Functions ============

    function setProofValidityPeriod(uint256 period) external onlyRole(ADMIN_ROLE) {
        require(period >= 1 hours && period <= 7 days, "Invalid period");
        proofValidityPeriod = period;
    }

    function deactivateVerifier(ProofType proofType) external onlyRole(ADMIN_ROLE) {
        verifiers[proofType].isActive = false;
    }

    function revokeCommitment(bytes32 commitment) external onlyRole(ADMIN_ROLE) {
        require(commitments[commitment].timestamp > 0, "Not found");
        commitments[commitment].isUsed = true;
        stats.usedCommitments++;
    }

    function grantLoanCoreRole(address loanCore) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(loanCore != address(0), "Invalid address");
        _grantRole(LOAN_CORE_ROLE, loanCore);
    }
}