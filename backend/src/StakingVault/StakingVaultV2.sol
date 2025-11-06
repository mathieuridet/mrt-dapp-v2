// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StakingVaultV1} from "./StakingVaultV1.sol";

/// @title StakingVault V2
/// @author Mathieu Ridet
/// @notice Single-sided staking vault paying rewards in the same ERC20 token (upgraded version)
/// @dev Adds new storage variable for testing upgrades
contract StakingVaultV2 is StakingVaultV1 {
    // State variables
    /// @notice New storage variable added in V2 for testing
    uint8 public s_addStorageVarTest;

    /// @notice Useful to add state variables in new versions of the contract
    uint256[44] private __gap;

    // Functions
    /// @notice Constructs the StakingVaultV2 contract
    /// @param _token ERC20 token used for staking and rewards
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(IERC20 _token) StakingVaultV1(_token) {}

    /// @notice New initializer for upgrade v1 -> v2
    function initializeV2() public reinitializer(2) {
        s_addStorageVarTest = 4;
    }

    /// @notice Returns the version of this contract
    /// @return Version number (2 for V2)
    function version() external pure override returns (uint256) {
        return 2;
    }
}

