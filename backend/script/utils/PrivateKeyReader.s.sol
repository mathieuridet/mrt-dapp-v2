// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";

abstract contract PrivateKeyReader is Script {
    function readPrivateKey(string memory envVar) public returns (uint256 key, address account) {
        string memory pk = vm.envString(envVar);
        bytes memory pkBytes = bytes(pk);
        if (!(pkBytes.length > 1 && pkBytes[0] == bytes1('0') && (pkBytes[1] == bytes1('x') || pkBytes[1] == bytes1('X')))) {
            pk = string.concat("0x", pk);
        }
        key = vm.parseUint(pk);
        account = vm.addr(key);
    }
}
