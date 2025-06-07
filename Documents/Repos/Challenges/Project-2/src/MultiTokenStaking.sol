// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MultiERC20Staking is Ownable {
    // --- Constants ---
    uint256 public constant MAX_REWARD_RATE = 1e18; 
    uint256 public constant MIN_STAKING_TIME = 1 days;
    uint256 public constant MAX_STAKING_TIME = 30 days;

    // --- Stake Info ---
    struct StakeInfo {
        uint256 amount;
        uint256 startTime;
    }

    // --- State Variables ---
    mapping(address => bool) public allowedTokens;                     // staking token => allowed?
    mapping(address => address) public rewardTokens;                   // staking token => reward token
    mapping(address => uint256) public rewardRates;                    // staking token => reward rate
    mapping(address => mapping(address => StakeInfo)) public stakes;   // staking token => user => info

    address[] public allStakingTokens;

    // --- Events ---
    event Staked(address indexed user, address indexed token, uint256 amount);
    event Withdrawn(address indexed user, address indexed token, uint256 amount, uint256 reward);
    event RewardPaid(address indexed user, address rewardToken, uint256 reward);
    event AllowedTokenSet(address token, bool allowed);
    event RewardTokenSet(address stakingToken, address rewardToken);
    event RewardRateSet(address stakingToken, uint256 newRate);
    event TokensRecovered(address token, uint256 amount);

    // --- Errors ---
    error TokenNotAllowed();
    error ZeroAmount();
    error LockPeriodNotMet();
    error NoRewardsAvailable();
    error InvalidRate();
    error InvalidTime();
    error CannotRecoverStakingToken();

    constructor() Ownable(msg.sender) {
        
    }

    // --- Stake Function ---
    function stake(address token, uint256 amount) external {
        if (!allowedTokens[token]) revert TokenNotAllowed();
        if (amount == 0) revert ZeroAmount();

        StakeInfo storage userStake = stakes[token][msg.sender];

        // If already staked, calculate and distribute pending rewards
        if (userStake.amount > 0) {
            uint256 pendingReward = calculateReward(token, msg.sender);
            address rewardToken = rewardTokens[token];

            if (IERC20(rewardToken).balanceOf(address(this)) < pendingReward) {
                revert NoRewardsAvailable();
            }

            IERC20(rewardToken).transfer(msg.sender, pendingReward);
            emit RewardPaid(msg.sender, rewardToken, pendingReward);
        }

        // Transfer new staking tokens
        IERC20(token).transferFrom(msg.sender, address(this), amount);

        // Accumulate and reset timer
        userStake.amount += amount;
        userStake.startTime = block.timestamp;

        emit Staked(msg.sender, token, amount);
    }

    // --- Withdraw Function ---
    function withdraw(address token) external {
        StakeInfo storage userStake = stakes[token][msg.sender];
        if (userStake.amount == 0) revert ZeroAmount();
        if (block.timestamp < userStake.startTime + MIN_STAKING_TIME) {
            revert LockPeriodNotMet();
        }

        uint256 staked = userStake.amount;
        uint256 reward = calculateReward(token, msg.sender);
        address rewardToken = rewardTokens[token];

        delete stakes[token][msg.sender];

        IERC20(token).transfer(msg.sender, staked);
        if (reward > 0) {
            if (IERC20(rewardToken).balanceOf(address(this)) < reward) {
                revert NoRewardsAvailable();
            }
            IERC20(rewardToken).transfer(msg.sender, reward);
            emit RewardPaid(msg.sender, rewardToken, reward);
        }

        emit Withdrawn(msg.sender, token, staked, reward);
    }

    // --- Reward Calculation ---
    function calculateReward(address token, address user) public view returns (uint256) {
        StakeInfo memory stakeData = stakes[token][user];
        if (stakeData.amount == 0) return 0;

        uint256 duration = block.timestamp - stakeData.startTime;
        uint256 rate = rewardRates[token];

        return duration * rate;
    }

    // --- Admin Functions ---
    function setAllowedToken(address token, bool allowed) external onlyOwner {
        allowedTokens[token] = allowed;
        if (allowed) {
            allStakingTokens.push(token);
        }
        emit AllowedTokenSet(token, allowed);
    }

    function setRewardToken(address stakingToken, address rewardToken) external onlyOwner {
        rewardTokens[stakingToken] = rewardToken;
        emit RewardTokenSet(stakingToken, rewardToken);
    }

    function setRewardRate(address token, uint256 rate) external onlyOwner {
        if (rate > MAX_REWARD_RATE) revert InvalidRate();
        rewardRates[token] = rate;
        emit RewardRateSet(token, rate);
    }

    function recoverTokens(address token, uint256 amount) external onlyOwner {
        if (allowedTokens[token]) revert CannotRecoverStakingToken();
        for (uint256 i = 0; i < allStakingTokens.length; i++) {
            if (rewardTokens[allStakingTokens[i]] == token) {
                revert CannotRecoverStakingToken();
            }
        }

        IERC20(token).transfer(owner(), amount);
        emit TokensRecovered(token, amount);
    }

    // --- Helper View Functions ---
    function getAllStakingTokens() external view returns (address[] memory) {
        return allStakingTokens;
    }

    function getStakeInfo(address token, address user) external view returns (uint256 amount, uint256 startTime) {
        StakeInfo memory info = stakes[token][user];
        return (info.amount, info.startTime);
    }

    function canWithdraw(address token, address user) external view returns (bool) {
        StakeInfo memory info = stakes[token][user];
        return info.amount > 0 && block.timestamp >= info.startTime + MIN_STAKING_TIME;
    }
}



