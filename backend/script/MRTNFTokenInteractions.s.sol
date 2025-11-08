// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {UUPSProxy} from "src/UUPSProxy.sol";
import {MRTNFTokenV1} from "src/MRTNFToken/MRTNFTokenV1.sol";
import {MRTNFTokenV2} from "src/MRTNFToken/MRTNFTokenV2.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

using Strings for uint256;

contract DeployScript is Script {
    struct DeployReturn {
        address nftTokenV1Impl;
        address proxyAddress;
        uint256 maxSupply;
        uint256 mintPrice;
    }

    function run() public returns (DeployReturn memory) {
        // Get deployer address
        string memory deployerPrivateKey = vm.envString("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deployer:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Step 1: Deploy MRTNFTokenV1 implementation
        console.log("\n=== Deploying MRTNFTokenV1 ===");
        uint256 maxSupply = 10000;
        uint256 mintPrice = 0.01 ether;
        MRTNFTokenV1 nftTokenV1 = new MRTNFTokenV1(maxSupply, mintPrice);
        console.log("MRTNFTokenV1 Implementation:", address(nftTokenV1));
        
        // Step 2: Deploy proxy with MRTNFTokenV1
        console.log("\n=== Deploying UUPS Proxy ===");
        string memory baseURI = "ipfs://QmTest/";
        address royaltyReceiver = deployer;
        uint96 royaltyBps = 500; // 5%
        bytes memory initData = abi.encodeCall(
            MRTNFTokenV1.initialize,
            (deployer, baseURI, royaltyReceiver, royaltyBps)
        );
        UUPSProxy proxy = new UUPSProxy(address(nftTokenV1), initData);
        address proxyAddress = address(proxy);
        console.log("Proxy Address:", proxyAddress);
        console.log("Proxy Implementation:", proxy.getImplementation());
        
        // Step 3: Verify MRTNFTokenV1 works
        console.log("\n=== Testing MRTNFTokenV1 ===");
        MRTNFTokenV1 instance = MRTNFTokenV1(proxyAddress);
        uint256 version = instance.version();
        console.log("version() returns:", version);
        require(version == 1, "MRTNFTokenV1 version should return 1");
        
        uint256 maxSupplyValue = instance.i_maxSupply();
        console.log("i_maxSupply:", maxSupplyValue);
        require(maxSupplyValue == maxSupply, "MRTNFTokenV1 i_maxSupply should match");
        
        vm.stopBroadcast();
        
        return DeployReturn({
            nftTokenV1Impl: address(nftTokenV1),
            proxyAddress: proxyAddress,
            maxSupply: maxSupply,
            mintPrice: mintPrice
        });
    }
}

contract UpgradeScript is Script {
    struct UpgradeReturn {
        address nftTokenV2Impl;
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
        
        // Get the max supply and mint price from the proxy
        MRTNFTokenV1 instanceV1 = MRTNFTokenV1(proxyAddress);
        uint256 maxSupply = instanceV1.i_maxSupply();
        uint256 mintPrice = instanceV1.i_mintPrice();
        console.log("i_maxSupply:", maxSupply);
        console.log("MINT_PRICE:", mintPrice);
        
        // Step 4: Deploy MRTNFTokenV2 implementation
        console.log("\n=== Deploying MRTNFTokenV2 ===");
        MRTNFTokenV2 nftTokenV2 = new MRTNFTokenV2(maxSupply, mintPrice);
        console.log("MRTNFTokenV2 Implementation:", address(nftTokenV2));
        
        // Step 5: Upgrade proxy to MRTNFTokenV2
        console.log("\n=== Upgrading Proxy to MRTNFTokenV2 ===");
        instanceV1.upgradeToAndCall(
            address(nftTokenV2),
            abi.encodeWithSelector(MRTNFTokenV2.initializeV2.selector)
        );

        console.log("Proxy Address (should be same):", proxyAddress);
        console.log("New Implementation:", Upgrades.getImplementationAddress(proxyAddress));
        
        // Step 6: Verify MRTNFTokenV2 works
        console.log("\n=== Testing MRTNFTokenV2 ===");
        MRTNFTokenV2 instance = MRTNFTokenV2(proxyAddress);
        uint256 version = instance.version();
        console.log("version() returns:", version);
        require(version == 2, "MRTNFTokenV2 version should return 2");
        
        // Check new storage variable
        uint8 storageVar = instance.s_addStorageVarTest();
        console.log("s_addStorageVarTest:", storageVar);
        require(storageVar == 4, "MRTNFTokenV2 s_addStorageVarTest should be 4");
        
        // Verify storage persisted (i_maxSupply should still be there)
        uint256 maxSupplyValue = instance.i_maxSupply();
        console.log("i_maxSupply (should persist):", maxSupplyValue);
        
        console.log("\n=== SUCCESS: Proxy address unchanged, implementation upgraded! ===");
        console.log("Proxy Address:", proxyAddress);
        console.log("Final Implementation:", Upgrades.getImplementationAddress(proxyAddress));
        
        vm.stopBroadcast();
        
        return UpgradeReturn({
            nftTokenV2Impl: address(nftTokenV2),
            proxyAddress: proxyAddress
        });
    }
}

