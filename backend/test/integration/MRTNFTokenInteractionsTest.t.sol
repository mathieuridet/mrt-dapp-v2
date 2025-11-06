//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {DeployScript, UpgradeScript} from "../../script/MRTNFTokenInteractions.s.sol";
import {MRTNFTokenV1} from "../../src/MRTNFToken/MRTNFTokenV1.sol";
import {MRTNFTokenV2} from "../../src/MRTNFToken/MRTNFTokenV2.sol";

contract MRTNFTokenInteractionsTest is Test {
    address public deployer = address(0x1);
    address public proxyAddress;

    function setUp() public {
        vm.setEnv("PRIVATE_KEY", "1");
    }

    function test_deployMRTNFToken() public {
        DeployScript deployScript = new DeployScript();
        DeployScript.DeployReturn memory result = deployScript.run();
        
        assertNotEq(result.nftTokenV1Impl, address(0), "Implementation should be deployed");
        assertNotEq(result.proxyAddress, address(0), "Proxy should be deployed");
        assertEq(result.maxSupply, 10000, "Max supply should be 10000");
        assertEq(result.mintPrice, 0.01 ether, "Mint price should be 0.01 ether");
        
        MRTNFTokenV1 instance = MRTNFTokenV1(result.proxyAddress);
        assertEq(instance.version(), 1, "Version should be 1");
        assertEq(instance.MAX_SUPPLY(), 10000, "MAX_SUPPLY should be 10000");
        
        proxyAddress = result.proxyAddress;
    }

    function test_upgradeMRTNFToken() public {
        DeployScript deployScript = new DeployScript();
        DeployScript.DeployReturn memory deployResult = deployScript.run();
        proxyAddress = deployResult.proxyAddress;
        
        vm.setEnv("PROXY_ADDRESS", vm.toString(proxyAddress));
        
        UpgradeScript upgradeScript = new UpgradeScript();
        UpgradeScript.UpgradeReturn memory upgradeResult = upgradeScript.run(proxyAddress);
        
        assertNotEq(upgradeResult.nftTokenV2Impl, address(0), "V2 Implementation should be deployed");
        assertEq(upgradeResult.proxyAddress, proxyAddress, "Proxy address should remain the same");
        
        MRTNFTokenV2 instance = MRTNFTokenV2(proxyAddress);
        assertEq(instance.version(), 2, "Version should be 2");
        assertEq(instance.s_addStorageVarTest(), 4, "New storage variable should be set");
        assertEq(instance.MAX_SUPPLY(), 10000, "MAX_SUPPLY should persist");
    }

    function test_deployAndUpgradeMRTNFToken() public {
        DeployScript deployScript = new DeployScript();
        DeployScript.DeployReturn memory deployResult = deployScript.run();
        
        MRTNFTokenV1 instanceV1 = MRTNFTokenV1(deployResult.proxyAddress);
        assertEq(instanceV1.version(), 1, "Initial version should be 1");
        assertEq(instanceV1.MAX_SUPPLY(), 10000, "Initial MAX_SUPPLY should be 10000");
        
        UpgradeScript upgradeScript = new UpgradeScript();
        UpgradeScript.UpgradeReturn memory upgradeResult = upgradeScript.run(deployResult.proxyAddress);
        
        assertEq(upgradeResult.proxyAddress, deployResult.proxyAddress, "Proxy address should remain the same");
        
        MRTNFTokenV2 instanceV2 = MRTNFTokenV2(deployResult.proxyAddress);
        assertEq(instanceV2.version(), 2, "Version should be 2 after upgrade");
        assertEq(instanceV2.s_addStorageVarTest(), 4, "New storage variable should be set");
        assertEq(instanceV2.MAX_SUPPLY(), 10000, "MAX_SUPPLY should persist after upgrade");
    }
}

