// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {UUPSProxy} from "src/UUPSProxy.sol";

/// @title MerkleDistributor V2 (only for proxy testing)
contract MerkleDistributorV2 is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    // Errors
    /// @notice Error thrown when root is set to zero
    error MerkleDistributor__RootZero();

    /// @notice Error thrown when attempting to set a round backwards
    error MerkleDistributor__RoundBackwards();

    /// @notice Error thrown when claim amount doesn't match i_rewardAmount
    error MerkleDistributor__WrongAmount();

    /// @notice Error thrown when address has already claimed for this round
    error MerkleDistributor__AlreadyClaimed();

    /// @notice Error thrown when claiming for wrong round
    error MerkleDistributor__WrongRound();

    /// @notice Error thrown when Merkle proof verification fails
    error MerkleDistributor__BadProof();

    /// @notice Error thrown when token transfer fails
    error MerkleDistributor__TransferFailed();

    // State variables
    /// @notice ERC20 token being distributed
    IERC20 public immutable i_token;

    /// @notice Fixed reward amount per claim
    uint256 public immutable i_rewardAmount;

    /// @notice Current Merkle root for claim verification
    bytes32 public s_merkleRoot;

    /// @notice Current distribution round
    uint64 public s_round;

    /// @notice Mapping of round => address => claimed status
    mapping(uint64 => mapping(address => bool)) private claimed;

    uint8 public s_addStorageVarTest;

    /// @notice Useful to add state variables in new versions of the contract
    uint256[49] private __gap;

    // Events
    /// @notice Emitted when a new root and round are set
    /// @param newRoot New Merkle root
    /// @param newRound New round number
    event RootUpdated(bytes32 indexed newRoot, uint64 indexed newRound);

    /// @notice Emitted when a claim is successful
    /// @param round Round number of the claim
    /// @param account Address that claimed
    /// @param amount Amount claimed
    event Claimed(uint64 indexed round, address indexed account, uint256 amount);

    // Functions
    /// @notice Constructs the MerkleDistributor contract
    /// @param _token ERC20 token to distribute
    /// @param _rewardAmount Fixed reward amount per claim
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(IERC20 _token, uint256 _rewardAmount) {
        _disableInitializers();

        i_token = _token;
        i_rewardAmount = _rewardAmount;
    }

    /// @notice new initializer for upgrade v1 -> v2
    function initializeV2() public reinitializer(2) {
        s_addStorageVarTest = 4;
    }

    function _authorizeUpgrade(address _newImplementation) internal override onlyOwner {}

    /// @notice Sets a new Merkle root and round for claims
    /// @param newRoot New Merkle root for claim verification
    /// @param newRound New round number (must be >= current round)
    /// @dev Allows updating multiple times within the same round
    function setRoot(bytes32 newRoot, uint64 newRound) external onlyOwner {
        require(newRoot != bytes32(0), MerkleDistributor__RootZero());
        require(newRound >= s_round, MerkleDistributor__RoundBackwards());
        s_merkleRoot = newRoot;
        s_round = newRound;
        emit RootUpdated(newRoot, newRound);
    }

    /// @notice Claims tokens for an address using a Merkle proof
    /// @param r Round number to claim for
    /// @param account Address claiming the reward
    /// @param amount Amount to claim (must equal i_rewardAmount)
    /// @param merkleProof Merkle proof to verify the claim
    /// @dev Can only claim once per round per address
    function claim(uint64 r, address account, uint256 amount, bytes32[] calldata merkleProof) external {
        require(r == s_round, MerkleDistributor__WrongRound());
        require(amount == i_rewardAmount, MerkleDistributor__WrongAmount());
        require(!claimed[r][account], MerkleDistributor__AlreadyClaimed());

        bytes32 leaf = keccak256(abi.encodePacked(account, amount, r));
        require(MerkleProof.verify(merkleProof, s_merkleRoot, leaf), MerkleDistributor__BadProof());

        claimed[r][account] = true;
        require(i_token.transfer(account, amount), MerkleDistributor__TransferFailed());
        emit Claimed(r, account, amount);
    }

    /// @notice Owner can rescue leftover tokens after the claim window
    /// @param to Address to receive the rescued tokens
    /// @param amount Amount of tokens to rescue
    function rescue(address to, uint256 amount) external onlyOwner {
        require(i_token.transfer(to, amount), MerkleDistributor__TransferFailed());
    }

    /// @notice Checks if an address has claimed for a specific round
    /// @param r Round number to check
    /// @param a Address to check
    /// @return True if the address has claimed for this round
    function isClaimed(uint64 r, address a) public view returns (bool) {
        return claimed[r][a];
    }

    function version() external pure returns (uint256) {
        return 2;
    }
}