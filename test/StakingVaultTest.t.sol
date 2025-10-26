// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {StakingVault} from "../src/StakingVault/StakingVault.sol";
import {MockERC20} from "./TestHelper.sol";

contract StakingVaultTest is Test {
    StakingVault public vault;
    MockERC20 public token;

    function setUp() public {
        // Deploy a mock ERC20 token
        token = new MockERC20("MRT Mock Token", "MRT");

        // Mint tokens to the test contract
        token.mint(address(this), 1_000e18);

        // Deploy the StakingVault contract
        vault = new StakingVault(address(this), token, 1e18); // 1 token per second reward rate

        // Mint tokens to the vault for rewards
        token.mint(address(vault), 1_000e18);

        // Approve the vault to spend tokens on behalf of the test contract
        token.approve(address(vault), type(uint256).max);
    }

    function test_stake() public {
        vault.stake(100e18);
        assertEq(
            vault.balanceOf(address(this)),
            100e18,
            "User balance should be 100 tokens"
        );

        assertEq(
            vault.totalSupply(),
            100e18,
            "Total supply should be 100 tokens"
        );
    }

    function test_withdraw() public {
        // Stake 100 tokens first
        vault.stake(100e18);

        // Withdraw 50 tokens
        vault.withdraw(50e18);

        // Assert that the user's balance is updated
        assertEq(
            vault.balanceOf(address(this)),
            50e18,
            "User balance should be 50 tokens"
        );

        // Assert that the total supply in the vault is updated
        assertEq(
            vault.totalSupply(),
            50e18,
            "Total supply should be 50 tokens"
        );
    }

    function test_getReward() public {
        // Stake 100 tokens
        vault.stake(100e18);

        // Fast forward time by 10 seconds
        skip(10);

        // Claim rewards
        vault.getReward();

        // Assert that the user received 10 tokens as rewards (1 token per second * 10 seconds)
        assertEq(
            token.balanceOf(address(this)),
            910e18,
            "User should have 910 tokens (1000 - 100 staked + 10 rewards)"
        );

        // Assert that the rewards mapping is reset to 0
        assertEq(
            vault.rewards(address(this)),
            0,
            "Rewards should be reset to 0"
        );
    }

    function test_exit() public {
        // Stake 100 tokens
        vault.stake(100e18);

        // Fast forward time by 10 seconds
        skip(10);

        // Exit the vault
        vault.exit();

        // Assert that the user's balance in the vault is 0
        assertEq(vault.balanceOf(address(this)), 0, "User balance should be 0");

        // Assert that the total supply in the vault is 0
        assertEq(vault.totalSupply(), 0, "Total supply should be 0");

        // Assert that the user received their staked tokens and rewards
        assertEq(
            token.balanceOf(address(this)),
            1010e18,
            "User should have 1010 tokens (1000 + 10 rewards)"
        );
    }

    function test_setRewardRate() public {
        // Set a new reward rate
        vault.setRewardRate(2e18);

        // Assert that the reward rate is updated
        assertEq(
            vault.rewardRate(),
            2e18,
            "Reward rate should be updated to 2 tokens per second"
        );
    }

    function test_userRewardPerTokenPaidMapping() public {
        // Stake 100 tokens
        vault.stake(100e18);

        // Assert that the user's rewardPerTokenPaid is updated
        assertEq(
            vault.userRewardPerTokenPaid(address(this)),
            vault.rewardPerToken(),
            "userRewardPerTokenPaid should match rewardPerToken"
        );

        // Fast forward time by 10 seconds
        skip(10);

        // Stake more tokens
        vault.stake(50e18);

        // Assert that the user's rewardPerTokenPaid is updated again
        assertEq(
            vault.userRewardPerTokenPaid(address(this)),
            vault.rewardPerToken(),
            "userRewardPerTokenPaid should be updated after staking more tokens"
        );
    }

    function test_rewardsMapping() public {
        // Stake 100 tokens
        vault.stake(100e18);

        // Fast forward time by 10 seconds
        skip(10);

        // Trigger the updateReward modifier to update the rewards mapping
        vault.updateRewardsOnly();

        // Assert that the rewards mapping is updated with the earned rewards
        assertEq(
            vault.rewards(address(this)),
            10e18,
            "Rewards mapping should contain 10 tokens (1 token per second * 10 seconds)"
        );

        // Claim rewards
        vault.getReward();

        // Assert that the rewards mapping is reset to 0
        assertEq(
            vault.rewards(address(this)),
            0,
            "Rewards mapping should be reset to 0 after claiming rewards"
        );
    }

    function test_rescue() public {
        // Deploy another mock ERC20 token to simulate unrelated tokens
        MockERC20 unrelatedToken = new MockERC20("Unrelated Token", "UTK");

        // Mint some tokens to the vault
        unrelatedToken.mint(address(vault), 500e18);

        // Assert that the vault has the unrelated tokens
        assertEq(
            unrelatedToken.balanceOf(address(vault)),
            500e18,
            "Vault should have 500 unrelated tokens"
        );

        // Rescue the unrelated tokens to the owner
        vault.rescue(unrelatedToken, address(this), 500e18);

        // Assert that the unrelated tokens were transferred to the owner
        assertEq(
            unrelatedToken.balanceOf(address(this)),
            500e18,
            "Owner should have 500 rescued tokens"
        );

        // Assert that the vault no longer has the unrelated tokens
        assertEq(
            unrelatedToken.balanceOf(address(vault)),
            0,
            "Vault should have 0 unrelated tokens"
        );
    }
}
