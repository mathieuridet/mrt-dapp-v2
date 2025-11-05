// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {UUPSProxy} from "../../src/poc-uups-proxy.sol";
import {ContractA} from "../../src/poc-uups-proxy.sol";

contract DeployScript is Script {
    function run() public {
        // Get deployer address
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deployer:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Step 1: Deploy ContractA implementation
        console.log("\n=== Deploying ContractA ===");
        ContractA contractA = new ContractA();
        console.log("ContractA Implementation:", address(contractA));
        
        // Step 2: Deploy proxy with ContractA
        console.log("\n=== Deploying UUPS Proxy ===");
        bytes memory initData = abi.encodeCall(ContractA.initialize, (deployer));
        UUPSProxy proxy = new UUPSProxy(address(contractA), initData);
        address proxyAddress = address(proxy);
        console.log("Proxy Address:", proxyAddress);
        console.log("Proxy Implementation:", proxy.getImplementation());
        
        // Step 3: Verify ContractA works
        console.log("\n=== Testing ContractA ===");
        ContractA instance = ContractA(proxyAddress);
        uint256 numberA = instance.myNumber();
        console.log("myNumber() returns:", numberA);
        require(numberA == 1, "ContractA myNumber should return 1");
        
        vm.stopBroadcast();
    }
}

