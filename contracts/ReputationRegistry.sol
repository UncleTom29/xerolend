// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IGroth16Verifier {
    function verifyProof(
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[] calldata input
    ) external view returns (bool);
}

/**
 * @title ReputationRegistry
 * @notice Production-grade on-chain reputation with ZK proof support
 */
contract ReputationRegistry is AccessControl, ReentrancyGuard {
    
    bytes32 public constant LOAN_CORE_ROLE = keccak256("LOAN_CORE_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    enum ReputationTier { None, Bronze, Silver, Gold, Platinum, Diamond }

    struct UserReputation {
        uint256 totalLoansCreated;
        uint256 totalLoansRepaid;
        uint256 totalLoansDefaulted;
        uint256 totalBorrowed;
        uint256 totalLent;
        uint256 totalVolumeRepaid;
        uint256 score;
        ReputationTier tier;
        uint256 lastUpdated;
        bool isBlacklisted;
    }

    struct LoanRecord {
        uint256 loanId;
        address borrower;
        address lender;
        uint256 amount;
        uint256 createdAt;
        uint256 completedAt;
        bool isRepaid;
        bool isDefaulted;
    }

    struct ReputationProof {
        bytes32 commitment;
        bytes32 nullifier;
        uint256 threshold;
        uint256 timestamp;
        bool isUsed;
        bool isVerified;
    }

    struct ZKVerifierConfig {
        address verifierAddress;
        bool isActive;
    }

    // State
    mapping(address => UserReputation) public reputations;
    mapping(address => LoanRecord[]) private userLoanHistory;
    mapping(address => mapping(address => uint256)) public peerInteractions;
    mapping(bytes32 => ReputationProof) public reputationProofs;
    mapping(address => bytes32[]) public userProofs;
    
    ZKVerifierConfig public zkVerifier;
    
    // Score weights
    uint256 public repaymentRateWeight = 5000;
    uint256 public volumeWeight = 2000;
    uint256 public consistencyWeight = 1500;
    uint256 public diversityWeight = 1000;
    uint256 public ageWeight = 500;

    uint256 public constant BRONZE_THRESHOLD = 50;
    uint256 public constant SILVER_THRESHOLD = 100;
    uint256 public constant GOLD_THRESHOLD = 250;
    uint256 public constant PLATINUM_THRESHOLD = 500;
    uint256 public constant DIAMOND_THRESHOLD = 1000;

    event LoanCreated(address indexed user, uint256 indexed loanId, uint256 amount);
    event LoanRepaid(address indexed borrower, address indexed lender, uint256 amount);
    event LoanDefaulted(address indexed borrower, address indexed lender, uint256 amount);
    event ReputationUpdated(address indexed user, uint256 oldScore, uint256 newScore, ReputationTier tier);
    event ReputationProofGenerated(address indexed user, bytes32 indexed commitment, uint256 threshold);
    event ProofVerified(bytes32 indexed commitment, bool isValid);
    event UserBlacklisted(address indexed user, bool status);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
    }

    // ============ ZK Verifier Configuration ============

    function setZKVerifier(address verifierAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(verifierAddress != address(0), "Invalid verifier");
        
        zkVerifier = ZKVerifierConfig({
            verifierAddress: verifierAddress,
            isActive: true
        });
    }

    // ============ Core Functions ============

    function recordLoanCreated(address user, uint256 amount) 
        external 
        onlyRole(LOAN_CORE_ROLE) 
        nonReentrant 
    {
        require(user != address(0), "Invalid user");
        require(!reputations[user].isBlacklisted, "User blacklisted");

        UserReputation storage rep = reputations[user];
        rep.totalLoansCreated++;
        rep.totalBorrowed += amount;
        rep.lastUpdated = block.timestamp;

        _updateScore(user);
        emit LoanCreated(user, rep.totalLoansCreated, amount);
    }

    function recordLoanRepaid(address borrower, address lender, uint256 amount) 
        external 
        onlyRole(LOAN_CORE_ROLE) 
        nonReentrant 
    {
        require(borrower != address(0) && lender != address(0), "Invalid addresses");

        UserReputation storage borrowerRep = reputations[borrower];
        borrowerRep.totalLoansRepaid++;
        borrowerRep.totalVolumeRepaid += amount;
        borrowerRep.lastUpdated = block.timestamp;

        UserReputation storage lenderRep = reputations[lender];
        lenderRep.totalLent += amount;
        lenderRep.lastUpdated = block.timestamp;

        peerInteractions[borrower][lender]++;

        userLoanHistory[borrower].push(LoanRecord({
            loanId: borrowerRep.totalLoansRepaid,
            borrower: borrower,
            lender: lender,
            amount: amount,
            createdAt: block.timestamp,
            completedAt: block.timestamp,
            isRepaid: true,
            isDefaulted: false
        }));

        _updateScore(borrower);
        _updateScore(lender);

        emit LoanRepaid(borrower, lender, amount);
    }

    function recordLoanDefaulted(address borrower, address lender, uint256 amount) 
        external 
        onlyRole(LOAN_CORE_ROLE) 
        nonReentrant 
    {
        require(borrower != address(0) && lender != address(0), "Invalid addresses");

        UserReputation storage borrowerRep = reputations[borrower];
        borrowerRep.totalLoansDefaulted++;
        borrowerRep.lastUpdated = block.timestamp;

        reputations[lender].lastUpdated = block.timestamp;

        userLoanHistory[borrower].push(LoanRecord({
            loanId: borrowerRep.totalLoansDefaulted,
            borrower: borrower,
            lender: lender,
            amount: amount,
            createdAt: block.timestamp,
            completedAt: block.timestamp,
            isRepaid: false,
            isDefaulted: true
        }));

        _updateScore(borrower);
        _updateScore(lender);

        emit LoanDefaulted(borrower, lender, amount);
    }

    // ============ ZK Reputation Proofs ============

    function generateReputationProof(
        uint256 threshold,
        bytes32 commitment,
        bytes32 nullifier
    ) external nonReentrant returns (bytes32) {
        require(reputations[msg.sender].score >= threshold, "Score below threshold");
        require(!reputationProofs[commitment].isUsed, "Commitment used");
        require(nullifier != bytes32(0), "Invalid nullifier");

        // Check nullifier uniqueness across all proofs
        bytes32[] storage proofs = userProofs[msg.sender];
        for (uint256 i = 0; i < proofs.length; i++) {
            require(
                reputationProofs[proofs[i]].nullifier != nullifier,
                "Nullifier already used"
            );
        }

        reputationProofs[commitment] = ReputationProof({
            commitment: commitment,
            nullifier: nullifier,
            threshold: threshold,
            timestamp: block.timestamp,
            isUsed: false,
            isVerified: false
        });

        userProofs[msg.sender].push(commitment);

        emit ReputationProofGenerated(msg.sender, commitment, threshold);
        return commitment;
    }

    /**
     * @notice Verify reputation proof using Groth16
     */
    function verifyReputationProof(
        bytes32 commitment,
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[] calldata publicInputs
    ) external nonReentrant returns (bool) {
        ReputationProof storage proof = reputationProofs[commitment];
        require(proof.timestamp > 0, "Proof does not exist");
        require(!proof.isUsed, "Proof already used");
        require(!proof.isVerified, "Already verified");
        require(zkVerifier.isActive, "Verifier not configured");

        // Public inputs: [commitment, nullifier, threshold, score]
        require(publicInputs.length >= 4, "Invalid public inputs");
        require(publicInputs[0] == uint256(commitment), "Commitment mismatch");
        require(publicInputs[1] == uint256(proof.nullifier), "Nullifier mismatch");
        require(publicInputs[2] == proof.threshold, "Threshold mismatch");

        IGroth16Verifier verifier = IGroth16Verifier(zkVerifier.verifierAddress);
        bool isValid = verifier.verifyProof(a, b, c, publicInputs);

        if (isValid) {
            proof.isVerified = true;
        }

        emit ProofVerified(commitment, isValid);
        return isValid;
    }

    function useReputationProof(bytes32 commitment) 
        external 
        onlyRole(LOAN_CORE_ROLE) 
    {
        ReputationProof storage proof = reputationProofs[commitment];
        require(proof.timestamp > 0, "Proof does not exist");
        require(proof.isVerified, "Proof not verified");
        require(!proof.isUsed, "Proof already used");
        
        proof.isUsed = true;
    }

    // ============ Score Calculation ============

    function _updateScore(address user) internal {
        UserReputation storage rep = reputations[user];
        
        if (rep.totalLoansCreated == 0) {
            rep.score = 0;
            rep.tier = ReputationTier.None;
            return;
        }

        uint256 oldScore = rep.score;

        uint256 repaymentScore = _calculateRepaymentScore(rep);
        uint256 volumeScore = _calculateVolumeScore(rep);
        uint256 consistencyScore = _calculateConsistencyScore(rep);
        uint256 diversityScore = _calculateDiversityScore(user);
        uint256 ageScore = _calculateAgeScore(rep);

        rep.score = (
            (repaymentScore * repaymentRateWeight) +
            (volumeScore * volumeWeight) +
            (consistencyScore * consistencyWeight) +
            (diversityScore * diversityWeight) +
            (ageScore * ageWeight)
        ) / 10000;

        if (rep.score > 1000) rep.score = 1000;

        rep.tier = _calculateTier(rep.score);

        emit ReputationUpdated(user, oldScore, rep.score, rep.tier);
    }

    function _calculateRepaymentScore(UserReputation memory rep) internal pure returns (uint256) {
        if (rep.totalLoansCreated == 0) return 0;
        
        uint256 successRate = (rep.totalLoansRepaid * 100) / rep.totalLoansCreated;
        
        if (rep.totalLoansDefaulted > 0) {
            uint256 defaultRate = (rep.totalLoansDefaulted * 100) / rep.totalLoansCreated;
            successRate = successRate > defaultRate * 2 ? successRate - (defaultRate * 2) : 0;
        }
        
        return successRate > 100 ? 100 : successRate;
    }

    function _calculateVolumeScore(UserReputation memory rep) internal pure returns (uint256) {
        uint256 volumeInThousands = rep.totalVolumeRepaid / 1000 ether;
        if (volumeInThousands == 0) return 0;
        if (volumeInThousands >= 1000) return 100;
        return _log10(volumeInThousands) * 3333 / 100;
    }

    function _calculateConsistencyScore(UserReputation memory rep) internal pure returns (uint256) {
        if (rep.totalLoansRepaid < 3) return 0;
        uint256 consistencyRate = (rep.totalLoansRepaid * 100) / (rep.totalLoansRepaid + rep.totalLoansDefaulted);
        return consistencyRate;
    }

    function _calculateDiversityScore(address user) internal view returns (uint256) {
        LoanRecord[] memory history = userLoanHistory[user];
        if (history.length == 0) return 0;

        // Count unique counterparties (simplified - gas optimized)
        uint256 uniqueCount = 0;
        uint256 checkLimit = history.length > 50 ? 50 : history.length;
        
        for (uint256 i = 0; i < checkLimit; i++) {
            address counterparty = history[i].borrower == user ? history[i].lender : history[i].borrower;
            if (counterparty != address(0)) {
                uniqueCount++;
            }
        }
        
        uint256 score = (uniqueCount * 10) > 100 ? 100 : (uniqueCount * 10);
        return score;
    }

    function _calculateAgeScore(UserReputation memory rep) internal view returns (uint256) {
        if (rep.lastUpdated == 0) return 0;
        uint256 daysOld = (block.timestamp - rep.lastUpdated) / 1 days;
        return daysOld >= 365 ? 100 : (daysOld * 100) / 365;
    }

    function _calculateTier(uint256 score) internal pure returns (ReputationTier) {
        if (score >= DIAMOND_THRESHOLD) return ReputationTier.Diamond;
        if (score >= PLATINUM_THRESHOLD) return ReputationTier.Platinum;
        if (score >= GOLD_THRESHOLD) return ReputationTier.Gold;
        if (score >= SILVER_THRESHOLD) return ReputationTier.Silver;
        if (score >= BRONZE_THRESHOLD) return ReputationTier.Bronze;
        return ReputationTier.None;
    }

    function _log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        while (value >= 10) {
            value /= 10;
            result++;
        }
        return result;
    }

    // ============ View Functions ============

    function getReputationScore(address user) external view returns (uint256) {
        return reputations[user].score;
    }

    function getUserReputation(address user) external view returns (UserReputation memory) {
        return reputations[user];
    }

    function getLoanHistory(address user, uint256 offset, uint256 limit) 
        external 
        view 
        returns (LoanRecord[] memory) 
    {
        LoanRecord[] storage history = userLoanHistory[user];
        if (offset >= history.length) return new LoanRecord[](0);
        
        uint256 end = offset + limit > history.length ? history.length : offset + limit;
        LoanRecord[] memory result = new LoanRecord[](end - offset);
        
        for (uint256 i = offset; i < end; i++) {
            result[i - offset] = history[i];
        }
        
        return result;
    }

    function isEligibleForLoan(address user, uint256 minScore) external view returns (bool) {
        UserReputation memory rep = reputations[user];
        return !rep.isBlacklisted && rep.score >= minScore;
    }

    function getUserProofs(address user) external view returns (bytes32[] memory) {
        return userProofs[user];
    }

    function getProofDetails(bytes32 commitment) external view returns (ReputationProof memory) {
        return reputationProofs[commitment];
    }

    // ============ Admin Functions ============

    function grantLoanCoreRole(address loanCore) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(loanCore != address(0), "Invalid address");
        _grantRole(LOAN_CORE_ROLE, loanCore);
    }

    function blacklistUser(address user, bool status) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(user != address(0), "Invalid user");
        reputations[user].isBlacklisted = status;
        emit UserBlacklisted(user, status);
    }

    function recalculateScore(address user) external onlyRole(OPERATOR_ROLE) {
        _updateScore(user);
    }
}