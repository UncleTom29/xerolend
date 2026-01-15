// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title OfferBook
 * @notice Advanced order book with complex matching for loans
 */
contract OfferBook is ReentrancyGuard, AccessControl {
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    enum OfferType { Lend, Borrow }
    enum OfferStatus { Active, Cancelled, Accepted, Expired }
    enum CollateralRequirement { Any, Specific, Whitelist }
    enum CollateralType { ERC20, ERC721, ERC1155, CrossChain }

    struct Offer {
        uint256 offerId;
        address creator;
        OfferType offerType;
        address principalToken;
        uint256 minAmount;
        uint256 maxAmount;
        uint256 interestRate;       // Basis points
        uint256 minDuration;
        uint256 maxDuration;
        uint256 minReputation;
        CollateralRequirement collateralReq;
        CollateralType preferredCollateralType;
        address[] acceptedCollaterals;  // Specific tokens/NFTs accepted
        bool acceptsRWA;                // Accepts RWA collateral
        bool acceptsCrossChain;         // Accepts cross-chain collateral
        uint256 createdAt;
        uint256 expiryTime;
        OfferStatus status;
        bool isPrivate;
        uint256 matchCount;
    }

    struct OfferMatch {
        uint256 matchId;
        uint256 offerId;
        address offerCreator;
        address counterparty;
        uint256 amount;
        uint256 timestamp;
    }

    // ============ State Variables ============
    uint256 public offerCounter;
    uint256 public matchCounter;
    uint256 public constant MAX_OFFER_DURATION = 30 days;
    uint256 public constant MAX_COLLATERAL_TYPES = 20;

    mapping(uint256 => Offer) public offers;
    mapping(address => uint256[]) public userOffers;
    mapping(uint256 => OfferMatch[]) public offerMatches;
    mapping(address => uint256) public activeOffersCount;

    // Advanced indexing for complex matching
    mapping(address => uint256[]) public tokenOffers;          // principalToken => offerIds
    mapping(OfferType => uint256[]) public offersByType;       // type => offerIds
    mapping(uint256 => uint256[]) public offersByReputation;   // minReputation => offerIds
    mapping(bool => uint256[]) public rwaOffers;               // acceptsRWA => offerIds
    mapping(bool => uint256[]) public crossChainOffers;        // acceptsCrossChain => offerIds

    uint256 public maxOffersPerUser = 50;

    event OfferCreated(
        uint256 indexed offerId,
        address indexed creator,
        OfferType offerType,
        address principalToken,
        uint256 minAmount,
        uint256 maxAmount,
        uint256 interestRate,
        bool acceptsRWA,
        bool acceptsCrossChain
    );

    event OfferCancelled(uint256 indexed offerId, address indexed creator);
    event OfferAccepted(uint256 indexed offerId, address indexed acceptor, uint256 amount);
    event OfferExpired(uint256 indexed offerId);
    event OfferModified(uint256 indexed offerId, uint256 newInterestRate, uint256 newExpiry);

    // ============ Modifiers ============
    modifier offerExists(uint256 offerId) {
        require(offers[offerId].creator != address(0), "Offer does not exist");
        _;
    }

    modifier onlyOfferCreator(uint256 offerId) {
        require(offers[offerId].creator == msg.sender, "Not offer creator");
        _;
    }

    // ============ Constructor ============
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
        offerCounter = 1;
        matchCounter = 1;
    }

    // ============ Core Functions ============

    /**
     * @notice Create lending or borrowing offer with advanced parameters
     */
    function createOffer(
        OfferType offerType,
        address principalToken,
        uint256 minAmount,
        uint256 maxAmount,
        uint256 interestRate,
        uint256 minDuration,
        uint256 maxDuration,
        uint256 minReputation,
        CollateralRequirement collateralReq,
        CollateralType preferredCollateralType,
        address[] calldata acceptedCollaterals,
        bool acceptsRWA,
        bool acceptsCrossChain,
        uint256 duration,
        bool isPrivate
    ) external nonReentrant returns (uint256) {
        require(principalToken != address(0), "Invalid token");
        require(minAmount > 0 && minAmount <= maxAmount, "Invalid amounts");
        require(interestRate > 0 && interestRate <= 10000, "Invalid interest rate");
        require(minDuration > 0 && minDuration <= maxDuration, "Invalid durations");
        require(duration <= MAX_OFFER_DURATION, "Duration too long");
        require(
            activeOffersCount[msg.sender] < maxOffersPerUser,
            "Too many active offers"
        );
        require(
            acceptedCollaterals.length <= MAX_COLLATERAL_TYPES,
            "Too many collateral types"
        );

        uint256 offerId = offerCounter++;
        uint256 expiryTime = block.timestamp + duration;

        offers[offerId] = Offer({
            offerId: offerId,
            creator: msg.sender,
            offerType: offerType,
            principalToken: principalToken,
            minAmount: minAmount,
            maxAmount: maxAmount,
            interestRate: interestRate,
            minDuration: minDuration,
            maxDuration: maxDuration,
            minReputation: minReputation,
            collateralReq: collateralReq,
            preferredCollateralType: preferredCollateralType,
            acceptedCollaterals: acceptedCollaterals,
            acceptsRWA: acceptsRWA,
            acceptsCrossChain: acceptsCrossChain,
            createdAt: block.timestamp,
            expiryTime: expiryTime,
            status: OfferStatus.Active,
            isPrivate: isPrivate,
            matchCount: 0
        });

        // Index offer for complex matching
        userOffers[msg.sender].push(offerId);
        tokenOffers[principalToken].push(offerId);
        offersByType[offerType].push(offerId);
        offersByReputation[minReputation].push(offerId);
        
        if (acceptsRWA) {
            rwaOffers[true].push(offerId);
        }
        if (acceptsCrossChain) {
            crossChainOffers[true].push(offerId);
        }
        
        activeOffersCount[msg.sender]++;

        emit OfferCreated(
            offerId,
            msg.sender,
            offerType,
            principalToken,
            minAmount,
            maxAmount,
            interestRate,
            acceptsRWA,
            acceptsCrossChain
        );

        return offerId;
    }

    /**
     * @notice Accept an offer
     */
    function acceptOffer(uint256 offerId) external nonReentrant returns (uint256) {
        Offer storage offer = offers[offerId];
        
        require(offer.creator != address(0), "Offer does not exist");
        require(offer.status == OfferStatus.Active, "Offer not active");
        require(block.timestamp < offer.expiryTime, "Offer expired");
        require(offer.creator != msg.sender, "Cannot accept own offer");

        offer.status = OfferStatus.Accepted;
        activeOffersCount[offer.creator]--;

        emit OfferAccepted(offerId, msg.sender, offer.minAmount);

        return offerId;
    }

    /**
     * @notice Cancel offer
     */
    function cancelOffer(uint256 offerId) external nonReentrant {
        Offer storage offer = offers[offerId];
        
        require(offer.creator == msg.sender, "Not offer creator");
        require(offer.status == OfferStatus.Active, "Offer not active");

        offer.status = OfferStatus.Cancelled;
        activeOffersCount[offer.creator]--;

        emit OfferCancelled(offerId, msg.sender);
    }

    /**
     * @notice Batch expire old offers
     */
    function expireOffers(uint256[] calldata offerIds) external {
        for (uint256 i = 0; i < offerIds.length; i++) {
            uint256 offerId = offerIds[i];
            Offer storage offer = offers[offerId];
            
            if (
                offer.status == OfferStatus.Active &&
                block.timestamp >= offer.expiryTime
            ) {
                offer.status = OfferStatus.Expired;
                activeOffersCount[offer.creator]--;
                emit OfferExpired(offerId);
            }
        }
    }

    // ============ View Functions ============

    function getOffer(uint256 offerId) external view returns (Offer memory) {
        return offers[offerId];
    }

    function getUserOffers(address user) external view returns (uint256[] memory) {
        return userOffers[user];
    }

    function getActiveOffersByType(OfferType offerType) 
        external 
        view 
        returns (Offer[] memory) 
    {
        uint256 count = 0;
        
        // Count active offers
        for (uint256 i = 1; i < offerCounter; i++) {
            Offer memory offer = offers[i];
            if (
                offer.offerType == offerType &&
                offer.status == OfferStatus.Active &&
                block.timestamp < offer.expiryTime
            ) {
                count++;
            }
        }
        
        // Build result
        Offer[] memory result = new Offer[](count);
        uint256 index = 0;
        
        for (uint256 i = 1; i < offerCounter; i++) {
            Offer memory offer = offers[i];
            if (
                offer.offerType == offerType &&
                offer.status == OfferStatus.Active &&
                block.timestamp < offer.expiryTime
            ) {
                result[index] = offer;
                index++;
            }
        }
        
        return result;
    }

    /**
     * @notice Find matching offers
     */
    function findMatchingOffers(
        OfferType lookingFor,
        address principalToken,
        uint256 amount,
        uint256 maxInterestRate
    ) external view returns (Offer[] memory) {
        uint256 matchCount = 0;
        
        // Count matches
        for (uint256 i = 1; i < offerCounter; i++) {
            Offer memory offer = offers[i];
            
            if (
                offer.offerType == lookingFor &&
                offer.status == OfferStatus.Active &&
                block.timestamp < offer.expiryTime &&
                offer.principalToken == principalToken &&
                offer.minAmount <= amount &&
                offer.maxAmount >= amount &&
                offer.interestRate <= maxInterestRate
            ) {
                matchCount++;
            }
        }
        
        // Build result
        Offer[] memory matches = new Offer[](matchCount);
        uint256 index = 0;
        
        for (uint256 i = 1; i < offerCounter; i++) {
            Offer memory offer = offers[i];
            
            if (
                offer.offerType == lookingFor &&
                offer.status == OfferStatus.Active &&
                block.timestamp < offer.expiryTime &&
                offer.principalToken == principalToken &&
                offer.minAmount <= amount &&
                offer.maxAmount >= amount &&
                offer.interestRate <= maxInterestRate
            ) {
                matches[index] = offer;
                index++;
            }
        }
        
        return matches;
    }

    function getMarketStats() 
        external 
        view 
        returns (
            uint256 totalOffers,
            uint256 activeOffers,
            uint256 lendOffers,
            uint256 borrowOffers
        ) 
    {
        totalOffers = offerCounter - 1;
        
        for (uint256 i = 1; i < offerCounter; i++) {
            Offer memory offer = offers[i];
            
            if (offer.status == OfferStatus.Active && block.timestamp < offer.expiryTime) {
                activeOffers++;
                if (offer.offerType == OfferType.Lend) {
                    lendOffers++;
                } else {
                    borrowOffers++;
                }
            }
        }
        
        return (totalOffers, activeOffers, lendOffers, borrowOffers);
    }

    // ============ Admin Functions ============

    function setMaxOffersPerUser(uint256 _max) external onlyRole(ADMIN_ROLE) {
        require(_max > 0 && _max <= 100, "Invalid max");
        maxOffersPerUser = _max;
    }
}