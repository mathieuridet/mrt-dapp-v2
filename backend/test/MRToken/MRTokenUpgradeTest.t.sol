// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {MRTokenV1} from "src/MRToken/MRTokenV1.sol";
import {MRTokenV2} from "src/MRToken/MRTokenV2.sol";
import {UUPSProxy} from "src/UUPSProxy.sol";

contract MRTokenUpgradeTest is Test {
    address public owner = address(0x1);
    address public user = address(0x2);
    address public proxyAddress;

    MRTokenV1 mrtokenV1;
    MRTokenV2 mrtokenV2;
    UUPSProxy public proxy;

    function setUp() public {
        mrtokenV1 = new MRTokenV1();
        mrtokenV2 = new MRTokenV2();

        bytes memory initData = abi.encodeCall(MRTokenV1.initialize, (owner));
        proxy = new UUPSProxy(address(mrtokenV1), initData);
        proxyAddress = address(proxy);
    }

    function test_ProxyAddressStaysSame() public {
        // Get the proxy address
        address initialProxyAddress = proxyAddress;
        console.log("Initial Proxy Address:", initialProxyAddress);
        
        // Get initial implementation
        address initialImpl = proxy.getImplementation();
    
        console.log("Initial Implementation:", initialImpl);
        assertEq(initialImpl, address(mrtokenV1));

        // Check that s_addStorageVarTest does not exist on proxy (ie on MRToken V1)
        (bool ok, ) = address(mrtokenV1).call(abi.encodeWithSignature("s_addStorageVarTest()"));
        assertFalse(ok, "Getter exists (variable likely public)");

        // Verify version is 1
        assertEq(MRTokenV1(proxyAddress).version(), 1);

        // Upgrade to MRTokenV2 as owner
        vm.prank(owner);
        MRTokenV2(proxyAddress).upgradeToAndCall(
            address(mrtokenV2),
            abi.encodeWithSelector(MRTokenV2.initializeV2.selector));

        // Verify proxy address is still the same
        assertEq(address(proxy), initialProxyAddress);
        console.log("Proxy Address After Upgrade:", address(proxy));
        
        // Verify implementation changed
        address newImpl = proxy.getImplementation();

        console.log("New Implementation:", newImpl);
        assertEq(newImpl, address(mrtokenV2));
        assertNotEq(initialImpl, newImpl);

        // Verify s_addStorageVarTest exists on proxy (ie MRToken V2) and is 4
        MRTokenV2 instanceB = MRTokenV2(proxyAddress);
        assertEq(instanceB.s_addStorageVarTest(), 4);

        // Verify version is 2
        assertEq(instanceB.version(), 2);
    }

}