// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

contract UUPSProxy is ERC1967Proxy {
    constructor(address _implementation, bytes memory _data) ERC1967Proxy(_implementation, _data) payable {}

    function getImplementation() external view returns (address) {
        // Reads the EIP-1967 implementation slot in *this proxy's* storage
        return ERC1967Utils.getImplementation();
    }
}

contract ContractA is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) initializer public {
        __Ownable_init(initialOwner);
        // UUPSUpgradeable doesn't need initialization in v5
    }

    function myNumber() public pure returns (uint256) {
        return 1;
    }

    function _authorizeUpgrade(address _newImplementation) internal override onlyOwner {}
}

contract ContractB is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) initializer public {
        __Ownable_init(initialOwner);
        // UUPSUpgradeable doesn't need initialization in v5
    }

    function myNumber() public pure returns (uint256) {
        return 2;
    }

    function _authorizeUpgrade(address _newImplementation) internal override onlyOwner {}
}