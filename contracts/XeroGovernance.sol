// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title XeroGovernance
 * @notice Decentralized governance for Xero Protocol
 * @dev Token-weighted voting with timelock and proposal execution
 */
contract XeroGovernance is AccessControl, ReentrancyGuard {
    
    // ============ Roles ============
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    // ============ Enums ============
    enum ProposalState {
        Pending,
        Active,
        Cancelled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }

    enum VoteType { Against, For, Abstain }

    // ============ Structs ============
    struct Proposal {
        uint256 proposalId;
        address proposer;
        string title;
        string description;
        address[] targets;
        uint256[] values;
        bytes[] calldatas;
        uint256 startBlock;
        uint256 endBlock;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        ProposalState state;
        uint256 eta; // Execution timestamp
        bool executed;
        mapping(address => Receipt) receipts;
    }

    struct Receipt {
        bool hasVoted;
        VoteType support;
        uint256 votes;
    }

    struct ProposalCore {
        uint256 proposalId;
        address proposer;
        string title;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        uint256 startBlock;
        uint256 endBlock;
        ProposalState state;
    }

    // ============ State Variables ============
    IERC20 public governanceToken;
    
    uint256 public proposalCounter;
    mapping(uint256 => Proposal) public proposals;
    mapping(bytes32 => bool) public queuedTransactions;

    // Governance parameters
    uint256 public votingDelay = 1 days;                    // Delay before voting starts
    uint256 public votingPeriod = 3 days;                   // Duration of voting
    uint256 public proposalThreshold = 100000 * 1e18;       // Tokens needed to propose
    uint256 public quorumVotes = 1000000 * 1e18;           // Votes needed to pass
    uint256 public timelockPeriod = 2 days;                 // Delay before execution
    uint256 public gracePeriod = 14 days;                   // Time to execute after timelock
    
    uint256 public constant MIN_VOTING_DELAY = 1 hours;
    uint256 public constant MAX_VOTING_DELAY = 7 days;
    uint256 public constant MIN_VOTING_PERIOD = 1 days;
    uint256 public constant MAX_VOTING_PERIOD = 14 days;
    uint256 public constant MIN_TIMELOCK_PERIOD = 1 days;
    uint256 public constant MAX_TIMELOCK_PERIOD = 30 days;

    // ============ Events ============
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string title,
        string description,
        uint256 startBlock,
        uint256 endBlock
    );

    event VoteCast(
        address indexed voter,
        uint256 indexed proposalId,
        VoteType support,
        uint256 votes,
        string reason
    );

    event ProposalQueued(uint256 indexed proposalId, uint256 eta);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);
    
    event VotingDelaySet(uint256 oldDelay, uint256 newDelay);
    event VotingPeriodSet(uint256 oldPeriod, uint256 newPeriod);
    event ProposalThresholdSet(uint256 oldThreshold, uint256 newThreshold);
    event QuorumVotesSet(uint256 oldQuorum, uint256 newQuorum);

    // ============ Constructor ============
    constructor(address _governanceToken) {
        require(_governanceToken != address(0), "Invalid token");
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PROPOSER_ROLE, msg.sender);
        _grantRole(EXECUTOR_ROLE, msg.sender);
        _grantRole(GUARDIAN_ROLE, msg.sender);
        
        governanceToken = IERC20(_governanceToken);
        proposalCounter = 1;
    }

    // ============ Proposal Functions ============

    /**
     * @notice Create a new proposal
     */
    function propose(
        string memory title,
        string memory description,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas
    ) external returns (uint256) {
        require(
            governanceToken.balanceOf(msg.sender) >= proposalThreshold,
            "Below proposal threshold"
        );
        require(
            targets.length == values.length && 
            values.length == calldatas.length,
            "Proposal function information mismatch"
        );
        require(targets.length > 0, "Must provide actions");
        require(targets.length <= 10, "Too many actions");

        uint256 proposalId = proposalCounter++;
        Proposal storage proposal = proposals[proposalId];
        
        proposal.proposalId = proposalId;
        proposal.proposer = msg.sender;
        proposal.title = title;
        proposal.description = description;
        proposal.targets = targets;
        proposal.values = values;
        proposal.calldatas = calldatas;
        proposal.startBlock = block.number + (votingDelay / 12); // ~12s per block
        proposal.endBlock = proposal.startBlock + (votingPeriod / 12);
        proposal.state = ProposalState.Pending;
        proposal.executed = false;

        emit ProposalCreated(
            proposalId,
            msg.sender,
            title,
            description,
            proposal.startBlock,
            proposal.endBlock
        );

        return proposalId;
    }

    /**
     * @notice Cast vote on a proposal
     */
    function castVote(
        uint256 proposalId,
        VoteType support
    ) external nonReentrant {
        return _castVote(msg.sender, proposalId, support, "");
    }

    /**
     * @notice Cast vote with reason
     */
    function castVoteWithReason(
        uint256 proposalId,
        VoteType support,
        string calldata reason
    ) external nonReentrant {
        return _castVote(msg.sender, proposalId, support, reason);
    }

    /**
     * @notice Internal vote casting logic
     */
    function _castVote(
        address voter,
        uint256 proposalId,
        VoteType support,
        string memory reason
    ) internal {
        Proposal storage proposal = proposals[proposalId];
        
        require(
            state(proposalId) == ProposalState.Active,
            "Voting is closed"
        );
        
        Receipt storage receipt = proposal.receipts[voter];
        require(!receipt.hasVoted, "Already voted");

        uint256 votes = governanceToken.balanceOf(voter);
        require(votes > 0, "No voting power");

        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = votes;

        if (support == VoteType.For) {
            proposal.forVotes += votes;
        } else if (support == VoteType.Against) {
            proposal.againstVotes += votes;
        } else {
            proposal.abstainVotes += votes;
        }

        emit VoteCast(voter, proposalId, support, votes, reason);
    }

    /**
     * @notice Queue a successful proposal for execution
     */
    function queue(uint256 proposalId) external {
        require(
            state(proposalId) == ProposalState.Succeeded,
            "Proposal cannot be queued"
        );

        Proposal storage proposal = proposals[proposalId];
        uint256 eta = block.timestamp + timelockPeriod;
        proposal.eta = eta;
        proposal.state = ProposalState.Queued;

        for (uint256 i = 0; i < proposal.targets.length; i++) {
            _queueTransaction(
                proposal.targets[i],
                proposal.values[i],
                proposal.calldatas[i],
                eta
            );
        }

        emit ProposalQueued(proposalId, eta);
    }

    /**
     * @notice Execute a queued proposal
     */
    function execute(uint256 proposalId) 
        external 
        payable 
        nonReentrant 
    {
        require(
            state(proposalId) == ProposalState.Queued,
            "Proposal cannot be executed"
        );

        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp >= proposal.eta, "Timelock not met");
        require(
            block.timestamp <= proposal.eta + gracePeriod,
            "Transaction is stale"
        );

        proposal.executed = true;
        proposal.state = ProposalState.Executed;

        for (uint256 i = 0; i < proposal.targets.length; i++) {
            _executeTransaction(
                proposal.targets[i],
                proposal.values[i],
                proposal.calldatas[i],
                proposal.eta
            );
        }

        emit ProposalExecuted(proposalId);
    }

    /**
     * @notice Cancel a proposal
     */
    function cancel(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        
        require(
            msg.sender == proposal.proposer ||
            hasRole(GUARDIAN_ROLE, msg.sender),
            "Not authorized"
        );
        
        require(
            state(proposalId) != ProposalState.Executed,
            "Cannot cancel executed proposal"
        );

        proposal.state = ProposalState.Cancelled;

        emit ProposalCancelled(proposalId);
    }

    // ============ Internal Functions ============

    function _queueTransaction(
        address target,
        uint256 value,
        bytes memory data,
        uint256 eta
    ) internal {
        bytes32 txHash = keccak256(abi.encode(target, value, data, eta));
        queuedTransactions[txHash] = true;
    }

    function _executeTransaction(
        address target,
        uint256 value,
        bytes memory data,
        uint256 eta
    ) internal {
        bytes32 txHash = keccak256(abi.encode(target, value, data, eta));
        require(queuedTransactions[txHash], "Transaction not queued");

        queuedTransactions[txHash] = false;

        (bool success, ) = target.call{value: value}(data);
        require(success, "Transaction execution reverted");
    }

    // ============ View Functions ============

    /**
     * @notice Get current state of proposal
     */
    function state(uint256 proposalId) public view returns (ProposalState) {
        Proposal storage proposal = proposals[proposalId];
        
        if (proposal.state == ProposalState.Cancelled) {
            return ProposalState.Cancelled;
        } else if (proposal.state == ProposalState.Executed) {
            return ProposalState.Executed;
        } else if (block.number <= proposal.startBlock) {
            return ProposalState.Pending;
        } else if (block.number <= proposal.endBlock) {
            return ProposalState.Active;
        } else if (proposal.forVotes <= proposal.againstVotes || proposal.forVotes < quorumVotes) {
            return ProposalState.Defeated;
        } else if (proposal.eta == 0) {
            return ProposalState.Succeeded;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else if (block.timestamp >= proposal.eta + gracePeriod) {
            return ProposalState.Expired;
        } else {
            return ProposalState.Queued;
        }
    }

    /**
     * @notice Get proposal details
     */
    function getProposal(uint256 proposalId) 
        external 
        view 
        returns (
            uint256 id,
            address proposer,
            string memory title,
            string memory description,
            uint256 forVotes,
            uint256 againstVotes,
            uint256 abstainVotes,
            uint256 startBlock,
            uint256 endBlock,
            ProposalState currentState
        ) 
    {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.proposalId,
            proposal.proposer,
            proposal.title,
            proposal.description,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.abstainVotes,
            proposal.startBlock,
            proposal.endBlock,
            state(proposalId)
        );
    }

    /**
     * @notice Get proposal actions
     */
    function getProposalActions(uint256 proposalId)
        external
        view
        returns (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas
        )
    {
        Proposal storage proposal = proposals[proposalId];
        return (proposal.targets, proposal.values, proposal.calldatas);
    }

    /**
     * @notice Get user's receipt for a proposal
     */
    function getReceipt(uint256 proposalId, address voter)
        external
        view
        returns (
            bool hasVoted,
            VoteType support,
            uint256 votes
        )
    {
        Proposal storage proposal = proposals[proposalId];
        Receipt storage receipt = proposal.receipts[voter];
        return (receipt.hasVoted, receipt.support, receipt.votes);
    }

    /**
     * @notice Check if user has voted
     */
    function hasVoted(uint256 proposalId, address account) 
        external 
        view 
        returns (bool) 
    {
        return proposals[proposalId].receipts[account].hasVoted;
    }

    /**
     * @notice Get all proposals
     */
    function getAllProposals() 
        external 
        view 
        returns (ProposalCore[] memory) 
    {
        ProposalCore[] memory allProposals = new ProposalCore[](proposalCounter - 1);
        
        for (uint256 i = 1; i < proposalCounter; i++) {
            Proposal storage proposal = proposals[i];
            allProposals[i - 1] = ProposalCore({
                proposalId: proposal.proposalId,
                proposer: proposal.proposer,
                title: proposal.title,
                forVotes: proposal.forVotes,
                againstVotes: proposal.againstVotes,
                abstainVotes: proposal.abstainVotes,
                startBlock: proposal.startBlock,
                endBlock: proposal.endBlock,
                state: state(i)
            });
        }
        
        return allProposals;
    }

    /**
     * @notice Get active proposals
     */
    function getActiveProposals() 
        external 
        view 
        returns (ProposalCore[] memory) 
    {
        uint256 activeCount = 0;
        
        for (uint256 i = 1; i < proposalCounter; i++) {
            if (state(i) == ProposalState.Active) {
                activeCount++;
            }
        }
        
        ProposalCore[] memory activeProposals = new ProposalCore[](activeCount);
        uint256 index = 0;
        
        for (uint256 i = 1; i < proposalCounter; i++) {
            if (state(i) == ProposalState.Active) {
                Proposal storage proposal = proposals[i];
                activeProposals[index] = ProposalCore({
                    proposalId: proposal.proposalId,
                    proposer: proposal.proposer,
                    title: proposal.title,
                    forVotes: proposal.forVotes,
                    againstVotes: proposal.againstVotes,
                    abstainVotes: proposal.abstainVotes,
                    startBlock: proposal.startBlock,
                    endBlock: proposal.endBlock,
                    state: state(i)
                });
                index++;
            }
        }
        
        return activeProposals;
    }

    // ============ Admin Functions ============

    function setVotingDelay(uint256 newDelay) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(
            newDelay >= MIN_VOTING_DELAY && newDelay <= MAX_VOTING_DELAY,
            "Invalid voting delay"
        );
        
        uint256 oldDelay = votingDelay;
        votingDelay = newDelay;
        
        emit VotingDelaySet(oldDelay, newDelay);
    }

    function setVotingPeriod(uint256 newPeriod) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(
            newPeriod >= MIN_VOTING_PERIOD && newPeriod <= MAX_VOTING_PERIOD,
            "Invalid voting period"
        );
        
        uint256 oldPeriod = votingPeriod;
        votingPeriod = newPeriod;
        
        emit VotingPeriodSet(oldPeriod, newPeriod);
    }

    function setProposalThreshold(uint256 newThreshold) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(newThreshold > 0, "Invalid threshold");
        
        uint256 oldThreshold = proposalThreshold;
        proposalThreshold = newThreshold;
        
        emit ProposalThresholdSet(oldThreshold, newThreshold);
    }

    function setQuorumVotes(uint256 newQuorum) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(newQuorum > 0, "Invalid quorum");
        
        uint256 oldQuorum = quorumVotes;
        quorumVotes = newQuorum;
        
        emit QuorumVotesSet(oldQuorum, newQuorum);
    }

    /**
     * @notice Guardian can cancel malicious proposals
     */
    function guardianCancel(uint256 proposalId) 
        external 
        onlyRole(GUARDIAN_ROLE) 
    {
        Proposal storage proposal = proposals[proposalId];
        require(
            state(proposalId) != ProposalState.Executed,
            "Cannot cancel executed proposal"
        );
        
        proposal.state = ProposalState.Cancelled;
        
        emit ProposalCancelled(proposalId);
    }

    receive() external payable {}
}