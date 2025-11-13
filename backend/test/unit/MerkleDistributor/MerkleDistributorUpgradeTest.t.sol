// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {UUPSProxy} from "src/UUPSProxy.sol";
import {MerkleDistributorV1} from "src/MerkleDistributor/MerkleDistributorV1.sol";
import {MerkleDistributorV2} from "src/MerkleDistributor/MerkleDistributorV2.sol";
import {MRTokenV1} from "src/MRToken/MRTokenV1.sol";

contract MerkleDistributorUpgradeTest is Test {
    address public owner = address(0x1);
    address public user = address(0x2);
    address public proxyAddress;

    MerkleDistributorV1 public merkleDistributorV1;
    MerkleDistributorV2 public merkleDistributorV2;
    UUPSProxy public proxy;
    MRTokenV1 mrtoken;
    uint256 constant REWARD_AMOUNT_MERKLE_DISTRIBUTOR = 5;
    uint256 constant REWARD_AMOUNT_MERKLE_DISTRIBUTOR_B = 10;

    /*function setUp() public {
        // Deploy implementations
        mrtoken = new MRTokenV1();
        merkleDistributorV1 = new MerkleDistributorV1(mrtoken, REWARD_AMOUNT_MERKLE_DISTRIBUTOR);
        merkleDistributorV2 = new MerkleDistributorV2(mrtoken, REWARD_AMOUNT_MERKLE_DISTRIBUTOR_B);
        
        // Deploy proxy with MerkleDistributorV1 as implementation
        bytes memory initData = abi.encodeCall(MerkleDistributorV1.initialize, (owner));
        proxy = new UUPSProxy(address(merkleDistributorV1), initData);
        proxyAddress = address(proxy);
    }
    
    function test_ProxyAddressStaysSame() public {
        // Get the proxy address
        address initialProxyAddress = proxyAddress;
        console.log("Initial Proxy Address:", initialProxyAddress);
        
        // Get initial implementation
        address initialImpl = proxy.getImplementation();
    
        console.log("Initial Implementation:", initialImpl);
        assertEq(initialImpl, address(merkleDistributorV1));
        
        // Get i_rewardAmount on proxy (should return 5 from MerkleDistributorV1)
        MerkleDistributorV1 instance = MerkleDistributorV1(proxyAddress);
        assertEq(instance.i_rewardAmount(), 5);
        console.log("MerkleDistributorV1 i_rewardAmount:", instance.i_rewardAmount());

        // Verify version is 1
        assertEq(instance.version(), 1);
        
        // Upgrade to MerkleDistributorV2 as owner
        vm.prank(owner);
        MerkleDistributorV1(proxyAddress).upgradeToAndCall(
            address(merkleDistributorV2), 
            abi.encodeWithSelector(MerkleDistributorV2.initializeV2.selector));
        
        // Verify proxy address is still the same
        assertEq(address(proxy), initialProxyAddress);
        console.log("Proxy Address After Upgrade:", address(proxy));
        
        // Verify implementation changed
        address newImpl = proxy.getImplementation();

        console.log("New Implementation:", newImpl);
        assertEq(newImpl, address(merkleDistributorV2));
        assertNotEq(initialImpl, newImpl);
        
        // Get i_rewardAmount on proxy (should return 10 from MerkleDistributorV2)
        MerkleDistributorV2 instanceB = MerkleDistributorV2(proxyAddress);
        assertEq(instanceB.i_rewardAmount(), 10);
        console.log("MerkleDistributorV2 i_rewardAmount:", instanceB.i_rewardAmount());
        assertEq(instanceB.s_addStorageVarTest(), 4);

        // Verify version is 2
        assertEq(instanceB.version(), 2);
    }
    
    function test_OnlyOwnerCanUpgrade() public {
        // Non-owner cannot upgrade
        vm.prank(user);
        vm.expectRevert();
        MerkleDistributorV1(proxyAddress).upgradeToAndCall(address(merkleDistributorV2), "");
    }
    
    function test_InitializeOnlyOnce() public {
        // Cannot initialize twice
        vm.expectRevert();
        MerkleDistributorV1(proxyAddress).initialize(owner);
    }
    
    function test_ProxyStorage() public {
        // Upgrade to MerkleDistributorV2
        vm.prank(owner);
        MerkleDistributorV1(proxyAddress).upgradeToAndCall(address(merkleDistributorV2), "");
        
        // Verify we can still call functions through the proxy
        MerkleDistributorV2 instanceB = MerkleDistributorV2(proxyAddress);
        assertEq(instanceB.i_rewardAmount(), 10);
    }*/
}

