// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import { Test, console } from "forge-std/Test.sol";
import { DeployKittyConnect } from "../script/DeployKittyConnect.s.sol";
import { HelperConfig } from "../script/HelperConfig.s.sol";
import { KittyConnect, KittyToken } from "../src/KittyConnect.sol";
import { AggregatorV3Interface } from "../src/KittyToken.sol";
import { KittyBridge, Client } from "../src/KittyBridge.sol";

contract KittyConnectTest is Test {
    KittyConnect kittyConnect;
    KittyToken kittyToken;
    KittyBridge kittyBridge;
    HelperConfig helperConfig;
    HelperConfig.NetworkConfig networkConfig;
    address kittyConnectOwner;
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

        kittyConnectOwner = kittyConnect.getKittyConnectOwner();
        partnerA = kittyConnect.getKittyShopAtIdx(0);
        partnerB = kittyConnect.getKittyShopAtIdx(1);
        kittyToken = KittyToken(kittyConnect.getKittyToken());
        kittyBridge = KittyBridge(kittyConnect.getKittyBridge());
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

    function test_onlyShopPartnersCanAllocateCatToUsers() public {
        address someUser = makeAddr("someUser");
        string memory catImageIpfsHash = "ipfs://QmbxwGgBGrNdXPm84kqYskmcMT3jrzBN8LzQjixvkz4c62";

        vm.expectRevert(KittyConnect.KittyConnect__NotAPartner.selector);
        vm.prank(someUser);
        kittyConnect.mintCatToNewOwner(user, catImageIpfsHash, "Hehe", "Hehe", block.timestamp);
    }

    function test_ShopPartnerGivesCatToCustomer() public {
        string memory catImageIpfsHash = "ipfs://QmbxwGgBGrNdXPm84kqYskmcMT3jrzBN8LzQjixvkz4c62";
        vm.warp(block.timestamp + 10 weeks);

        uint256 tokenId = kittyConnect.getTokenCounter();

        vm.expectEmit(false, false, false, true);
        emit CatMinted(tokenId, catImageIpfsHash);
        vm.prank(partnerA);
        kittyConnect.mintCatToNewOwner(user, catImageIpfsHash, "Meowdy", "Ragdoll", block.timestamp - 3 weeks);

        string memory tokenUri = kittyConnect.tokenURI(tokenId);
        console.log(tokenUri);
        KittyConnect.CatInfo memory catInfo = kittyConnect.getCatInfo(tokenId);
        uint256[] memory userCatTokenId = kittyConnect.getCatsTokenIdOwnedBy(user);

        assertEq(kittyConnect.ownerOf(tokenId), user);
        assertEq(kittyConnect.getTokenCounter(), tokenId + 1);
        assertEq(userCatTokenId[0], tokenId);
        assertEq(catInfo.catName, "Meowdy");
        assertEq(catInfo.breed, "Ragdoll");
        assertEq(catInfo.image, catImageIpfsHash);
        assertEq(catInfo.dob, block.timestamp - 3 weeks);
        assertEq(catInfo.shopPartner, partnerA);
        assertEq(catInfo.idx, 0);
    }

    function test_onlyKittyConnectOwnerCanAddNewPartnerShop() public {
        address partnerC = makeAddr("partnerC");

        vm.prank(kittyConnectOwner);
        kittyConnect.addShop(partnerC);

        assert(kittyConnect.getIsKittyPartnerShop(partnerC) == true);
        assertEq(kittyConnect.getKittyShopAtIdx(2), partnerC);
    }

    function test_revertsIfCallerIsNotKittyConnectOwner() public {
        address partnerC = makeAddr("partnerC");

        vm.expectRevert(KittyConnect.KittyConnect__NotKittyConnectOwner.selector);
        vm.prank(partnerC);
        kittyConnect.addShop(partnerC);
    }

    modifier partnerGivesCatToOwner() {
        string memory catImageIpfsHash = "ipfs://QmbxwGgBGrNdXPm84kqYskmcMT3jrzBN8LzQjixvkz4c62";

        // Shop Partner gives Cat to user
        vm.prank(partnerA);
        kittyConnect.mintCatToNewOwner(user, catImageIpfsHash, "Meowdy", "Ragdoll", block.timestamp);
        _;
    }

    function test_transferCatToNewOwner() public {
        string memory catImageIpfsHash = "ipfs://QmbxwGgBGrNdXPm84kqYskmcMT3jrzBN8LzQjixvkz4c62";
        uint256 tokenId = kittyConnect.getTokenCounter();
        address newOwner = makeAddr("newOwner");

        // Shop Partner gives Cat to user
        vm.prank(partnerA);
        kittyConnect.mintCatToNewOwner(user, catImageIpfsHash, "Meowdy", "Ragdoll", block.timestamp);

        // Now user wants to transfer the cat to a new owner
        // first user approves the cat's token id to new owner
        vm.prank(user);
        kittyConnect.approve(newOwner, tokenId);

        // then the shop owner checks up with the new owner and confirms the transfer
        vm.expectEmit(false, false, false, true, address(kittyConnect));
        emit CatTransferredToNewOwner(user, newOwner, tokenId);
        vm.prank(partnerA);
        kittyConnect.transferFrom(user, newOwner, tokenId);

        uint256[] memory newOwnerTokenIds = kittyConnect.getCatsTokenIdOwnedBy(newOwner);
        KittyConnect.CatInfo memory catInfo = kittyConnect.getCatInfo(tokenId);
        string memory tokenUri = kittyConnect.tokenURI(tokenId);
        console.log(tokenUri);


        assert(kittyConnect.getCatsTokenIdOwnedBy(user).length == 0);
        assert(newOwnerTokenIds.length == 1);
        assertEq(newOwnerTokenIds[0], tokenId);
        assertEq(catInfo.prevOwner[0], user);
    }

    function test_transferCatReverts_if_OwnerHasNotApprovedToNewOwner() public partnerGivesCatToOwner {
        uint256 tokenId = kittyConnect.getTokenCounter() - 1;
        address newOwner = makeAddr("newOwner");

        vm.prank(partnerA);
        vm.expectRevert(KittyConnect.KittyConnect__NewOwnerNotApproved.selector);
        kittyConnect.transferFrom(user, newOwner, tokenId);
    }

    function test_transferCatReverts_If_CallerIsNotAPartnerShop() public partnerGivesCatToOwner {
        uint256 tokenId = kittyConnect.getTokenCounter() - 1;
        address newOwner = makeAddr("newOwner");
        address notPartnerShop = makeAddr("notPartnerShop");

        vm.prank(user);
        kittyConnect.approve(newOwner, tokenId);

        vm.prank(notPartnerShop);
        vm.expectRevert(KittyConnect.KittyConnect__NotAPartner.selector);
        kittyConnect.transferFrom(user, newOwner, tokenId);
    }



    // Kitty Token Tests
    function test_mintKittyTokenForEth(uint256 amount) public {
        vm.assume(amount != 0 && amount <= 1000000 ether);
        vm.deal(address(this), amount + 1e18);

        kittyToken.mintKittyTokenForEth{value: amount}();
        
        // price is 1 eth = 2265.4981 USD
        uint256 currentPrice = 2265.4981 ether;   // usdc price

        // now for amount eth, usdc = 2265.4981 * amount

        uint256 expectedAmount = (currentPrice * amount) / 1e18;

        assertEq(kittyToken.balanceOf(address(this)), expectedAmount);
    }

    function test_gasForCcipReceive() public {
        address sender = makeAddr("sender");
        bytes memory data = abi.encode(makeAddr("catOwner"), "meowdy", "ragdoll", "ipfs://QmbxwGgBGrNdXPm84kqYskmcMT3jrzBN8LzQjixvkz4c62", block.timestamp, partnerA);

        vm.prank(kittyConnectOwner);
        kittyBridge.allowlistSender(sender, true);

        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: bytes32(0),
            sourceChainSelector: networkConfig.otherChainSelector,
            sender: abi.encode(sender),
            data: data,
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });

        vm.prank(networkConfig.router);
        kittyBridge.ccipReceive(message);
    }
}