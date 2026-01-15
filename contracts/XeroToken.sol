// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/utils/Nonces.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title XeroToken
 * @notice Governance token for Xero Protocol
 * @dev ERC20 token with voting power, EIP-2612 permit, pausable transfers, blacklist & vesting
 */
contract XeroToken is
    ERC20,
    ERC20Burnable,
    ERC20Permit,
    ERC20Votes,
    AccessControl,
    Pausable
{
    // =============================================
    //              ROLES & CONSTANTS
    // =============================================

    bytes32 public constant MINTER_ROLE       = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE       = keccak256("PAUSER_ROLE");
    bytes32 public constant BLACKLISTER_ROLE  = keccak256("BLACKLISTER_ROLE");

    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 1e18; // 1 billion tokens

    // =============================================
    //              STATE VARIABLES
    // =============================================

    mapping(address => bool) public blacklisted;

    // Vesting
    struct VestingSchedule {
        uint256 totalAmount;
        uint256 startTime;
        uint256 cliffDuration;
        uint256 duration;
        uint256 released;
        bool revoked;
    }

    mapping(address => VestingSchedule) public vestingSchedules;

    // Optional distribution tracking
    uint256 public teamAllocation;
    uint256 public communityAllocation;
    uint256 public treasuryAllocation;
    uint256 public liquidityAllocation;

    // =============================================
    //                  EVENTS
    // =============================================

    event Blacklisted(address indexed account);
    event UnBlacklisted(address indexed account);
    event VestingScheduleCreated(
        address indexed beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 duration
    );
    event TokensReleased(address indexed beneficiary, uint256 amount);
    event VestingRevoked(address indexed beneficiary);

    // =============================================
    //                CONSTRUCTOR
    // =============================================

    constructor(
        uint256 initialSupply,
        address treasury
    )
        ERC20("Xero Protocol", "XERO")
        ERC20Permit("Xero Protocol")
    {
        require(treasury != address(0), "Invalid treasury address");
        require(initialSupply <= MAX_SUPPLY, "Initial supply exceeds max supply");

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE,       msg.sender);
        _grantRole(PAUSER_ROLE,       msg.sender);
        _grantRole(BLACKLISTER_ROLE,  msg.sender);

        _mint(treasury, initialSupply);
    }

    // =============================================
    //              MINTING FUNCTIONS
    // =============================================

    function mint(address to, uint256 amount)
        external
        onlyRole(MINTER_ROLE)
    {
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds max supply");
        require(!blacklisted[to], "Recipient is blacklisted");
        _mint(to, amount);
    }

    function batchMint(
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external onlyRole(MINTER_ROLE) {
        require(recipients.length == amounts.length, "Length mismatch");

        uint256 total = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            total += amounts[i];
        }
        require(totalSupply() + total <= MAX_SUPPLY, "Exceeds max supply");

        for (uint256 i = 0; i < recipients.length; i++) {
            require(!blacklisted[recipients[i]], "Recipient is blacklisted");
            _mint(recipients[i], amounts[i]);
        }
    }

    // =============================================
    //               VESTING LOGIC
    // =============================================

    function createVestingSchedule(
        address beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 duration
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(beneficiary != address(0), "Invalid beneficiary");
        require(amount > 0, "Invalid amount");
        require(duration > 0, "Invalid duration");
        require(cliffDuration <= duration, "Cliff > duration");
        require(vestingSchedules[beneficiary].totalAmount == 0, "Schedule already exists");

        vestingSchedules[beneficiary] = VestingSchedule({
            totalAmount: amount,
            startTime: startTime,
            cliffDuration: cliffDuration,
            duration: duration,
            released: 0,
            revoked: false
        });

        _transfer(msg.sender, address(this), amount);

        emit VestingScheduleCreated(beneficiary, amount, startTime, cliffDuration, duration);
    }

    function releaseVestedTokens() external {
        VestingSchedule storage sch = vestingSchedules[msg.sender];
        require(sch.totalAmount > 0, "No vesting schedule");
        require(!sch.revoked, "Vesting revoked");
        require(block.timestamp >= sch.startTime + sch.cliffDuration, "Cliff not reached");

        uint256 vested = _calculateVestedAmount(sch);
        uint256 releasable = vested - sch.released;
        require(releasable > 0, "Nothing to release");

        sch.released += releasable;
        _transfer(address(this), msg.sender, releasable);

        emit TokensReleased(msg.sender, releasable);
    }

    function revokeVesting(address beneficiary) external onlyRole(DEFAULT_ADMIN_ROLE) {
        VestingSchedule storage sch = vestingSchedules[beneficiary];
        require(sch.totalAmount > 0, "No vesting schedule");
        require(!sch.revoked, "Already revoked");

        uint256 vested = _calculateVestedAmount(sch);
        uint256 releasable = vested - sch.released;

        sch.revoked = true;

        if (releasable > 0) {
            sch.released += releasable;
            _transfer(address(this), beneficiary, releasable);
        }

        uint256 unvested = sch.totalAmount - vested;
        if (unvested > 0) {
            _transfer(address(this), msg.sender, unvested);
        }

        emit VestingRevoked(beneficiary);
    }

    function _calculateVestedAmount(VestingSchedule memory sch)
        internal view returns (uint256)
    {
        if (block.timestamp < sch.startTime + sch.cliffDuration) return 0;
        if (block.timestamp >= sch.startTime + sch.duration) return sch.totalAmount;

        uint256 timePassed = block.timestamp - sch.startTime;
        return (sch.totalAmount * timePassed) / sch.duration;
    }

    function getReleasableAmount(address beneficiary) external view returns (uint256) {
        VestingSchedule memory sch = vestingSchedules[beneficiary];
        if (sch.totalAmount == 0 || sch.revoked) return 0;

        uint256 vested = _calculateVestedAmount(sch);
        return vested - sch.released;
    }

    // =============================================
    //            BLACKLIST & PAUSE
    // =============================================

    function blacklist(address account) external onlyRole(BLACKLISTER_ROLE) {
        require(account != address(0), "Invalid address");
        require(!blacklisted[account], "Already blacklisted");
        blacklisted[account] = true;
        emit Blacklisted(account);
    }

    function unBlacklist(address account) external onlyRole(BLACKLISTER_ROLE) {
        require(blacklisted[account], "Not blacklisted");
        blacklisted[account] = false;
        emit UnBlacklisted(account);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // =============================================
    //         REQUIRED OVERRIDES (OZ 5.x)
    // =============================================

    function _update(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
        whenNotPaused
    {
        require(!blacklisted[from], "Sender is blacklisted");
        require(!blacklisted[to],   "Recipient is blacklisted");

        super._update(from, to, amount);
    }

    /// @dev Resolves conflict between ERC20Permit and Nonces
    function nonces(address owner)
        public
        view
        virtual
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner);
    }

    // =============================================
    //         VIEW & ADMIN UTILITIES
    // =============================================

    function getVestingSchedule(address beneficiary)
        external view
        returns (
            uint256 totalAmount,
            uint256 startTime,
            uint256 cliffDuration,
            uint256 duration,
            uint256 released,
            bool revoked
        )
    {
        VestingSchedule memory s = vestingSchedules[beneficiary];
        return (
            s.totalAmount,
            s.startTime,
            s.cliffDuration,
            s.duration,
            s.released,
            s.revoked
        );
    }

    function getRemainingSupply() external view returns (uint256) {
        return MAX_SUPPLY - totalSupply();
    }

    function isBlacklisted(address account) external view returns (bool) {
        return blacklisted[account];
    }

    function recoverERC20(address token, uint256 amount)
        external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(token != address(this), "Cannot recover XERO");
        IERC20(token).transfer(msg.sender, amount);
    }

    function setAllocations(
        uint256 _team,
        uint256 _community,
        uint256 _treasury,
        uint256 _liquidity
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            _team + _community + _treasury + _liquidity <= MAX_SUPPLY,
            "Total allocations exceed max supply"
        );
        teamAllocation = _team;
        communityAllocation = _community;
        treasuryAllocation = _treasury;
        liquidityAllocation = _liquidity;
    }
}