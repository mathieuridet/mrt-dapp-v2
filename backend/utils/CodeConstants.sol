// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

abstract contract CodeConstants {
    string public constant BASE_URI = "ipfs://bafybeiatfjaeyfu2a5pdf2f536q7vs62pfv6e33lwk5yckiwr5ntwaivs4/";
    // "2.0" tokens/hour with 18 decimals:
    uint256 public constant TOKENS_PER_HOUR_WEI = 2e18;
    uint256 public constant REWARD_RATE = TOKENS_PER_HOUR_WEI / 3600; // tokens/sec in wei
    uint96 public constant CAP = 1_000_000 * 10**18;
    uint96 public constant MINT_PRICE = 1e15;
    uint96 public constant INITIAL_MINT = 1000 * 10**18;
    uint96 public constant ROYALTY_BPS = 500;
    uint8 public constant REWARD_AMOUNT = 5;
}