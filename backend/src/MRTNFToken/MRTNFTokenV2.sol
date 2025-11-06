// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MRTNFTokenV1} from "./MRTNFTokenV1.sol";

/// @title MRTNFToken V2
/// @author Mathieu Ridet
/// @notice ERC721 NFT token with minting, royalties, and cooldown protection (upgraded version)
/// @dev Adds new storage variable for testing upgrades
contract MRTNFTokenV2 is MRTNFTokenV1 {
    // State variables
    /// @notice New storage variable added in V2 for testing
    uint8 public s_addStorageVarTest;

    /// @notice Useful to add state variables in new versions of the contract
    uint256[44] private __gap;

    // Functions
    /// @notice Constructs the MRTNFTokenV2 contract
    /// @param maxSupply Maximum number of NFTs that can be minted
    /// @param mintPriceWei Price per NFT in wei
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(uint256 maxSupply, uint256 mintPriceWei) MRTNFTokenV1(maxSupply, mintPriceWei) {}

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

