//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {DeployScript, UpgradeScript} from "../../script/StakingVaultInteractions.s.sol";
import {StakingVaultV1} from "../../src/StakingVault/StakingVaultV1.sol";
import {StakingVaultV2} from "../../src/StakingVault/StakingVaultV2.sol";

contract StakingVaultInteractionsTest is Test {
    address public deployer = address(0x1);
    address public proxyAddress;

    function setUp() public {
        vm.setEnv("PRIVATE_KEY", "1");
    }

    function test_deployStakingVault() public {
        DeployScript deployScript = new DeployScript();
        DeployScript.DeployReturn memory result = deployScript.run();
        
        assertNotEq(result.stakingVaultV1Impl, address(0), "Implementation should be deployed");
        assertNotEq(result.proxyAddress, address(0), "Proxy should be deployed");
        assertNotEq(result.tokenProxyAddress, address(0), "Token proxy should be deployed");
        assertEq(result.rewardRate, 1e18, "Reward rate should be 1e18");
        
        StakingVaultV1 instance = StakingVaultV1(result.proxyAddress);
        assertEq(instance.version(), 1, "Version should be 1");
        assertEq(instance.rewardRate(), 1e18, "Reward rate should be 1e18");
        
        proxyAddress = result.proxyAddress;
    }

    function test_upgradeStakingVault() public {
        DeployScript deployScript = new DeployScript();
        DeployScript.DeployReturn memory deployResult = deployScript.run();
        proxyAddress = deployResult.proxyAddress;
        
        vm.setEnv("PROXY_ADDRESS", vm.toString(proxyAddress));
        
        UpgradeScript upgradeScript = new UpgradeScript();
        UpgradeScript.UpgradeReturn memory upgradeResult = upgradeScript.run(proxyAddress);
        
        assertNotEq(upgradeResult.stakingVaultV2Impl, address(0), "V2 Implementation should be deployed");
        assertEq(upgradeResult.proxyAddress, proxyAddress, "Proxy address should remain the same");
        
        StakingVaultV2 instance = StakingVaultV2(proxyAddress);
        assertEq(instance.version(), 2, "Version should be 2");
        assertEq(instance.s_addStorageVarTest(), 4, "New storage variable should be set");
        assertEq(instance.rewardRate(), 1e18, "Reward rate should persist");
    }

    function test_deployAndUpgradeStakingVault() public {
        DeployScript deployScript = new DeployScript();
        DeployScript.DeployReturn memory deployResult = deployScript.run();
        
        StakingVaultV1 instanceV1 = StakingVaultV1(deployResult.proxyAddress);
        assertEq(instanceV1.version(), 1, "Initial version should be 1");
        assertEq(instanceV1.rewardRate(), 1e18, "Initial reward rate should be 1e18");
        
        UpgradeScript upgradeScript = new UpgradeScript();
        UpgradeScript.UpgradeReturn memory upgradeResult = upgradeScript.run(deployResult.proxyAddress);
        
        assertEq(upgradeResult.proxyAddress, deployResult.proxyAddress, "Proxy address should remain the same");
        
        StakingVaultV2 instanceV2 = StakingVaultV2(deployResult.proxyAddress);
        assertEq(instanceV2.version(), 2, "Version should be 2 after upgrade");
        assertEq(instanceV2.s_addStorageVarTest(), 4, "New storage variable should be set");
        assertEq(instanceV2.rewardRate(), 1e18, "Reward rate should persist after upgrade");
    }
}

