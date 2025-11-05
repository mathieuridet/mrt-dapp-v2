// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {UUPSProxy} from "../../src/poc-uups-proxy.sol";
import {ContractB} from "../../src/poc-uups-proxy.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";

// To avoid casting to UUPSUpgradeable
interface IUUPS {
    function upgradeToAndCall(address newImplementation, bytes calldata data) external payable;
}

contract UpgradeScript is Script {
    function run() public {
        // Get deployer address
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");

        console.log("Deployer:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Step 4: Deploy ContractB implementation
        console.log("\n=== Deploying ContractB ===");
        ContractB contractB = new ContractB();
        console.log("ContractB Implementation:", address(contractB));
        
        // Step 5: Upgrade proxy to ContractB
        console.log("\n=== Upgrading Proxy to ContractB ===");
        IUUPS(proxyAddress).upgradeToAndCall(address(contractB), bytes(""));
        console.log("Proxy Address (should be same):", proxyAddress);
        console.log("New Implementation:", Upgrades.getImplementationAddress(proxyAddress));
        
        // Step 6: Verify ContractB works
        console.log("\n=== Testing ContractB ===");
        ContractB instanceB = ContractB(proxyAddress);
        uint256 numberB = instanceB.myNumber();
        console.log("myNumber() returns:", numberB);
        require(numberB == 2, "ContractB myNumber should return 2");
        
        console.log("\n=== SUCCESS: Proxy address unchanged, implementation upgraded! ===");
        console.log("Proxy Address:", proxyAddress);
        console.log("Final Implementation:", Upgrades.getImplementationAddress(proxyAddress));
        
        vm.stopBroadcast();
    }
}

