// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MRTNFTokenV1} from "src/MRTNFToken/MRTNFTokenV1.sol";
import {UUPSProxy} from "src/UUPSProxy.sol";

contract MRTNFTokenTest is Test {
    uint256 public constant USER_INITIAL_BALANCE = 1000 ether;
    MRTNFTokenV1 nft;

    address public owner;
    address public user;

    uint256 public constant MAX_SUPPLY = 100;
    uint256 public constant MINT_PRICE = 0.1 ether;
    uint96 public constant ROYALTY_BPS = 500;

    function setUp() public {
        owner = payable(address(this));
        user = address(0x123);
        vm.deal(user, USER_INITIAL_BALANCE);

        // Deploy the MRTNFTokenV1 implementation
        MRTNFTokenV1 implementation = new MRTNFTokenV1(MAX_SUPPLY, MINT_PRICE);
        
        // Deploy proxy with MRTNFTokenV1 as implementation
        bytes memory initData = abi.encodeCall(
            MRTNFTokenV1.initialize,
            (owner, "ipfs://baseURI/", address(this), ROYALTY_BPS)
        );
        UUPSProxy proxy = new UUPSProxy(address(implementation), initData);
        nft = MRTNFTokenV1(address(proxy));
        
        // Enable sale (contract starts paused)
        nft.setSaleActive(true);
    }

    function test_mint() public {
        skip(nft.MINT_INTERVAL());

        // Mint 2 tokens
        vm.prank(user);
        nft.mint{value: 2 * MINT_PRICE}(2);

        // Assert that the total supply is updated
        assertEq(nft.totalSupply(), 2, "Total supply should be 2");

        // Assert that the user owns the tokens
        assertEq(nft.ownerOf(1), user, "User should own token 1");
        assertEq(nft.ownerOf(2), user, "User should own token 2");
    }

    function test_enforceCooldown() public {
        skip(nft.MINT_INTERVAL());

        // Mint 1 token
        vm.prank(user);
        nft.mint{value: MINT_PRICE}(1);

        // Attempt to mint again before the cooldown period
        vm.prank(user);
        vm.expectRevert(MRTNFTokenV1.MRTNFToken__MintTooSoon.selector);
        nft.mint{value: MINT_PRICE}(1);

        // Fast forward time to exceed the cooldown period
        skip(nft.MINT_INTERVAL());

        // Mint again successfully
        vm.prank(user);
        nft.mint{value: MINT_PRICE}(1);

        // Assert that the total supply is updated
        assertEq(nft.totalSupply(), 2, "Total supply should be 2");
    }

    function test_handleRefunds() public {
        skip(nft.MINT_INTERVAL());

        vm.prank(user);
        nft.mint{value: 0.5 ether}(1); // Send 0.5 ether (excess)

        // Assert that the user received the refund
        assertEq(user.balance, USER_INITIAL_BALANCE - MINT_PRICE, "User should receive a refund");

        // Assert that the total supply is updated
        assertEq(nft.totalSupply(), 1, "Total supply should be 1");
    }

    function test_enforceMaxSupply() public {
        skip(nft.MINT_INTERVAL());

        // Mint up to the max supply
        vm.prank(user);
        nft.mint{value: MAX_SUPPLY * MINT_PRICE}(MAX_SUPPLY);

        skip(nft.MINT_INTERVAL());

        // Attempt to mint more tokens
        vm.prank(user);
        vm.expectRevert(MRTNFTokenV1.MRTNFToken__MaxSupplyExceeded.selector);
        nft.mint{value: MINT_PRICE}(1);

        // Assert that the total supply is equal to MAX_SUPPLY
        assertEq(nft.totalSupply(), MAX_SUPPLY, "Total supply should be MAX_SUPPLY");
    }

    // Allow the test contract to receive ETH
    receive() external payable {}

    // Fallback function to accept ETH
    fallback() external payable {}

    function test_withdraw() public {
        skip(nft.MINT_INTERVAL());

        // Mint tokens to fund the contract
        vm.prank(user);
        nft.mint{value: 1 ether}(10);

        // Assert that the contract has a balance
        assertEq(address(nft).balance, 1 ether, "Contract should have 1 ether");

        // Withdraw the balance
        uint256 initialOwnerBalance = owner.balance;
        nft.withdraw(payable(owner));

        // Assert that the owner's balance is updated
        assertEq(owner.balance, initialOwnerBalance + 1 ether, "Owner should receive the contract's balance");

        // Assert that the contract's balance is 0
        assertEq(address(nft).balance, 0, "Contract balance should be 0");
    }

    function test_onlyOwnerCanWithdraw() public {
        // Attempt to withdraw as a non-owner
        vm.prank(user);
        vm.expectRevert();
        nft.withdraw(payable(user));
    }

    function test_setBaseURI() public {
        skip(nft.MINT_INTERVAL());

        // Set a new base URI
        string memory newBaseURI = "ipfs://newBaseURI/";
        nft.setBaseURI(newBaseURI);

        // Mint a token
        vm.prank(user);
        nft.mint{value: MINT_PRICE}(1);

        // Assert that the token URI is correct
        assertEq(nft.tokenURI(1), "ipfs://newBaseURI/1.json", "Token URI should match the new base URI");
    }

    function test_manageRoyalties() public {
        // Set a new royalty
        nft.setDefaultRoyalty(address(user), 1000); // 10%
        (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(1, 1 ether);

        // Assert that the royalty is updated
        assertEq(receiver, user, "Royalty receiver should be updated");
        assertEq(royaltyAmount, 0.1 ether, "Royalty amount should be 10%");

        // Delete the royalty
        nft.deleteDefaultRoyalty();
        (receiver, royaltyAmount) = nft.royaltyInfo(1, 1 ether);

        // Assert that the royalty is deleted
        assertEq(receiver, address(0), "Royalty receiver should be address(0)");
        assertEq(royaltyAmount, 0, "Royalty amount should be 0");
    }
}
