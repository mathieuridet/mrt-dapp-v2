// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {UUPSProxy} from "src/UUPSProxy.sol";
import {StakingVaultV1} from "src/StakingVault/StakingVaultV1.sol";
import {StakingVaultV2} from "src/StakingVault/StakingVaultV2.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {MRTokenV1} from "src/MRToken/MRTokenV1.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

using Strings for uint256;

contract DeployScript is Script {
    function run() public {
        // Get deployer address
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deployer:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Step 1: Deploy MRToken (needed for staking)
        console.log("\n=== Deploying MRToken ===");
        MRTokenV1 mrtoken = new MRTokenV1();
        console.log("MRToken Implementation:", address(mrtoken));
        
        // Deploy MRToken proxy
        bytes memory tokenInitData = abi.encodeCall(MRTokenV1.initialize, (deployer));
        UUPSProxy tokenProxy = new UUPSProxy(address(mrtoken), tokenInitData);
        address tokenProxyAddress = address(tokenProxy);
        console.log("MRToken Proxy Address:", tokenProxyAddress);
        
        // Step 2: Deploy StakingVaultV1 implementation
        console.log("\n=== Deploying StakingVaultV1 ===");
        StakingVaultV1 stakingVaultV1 = new StakingVaultV1(IERC20(tokenProxyAddress));
        console.log("StakingVaultV1 Implementation:", address(stakingVaultV1));
        
        // Step 3: Deploy proxy with StakingVaultV1
        console.log("\n=== Deploying UUPS Proxy ===");
        uint256 rewardRate = 1e18; // 1 token per second
        bytes memory initData = abi.encodeCall(StakingVaultV1.initialize, (deployer, rewardRate));
        UUPSProxy proxy = new UUPSProxy(address(stakingVaultV1), initData);
        address proxyAddress = address(proxy);
        console.log("Proxy Address:", proxyAddress);
        console.log("Proxy Implementation:", proxy.getImplementation());
        
        // Step 4: Verify StakingVaultV1 works
        console.log("\n=== Testing StakingVaultV1 ===");
        StakingVaultV1 instance = StakingVaultV1(proxyAddress);
        uint256 version = instance.version();
        console.log("version() returns:", version);
        require(version == 1, "StakingVaultV1 version should return 1");
        
        uint256 currentRewardRate = instance.rewardRate();
        console.log("rewardRate:", currentRewardRate);
        require(currentRewardRate == rewardRate, "StakingVaultV1 rewardRate should match");
        
        vm.stopBroadcast();
    }
}

contract UpgradeScript is Script {
    function run() public {
        // Get deployer address
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");

        console.log("Deployer:", deployer);
        console.log("Proxy Address:", proxyAddress);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Get the staking token address from the proxy
        StakingVaultV1 instanceV1 = StakingVaultV1(proxyAddress);
        address stakingToken = address(instanceV1.i_stakingToken());
        console.log("Staking Token:", stakingToken);
        
        // Step 4: Deploy StakingVaultV2 implementation
        console.log("\n=== Deploying StakingVaultV2 ===");
        StakingVaultV2 stakingVaultV2 = new StakingVaultV2(IERC20(stakingToken));
        console.log("StakingVaultV2 Implementation:", address(stakingVaultV2));
        
        // Step 5: Upgrade proxy to StakingVaultV2
        console.log("\n=== Upgrading Proxy to StakingVaultV2 ===");
        instanceV1.upgradeToAndCall(
            address(stakingVaultV2),
            abi.encodeWithSelector(StakingVaultV2.initializeV2.selector)
        );

        console.log("Proxy Address (should be same):", proxyAddress);
        console.log("New Implementation:", Upgrades.getImplementationAddress(proxyAddress));
        
        // Step 6: Verify StakingVaultV2 works
        console.log("\n=== Testing StakingVaultV2 ===");
        StakingVaultV2 instance = StakingVaultV2(proxyAddress);
        uint256 version = instance.version();
        console.log("version() returns:", version);
        require(version == 2, "StakingVaultV2 version should return 2");
        
        // Check new storage variable
        uint8 storageVar = instance.s_addStorageVarTest();
        console.log("s_addStorageVarTest:", storageVar);
        require(storageVar == 4, "StakingVaultV2 s_addStorageVarTest should be 4");
        
        // Verify storage persisted (rewardRate should still be there)
        uint256 rewardRate = instance.rewardRate();
        console.log("rewardRate (should persist):", rewardRate);
        
        console.log("\n=== SUCCESS: Proxy address unchanged, implementation upgraded! ===");
        console.log("Proxy Address:", proxyAddress);
        console.log("Final Implementation:", Upgrades.getImplementationAddress(proxyAddress));
        
        vm.stopBroadcast();
    }
}

