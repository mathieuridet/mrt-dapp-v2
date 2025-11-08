// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {CodeConstants} from "utils/CodeConstants.sol";
import {MRTokenV1} from "src/MRToken/MRTokenV1.sol";
import {MerkleDistributorV1} from "src/MerkleDistributor/MerkleDistributorV1.sol";
import {StakingVaultV1} from "src/StakingVault/StakingVaultV1.sol";
import {MRTNFTokenV1} from "src/MRTNFToken/MRTNFTokenV1.sol";
import {UUPSProxy} from "src/UUPSProxy.sol";
import {PrivateKeyReader} from "script/utils/PrivateKeyReader.s.sol";

contract DeployAll is PrivateKeyReader, CodeConstants {
    struct DeployAllReturn {
        address mrTokenProxyAddress;
        address merkleDistributorProxyAddress;
        address stakingVaultProxyAddress;
        address mrtnfTokenProxyAddress;
    }

    function run() public returns (DeployAllReturn memory) {
        (uint256 deployerPrivateKey, address owner) = readPrivateKey("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        address mrTokenProxyAddress;
        address merkleDistributorProxyAddress;
        address stakingVaultProxyAddress;
        address mrtnfTokenProxyAddress;

        MRTokenV1 mrToken;
        MerkleDistributorV1 merkleDistributor;
        StakingVaultV1 stakingVault;

        {
            MRTokenV1 implementation = new MRTokenV1();
            bytes memory initData = abi.encodeCall(MRTokenV1.initialize, (owner));
            UUPSProxy proxy = new UUPSProxy(address(implementation), initData);
            mrTokenProxyAddress = address(proxy);
            mrToken = MRTokenV1(mrTokenProxyAddress);
        }

        {
            MerkleDistributorV1 implementation = new MerkleDistributorV1(mrToken, REWARD_AMOUNT);
            bytes memory initData = abi.encodeCall(MerkleDistributorV1.initialize, (owner));
            UUPSProxy proxy = new UUPSProxy(address(implementation), initData);
            merkleDistributorProxyAddress = address(proxy);
            merkleDistributor = MerkleDistributorV1(merkleDistributorProxyAddress);
        }

        {
            StakingVaultV1 implementation = new StakingVaultV1(mrToken);
            bytes memory initData = abi.encodeCall(StakingVaultV1.initialize, (owner, REWARD_RATE));
            UUPSProxy proxy = new UUPSProxy(address(implementation), initData);
            stakingVaultProxyAddress = address(proxy);
            stakingVault = StakingVaultV1(stakingVaultProxyAddress);
        }

        {
            MRTNFTokenV1 implementation = new MRTNFTokenV1(CAP, MINT_PRICE);
            bytes memory initData = abi.encodeCall(
                MRTNFTokenV1.initialize,
                (owner, BASE_URI, owner, ROYALTY_BPS)
            ); // 5% royalty to owner/deployer
            UUPSProxy proxy = new UUPSProxy(address(implementation), initData);
            mrtnfTokenProxyAddress = address(proxy);
        }

        vm.stopBroadcast();

        return DeployAllReturn({
            mrTokenProxyAddress: mrTokenProxyAddress,
            merkleDistributorProxyAddress: merkleDistributorProxyAddress,
            stakingVaultProxyAddress: stakingVaultProxyAddress,
            mrtnfTokenProxyAddress: mrtnfTokenProxyAddress
        });
    }
}