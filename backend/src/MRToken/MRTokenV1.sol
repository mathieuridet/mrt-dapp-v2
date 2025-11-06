// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20CappedUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20CappedUpgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {UUPSProxy} from "src/UUPSProxy.sol";
import {CodeConstants} from "utils/CodeConstants.sol";

/// @title MRToken V1
/// @author Mathieu Ridet
/// @notice ERC20 token with permit functionality, capped supply, and owner minting
/// @dev Maximum supply is capped at 1,000,000 tokens
contract MRTokenV1 is ERC20Upgradeable, ERC20CappedUpgradeable, ERC20PermitUpgradeable, OwnableUpgradeable, UUPSUpgradeable, CodeConstants {
    // Storage variables
    /// @notice Useful to add state variables in new versions of the contract
    uint256[50] private __gap;

    // Functions
    /// @notice Constructs the MRToken contract
    /// @dev Mints 1000 tokens to the deployer on initialization
    function initialize(address _initialOwner) initializer public {
        __ERC20_init("MRToken", "MRT");
        __ERC20Permit_init("MRToken");
        __ERC20Capped_init(CAP);
        __Ownable_init(_initialOwner);

        _mint(_initialOwner, INITIAL_MINT);
    }

    function _authorizeUpgrade(address _newImplementation) internal override onlyOwner {}

    /// @notice Mints new tokens to the specified address
    /// @param _to Address to receive the minted tokens
    /// @param _amount Amount of tokens to mint
    /// @dev Only the owner can mint, and minting must not exceed the cap
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }

    /// @notice Updates token balances and enforces the cap
    /// @param from Address tokens are transferred from
    /// @param to Address tokens are transferred to
    /// @param value Amount of tokens to transfer
    /// @dev Overrides both ERC20Upgradeable and ERC20CappedUpgradeable _update functions
    function _update(address from, address to, uint256 value) internal override(ERC20Upgradeable, ERC20CappedUpgradeable) {
        super._update(from, to, value);
    }

    function version() external pure virtual returns (uint256) {
        return 1;
    }
}
