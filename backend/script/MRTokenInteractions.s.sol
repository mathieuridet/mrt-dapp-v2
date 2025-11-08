// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {UUPSProxy} from "src/UUPSProxy.sol";
import {MRTokenV1} from "src/MRToken/MRTokenV1.sol";
import {MRTokenV2} from "src/MRToken/MRTokenV2.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

using Strings for uint256;

contract DeployScript is Script {
    struct DeployReturn {
        address mrtokenV1Impl;
        address proxyAddress;
    }

    function run() public returns (DeployReturn memory) {
        // Get deployer address
        string memory deployerPrivateKey = vm.envString("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deployer:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Step 1: Deploy MRTokenV1 implementation
        console.log("\n=== Deploying MRTokenV1 ===");
        MRTokenV1 mrtokenV1 = new MRTokenV1();
        console.log("MRTokenV1 Implementation:", address(mrtokenV1));
        
        // Step 2: Deploy proxy with MRTokenV1
        console.log("\n=== Deploying UUPS Proxy ===");
        bytes memory initData = abi.encodeCall(MRTokenV1.initialize, (deployer));
        UUPSProxy proxy = new UUPSProxy(address(mrtokenV1), initData);
        address proxyAddress = address(proxy);
        console.log("Proxy Address:", proxyAddress);
        console.log("Proxy Implementation:", proxy.getImplementation());
        
        // Step 3: Verify MRTokenV1 works
        console.log("\n=== Testing MRTokenV1 ===");
        MRTokenV1 instance = MRTokenV1(proxyAddress);
        uint256 version = instance.version();
        console.log("version() returns:", version);
        require(version == 1, "MRTokenV1 version should return 1");
        
        // Check initial balance
        uint256 deployerBalance = instance.balanceOf(deployer);
        console.log("Deployer balance:", deployerBalance);
        
        // Check total supply
        uint256 totalSupply = instance.totalSupply();
        console.log("Total supply:", totalSupply);
        
        vm.stopBroadcast();
        
        return DeployReturn({
            mrtokenV1Impl: address(mrtokenV1),
            proxyAddress: proxyAddress
        });
    }
}

contract UpgradeScript is Script {
    struct UpgradeReturn {
        address mrtokenV2Impl;
        address proxyAddress;
    }

    function run() public returns (UpgradeReturn memory) {
        return run(vm.envAddress("PROXY_ADDRESS"));
    }

    function run(address proxyAddress) public returns (UpgradeReturn memory) {
        // Get deployer address
        string memory deployerPrivateKey = vm.envString("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deployer:", deployer);
        console.log("Proxy Address:", proxyAddress);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Step 4: Deploy MRTokenV2 implementation
        console.log("\n=== Deploying MRTokenV2 ===");
        MRTokenV2 mrtokenV2 = new MRTokenV2();
        console.log("MRTokenV2 Implementation:", address(mrtokenV2));
        
        // Step 5: Upgrade proxy to MRTokenV2
        console.log("\n=== Upgrading Proxy to MRTokenV2 ===");
        MRTokenV1(proxyAddress).upgradeToAndCall(
            address(mrtokenV2),
            abi.encodeWithSelector(MRTokenV2.initializeV2.selector)
        );

        console.log("Proxy Address (should be same):", proxyAddress);
        console.log("New Implementation:", Upgrades.getImplementationAddress(proxyAddress));
        
        // Step 6: Verify MRTokenV2 works
        console.log("\n=== Testing MRTokenV2 ===");
        MRTokenV2 instance = MRTokenV2(proxyAddress);
        uint256 version = instance.version();
        console.log("version() returns:", version);
        require(version == 2, "MRTokenV2 version should return 2");
        
        // Check new storage variable
        uint8 storageVar = instance.s_addStorageVarTest();
        console.log("s_addStorageVarTest:", storageVar);
        require(storageVar == 4, "MRTokenV2 s_addStorageVarTest should be 4");
        
        // Verify storage persisted (balance should still be there)
        uint256 deployerBalance = instance.balanceOf(deployer);
        console.log("Deployer balance (should persist):", deployerBalance);
        
        console.log("\n=== SUCCESS: Proxy address unchanged, implementation upgraded! ===");
        console.log("Proxy Address:", proxyAddress);
        console.log("Final Implementation:", Upgrades.getImplementationAddress(proxyAddress));
        
        vm.stopBroadcast();
        
        return UpgradeReturn({
            mrtokenV2Impl: address(mrtokenV2),
            proxyAddress: proxyAddress
        });
    }
}

