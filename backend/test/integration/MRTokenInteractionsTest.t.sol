//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {DeployScript, UpgradeScript} from "../../script/MRTokenInteractions.s.sol";
import {MRTokenV1} from "../../src/MRToken/MRTokenV1.sol";
import {MRTokenV2} from "../../src/MRToken/MRTokenV2.sol";

contract MRTokenInteractionsTest is Test {
    address public deployer = address(0x1);
    address public proxyAddress;

    function setUp() public {
        vm.setEnv("PRIVATE_KEY", "1");
    }

    function test_deployMRToken() public {
        DeployScript deployScript = new DeployScript();
        DeployScript.DeployReturn memory result = deployScript.run();
        
        assertNotEq(result.mrtokenV1Impl, address(0), "Implementation should be deployed");
        assertNotEq(result.proxyAddress, address(0), "Proxy should be deployed");
        
        MRTokenV1 instance = MRTokenV1(result.proxyAddress);
        assertEq(instance.version(), 1, "Version should be 1");
        
        proxyAddress = result.proxyAddress;
    }

    function test_upgradeMRToken() public {
        DeployScript deployScript = new DeployScript();
        DeployScript.DeployReturn memory deployResult = deployScript.run();
        proxyAddress = deployResult.proxyAddress;
        
        UpgradeScript upgradeScript = new UpgradeScript();
        UpgradeScript.UpgradeReturn memory upgradeResult = upgradeScript.run(proxyAddress);
        
        assertNotEq(upgradeResult.mrtokenV2Impl, address(0), "V2 Implementation should be deployed");
        assertEq(upgradeResult.proxyAddress, proxyAddress, "Proxy address should remain the same");
        
        MRTokenV2 instance = MRTokenV2(proxyAddress);
        assertEq(instance.version(), 2, "Version should be 2");
        assertEq(instance.s_addStorageVarTest(), 4, "New storage variable should be set");
    }

    function test_deployAndUpgradeMRToken() public {
        DeployScript deployScript = new DeployScript();
        DeployScript.DeployReturn memory deployResult = deployScript.run();
        
        MRTokenV1 instanceV1 = MRTokenV1(deployResult.proxyAddress);
        assertEq(instanceV1.version(), 1, "Initial version should be 1");
        
        UpgradeScript upgradeScript = new UpgradeScript();
        UpgradeScript.UpgradeReturn memory upgradeResult = upgradeScript.run(deployResult.proxyAddress);
        
        assertEq(upgradeResult.proxyAddress, deployResult.proxyAddress, "Proxy address should remain the same");
        
        MRTokenV2 instanceV2 = MRTokenV2(deployResult.proxyAddress);
        assertEq(instanceV2.version(), 2, "Version should be 2 after upgrade");
        assertEq(instanceV2.s_addStorageVarTest(), 4, "New storage variable should be set");
    }
}

