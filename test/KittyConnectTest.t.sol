// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import { Test, console } from "forge-std/Test.sol";
import { DeployKittyConnect } from "../script/DeployKittyConnect.s.sol";
import { HelperConfig } from "../script/HelperConfig.s.sol";
import { KittyConnect, KittyToken } from "../src/KittyConnect.sol";

contract KittyConnectTest is Test {
    KittyConnect kittyConnect;
    KittyToken kittyToken;
    HelperConfig helperConfig;
    HelperConfig.NetworkConfig networkConfig;
    address partnerA;
    address partnerB;
    address user;
    address ethUsdPriceFeed;

    event ShopPartnerAdded(address partner);
    event CatMinted(uint256 tokenId, string catIpfsHash);
    event TokensRedeemedForVetVisit(uint256 tokenId, uint256 amount, string remarks);
    event CatTransferredToNewOwner(address prevOwner, address newOwner, uint256 tokenId);

    function setUp() external {
        DeployKittyConnect deployer = new DeployKittyConnect();
        
        (kittyConnect, helperConfig) = deployer.run();
        networkConfig = helperConfig.getNetworkConfig();

        partnerA = kittyConnect.getKittyShopAtIdx(0);
        partnerB = kittyConnect.getKittyShopAtIdx(1);
        kittyToken = KittyToken(kittyConnect.getKittyToken());
        user = makeAddr("user");
    }

    function testConstructor() public {
        address[] memory partners = networkConfig.initShopPartners;

        assert(address(kittyToken) != address(0));
        assertEq(kittyToken.getEthUsdPriceFeed(), networkConfig.ethUsdPriceFeed);
        assertEq(partnerA, partners[0]);
        assertEq(partnerB, partners[1]);
        assert(kittyConnect.getIsKittyPartnerShop(partnerA) == true);
        assertEq(kittyToken.getKittyConnectAddr(), address(kittyConnect));
    }

    function test_ShopPartnerGivesCatToCustomer() public {
        string memory catImageIpfsHash = "ipfs://QmbxwGgBGrNdXPm84kqYskmcMT3jrzBN8LzQjixvkz4c62";
        vm.warp(block.timestamp + 10 weeks);

        vm.expectEmit(false, false, false, true);
        emit CatMinted(kittyConnect.getTokenCounter(), catImageIpfsHash);
        vm.prank(partnerA);
        kittyConnect.mintCatToNewOwner(user, catImageIpfsHash, "Meowdy", "Ragdoll", block.timestamp - 3 weeks);

        string memory tokenUri = kittyConnect.tokenURI(0);
        console.log(tokenUri);
    }
}