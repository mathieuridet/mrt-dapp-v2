// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {UUPSProxy} from "../../src/poc-uups-proxy.sol";
import {ContractA, ContractB} from "../../src/poc-uups-proxy.sol";

contract UpgradesTest is Test {
    address public owner = address(0x1);
    address public user = address(0x2);
    
    ContractA public contractA;
    ContractB public contractB;
    UUPSProxy public proxy;
    address public proxyAddress;
    
    function setUp() public {
        // Deploy implementations
        contractA = new ContractA();
        contractB = new ContractB();
        
        // Deploy proxy with ContractA as implementation
        bytes memory initData = abi.encodeCall(ContractA.initialize, (owner));
        proxy = new UUPSProxy(address(contractA), initData);
        proxyAddress = address(proxy);
    }
    
    function test_ProxyAddressStaysSame() public {
        // Get the proxy address
        address initialProxyAddress = proxyAddress;
        console.log("Initial Proxy Address:", initialProxyAddress);
        
        // Get initial implementation
        address initialImpl = proxy.getImplementation();
    
        console.log("Initial Implementation:", initialImpl);
        assertEq(initialImpl, address(contractA));
        
        // Call myNumber on proxy (should return 1 from ContractA)
        ContractA instance = ContractA(proxyAddress);
        assertEq(instance.myNumber(), 1);
        console.log("ContractA myNumber:", instance.myNumber());
        
        // Upgrade to ContractB as owner
        vm.prank(owner);
        ContractA(proxyAddress).upgradeToAndCall(address(contractB), "");
        
        // Verify proxy address is still the same
        assertEq(address(proxy), initialProxyAddress);
        console.log("Proxy Address After Upgrade:", address(proxy));
        
        // Verify implementation changed
        address newImpl = proxy.getImplementation();

        console.log("New Implementation:", newImpl);
        assertEq(newImpl, address(contractB));
        assertNotEq(initialImpl, newImpl);
        
        // Call myNumber on proxy (should return 2 from ContractB)
        // Note: We need to cast to ContractB interface to access the function
        ContractB instanceB = ContractB(proxyAddress);
        assertEq(instanceB.myNumber(), 2);
        console.log("ContractB myNumber:", instanceB.myNumber());
    }
    
    function test_OnlyOwnerCanUpgrade() public {
        // Non-owner cannot upgrade
        vm.prank(user);
        vm.expectRevert();
        ContractA(proxyAddress).upgradeToAndCall(address(contractB), "");
    }
    
    function test_InitializeOnlyOnce() public {
        // Cannot initialize twice
        vm.expectRevert();
        ContractA(proxyAddress).initialize(owner);
    }
    
    function test_ProxyStorage() public {
        // Set value on ContractA (if we had a setter)
        // Note: ContractA doesn't have setValue in the original, but we can test myNumber
        
        // Upgrade to ContractB
        vm.prank(owner);
        ContractA(proxyAddress).upgradeToAndCall(address(contractB), "");
        
        // Verify we can still call functions through the proxy
        ContractB instanceB = ContractB(proxyAddress);
        assertEq(instanceB.myNumber(), 2);
    }
}

