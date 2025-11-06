// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MerkleDistributorV1} from "src/MerkleDistributor/MerkleDistributorV1.sol";
import {MockERC20} from "../../TestHelper.sol";
import {UUPSProxy} from "src/UUPSProxy.sol";

contract MerkleDistributorTest is Test {

    MerkleDistributorV1 public distributor;
    UUPSProxy public proxy;
    address public proxyAddress;

    MockERC20 public token;

    bytes32 public merkleRoot;
    uint256 public rewardAmount = 100e18;
    address public owner;

    function setUp() public {
        // Deploy a mock ERC20 token
        token = new MockERC20("MRT Mock Token", "MRT");

        // Mint tokens to the test contract
        token.mint(address(this), 1_000e18);

        // Deploy the MerkleDistributorV1 contract
        distributor = new MerkleDistributorV1(token, rewardAmount);

        // Approve the distributor to spend tokens
        token.approve(address(distributor), type(uint256).max);

        // Set the owner
        owner = address(this);

        bytes memory initData = abi.encodeCall(MerkleDistributorV1.initialize, (owner));
        proxy = new UUPSProxy(address(distributor), initData);
        proxyAddress = address(proxy);
    }

    function test_setRoot() public {
        MerkleDistributorV1 instance = MerkleDistributorV1(proxyAddress);

        bytes32 newRoot = keccak256(abi.encodePacked("test"));
        uint64 newRound = 1;

        // Set the Merkle root
        instance.setRoot(newRoot, newRound);

        // Assert that the Merkle root and round are updated
        assertEq(instance.s_merkleRoot(), newRoot, "Merkle root should be updated");
        assertEq(instance.s_round(), newRound, "Round should be updated");
    }

    function test_claim() public {
        MerkleDistributorV1 instance = MerkleDistributorV1(proxyAddress);

        // Set up the Merkle tree
        address account = address(0x123);
        uint64 round = 1;
        uint256 amount = rewardAmount;

        // Generate the leaf node
        bytes32 leaf = keccak256(abi.encodePacked(account, amount, round));

        // Construct the Merkle tree
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = leaf;

        // Generate the Merkle root
        bytes32 root = computeMerkleRoot(leaves);
        instance.setRoot(root, round);

        // Generate the proof (empty for a single leaf)
        bytes32[] memory proof = new bytes32[](0);

        // Mint tokens to the distributor
        token.mint(address(instance), amount);

        // Claim the reward
        vm.prank(account);
        instance.claim(round, account, amount, proof);

        // Assert that the reward was transferred
        assertEq(token.balanceOf(account), amount, "Account should receive the reward");

        // Assert that the claim is marked as claimed
        assertTrue(instance.isClaimed(round, account), "Claim should be marked as claimed");
    }

    function test_preventDoubleClaim() public {
        MerkleDistributorV1 instance = MerkleDistributorV1(proxyAddress);

        // Set up the Merkle tree
        address account = address(0x123);
        uint64 round = 1;
        uint256 amount = rewardAmount;

        // Generate the leaf node
        bytes32 leaf = keccak256(abi.encodePacked(account, amount, round));

        // Construct the Merkle tree
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = leaf;

        // Generate the Merkle root
        bytes32 root = computeMerkleRoot(leaves);
        instance.setRoot(root, round);

        // Generate the proof (empty for a single leaf)
        bytes32[] memory proof = new bytes32[](0);

        // Mint tokens to the distributor
        token.mint(address(instance), amount);

        // Claim the reward
        vm.prank(account);
        instance.claim(round, account, rewardAmount, proof);

        // Attempt to claim again
        vm.prank(account);
        vm.expectRevert(MerkleDistributorV1.MerkleDistributor__AlreadyClaimed.selector);
        instance.claim(round, account, rewardAmount, proof);
    }

    function test_invalidProof() public {
        MerkleDistributorV1 instance = MerkleDistributorV1(proxyAddress);

        // Set up the Merkle tree
        address account = address(0x123);
        uint64 round = 1;
        bytes32 leaf = keccak256(abi.encodePacked(account, rewardAmount, round));
        merkleRoot = keccak256(abi.encodePacked(leaf));
        instance.setRoot(merkleRoot, round);

        // Mint tokens to the distributor
        token.mint(address(instance), rewardAmount);

        // Attempt to claim with an invalid proof
        bytes32[] memory invalidProof = new bytes32[](1);
        invalidProof[0] = keccak256(abi.encodePacked("invalid"));
        vm.prank(account);
        vm.expectRevert(MerkleDistributorV1.MerkleDistributor__BadProof.selector);
        instance.claim(round, account, rewardAmount, invalidProof);
    }

    function test_rescue() public {
        MerkleDistributorV1 instance = MerkleDistributorV1(proxyAddress);

        // Mint tokens to the distributor
        uint256 rescueAmount = 500e18;
        token.mint(address(instance), rescueAmount);

        // Get the owner's initial balance
        uint256 initialBalance = token.balanceOf(address(this));

        // Rescue the tokens
        instance.rescue(address(this), rescueAmount);

        // Assert that the tokens were transferred to the owner
        assertEq(
            token.balanceOf(address(this)), initialBalance + rescueAmount, "Owner should receive the rescued tokens"
        );
    }

    function test_onlyOwnerCanRescue() public {
        MerkleDistributorV1 instance = MerkleDistributorV1(proxyAddress);

        // Mint tokens to the distributor
        uint256 rescueAmount = 500e18;
        token.mint(address(instance), rescueAmount);

        // Attempt to rescue tokens as a non-owner
        address nonOwner = address(0x456);
        vm.prank(nonOwner);
        vm.expectRevert();
        instance.rescue(nonOwner, rescueAmount);
    }

    function computeMerkleRoot(bytes32[] memory leaves) internal pure returns (bytes32) {        
        require(leaves.length > 0, "NO_LEAVES");

        while (leaves.length > 1) {
            uint256 n = (leaves.length + 1) / 2;
            bytes32[] memory newLeaves = new bytes32[](n);

            for (uint256 i = 0; i < leaves.length / 2; i++) {
                newLeaves[i] = keccak256(abi.encodePacked(leaves[2 * i], leaves[2 * i + 1]));
            }

            if (leaves.length % 2 == 1) {
                newLeaves[n - 1] = leaves[leaves.length - 1];
            }

            leaves = newLeaves;
        }

        return leaves[0];
    }
}
