// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MRTokenV1} from "./MRTokenV1.sol";

/// @title MRToken V2 (just for upgrade testing)
/// @author Mathieu Ridet
/// @notice ERC20 token with permit functionality, capped supply, and owner minting
/// @dev Maximum supply is capped at 1,000,000 tokens
contract MRTokenV2 is MRTokenV1 {
    // Storage variables
    uint8 public s_addStorageVarTest;

    /// @notice Useful to add state variables in new versions of the contract
    uint256[49] private __gap;

    // Functions
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
