// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {MerkleDistributorV2} from "src/MerkleDistributor/MerkleDistributorV2.sol";

using Strings for uint256;

// Interfaces you need
interface IUUPS {
    function upgradeTo(address newImplementation) external;
    function upgradeToAndCall(address newImplementation, bytes calldata data) external;
}

interface IMerkleDistributorV2 {
    function setRewardAmount(uint256) external;
    function rewardAmount() external view returns (uint256);
    function i_rewardAmount() external view returns (uint256); // legacy, immutable
}

contract UpgradeScript is Script {
    struct UpgradeReturn {
        address merkleDistributorV2Impl;
        address proxyAddress;
        uint256 rewardAmount;
    }

    // Env:
    // - PROXY_ADDRESS: address of your existing UUPS proxy (distributor)
    // - PRIVATE_KEY:   private key (uint256) of the upgrade admin/owner
    // - NEW_REWARD:    (optional) human value in ether units (e.g. 5)
    function run() public returns (UpgradeReturn memory) {
        address proxy = vm.envAddress("DISTRIBUTOR_PROXY_ADDRESS");
        return run(proxy);
    }

    function run(address proxyAddress) public returns (UpgradeReturn memory) {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);

        // default to 5 ether unless NEW_REWARD is provided (as whole tokens)
        uint256 human = vm.envOr("NEW_REWARD", uint256(5));
        uint256 rewardWei = human * 1e18; // 18-decimals token

        console.log("Deployer:       ", deployer);
        console.log("Proxy Address:  ", proxyAddress);
        console.log("New reward (wei)", rewardWei);

        vm.startBroadcast(pk);

        // 1) Deploy the new implementation (NO constructor args for upgradeable impls)
        console.log("\n=== Deploying MerkleDistributorV2 implementation ===");
        // Replace this with your actual V2 contract type
        // Must NOT rely on constructor for state; use setters/initializers only.
        MerkleDistributorV2 impl = new MerkleDistributorV2();
        address implAddr = address(impl);
        console.log("V2 Implementation:", implAddr);

        // 2) Upgrade proxy -> V2 AND call setRewardAmount(5e18) in the same tx
        console.log("\n=== Upgrading proxy & setting reward in one tx ===");
        bytes memory data = abi.encodeWithSelector(
            IMerkleDistributorV2.setRewardAmount.selector,
            rewardWei
        );
        IUUPS(proxyAddress).upgradeToAndCall(implAddr, data);

        // 3) Verify through the proxy
        IMerkleDistributorV2 proxy = IMerkleDistributorV2(proxyAddress);

        uint256 afterMutable = proxy.rewardAmount();
        console.log("rewardAmount():", afterMutable);         // expect 5e18

        uint256 legacyImm = proxy.i_rewardAmount();
        console.log("i_rewardAmount() (immutable):", legacyImm); // expect 0 (from V2 dummy ctor)

        require(afterMutable == rewardWei, "reward not set to expected value");

        vm.stopBroadcast();

        return UpgradeReturn({
            merkleDistributorV2Impl: implAddr,
            proxyAddress: proxyAddress,
            rewardAmount: rewardWei
        });
    }
}
