// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {CodeConstants} from "utils/CodeConstants.sol";
import {MRTokenV1} from "src/MRToken/MRTokenV1.sol";
import {MerkleDistributorV1} from "src/MerkleDistributor/MerkleDistributorV1.sol";
import {StakingVaultV1} from "src/StakingVault/StakingVaultV1.sol";
import {MRTNFTokenV1} from "src/MRTNFToken/MRTNFTokenV1.sol";
import {UUPSProxy} from "src/UUPSProxy.sol";

contract DeployAll is Script, CodeConstants {
    function run() public {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(pk);

        vm.startBroadcast(pk);
        
        // 1. Deploy MRToken
        MRTokenV1 mrToken = new MRTokenV1();
        bytes memory mrTokenInitData = abi.encodeCall(MRTokenV1.initialize, (owner));
        UUPSProxy mrTokenProxy = new UUPSProxy(address(mrToken), mrTokenInitData);

        // 2. Deploy MerkleDistributor
        MerkleDistributorV1 merkleDistributor = new MerkleDistributorV1(mrToken, REWARD_AMOUNT);
        bytes memory mdInitData = abi.encodeCall(MerkleDistributorV1.initialize, (owner));
        UUPSProxy mdProxy = new UUPSProxy(address(merkleDistributor), mdInitData);

        // 3. Deploy StakingVault
        StakingVaultV1 stakingVault = new StakingVaultV1(mrToken);
        bytes memory svInitData = abi.encodeCall(StakingVaultV1.initialize, (owner, REWARD_RATE));
        UUPSProxy svProxy = new UUPSProxy(address(stakingVault), svInitData);

        // 4. Deploy MRTNFToken
        MRTNFTokenV1 nft = new MRTNFTokenV1(CAP, MINT_PRICE);
        bytes memory nftInitData = abi.encodeCall(
            MRTNFTokenV1.initialize,
            (owner, BASE_URI, owner, ROYALTY_BPS)
        ); // 5% royalty to owner/deployer
        UUPSProxy nftProxy = new UUPSProxy(address(nft), nftInitData);

        vm.stopBroadcast();
    }
}