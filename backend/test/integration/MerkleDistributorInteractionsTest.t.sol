//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {DeployScript} from "script/MerkleDistributorInteractions.s.sol";
//import {DeployScript, UpgradeScript} from "script/MerkleDistributorInteractions.s.sol";
import {MerkleDistributorV1} from "src/MerkleDistributor/MerkleDistributorV1.sol";
import {MerkleDistributorV2} from "src/MerkleDistributor/MerkleDistributorV2.sol";

contract MerkleDistributorInteractionsTest is Test {
    address public deployer = address(0x1);
    address public proxyAddress;

    function setUp() public {
        // Set up environment variables for the script
        vm.setEnv("PRIVATE_KEY", "1"); // Private key for address(0x1)
    }

    function test_deployMerkleDistributor() public {
        DeployScript deployScript = new DeployScript();
        
        // Run deploy script
        DeployScript.DeployReturn memory result = deployScript.run();
        
        // Verify results
        assertNotEq(result.merkleDistributorV1Impl, address(0), "Implementation should be deployed");
        assertNotEq(result.proxyAddress, address(0), "Proxy should be deployed");
        assertNotEq(result.mrtoken, address(0), "MRToken should be deployed");
        assertEq(result.rewardAmount, 5, "Reward amount should be 5");
        
        // Verify proxy works
        MerkleDistributorV1 instance = MerkleDistributorV1(result.proxyAddress);
        assertEq(instance.i_rewardAmount(), 5, "Proxy should return correct reward amount");
        assertEq(instance.version(), 1, "Version should be 1");
        
        // Store proxy address for upgrade test
        proxyAddress = result.proxyAddress;
    }

    /*
    function test_upgradeMerkleDistributor() public {
        // First deploy
        DeployScript deployScript = new DeployScript();
        DeployScript.DeployReturn memory deployResult = deployScript.run();
        proxyAddress = deployResult.proxyAddress;
        
        // Set environment variables for upgrade script
        vm.setEnv("PROXY_ADDRESS", vm.toString(proxyAddress));
        
        // Run upgrade script
        UpgradeScript upgradeScript = new UpgradeScript();
        UpgradeScript.UpgradeReturn memory upgradeResult = upgradeScript.run(proxyAddress);
        
        // Verify results
        assertNotEq(upgradeResult.merkleDistributorV2Impl, address(0), "V2 Implementation should be deployed");
        assertEq(upgradeResult.proxyAddress, proxyAddress, "Proxy address should remain the same");
        assertEq(upgradeResult.rewardAmount, 10, "Reward amount should be 10");
        
        // Verify proxy works with V2
        MerkleDistributorV2 instance = MerkleDistributorV2(proxyAddress);
        assertEq(instance.i_rewardAmount(), 10, "Proxy should return correct reward amount after upgrade");
        assertEq(instance.version(), 2, "Version should be 2");
        assertEq(instance.s_addStorageVarTest(), 4, "New storage variable should be set");
    }

    function test_deployAndUpgradeMerkleDistributor() public {
        // Deploy
        DeployScript deployScript = new DeployScript();
        DeployScript.DeployReturn memory deployResult = deployScript.run();
        
        // Verify initial state
        MerkleDistributorV1 instanceV1 = MerkleDistributorV1(deployResult.proxyAddress);
        assertEq(instanceV1.version(), 1, "Initial version should be 1");
        assertEq(instanceV1.i_rewardAmount(), 5, "Initial reward amount should be 5");
        
        // Upgrade
        UpgradeScript upgradeScript = new UpgradeScript();
        UpgradeScript.UpgradeReturn memory upgradeResult = upgradeScript.run(deployResult.proxyAddress);
        
        // Verify upgrade
        assertEq(upgradeResult.proxyAddress, deployResult.proxyAddress, "Proxy address should remain the same");
        
        MerkleDistributorV2 instanceV2 = MerkleDistributorV2(deployResult.proxyAddress);
        assertEq(instanceV2.version(), 2, "Version should be 2 after upgrade");
        assertEq(instanceV2.i_rewardAmount(), 10, "Reward amount should be 10 after upgrade");
        assertEq(instanceV2.s_addStorageVarTest(), 4, "New storage variable should be set");
    }
*/
}