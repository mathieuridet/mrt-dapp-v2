// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @notice One-time token claims for an allowlist using a Merkle root.
/// Leaf = keccak256(abi.encodePacked(index, account, amount))
contract MerkleDistributor is Ownable {
    IERC20 public immutable TOKEN;
    uint256 public immutable REWARD_AMOUNT;
    bytes32 public merkleRoot;
    uint64 public round;

    // one bit per address per round
    mapping(uint64 => mapping(address => bool)) private claimed;

    event RootUpdated(bytes32 indexed newRoot, uint64 indexed newRound);
    event Claimed(uint64 indexed round, address indexed account, uint256 amount);

    constructor(address initialOwner, IERC20 _token, uint256 _rewardAmount) Ownable(initialOwner) {
        TOKEN = _token;
        REWARD_AMOUNT = _rewardAmount;
    }

    function setRoot(bytes32 newRoot, uint64 newRound) external onlyOwner {
        require(newRoot != bytes32(0), "ROOT_0");
        // allow updating multiple times within the same hour/round
        require(newRound >= round, "ROUND_BACKWARDS");
        merkleRoot = newRoot;
        round = newRound;
        emit RootUpdated(newRoot, newRound);
    }

    function isClaimed(uint64 r, address a) public view returns (bool) {
        return claimed[r][a];
    }

    function claim(uint64 r, address account, uint256 amount, bytes32[] calldata merkleProof) external {
        require(r == round, "WRONG_ROUND");
        require(amount == REWARD_AMOUNT, "AMOUNT");
        require(!claimed[r][account], "ALREADY_CLAIMED");

        bytes32 leaf = keccak256(abi.encodePacked(account, amount, r));
        require(MerkleProof.verify(merkleProof, merkleRoot, leaf), "BAD_PROOF");

        claimed[r][account] = true;
        require(TOKEN.transfer(account, amount), "TRANSFER_FAILED");
        emit Claimed(r, account, amount);
    }

    /// @notice owner can rescue leftover tokens (after the claim window)
    function rescue(address to, uint256 amount) external onlyOwner {
        require(TOKEN.transfer(to, amount), "TRANSFER_FAILED");
    }
}
