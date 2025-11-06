// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {UUPSProxy} from "src/UUPSProxy.sol";
import {MRTNFTokenV1} from "src/MRTNFToken/MRTNFTokenV1.sol";
import {MRTNFTokenV2} from "src/MRTNFToken/MRTNFTokenV2.sol";

contract MRTNFTokenUpgradeTest is Test {
    address public owner = address(0x1);
    address public user = address(0x2);
    address public proxyAddress;

    MRTNFTokenV1 public nftTokenV1;
    MRTNFTokenV2 public nftTokenV2;
    UUPSProxy public proxy;
    
    uint256 constant MAX_SUPPLY = 10000;
    uint256 constant MINT_PRICE = 0.01 ether;
    string constant BASE_URI = "ipfs://QmTest/";
    uint96 constant ROYALTY_BPS = 500; // 5%

    function setUp() public {
        // Deploy implementations
        nftTokenV1 = new MRTNFTokenV1(MAX_SUPPLY, MINT_PRICE);
        nftTokenV2 = new MRTNFTokenV2(MAX_SUPPLY, MINT_PRICE);
        
        // Deploy proxy with MRTNFTokenV1 as implementation
        bytes memory initData = abi.encodeCall(
            MRTNFTokenV1.initialize,
            (owner, BASE_URI, owner, ROYALTY_BPS)
        );
        proxy = new UUPSProxy(address(nftTokenV1), initData);
        proxyAddress = address(proxy);
    }
    
    function test_ProxyAddressStaysSame() public {
        // Get the proxy address
        address initialProxyAddress = proxyAddress;
        console.log("Initial Proxy Address:", initialProxyAddress);
        
        // Get initial implementation
        address initialImpl = proxy.getImplementation();
        console.log("Initial Implementation:", initialImpl);
        assertEq(initialImpl, address(nftTokenV1));
        
        // Verify version is 1
        MRTNFTokenV1 instance = MRTNFTokenV1(proxyAddress);
        assertEq(instance.version(), 1);
        console.log("MRTNFTokenV1 version:", instance.version());
        
        // Verify MAX_SUPPLY
        assertEq(instance.MAX_SUPPLY(), MAX_SUPPLY);
        console.log("MRTNFTokenV1 MAX_SUPPLY:", instance.MAX_SUPPLY());
        
        // Upgrade to MRTNFTokenV2 as owner
        vm.prank(owner);
        instance.upgradeToAndCall(
            address(nftTokenV2),
            abi.encodeWithSelector(MRTNFTokenV2.initializeV2.selector)
        );
        
        // Verify proxy address is still the same
        assertEq(address(proxy), initialProxyAddress);
        console.log("Proxy Address After Upgrade:", address(proxy));
        
        // Verify implementation changed
        address newImpl = proxy.getImplementation();
        console.log("New Implementation:", newImpl);
        assertEq(newImpl, address(nftTokenV2));
        assertNotEq(initialImpl, newImpl);
        
        // Verify version is 2
        MRTNFTokenV2 instanceB = MRTNFTokenV2(proxyAddress);
        assertEq(instanceB.version(), 2);
        console.log("MRTNFTokenV2 version:", instanceB.version());
        
        // Verify new storage variable
        assertEq(instanceB.s_addStorageVarTest(), 4);
        console.log("MRTNFTokenV2 s_addStorageVarTest:", instanceB.s_addStorageVarTest());
        
        // Verify storage persisted (MAX_SUPPLY should still be there)
        assertEq(instanceB.MAX_SUPPLY(), MAX_SUPPLY);
        console.log("MRTNFTokenV2 MAX_SUPPLY (should persist):", instanceB.MAX_SUPPLY());
    }
    
    function test_OnlyOwnerCanUpgrade() public {
        // Non-owner cannot upgrade
        vm.prank(user);
        vm.expectRevert();
        MRTNFTokenV1(proxyAddress).upgradeToAndCall(address(nftTokenV2), "");
    }
    
    function test_InitializeOnlyOnce() public {
        // Cannot initialize twice
        vm.expectRevert();
        MRTNFTokenV1(proxyAddress).initialize(owner, BASE_URI, owner, ROYALTY_BPS);
    }
    
    function test_ProxyStorage() public {
        MRTNFTokenV1 instance = MRTNFTokenV1(proxyAddress);
        
        // Enable sale
        vm.prank(owner);
        instance.setSaleActive(true);
        
        // Skip time to pass cooldown period
        skip(instance.MINT_INTERVAL());
        
        // Mint an NFT
        vm.deal(user, 1 ether);
        vm.prank(user);
        instance.mint{value: MINT_PRICE}(1);
        
        // Verify mint
        assertEq(instance.totalSupply(), 1);
        assertEq(instance.ownerOf(1), user);
        
        // Upgrade to MRTNFTokenV2
        vm.prank(owner);
        instance.upgradeToAndCall(
            address(nftTokenV2),
            abi.encodeWithSelector(MRTNFTokenV2.initializeV2.selector)
        );
        
        // Verify storage persisted
        MRTNFTokenV2 instanceB = MRTNFTokenV2(proxyAddress);
        assertEq(instanceB.totalSupply(), 1);
        assertEq(instanceB.ownerOf(1), user);
        assertEq(instanceB.MAX_SUPPLY(), MAX_SUPPLY);
        assertEq(instanceB.MINT_PRICE(), MINT_PRICE);
    }
}

