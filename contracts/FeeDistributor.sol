// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title FeeDistributor
 * @notice Protocol fee collection and distribution system
 * @dev Manages fee allocation to multiple recipients with flexible distribution
 */
contract FeeDistributor is ReentrancyGuard, AccessControl {
    using SafeERC20 for IERC20;

    // ============ Roles ============
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");

    // ============ Structs ============
    struct FeeAllocation {
        address recipient;
        uint256 percentage;         // Basis points (100 = 1%)
        bool isActive;
        string label;
    }

    struct FeeBalance {
        uint256 totalCollected;
        uint256 totalDistributed;
        uint256 pendingDistribution;
        uint256 lastDistribution;
    }

    struct DistributionRecord {
        uint256 timestamp;
        address token;
        uint256 amount;
        address recipient;
    }

    // ============ State Variables ============
    FeeAllocation[] public allocations;
    mapping(address => FeeBalance) public tokenBalances;
    mapping(address => mapping(address => uint256)) public recipientBalances; // token => recipient => balance
    mapping(address => DistributionRecord[]) public distributionHistory;
    
    uint256 public totalAllocated;
    uint256 public constant MAX_ALLOCATIONS = 20;
    uint256 public constant BASIS_POINTS = 10000;
    
    uint256 public minDistributionAmount = 100 * 1e18; // Minimum 100 tokens before distribution
    uint256 public distributionInterval = 1 days;
    mapping(address => uint256) public lastDistributionTime;

    // Auto-compound for stakers
    mapping(address => bool) public autoCompoundEnabled;
    address public stakingContract;

    // ============ Events ============
    event FeeCollected(address indexed token, uint256 amount, address indexed from);
    event FeesDistributed(address indexed token, uint256 totalAmount, uint256 recipientCount);
    event FeesClaimed(address indexed recipient, address indexed token, uint256 amount);
    event AllocationUpdated(uint256 indexed index, address recipient, uint256 percentage, string label);
    event AllocationRemoved(uint256 indexed index, address recipient);
    event MinDistributionAmountUpdated(uint256 oldAmount, uint256 newAmount);
    event AutoCompoundEnabled(address indexed recipient, bool enabled);

    // ============ Constructor ============
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(DISTRIBUTOR_ROLE, msg.sender);
    }

    // ============ Fee Collection ============

    /**
     * @notice Collect fees from a source
     */
    function collectFees(address token, uint256 amount) 
        external 
        nonReentrant 
    {
        require(token != address(0), "Invalid token");
        require(amount > 0, "Invalid amount");

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        FeeBalance storage balance = tokenBalances[token];
        balance.totalCollected += amount;
        balance.pendingDistribution += amount;

        emit FeeCollected(token, amount, msg.sender);

        // Auto-distribute if threshold met and interval passed
        if (balance.pendingDistribution >= minDistributionAmount &&
            block.timestamp >= lastDistributionTime[token] + distributionInterval) {
            _distributeFees(token);
        }
    }

    /**
     * @notice Batch collect fees for multiple tokens
     */
    function batchCollectFees(
        address[] calldata tokens,
        uint256[] calldata amounts
    ) external nonReentrant {
        require(tokens.length == amounts.length, "Length mismatch");

        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] != address(0) && amounts[i] > 0) {
                IERC20(tokens[i]).safeTransferFrom(msg.sender, address(this), amounts[i]);

                FeeBalance storage balance = tokenBalances[tokens[i]];
                balance.totalCollected += amounts[i];
                balance.pendingDistribution += amounts[i];

                emit FeeCollected(tokens[i], amounts[i], msg.sender);
            }
        }
    }

    // ============ Fee Distribution ============

    /**
     * @notice Distribute pending fees to all recipients
     */
    function distributeFees(address token) 
        external 
        onlyRole(DISTRIBUTOR_ROLE) 
        nonReentrant 
    {
        _distributeFees(token);
    }

    /**
     * @notice Internal fee distribution logic
     */
    function _distributeFees(address token) internal {
        require(token != address(0), "Invalid token");
        
        FeeBalance storage balance = tokenBalances[token];
        uint256 amount = balance.pendingDistribution;
        
        require(amount > 0, "No fees to distribute");
        require(totalAllocated == BASIS_POINTS, "Allocations incomplete");

        uint256 distributed = 0;
        uint256 recipientCount = 0;

        for (uint256 i = 0; i < allocations.length; i++) {
            FeeAllocation storage allocation = allocations[i];
            
            if (allocation.isActive && allocation.percentage > 0) {
                uint256 share = (amount * allocation.percentage) / BASIS_POINTS;
                
                if (share > 0) {
                    recipientBalances[token][allocation.recipient] += share;
                    distributed += share;
                    recipientCount++;

                    distributionHistory[allocation.recipient].push(DistributionRecord({
                        timestamp: block.timestamp,
                        token: token,
                        amount: share,
                        recipient: allocation.recipient
                    }));
                }
            }
        }

        balance.pendingDistribution -= distributed;
        balance.totalDistributed += distributed;
        balance.lastDistribution = block.timestamp;
        lastDistributionTime[token] = block.timestamp;

        emit FeesDistributed(token, distributed, recipientCount);
    }

    /**
     * @notice Batch distribute fees for multiple tokens
     */
    function batchDistributeFees(address[] calldata tokens) 
        external 
        onlyRole(DISTRIBUTOR_ROLE) 
        nonReentrant 
    {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokenBalances[tokens[i]].pendingDistribution > 0) {
                _distributeFees(tokens[i]);
            }
        }
    }

    // ============ Fee Claiming ============

    /**
     * @notice Claim accumulated fees for a specific token
     */
    function claimFees(address token) external nonReentrant {
        uint256 amount = recipientBalances[token][msg.sender];
        require(amount > 0, "No fees to claim");

        recipientBalances[token][msg.sender] = 0;
        IERC20(token).safeTransfer(msg.sender, amount);

        emit FeesClaimed(msg.sender, token, amount);
    }

    /**
     * @notice Claim fees for multiple tokens at once
     */
    function batchClaimFees(address[] calldata tokens) external nonReentrant {
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 amount = recipientBalances[tokens[i]][msg.sender];
            
            if (amount > 0) {
                recipientBalances[tokens[i]][msg.sender] = 0;
                IERC20(tokens[i]).safeTransfer(msg.sender, amount);
                
                emit FeesClaimed(msg.sender, tokens[i], amount);
            }
        }
    }

    /**
     * @notice Auto-compound fees to staking contract
     */
    function autoCompound(address token) external nonReentrant {
        require(autoCompoundEnabled[msg.sender], "Auto-compound not enabled");
        require(stakingContract != address(0), "Staking contract not set");

        uint256 amount = recipientBalances[token][msg.sender];
        require(amount > 0, "No fees to compound");

        recipientBalances[token][msg.sender] = 0;
        
        // Transfer to staking contract and stake on behalf of user
        IERC20(token).safeTransfer(stakingContract, amount);
        
        // Call staking contract to stake for user
        (bool success, ) = stakingContract.call(
            abi.encodeWithSignature("stakeFor(address,uint256)", msg.sender, amount)
        );
        require(success, "Auto-compound failed");

        emit FeesClaimed(msg.sender, token, amount);
    }

    // ============ Allocation Management ============

    /**
     * @notice Add or update fee allocation
     */
    function setAllocation(
        address recipient,
        uint256 percentage,
        string calldata label
    ) external onlyRole(ADMIN_ROLE) {
        require(recipient != address(0), "Invalid recipient");
        require(percentage > 0 && percentage <= BASIS_POINTS, "Invalid percentage");

        // Check if recipient already exists
        bool exists = false;
        uint256 existingIndex;
        
        for (uint256 i = 0; i < allocations.length; i++) {
            if (allocations[i].recipient == recipient) {
                exists = true;
                existingIndex = i;
                break;
            }
        }

        if (exists) {
            // Update existing allocation
            FeeAllocation storage allocation = allocations[existingIndex];
            
            uint256 oldPercentage = allocation.percentage;
            totalAllocated = totalAllocated - oldPercentage + percentage;
            
            allocation.percentage = percentage;
            allocation.label = label;
            allocation.isActive = true;
        } else {
            // Add new allocation
            require(allocations.length < MAX_ALLOCATIONS, "Too many allocations");
            
            totalAllocated += percentage;
            
            allocations.push(FeeAllocation({
                recipient: recipient,
                percentage: percentage,
                isActive: true,
                label: label
            }));
        }

        require(totalAllocated <= BASIS_POINTS, "Total allocation exceeds 100%");

        emit AllocationUpdated(
            exists ? existingIndex : allocations.length - 1,
            recipient,
            percentage,
            label
        );
    }

    /**
     * @notice Remove allocation
     */
    function removeAllocation(address recipient) external onlyRole(ADMIN_ROLE) {
        for (uint256 i = 0; i < allocations.length; i++) {
            if (allocations[i].recipient == recipient) {
                totalAllocated -= allocations[i].percentage;
                
                emit AllocationRemoved(i, recipient);
                
                // Remove by replacing with last element and popping
                allocations[i] = allocations[allocations.length - 1];
                allocations.pop();
                
                return;
            }
        }
        
        revert("Allocation not found");
    }

    /**
     * @notice Deactivate allocation without removing
     */
    function deactivateAllocation(address recipient) external onlyRole(ADMIN_ROLE) {
        for (uint256 i = 0; i < allocations.length; i++) {
            if (allocations[i].recipient == recipient) {
                allocations[i].isActive = false;
                totalAllocated -= allocations[i].percentage;
                return;
            }
        }
    }

    /**
     * @notice Reactivate allocation
     */
    function reactivateAllocation(address recipient) external onlyRole(ADMIN_ROLE) {
        for (uint256 i = 0; i < allocations.length; i++) {
            if (allocations[i].recipient == recipient) {
                require(!allocations[i].isActive, "Already active");
                
                totalAllocated += allocations[i].percentage;
                require(totalAllocated <= BASIS_POINTS, "Would exceed 100%");
                
                allocations[i].isActive = true;
                return;
            }
        }
    }

    // ============ View Functions ============

    function getAllocations() external view returns (FeeAllocation[] memory) {
        return allocations;
    }

    function getActiveAllocations() external view returns (FeeAllocation[] memory) {
        uint256 activeCount = 0;
        
        for (uint256 i = 0; i < allocations.length; i++) {
            if (allocations[i].isActive) {
                activeCount++;
            }
        }
        
        FeeAllocation[] memory activeAllocations = new FeeAllocation[](activeCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < allocations.length; i++) {
            if (allocations[i].isActive) {
                activeAllocations[index] = allocations[i];
                index++;
            }
        }
        
        return activeAllocations;
    }

    function getRecipientBalance(address token, address recipient) 
        external 
        view 
        returns (uint256) 
    {
        return recipientBalances[token][recipient];
    }

    function getTokenBalance(address token) 
        external 
        view 
        returns (FeeBalance memory) 
    {
        return tokenBalances[token];
    }

    function getDistributionHistory(address recipient) 
        external 
        view 
        returns (DistributionRecord[] memory) 
    {
        return distributionHistory[recipient];
    }

    function getPendingDistribution(address token) 
        external 
        view 
        returns (uint256) 
    {
        return tokenBalances[token].pendingDistribution;
    }

    function isDistributionReady(address token) external view returns (bool) {
        FeeBalance memory balance = tokenBalances[token];
        return balance.pendingDistribution >= minDistributionAmount &&
               block.timestamp >= lastDistributionTime[token] + distributionInterval;
    }

    // ============ Admin Functions ============

    function setMinDistributionAmount(uint256 amount) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        require(amount > 0, "Invalid amount");
        
        uint256 oldAmount = minDistributionAmount;
        minDistributionAmount = amount;
        
        emit MinDistributionAmountUpdated(oldAmount, amount);
    }

    function setDistributionInterval(uint256 interval) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        require(interval >= 1 hours && interval <= 30 days, "Invalid interval");
        distributionInterval = interval;
    }

    function setStakingContract(address _stakingContract) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        require(_stakingContract != address(0), "Invalid address");
        stakingContract = _stakingContract;
    }

    function setAutoCompound(bool enabled) external {
        autoCompoundEnabled[msg.sender] = enabled;
        emit AutoCompoundEnabled(msg.sender, enabled);
    }

    function emergencyWithdraw(address token, address to, uint256 amount) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(to != address(0), "Invalid recipient");
        IERC20(token).safeTransfer(to, amount);
    }
}