// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {MerkleDistributorV1} from "./MerkleDistributorV1.sol";

contract MerkleDistributorV2 is MerkleDistributorV1 {
    // Dummy ctor ONLY to satisfy V1's non-empty constructor; NOT executed via proxy.
    constructor() MerkleDistributorV1(IERC20(address(0)), 0) {}

    // New mutable reward (0 => fallback to immutable i_rewardAmount)
    uint256 private s_rewardAmount;

    // Separate claimed map for V2 path (since V1.claimed is private)
    mapping(uint64 => mapping(address => bool)) private s_claimedV2;

    event RewardAmountUpdated(uint256 newAmount);

    function version() external pure override returns (uint256) { return 2; }

    function setRewardAmount(uint256 newAmount) external onlyOwner {
        s_rewardAmount = newAmount;
        emit RewardAmountUpdated(newAmount);
    }

    /// Effective reward used by V2 (prefers mutable, falls back to immutable)
    function rewardAmount() public view returns (uint256) {
        uint256 m = s_rewardAmount;
        return m != 0 ? m : i_rewardAmount;
    }

    /// @notice New claim entrypoint that uses the mutable reward.
    /// @dev amount is derived, not user-provided; proof is built over (account, amount, r)
    function claimV2(
        uint64 r,
        address account,
        bytes32[] calldata merkleProof
    ) external {
        require(r == s_round, MerkleDistributor__WrongRound());
        require(!s_claimedV2[r][account], MerkleDistributor__AlreadyClaimed());

        uint256 amount = rewardAmount();

        bytes32 leaf = keccak256(abi.encodePacked(account, amount, r));
        require(MerkleProof.verify(merkleProof, s_merkleRoot, leaf), MerkleDistributor__BadProof());

        s_claimedV2[r][account] = true;

        require(i_token.transfer(account, amount), MerkleDistributor__TransferFailed());
        emit Claimed(r, account, amount);
    }

    /// Optional view to help frontends/backends
    function isClaimedV2(uint64 r, address account) external view returns (bool) {
        return s_claimedV2[r][account];
    }
}
