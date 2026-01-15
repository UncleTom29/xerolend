// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title LoanCore
 * @notice Core lending with RWA support, optional privacy, and cross-chain collateral
 */
contract LoanCore is ReentrancyGuard, Pausable, AccessControl {
    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");

    enum LoanStatus { 
        Active,       // Loan funded and active
        Repaid,       // Loan fully repaid
        Defaulted,    // Loan defaulted
        Cancelled     // Loan cancelled
    }

    enum CollateralType { 
        ERC20,        // Stablecoins, crypto, RWAs
        ERC721,       // NFTs
        ERC1155,      // Multi-edition tokens
        CrossChain    // Cross-chain collateral (Ethereum mainnet)
    }

    enum AssetCategory {
        Stablecoin,   // USDC, DAI, USDT
        Crypto,       // WETH, WBTC, LINK
        RWA,          // OUSG, XAUM
        NFT,          // BAYC, PUNK
        GameFi        // Game tokens
    }

    struct Loan {
        uint256 loanId;
        address borrower;
        address lender;
        address principalToken;
        uint256 principalAmount;
        uint256 interestRate;           // Basis points (100 = 1%)
        uint256 duration;                // Seconds
        uint256 startTime;
        CollateralType collateralType;
        address collateralAsset;
        uint256 collateralTokenId;      // For NFTs
        uint256 collateralAmount;       // For ERC20/ERC1155
        LoanStatus status;
        uint256 repaidAmount;
        bool isPrivate;                 // Optional privacy
        bytes32 privacyCommitment;      // ZK commitment if private
        bool isCrossChain;              // Collateral on Ethereum mainnet
        bytes32 crossChainProof;        // Cross-chain proof hash
    }

    struct AssetInfo {
        AssetCategory category;
        bool isWhitelisted;
        uint256 minCollateralRatio;    // Basis points (15000 = 150%)
        bool supportsPrivacy;           // Can be used with privacy
        bool isCrossChainAsset;        // Asset deployed on Ethereum mainnet
    }

    struct CrossChainCollateral {
        address ethereumAddress;        // Asset address on Ethereum mainnet
        uint256 tokenId;                // For NFTs
        uint256 amount;                 // For ERC20
        bytes32 lockTxHash;            // Ethereum lock transaction
        bool isLocked;
        bool isReleased;
    }

    uint256 public loanCounter;
    
    mapping(uint256 => Loan) public loans;
    mapping(address => AssetInfo) public assetInfo;
    mapping(address => uint256[]) public userLoans;
    mapping(uint256 => CrossChainCollateral) public crossChainCollaterals;
    
    uint256 public constant MAX_INTEREST_RATE = 10000;      // 100%
    uint256 public constant MIN_LOAN_DURATION = 1 hours;
    uint256 public constant MAX_LOAN_DURATION = 365 days;
    uint256 public protocolFee = 50;                        // 0.5%
    
    address public feeCollector;
    address public reputationRegistry;
    address public privacyModule;
    address public crossChainBridge;

    event LoanCreated(
        uint256 indexed loanId,
        address indexed borrower,
        address principalToken,
        uint256 principalAmount,
        uint256 interestRate,
        CollateralType collateralType,
        address collateralAsset,
        bool isPrivate,
        bool isCrossChain
    );

    event LoanFunded(uint256 indexed loanId, address indexed lender);
    event LoanRepaid(uint256 indexed loanId, uint256 amount, bool isFull);
    event LoanDefaulted(uint256 indexed loanId);
    event CollateralSeized(uint256 indexed loanId, address indexed lender);
    event CrossChainCollateralLocked(uint256 indexed loanId, bytes32 lockTxHash);
    event CrossChainCollateralReleased(uint256 indexed loanId, bytes32 releaseTxHash);

    constructor(address _feeCollector) {
        require(_feeCollector != address(0), "Invalid fee collector");
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        
        feeCollector = _feeCollector;
        loanCounter = 1;
    }

    // ============ Simplified Loan Creation ============

    /**
     * @notice Create loan with ERC20 collateral (Stablecoins, Crypto, RWAs)
     */
    function createLoanERC20(
        address principalToken,
        uint256 principalAmount,
        uint256 interestRate,
        uint256 duration,
        address collateralToken,
        uint256 collateralAmount,
        bool isPrivate,
        bytes32 privacyCommitment
    ) external nonReentrant whenNotPaused returns (uint256) {
        require(assetInfo[principalToken].isWhitelisted, "Principal token not whitelisted");
        require(assetInfo[collateralToken].isWhitelisted, "Collateral token not whitelisted");
        require(principalAmount > 0, "Invalid principal");
        require(interestRate <= MAX_INTEREST_RATE, "Interest too high");
        require(duration >= MIN_LOAN_DURATION && duration <= MAX_LOAN_DURATION, "Invalid duration");
        require(collateralAmount > 0, "Invalid collateral amount");
        
        if (isPrivate) {
            require(privacyModule != address(0), "Privacy module not set");
            require(assetInfo[collateralToken].supportsPrivacy, "Asset doesn't support privacy");
            require(privacyCommitment != bytes32(0), "Privacy commitment required");
        }

        uint256 loanId = loanCounter++;

        loans[loanId] = Loan({
            loanId: loanId,
            borrower: msg.sender,
            lender: address(0),
            principalToken: principalToken,
            principalAmount: principalAmount,
            interestRate: interestRate,
            duration: duration,
            startTime: 0,
            collateralType: CollateralType.ERC20,
            collateralAsset: collateralToken,
            collateralTokenId: 0,
            collateralAmount: collateralAmount,
            status: LoanStatus.Cancelled,
            repaidAmount: 0,
            isPrivate: isPrivate,
            privacyCommitment: privacyCommitment,
            isCrossChain: false,
            crossChainProof: bytes32(0)
        });

        // Transfer collateral to contract
        IERC20(collateralToken).safeTransferFrom(msg.sender, address(this), collateralAmount);

        userLoans[msg.sender].push(loanId);
        
        // Register with privacy module if private
        if (isPrivate && privacyModule != address(0)) {
            (bool success, ) = privacyModule.call(
                abi.encodeWithSignature("useCommitment(bytes32)", privacyCommitment)
            );
            // Don't revert if privacy registration fails
        }

        emit LoanCreated(
            loanId,
            msg.sender,
            principalToken,
            principalAmount,
            interestRate,
            CollateralType.ERC20,
            collateralToken,
            isPrivate,
            false
        );

        return loanId;
    }

    /**
     * @notice Create loan with NFT collateral
     */
    function createLoanNFT(
        address principalToken,
        uint256 principalAmount,
        uint256 interestRate,
        uint256 duration,
        address nftCollection,
        uint256 tokenId,
        bool isPrivate,
        bytes32 privacyCommitment
    ) external nonReentrant whenNotPaused returns (uint256) {
        require(assetInfo[principalToken].isWhitelisted, "Principal token not whitelisted");
        require(assetInfo[nftCollection].isWhitelisted, "NFT not whitelisted");
        require(principalAmount > 0, "Invalid principal");
        require(interestRate <= MAX_INTEREST_RATE, "Interest too high");
        require(duration >= MIN_LOAN_DURATION && duration <= MAX_LOAN_DURATION, "Invalid duration");

        if (isPrivate) {
            require(privacyModule != address(0), "Privacy module not set");
            require(privacyCommitment != bytes32(0), "Privacy commitment required");
        }

        uint256 loanId = loanCounter++;

        loans[loanId] = Loan({
            loanId: loanId,
            borrower: msg.sender,
            lender: address(0),
            principalToken: principalToken,
            principalAmount: principalAmount,
            interestRate: interestRate,
            duration: duration,
            startTime: 0,
            collateralType: CollateralType.ERC721,
            collateralAsset: nftCollection,
            collateralTokenId: tokenId,
            collateralAmount: 1,
            status: LoanStatus.Cancelled,
            repaidAmount: 0,
            isPrivate: isPrivate,
            privacyCommitment: privacyCommitment,
            isCrossChain: false,
            crossChainProof: bytes32(0)
        });

        // Transfer NFT to contract
        IERC721(nftCollection).transferFrom(msg.sender, address(this), tokenId);

        userLoans[msg.sender].push(loanId);

        if (isPrivate && privacyModule != address(0)) {
            (bool success, ) = privacyModule.call(
                abi.encodeWithSignature("useCommitment(bytes32)", privacyCommitment)
            );
        }

        emit LoanCreated(
            loanId,
            msg.sender,
            principalToken,
            principalAmount,
            interestRate,
            CollateralType.ERC721,
            nftCollection,
            isPrivate,
            false
        );

        return loanId;
    }

    /**
     * @notice Create loan with cross-chain collateral (Ethereum mainnet NFTs/RWAs)
     * @dev Only for mainnet deployment - collateral stays on Ethereum
     */
    function createLoanCrossChain(
        address principalToken,
        uint256 principalAmount,
        uint256 interestRate,
        uint256 duration,
        address ethereumAsset,
        uint256 tokenIdOrAmount,
        bytes32 lockTxHash,
        bytes calldata lockProof,
        bool isPrivate,
        bytes32 privacyCommitment
    ) external nonReentrant whenNotPaused returns (uint256) {
        require(crossChainBridge != address(0), "Cross-chain not supported");
        require(assetInfo[principalToken].isWhitelisted, "Principal token not whitelisted");
        require(principalAmount > 0, "Invalid principal");
        require(interestRate <= MAX_INTEREST_RATE, "Interest too high");
        require(duration >= MIN_LOAN_DURATION && duration <= MAX_LOAN_DURATION, "Invalid duration");
        require(lockTxHash != bytes32(0), "Lock tx hash required");

        // Verify cross-chain lock proof with bridge
        (bool verified, ) = crossChainBridge.call(
            abi.encodeWithSignature(
                "verifyLock(address,address,uint256,bytes32,bytes)",
                msg.sender,
                ethereumAsset,
                tokenIdOrAmount,
                lockTxHash,
                lockProof
            )
        );
        require(verified, "Cross-chain proof verification failed");

        uint256 loanId = loanCounter++;

        loans[loanId] = Loan({
            loanId: loanId,
            borrower: msg.sender,
            lender: address(0),
            principalToken: principalToken,
            principalAmount: principalAmount,
            interestRate: interestRate,
            duration: duration,
            startTime: 0,
            collateralType: CollateralType.CrossChain,
            collateralAsset: ethereumAsset,
            collateralTokenId: tokenIdOrAmount,
            collateralAmount: tokenIdOrAmount,
            status: LoanStatus.Cancelled,
            repaidAmount: 0,
            isPrivate: isPrivate,
            privacyCommitment: privacyCommitment,
            isCrossChain: true,
            crossChainProof: lockTxHash
        });

        crossChainCollaterals[loanId] = CrossChainCollateral({
            ethereumAddress: ethereumAsset,
            tokenId: tokenIdOrAmount,
            amount: tokenIdOrAmount,
            lockTxHash: lockTxHash,
            isLocked: true,
            isReleased: false
        });

        userLoans[msg.sender].push(loanId);

        emit LoanCreated(
            loanId,
            msg.sender,
            principalToken,
            principalAmount,
            interestRate,
            CollateralType.CrossChain,
            ethereumAsset,
            isPrivate,
            true
        );
        emit CrossChainCollateralLocked(loanId, lockTxHash);

        return loanId;
    }

    /**
     * @notice Fund a loan
     */
    function fundLoan(uint256 loanId) external nonReentrant whenNotPaused {
        Loan storage loan = loans[loanId];
        
        require(loan.borrower != address(0), "Loan does not exist");
        require(loan.status == LoanStatus.Cancelled, "Loan already funded or closed");
        require(loan.borrower != msg.sender, "Cannot fund own loan");

        loan.lender = msg.sender;
        loan.status = LoanStatus.Active;
        loan.startTime = block.timestamp;

        uint256 feeAmount = (loan.principalAmount * protocolFee) / 10000;
        uint256 borrowerAmount = loan.principalAmount - feeAmount;

        // Transfer principal to borrower
        IERC20(loan.principalToken).safeTransferFrom(msg.sender, loan.borrower, borrowerAmount);
        
        // Transfer fee
        if (feeAmount > 0) {
            IERC20(loan.principalToken).safeTransferFrom(msg.sender, feeCollector, feeAmount);
        }

        userLoans[msg.sender].push(loanId);

        emit LoanFunded(loanId, msg.sender);
    }

    /**
     * @notice Repay loan
     */
    function repayLoan(uint256 loanId, uint256 amount) external nonReentrant {
        Loan storage loan = loans[loanId];
        
        require(loan.status == LoanStatus.Active, "Loan not active");
        require(msg.sender == loan.borrower, "Not borrower");
        require(amount > 0, "Invalid amount");

        uint256 interest = _calculateInterest(loan);
        uint256 totalOwed = loan.principalAmount + interest - loan.repaidAmount;
        
        require(amount <= totalOwed, "Amount exceeds debt");

        loan.repaidAmount += amount;

        // Transfer repayment to lender
        IERC20(loan.principalToken).safeTransferFrom(msg.sender, loan.lender, amount);

        bool isFull = loan.repaidAmount >= (loan.principalAmount + interest);

        if (isFull) {
            loan.status = LoanStatus.Repaid;
            
            // Return collateral
            _returnCollateral(loan);

            // Update reputation
            if (reputationRegistry != address(0)) {
                (bool success, ) = reputationRegistry.call(
                    abi.encodeWithSignature(
                        "recordLoanRepaid(address,address,uint256)",
                        loan.borrower,
                        loan.lender,
                        loan.principalAmount
                    )
                );
                // Don't revert if reputation call fails
            }
        }

        emit LoanRepaid(loanId, amount, isFull);
    }

    /**
     * @notice Seize collateral on default
     */
    function seizeCollateral(uint256 loanId) external nonReentrant {
        Loan storage loan = loans[loanId];
        
        require(loan.status == LoanStatus.Active, "Loan not active");
        require(msg.sender == loan.lender, "Not lender");
        require(block.timestamp > loan.startTime + loan.duration, "Loan not expired");

        loan.status = LoanStatus.Defaulted;

        // Handle cross-chain collateral
        if (loan.isCrossChain && crossChainBridge != address(0)) {
            CrossChainCollateral storage ccCollateral = crossChainCollaterals[loanId];
            require(ccCollateral.isLocked, "Collateral not locked");
            
            // Initiate cross-chain transfer to lender
            (bool success, ) = crossChainBridge.call(
                abi.encodeWithSignature(
                    "releaseTo(address,address,uint256,address)",
                    loan.collateralAsset,
                    loan.lender,
                    loan.collateralTokenId,
                    msg.sender
                )
            );
            require(success, "Cross-chain release failed");
            
            ccCollateral.isReleased = true;
            emit CrossChainCollateralReleased(loanId, keccak256(abi.encodePacked(loanId, loan.lender)));
        } else {
            // Transfer local collateral to lender
            if (loan.collateralType == CollateralType.ERC20) {
                IERC20(loan.collateralAsset).safeTransfer(loan.lender, loan.collateralAmount);
            } else if (loan.collateralType == CollateralType.ERC721) {
                IERC721(loan.collateralAsset).transferFrom(address(this), loan.lender, loan.collateralTokenId);
            } else if (loan.collateralType == CollateralType.ERC1155) {
                IERC1155(loan.collateralAsset).safeTransferFrom(
                    address(this),
                    loan.lender,
                    loan.collateralTokenId,
                    loan.collateralAmount,
                    ""
                );
            }
        }

        // Update reputation
        if (reputationRegistry != address(0)) {
            (bool success, ) = reputationRegistry.call(
                abi.encodeWithSignature(
                    "recordLoanDefaulted(address,address,uint256)",
                    loan.borrower,
                    loan.lender,
                    loan.principalAmount
                )
            );
        }

        emit LoanDefaulted(loanId);
        emit CollateralSeized(loanId, loan.lender);
    }

    /**
     * @notice Cancel unfunded loan
     */
    function cancelLoan(uint256 loanId) external nonReentrant {
        Loan storage loan = loans[loanId];
        
        require(loan.borrower == msg.sender, "Not borrower");
        require(loan.status == LoanStatus.Cancelled, "Loan already funded");

        // Return collateral
        if (loan.isCrossChain && crossChainBridge != address(0)) {
            CrossChainCollateral storage ccCollateral = crossChainCollaterals[loanId];
            if (ccCollateral.isLocked && !ccCollateral.isReleased) {
                (bool success, ) = crossChainBridge.call(
                    abi.encodeWithSignature(
                        "releaseTo(address,address,uint256,address)",
                        loan.collateralAsset,
                        loan.borrower,
                        loan.collateralTokenId,
                        msg.sender
                    )
                );
                if (success) {
                    ccCollateral.isReleased = true;
                }
            }
        } else {
            _returnCollateral(loan);
        }
    }

    // ============ Internal Functions ============

    function _returnCollateral(Loan storage loan) internal {
        if (loan.collateralType == CollateralType.ERC20) {
            IERC20(loan.collateralAsset).safeTransfer(loan.borrower, loan.collateralAmount);
        } else if (loan.collateralType == CollateralType.ERC721) {
            IERC721(loan.collateralAsset).transferFrom(address(this), loan.borrower, loan.collateralTokenId);
        } else if (loan.collateralType == CollateralType.ERC1155) {
            IERC1155(loan.collateralAsset).safeTransferFrom(
                address(this),
                loan.borrower,
                loan.collateralTokenId,
                loan.collateralAmount,
                ""
            );
        }
    }

    function _calculateInterest(Loan memory loan) internal view returns (uint256) {
        uint256 timeElapsed = block.timestamp - loan.startTime;
        if (timeElapsed > loan.duration) {
            timeElapsed = loan.duration;
        }
        
        return (loan.principalAmount * loan.interestRate * timeElapsed) / (10000 * loan.duration);
    }

    // ============ View Functions ============

    function getLoan(uint256 loanId) external view returns (Loan memory) {
        return loans[loanId];
    }

    function getUserLoans(address user) external view returns (uint256[] memory) {
        return userLoans[user];
    }

    function calculateTotalOwed(uint256 loanId) external view returns (uint256) {
        Loan memory loan = loans[loanId];
        if (loan.status != LoanStatus.Active) return 0;
        
        uint256 interest = _calculateInterest(loan);
        return loan.principalAmount + interest - loan.repaidAmount;
    }

    function isLoanDefaulted(uint256 loanId) external view returns (bool) {
        Loan memory loan = loans[loanId];
        return loan.status == LoanStatus.Active && block.timestamp > loan.startTime + loan.duration;
    }

    function getCrossChainCollateral(uint256 loanId) external view returns (CrossChainCollateral memory) {
        return crossChainCollaterals[loanId];
    }

    // ============ Admin Functions ============

    function whitelistAsset(
        address asset,
        AssetCategory category,
        bool status,
        uint256 minCollateralRatio,
        bool supportsPrivacy,
        bool isCrossChainAsset
    ) external onlyRole(ADMIN_ROLE) {
        require(asset != address(0), "Invalid asset");
        assetInfo[asset] = AssetInfo({
            category: category,
            isWhitelisted: status,
            minCollateralRatio: minCollateralRatio,
            supportsPrivacy: supportsPrivacy,
            isCrossChainAsset: isCrossChainAsset
        });
    }

    function setReputationRegistry(address _registry) external onlyRole(ADMIN_ROLE) {
        reputationRegistry = _registry;
    }

    function setPrivacyModule(address _module) external onlyRole(ADMIN_ROLE) {
        privacyModule = _module;
    }

    function setCrossChainBridge(address _bridge) external onlyRole(ADMIN_ROLE) {
        crossChainBridge = _bridge;
    }

    function setProtocolFee(uint256 _fee) external onlyRole(ADMIN_ROLE) {
        require(_fee <= 500, "Fee too high"); // Max 5%
        protocolFee = _fee;
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // ERC721 & ERC1155 Receiver
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata) external pure returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}