// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {UUPSProxy} from "src/UUPSProxy.sol";
import {MerkleDistributorV1} from "src/MerkleDistributor/MerkleDistributorV1.sol";
import {MerkleDistributorV2} from "src/MerkleDistributor/MerkleDistributorV2.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {MRTokenV1} from "src/MRToken/MRTokenV1.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

using Strings for uint256;

contract DeployScript is Script {
    struct DeployReturn {
        address merkleDistributorV1Impl;
        address proxyAddress;
        address mrtoken;
        uint256 rewardAmount;
    }

    function run() public returns (DeployReturn memory) {
        // Get deployer address
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deployer:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Step 1: Deploy MerkleDistributorV1 implementation
        console.log("\n=== Deploying MerkleDistributorV1 ===");
        MRTokenV1 mrtoken = new MRTokenV1();
        uint256 rewardAmount = 5;
        MerkleDistributorV1 merkleDistributor = new MerkleDistributorV1(mrtoken, rewardAmount);
        console.log("MerkleDistributorV1 Implementation:", address(merkleDistributor));
        
        // Step 2: Deploy proxy with MerkleDistributorV1
        console.log("\n=== Deploying UUPS Proxy ===");
        bytes memory initData = abi.encodeCall(MerkleDistributorV1.initialize, (deployer));
        UUPSProxy proxy = new UUPSProxy(address(merkleDistributor), initData);
        address proxyAddress = address(proxy);
        console.log("Proxy Address:", proxyAddress);
        console.log("Proxy Implementation:", proxy.getImplementation());
        
        // Step 3: Verify MerkleDistributorV1 works
        console.log("\n=== Testing MerkleDistributorV1 ===");
        MerkleDistributorV1 instance = MerkleDistributorV1(proxyAddress);
        console.log("i_rewardAmount is:", instance.i_rewardAmount());
        require(instance.i_rewardAmount() == rewardAmount, 
            string.concat(
                "MerkleDistributorV1 i_rewardAmount should be ",
                Strings.toString(rewardAmount)
            ));        
        vm.stopBroadcast();
        
        return DeployReturn({
            merkleDistributorV1Impl: address(merkleDistributor),
            proxyAddress: proxyAddress,
            mrtoken: address(mrtoken),
            rewardAmount: rewardAmount
        });
    }
}

/*
contract UpgradeScript is Script {
    struct UpgradeReturn {
        address merkleDistributorV2Impl;
        address proxyAddress;
        uint256 rewardAmount;
    }

    function run() public returns (UpgradeReturn memory) {
        return run(vm.envAddress("PROXY_ADDRESS"));
    }

    function run(address proxyAddress) public returns (UpgradeReturn memory) {
        // Get deployer address
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deployer:", deployer);
        console.log("Proxy Address:", proxyAddress);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Step 4: Deploy MerkleDistributorV2 implementation
        console.log("\n=== Deploying MerkleDistributorV2 ===");
        MRTokenV1 mrtoken = new MRTokenV1();
        uint256 rewardAmount = 10;
        MerkleDistributorV2 merkleDistributorV2 = new MerkleDistributorV2(mrtoken, rewardAmount);
        console.log("MerkleDistributorV2 Implementation:", address(merkleDistributorV2));
        
        // Step 5: Upgrade proxy to MerkleDistributorV2
        console.log("\n=== Upgrading Proxy to MerkleDistributorV2 ===");
        MerkleDistributorV1(proxyAddress).upgradeToAndCall(
            address(merkleDistributorV2),
            abi.encodeWithSelector(MerkleDistributorV2.initializeV2.selector)
        );

        console.log("Proxy Address (should be same):", proxyAddress);
        console.log("New Implementation:", Upgrades.getImplementationAddress(proxyAddress));
        
        // Step 6: Verify MerkleDistributorV2 works
        console.log("\n=== Testing MerkleDistributorV2 ===");
        MerkleDistributorV2 instance = MerkleDistributorV2(proxyAddress);
        console.log("i_rewardAmount is:", instance.i_rewardAmount());
        require(instance.i_rewardAmount() == rewardAmount, 
            string.concat(
                "MerkleDistributorV2 i_rewardAmount should be ",
                Strings.toString(rewardAmount)
            ));
        
        console.log("\n=== SUCCESS: Proxy address unchanged, implementation upgraded! ===");
        console.log("Proxy Address:", proxyAddress);
        console.log("Final Implementation:", Upgrades.getImplementationAddress(proxyAddress));
        
        vm.stopBroadcast();
        
        return UpgradeReturn({
            merkleDistributorV2Impl: address(merkleDistributorV2),
            proxyAddress: proxyAddress,
            rewardAmount: rewardAmount
        });
    }
}*/