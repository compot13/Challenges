// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Import ERC20 interface and Ownable contract from OpenZeppelin
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ERC20Staking is Ownable {
    // The ERC20 token users will stake
    IERC20 public stakingToken;

    // Reward rate: number of tokens distributed per second
    uint256 public rewardRate;

    // Minimum time (in seconds) that tokens must remain staked before withdrawal
    uint256 public minStakingTime;

    // Structure to store individual user's stake information
    struct StakeInfo {
        uint256 amount;         // Amount of tokens staked
        uint256 startTime;      // Timestamp when staking started
        uint256 rewardClaimed;  // Reserved for tracking (not used here)
    }

    // Mapping to store stake info for each staker
    mapping(address => StakeInfo) public stakes;

    // -------- Custom Errors --------
    error AlreadyStaking();                // User tried to stake again before withdrawing
    error NotStaking();                    // User tried to withdraw without staking
    error LockPeriodNotMet();             // Withdrawal attempted before minStakingTime
    error ZeroAmount();                   // Tried to stake zero tokens
    error InvalidRate();                  // Admin tried to set an unreasonable reward rate
    error InvalidTime();                  // Admin tried to set an unreasonably short lock time
    error CannotRecoverStakingToken();    // Admin tried to recover the staking token itself

    // -------- Events --------
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount, uint256 reward);
    event RewardRateUpdated(uint256 newRate);
    event MinStakingTimeUpdated(uint256 newTime);
    event TokensRecovered(address token, uint256 amount);

    /**
     * @notice Constructor initializes staking token, reward rate, and lock time
     * @param _token Address of ERC20 token to be staked
     * @param _rewardRate Reward rate in tokens per second
     * @param _minStakingTime Minimum staking period in seconds
     */                                                        //kogato se vika konstruktora (v sluchaq Ownable e imate + msg.sender ili informaciq ako e token for example)
    constructor(address _token, uint256 _rewardRate, uint256 _minStakingTime) Ownable(msg.sender) {
        stakingToken = IERC20(_token);
        rewardRate = _rewardRate;
        minStakingTime = _minStakingTime;
    }

    /**
     * @notice Allows user to stake a fixed amount
     * @param amount Number of tokens to stake
     */
    function stake(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (stakes[msg.sender].amount > 0) revert AlreadyStaking();

        // Transfer tokens from user to this contract (requires approve first)
        stakingToken.transferFrom(msg.sender, address(this), amount);

        // Store stake information
        stakes[msg.sender] = StakeInfo({
            amount: amount,
            startTime: block.timestamp,
            rewardClaimed: 0
        });

        emit Staked(msg.sender, amount);
    }

    /**
     * @notice Withdraws staked tokens and any earned rewards
     */
    function withdraw() external {
        StakeInfo storage stakeData = stakes[msg.sender];

        if (stakeData.amount == 0) revert NotStaking();
        if (block.timestamp < stakeData.startTime + minStakingTime) revert LockPeriodNotMet();

        uint256 stakedAmount = stakeData.amount;
        uint256 reward = calculateReward(msg.sender);

        // Reset user's stake info
        delete stakes[msg.sender];

        // Transfer staked tokens and rewards back to the user
        stakingToken.transfer(msg.sender, stakedAmount + reward);

        emit Withdrawn(msg.sender, stakedAmount, reward);
    }

    /**
     * @notice Calculates the staking reward for a user
     * @param user address of the staker
     * @return amount of reward tokens earned
     */
    function calculateReward(address user) public view returns (uint256) {
        StakeInfo storage stakeData = stakes[user];
        if (stakeData.amount == 0) return 0;

        // Reward = time staked * reward rate
        uint256 duration = block.timestamp - stakeData.startTime;
        return duration * rewardRate;
    }

    // ------------------------------------
    // Admin Functions (onlyOwner)
    // ------------------------------------

    /**
     * @notice Set a new reward rate (tokens per second)
     * @param _rate New reward rate
     */
    function setRewardRate(uint256 _rate) external onlyOwner {
        if (_rate > 1e18) revert InvalidRate(); // Optional sanity limit
        rewardRate = _rate;
        emit RewardRateUpdated(_rate);
    }

    /**
     * @notice Set a new minimum staking time
     * @param _time Minimum time in seconds
     */
    function setMinStakingTime(uint256 _time) external onlyOwner {
        if (_time < 1 days) revert InvalidTime(); // Prevent absurdly short periods
        minStakingTime = _time;
        emit MinStakingTimeUpdated(_time);
    }

    /**
     * @notice Recover tokens sent to contract by mistake (excluding staking token)
     * @param tokenAddress Address of the token to recover
     * @param amount Amount of tokens to recover
     */
    function recoverTokens(address tokenAddress, uint256 amount) external onlyOwner {
        if (tokenAddress == address(stakingToken)) revert CannotRecoverStakingToken();
        IERC20(tokenAddress).transfer(owner(), amount);
        emit TokensRecovered(tokenAddress, amount);
    }
}


