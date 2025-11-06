// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {UUPSProxy} from "src/UUPSProxy.sol";

/// @title StakingVault V1
/// @author Mathieu Ridet
/// @notice Single-sided staking vault paying rewards in the same ERC20 token
/// @dev Fund this contract with reward tokens and set rewardRate tokens/sec
contract StakingVaultV1 is Initializable, OwnableUpgradeable, ReentrancyGuard, UUPSUpgradeable {
    // Errors
    /// @notice Error thrown when amount is zero
    error StakingVault__AmountZero();

    /// @notice Error thrown when withdrawal amount exceeds staked balance
    error StakingVault__InsufficientStake();

    /// @notice Error thrown when attempting to rescue the staking token
    error StakingVault__NoStakingToken();

    // Type declarations
    using SafeERC20 for IERC20;

    // State variables
    /// @notice ERC20 token used for both staking and rewards
    IERC20 public immutable i_stakingToken;

    /// @notice Reward rate in tokens per second
    uint256 public rewardRate;

    /// @notice Last time rewards were updated
    uint256 public lastUpdateTime;

    /// @notice Accumulated reward per token (scaled by 1e18)
    uint256 public rewardPerTokenStored;

    /// @notice Total amount of tokens staked
    uint256 public totalSupply;

    /// @notice Mapping of user address to staked balance
    mapping(address => uint256) public balanceOf;

    /// @notice Mapping of user address to their reward per token paid
    mapping(address => uint256) public userRewardPerTokenPaid;

    /// @notice Mapping of user address to their pending rewards
    mapping(address => uint256) public rewards;

    /// @notice Useful to add state variables in new versions of the contract
    uint256[45] private __gap;

    // Events
    /// @notice Emitted when a user stakes tokens
    /// @param user Address that staked
    /// @param amount Amount staked
    event Staked(address indexed user, uint256 amount);

    /// @notice Emitted when a user withdraws staked tokens
    /// @param user Address that withdrew
    /// @param amount Amount withdrawn
    event Withdrawn(address indexed user, uint256 amount);

    /// @notice Emitted when rewards are paid to a user
    /// @param user Address that received rewards
    /// @param reward Amount of rewards paid
    event RewardPaid(address indexed user, uint256 reward);

    /// @notice Emitted when the reward rate is updated
    /// @param rewardRate New reward rate in tokens per second
    event RewardRateSet(uint256 rewardRate);

    // Modifiers
    /// @notice Modifier that updates rewards for an account before executing a function
    /// @param account Address to update rewards for
    modifier updateReward(address account) {
        _updateReward(account);
        _;
    }

    // Functions
    /// @notice Constructs the StakingVault contract
    /// @param _token ERC20 token used for staking and rewards
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(IERC20 _token) ReentrancyGuard() {
        _disableInitializers();
        i_stakingToken = _token;
    }

    /// @notice Initializes the StakingVault contract
    /// @param initialOwner Address that will own the contract
    /// @param _rewardRate Initial reward rate in tokens per second
    function initialize(address initialOwner, uint256 _rewardRate) initializer public {
        __Ownable_init(initialOwner);
        // ReentrancyGuard doesn't need initialization in v5
        rewardRate = _rewardRate;
        lastUpdateTime = block.timestamp;
    }

    /// @notice Updates the reward rate (tokens per second)
    /// @param _rate New reward rate in tokens per second
    function setRewardRate(uint256 _rate) external onlyOwner updateReward(address(0)) {
        rewardRate = _rate;
        emit RewardRateSet(_rate);
    }

    /// @notice Stakes tokens into the vault
    /// @param amount Amount of tokens to stake
    function stake(uint256 amount) external nonReentrant updateReward(msg.sender) {
        require(amount > 0, StakingVault__AmountZero());
        totalSupply += amount;
        balanceOf[msg.sender] += amount;
        i_stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    /// @notice Withdraws staked tokens from the vault
    /// @param amount Amount of tokens to withdraw
    function withdraw(uint256 amount) public nonReentrant updateReward(msg.sender) {
        require(amount > 0, StakingVault__AmountZero());
        require(balanceOf[msg.sender] >= amount, StakingVault__InsufficientStake());
        totalSupply -= amount;
        balanceOf[msg.sender] -= amount;
        i_stakingToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    /// @notice Claims accumulated rewards
    function getReward() public nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            i_stakingToken.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    /// @notice Withdraws all staked tokens and claims all rewards
    function exit() external {
        withdraw(balanceOf[msg.sender]);
        getReward();
    }

    /// @notice Owner can rescue unrelated tokens (not the staking token)
    /// @param token Token to rescue
    /// @param to Address to receive the rescued tokens
    /// @param amount Amount of tokens to rescue
    function rescue(IERC20 token, address to, uint256 amount) external onlyOwner {
        require(token != i_stakingToken, StakingVault__NoStakingToken());
        token.safeTransfer(to, amount);
    }

    /// @notice Internal function to update rewards for an account
    /// @param account Address to update rewards for
    function _updateReward(address account) internal {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
    }

    /// @notice Manually triggers reward update for the caller
    /// @dev This function only triggers the updateReward modifier
    function updateRewardsOnly() external updateReward(msg.sender) {
        // This function only triggers the updateReward modifier
    }

    /// @notice Calculates the current reward per token
    /// @return Current reward per token (scaled by 1e18)
    function rewardPerToken() public view returns (uint256) {
        if (totalSupply == 0) return rewardPerTokenStored;
        uint256 delta = block.timestamp - lastUpdateTime;
        return rewardPerTokenStored + (delta * rewardRate * 1e18) / totalSupply;
    }

    /// @notice Calculates the total rewards earned by an account
    /// @param account Address to check rewards for
    /// @return Total rewards earned (including pending)
    function earned(address account) public view returns (uint256) {
        return (balanceOf[account] * (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18 + rewards[account];
    }

    /// @notice Returns the version of this contract
    /// @return Version number (1 for V1)
    function version() external pure virtual returns (uint256) {
        return 1;
    }

    /// @notice Authorizes upgrades (only owner)
    /// @param _newImplementation Address of the new implementation
    function _authorizeUpgrade(address _newImplementation) internal override onlyOwner {}
}

