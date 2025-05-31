// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ERC20MultiTokenStaking is Ownable {
    // Allowed staking tokens
    mapping(address => bool) public allowedTokens;

    // Reward token for each staking token
    mapping(address => IERC20) public rewardTokens;

    // Reward rate per staking token (tokens per second)
    mapping(address => uint256) public rewardRates;

    // Minimum staking time per token (seconds)
    mapping(address => uint256) public minStakingTime;

    // Maximum staking time per token (seconds), 0 = no max limit
    mapping(address => uint256) public maxStakingTime;

    // User stake info per token
    struct StakeInfo {
        uint256 amount;
        uint256 startTime;
    }
    mapping(address => mapping(address => StakeInfo)) public stakes;

    // Events
    event Staked(address indexed user, address indexed token, uint256 amount);
    event Withdrawn(address indexed user, address indexed token, uint256 amount, uint256 reward);
    event EmergencyWithdrawn(address indexed user, address indexed token, uint256 amount);
    event RewardRateSet(address indexed token, uint256 rate);
    event MinStakingTimeSet(address indexed token, uint256 time);
    event MaxStakingTimeSet(address indexed token, uint256 time);
    event AllowedTokenSet(address indexed token, bool allowed);
    event RewardTokenSet(address indexed stakingToken, address indexed rewardToken);

    // Errors
    error TokenNotAllowed();
    error NotStaking();
    error LockPeriodNotMet();
    error InsufficientRewardTokens();
    error AlreadyStaking();
    error ZeroAmount();

    // -------------------------
    // Admin functions
    // -------------------------

    /**
     * @notice Enable or disable a staking token
     */
    function setAllowedToken(address token, bool allowed) external onlyOwner {
        allowedTokens[token] = allowed;
        emit AllowedTokenSet(token, allowed);
    }

    /**
     * @notice Set the reward token corresponding to a staking token
     */
    function setRewardToken(address stakingToken, address rewardToken) external onlyOwner {
        rewardTokens[stakingToken] = IERC20(rewardToken);
        emit RewardTokenSet(stakingToken, rewardToken);
    }

    /**
     * @notice Set reward rate (tokens per second) for a staking token
     */
    function setRewardRate(address token, uint256 rate) external onlyOwner {
        if (!allowedTokens[token]) revert TokenNotAllowed();
        rewardRates[token] = rate;
        emit RewardRateSet(token, rate);
    }

    /**
     * @notice Set minimum staking time (in seconds) for a token
     */
    function setMinStakingTime(address token, uint256 time) external onlyOwner {
        minStakingTime[token] = time;
        emit MinStakingTimeSet(token, time);
    }

    /**
     * @notice Set maximum staking time (in seconds) for a token; 0 = no limit
     */
    function setMaxStakingTime(address token, uint256 time) external onlyOwner {
        maxStakingTime[token] = time;
        emit MaxStakingTimeSet(token, time);
    }

    // -------------------------
    // User functions
    // -------------------------

    /**
     * @notice Stake a specific token
     * @param token The ERC20 token to stake (must be allowed)
     * @param amount Amount to stake (must be > 0)
     */
    function stake(address token, uint256 amount) external {
        if (!allowedTokens[token]) revert TokenNotAllowed();
        StakeInfo storage userStake = stakes[token][msg.sender];
        if (userStake.amount > 0) revert AlreadyStaking();
        if (amount == 0) revert ZeroAmount();

        // Transfer staking tokens from user to contract
        IERC20(token).transferFrom(msg.sender, address(this), amount);

        // Record stake info
        stakes[token][msg.sender] = StakeInfo(amount, block.timestamp);

        emit Staked(msg.sender, token, amount);
    }

    /**
     * @notice Withdraw staked tokens and earned rewards
     * @param token The token to withdraw
     */
    function withdraw(address token) external {
        StakeInfo storage userStake = stakes[token][msg.sender];
        if (userStake.amount == 0) revert NotStaking();

        uint256 stakingDuration = block.timestamp - userStake.startTime;

        // Check minimum staking time
        if (stakingDuration < minStakingTime[token]) revert LockPeriodNotMet();

        // Cap staking duration to max if set
        if (maxStakingTime[token] > 0 && stakingDuration > maxStakingTime[token]) {
            stakingDuration = maxStakingTime[token];
        }

        uint256 reward = stakingDuration * rewardRates[token];

        IERC20 rewardToken = rewardTokens[token];
        uint256 rewardBalance = rewardToken.balanceOf(address(this));
        if (rewardBalance < reward) revert InsufficientRewardTokens();

        uint256 stakedAmount = userStake.amount;

        // Clear stake
        delete stakes[token][msg.sender];

        // Transfer back staked tokens
        IERC20(token).transfer(msg.sender, stakedAmount);

        // Transfer rewards
        rewardToken.transfer(msg.sender, reward);

        emit Withdrawn(msg.sender, token, stakedAmount, reward);
    }

    /**
     * @notice Emergency withdraw staked tokens without rewards
     * @param token Token to withdraw
     */
    function emergencyWithdraw(address token) external {
        StakeInfo storage userStake = stakes[token][msg.sender];
        if (userStake.amount == 0) revert NotStaking();

        uint256 stakedAmount = userStake.amount;
        delete stakes[token][msg.sender];

        IERC20(token).transfer(msg.sender, stakedAmount);

        emit EmergencyWithdrawn(msg.sender, token, stakedAmount);
    }

    /**
     * @notice Calculate pending rewards for a user on a token
     */
    function calculateReward(address user, address token) public view returns (uint256) {
        StakeInfo storage userStake = stakes[token][user];
        if (userStake.amount == 0) return 0;

        uint256 stakingDuration = block.timestamp - userStake.startTime;

        // Cap at max staking time if set
        if (maxStakingTime[token] > 0 && stakingDuration > maxStakingTime[token]) {
            stakingDuration = maxStakingTime[token];
        }

        return stakingDuration * rewardRates[token];
    }
}
