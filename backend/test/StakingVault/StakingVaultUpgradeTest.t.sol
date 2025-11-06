// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {UUPSProxy} from "src/UUPSProxy.sol";
import {StakingVaultV1} from "src/StakingVault/StakingVaultV1.sol";
import {StakingVaultV2} from "src/StakingVault/StakingVaultV2.sol";
import {MRTokenV1} from "src/MRToken/MRTokenV1.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StakingVaultUpgradeTest is Test {
    address public owner = address(0x1);
    address public user = address(0x2);
    address public proxyAddress;

    StakingVaultV1 public stakingVaultV1;
    StakingVaultV2 public stakingVaultV2;
    UUPSProxy public proxy;
    MRTokenV1 mrtoken;
    uint256 constant REWARD_RATE = 1e18; // 1 token per second

    function setUp() public {
        // Deploy MRToken implementation
        mrtoken = new MRTokenV1();
        
        // Deploy MRToken proxy
        bytes memory tokenInitData = abi.encodeCall(MRTokenV1.initialize, (owner));
        UUPSProxy tokenProxy = new UUPSProxy(address(mrtoken), tokenInitData);
        address tokenProxyAddress = address(tokenProxy);
        
        // Deploy implementations
        stakingVaultV1 = new StakingVaultV1(IERC20(tokenProxyAddress));
        stakingVaultV2 = new StakingVaultV2(IERC20(tokenProxyAddress));
        
        // Deploy proxy with StakingVaultV1 as implementation
        bytes memory initData = abi.encodeCall(StakingVaultV1.initialize, (owner, REWARD_RATE));
        proxy = new UUPSProxy(address(stakingVaultV1), initData);
        proxyAddress = address(proxy);
    }
    
    function test_ProxyAddressStaysSame() public {
        // Get the proxy address
        address initialProxyAddress = proxyAddress;
        console.log("Initial Proxy Address:", initialProxyAddress);
        
        // Get initial implementation
        address initialImpl = proxy.getImplementation();
        console.log("Initial Implementation:", initialImpl);
        assertEq(initialImpl, address(stakingVaultV1));
        
        // Verify version is 1
        StakingVaultV1 instance = StakingVaultV1(proxyAddress);
        assertEq(instance.version(), 1);
        console.log("StakingVaultV1 version:", instance.version());
        
        // Verify rewardRate
        assertEq(instance.rewardRate(), REWARD_RATE);
        console.log("StakingVaultV1 rewardRate:", instance.rewardRate());
        
        // Upgrade to StakingVaultV2 as owner
        vm.prank(owner);
        instance.upgradeToAndCall(
            address(stakingVaultV2),
            abi.encodeWithSelector(StakingVaultV2.initializeV2.selector)
        );
        
        // Verify proxy address is still the same
        assertEq(address(proxy), initialProxyAddress);
        console.log("Proxy Address After Upgrade:", address(proxy));
        
        // Verify implementation changed
        address newImpl = proxy.getImplementation();
        console.log("New Implementation:", newImpl);
        assertEq(newImpl, address(stakingVaultV2));
        assertNotEq(initialImpl, newImpl);
        
        // Verify version is 2
        StakingVaultV2 instanceB = StakingVaultV2(proxyAddress);
        assertEq(instanceB.version(), 2);
        console.log("StakingVaultV2 version:", instanceB.version());
        
        // Verify new storage variable
        assertEq(instanceB.s_addStorageVarTest(), 4);
        console.log("StakingVaultV2 s_addStorageVarTest:", instanceB.s_addStorageVarTest());
        
        // Verify storage persisted (rewardRate should still be there)
        assertEq(instanceB.rewardRate(), REWARD_RATE);
        console.log("StakingVaultV2 rewardRate (should persist):", instanceB.rewardRate());
    }
    
    function test_OnlyOwnerCanUpgrade() public {
        // Non-owner cannot upgrade
        vm.prank(user);
        vm.expectRevert();
        StakingVaultV1(proxyAddress).upgradeToAndCall(address(stakingVaultV2), "");
    }
    
    function test_InitializeOnlyOnce() public {
        // Cannot initialize twice
        vm.expectRevert();
        StakingVaultV1(proxyAddress).initialize(owner, REWARD_RATE);
    }
    
    function test_ProxyStorage() public {
        StakingVaultV1 instance = StakingVaultV1(proxyAddress);
        
        // Set some state (stake tokens)
        // First, mint tokens to user
        address tokenAddress = address(instance.i_stakingToken());
        MRTokenV1 token = MRTokenV1(tokenAddress);
        vm.prank(owner);
        token.mint(user, 1000e18);
        
        // Approve and stake
        vm.prank(user);
        IERC20(tokenAddress).approve(proxyAddress, 1000e18);
        vm.prank(user);
        instance.stake(100e18);
        
        // Verify stake
        assertEq(instance.balanceOf(user), 100e18);
        assertEq(instance.totalSupply(), 100e18);
        
        // Upgrade to StakingVaultV2
        vm.prank(owner);
        instance.upgradeToAndCall(
            address(stakingVaultV2),
            abi.encodeWithSelector(StakingVaultV2.initializeV2.selector)
        );
        
        // Verify storage persisted
        StakingVaultV2 instanceB = StakingVaultV2(proxyAddress);
        assertEq(instanceB.balanceOf(user), 100e18);
        assertEq(instanceB.totalSupply(), 100e18);
        assertEq(instanceB.rewardRate(), REWARD_RATE);
    }
}

