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

    function test_mintCatToNewOwnerIfCatOwnerIsShopPartner() public {
        string memory catImageIpfsHash = "ipfs://QmbxwGgBGrNdXPm84kqYskmcMT3jrzBN8LzQjixvkz4c62";

        vm.expectRevert(KittyConnect.KittyConnect__CatOwnerCantBeShopPartner.selector);
        vm.prank(partnerA);
        kittyConnect.mintCatToNewOwner(partnerB, catImageIpfsHash, "Hehe", "Hehe", block.timestamp);
    }

    function test_redeemTokensForVetVisitRevetIfInsufficientAllowance() public {
        string memory catImageIpfsHash = "ipfs://QmbxwGgBGrNdXPm84kqYskmcMT3jrzBN8LzQjixvkz4c62";
        uint256 tokenId = kittyConnect.getTokenCounter();

        vm.prank(partnerA);
        kittyConnect.mintCatToNewOwner(user, catImageIpfsHash, "Meowdy", "Ragdoll", block.timestamp);
        vm.stopPrank();

        vm.expectRevert(KittyConnect.KittyConnect__InsufficientAllowance.selector);
        vm.prank(partnerA);
        kittyConnect.redeemTokensForVetVisit(user, tokenId, 1, "Cat is healthy");
        vm.stopPrank();
    }

    function test_redeemTokensForVetVisitRvertsIfCallerIsNotShopPartner() public {
        string memory catImageIpfsHash = "ipfs://QmbxwGgBGrNdXPm84kqYskmcMT3jrzBN8LzQjixvkz4c62";
        uint256 tokenId = kittyConnect.getTokenCounter();
        address attacker = makeAddr("attacker");

        vm.prank(partnerA);
        kittyConnect.mintCatToNewOwner(user, catImageIpfsHash, "Meowdy", "Ragdoll", block.timestamp);

        vm.stopPrank();

        vm.expectRevert(KittyConnect.KittyConnect__NotAPartner.selector);
        vm.prank(attacker);
        kittyConnect.redeemTokensForVetVisit(user, tokenId, 1, "Cat is healthy");
        vm.stopPrank();
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

    function test_getCatAge() public {
        string memory catImageIpfsHash = "ipfs://QmbxwGgBGrNdXPm84kqYskmcMT3jrzBN8LzQjixvkz4c62";
        uint256 tokenId = kittyConnect.getTokenCounter();

        vm.prank(partnerA);
        kittyConnect.mintCatToNewOwner(user, catImageIpfsHash, "Meowdy", "Ragdoll", block.timestamp);
        
        vm.warp(block.timestamp + 10 weeks);
        vm.prank(user);
        uint256 catAge = kittyConnect.getCatAge(tokenId);

        assertEq(catAge, 10 weeks);
    }

    function test_onlyKittyConnectOwnerCanAddNewPartnerShop() public {
        address partnerC = makeAddr("partnerC");

        vm.prank(kittyConnectOwner);
        kittyConnect.addShop(partnerC);

        assert(kittyConnect.getIsKittyPartnerShop(partnerC) == true);
        assertEq(kittyConnect.getKittyShopAtIdx(2), partnerC);
    }

    function test_revertIfCallerIsAlreadyPartner() public {
        address partnerC = makeAddr("partnerC");

        vm.prank(kittyConnectOwner);
        kittyConnect.addShop(partnerC);

        vm.expectRevert(KittyConnect.KittyConnect__AlreadyAPartner.selector);
        vm.prank(kittyConnectOwner);
        kittyConnect.addShop(partnerC);
    }

    function test_revertsIfCallerIsNotKittyConnectOwner() public {
        address partnerC = makeAddr("partnerC");

        vm.expectRevert(KittyConnect.KittyConnect__NotKittyConnectOwner.selector);
        vm.prank(partnerC);
        kittyConnect.addShop(partnerC);
    }

    function test_tokenURI() public {
        string memory catImageIpfsHash = "ipfs://QmbxwGgBGrNdXPm84kqYskmcMT3jrzBN8LzQjixvkz4c62";
        string memory expectedTokenURI = "data:application/json;base64,eyJuYW1lIjogIiIsICJicmVlZCI6ICIiLCAiaW1hZ2UiOiAiIiwgImRvYiI6IDAsICJvd25lciI6ICIweDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAiLCAic2hvcFBhcnRuZXIiOiAiMHgwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwIn0=";
        vm.prank(partnerA);
        kittyConnect.mintCatToNewOwner(user, catImageIpfsHash, "Meowdy", "Ragdoll", block.timestamp);

        uint256 tokenId = kittyConnect.getTokenCounter();
        string memory tokenUri = kittyConnect.tokenURI(tokenId);

        assertEq(tokenUri, expectedTokenURI);
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

    function test_safetransferCatToNewOwner() public {
        string memory catImageIpfsHash = "ipfs://QmbxwGgBGrNdXPm84kqYskmcMT3jrzBN8LzQjixvkz4c62";
        uint256 tokenId = kittyConnect.getTokenCounter();
        address newOwner = makeAddr("newOwner");

        vm.prank(partnerA);
        kittyConnect.mintCatToNewOwner(user, catImageIpfsHash, "Meowdy", "Ragdoll", block.timestamp);

        vm.prank(user);
        kittyConnect.approve(newOwner, tokenId);

        vm.expectEmit(false, false, false, true, address(kittyConnect));
        emit CatTransferredToNewOwner(user, newOwner, tokenId);
        vm.prank(partnerA);
        kittyConnect.safeTransferFrom(user, newOwner, tokenId);

        assertEq(kittyConnect.ownerOf(tokenId), newOwner);
        assertEq(kittyConnect.getCatsTokenIdOwnedBy(user).length, 0);
        assertEq(kittyConnect.getCatsTokenIdOwnedBy(newOwner).length, 1);
        assertEq(kittyConnect.getCatsTokenIdOwnedBy(newOwner)[0], tokenId);
        assertEq(kittyConnect.getCatInfo(tokenId).prevOwner[0], user);
        assertEq(kittyConnect.getCatInfo(tokenId).prevOwner.length, 1);
        assertEq(kittyConnect.getCatInfo(tokenId).idx, 0);
    }

    // Kitty Token Tests
    function test_KittyTokenConstructor() public {
        assertEq(kittyToken.getKittyConnectAddr(), address(kittyConnect));
        assertEq(kittyToken.getEthUsdPriceFeed(), networkConfig.ethUsdPriceFeed);
    }

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

    function test_burnFrom(uint256 amount) public {
        vm.assume(amount != 0 && amount <= 1000000 ether);
        vm.deal(address(this), amount + 1e18);

        kittyToken.mintKittyTokenForEth{value: amount}();
        
        // price is 1 eth = 2265.4981 USD
        uint256 currentPrice = 2265.4981 ether;   // usdc price

        // now for amount eth, usdc = 2265.4981 * amount

        uint256 expectedAmount = (currentPrice * amount) / 1e18;

        assertEq(kittyToken.balanceOf(address(this)), expectedAmount);

        vm.prank(address(kittyConnect));
        kittyToken.burnFrom(address(this), expectedAmount);
        vm.stopPrank();

        assertEq(kittyToken.balanceOf(address(this)), 0);
    }

    // kittyBridge Tests
    function test_KittyBridgeConstructor() public {
        address mockLinkToken = 0x90193C961A926261B756D1E5bb255e67ff9498A1;

        assertEq(kittyBridge.getKittyConnectAddr(), address(kittyConnect));
        assertEq(kittyBridge.getGaslimit(), 400000);
        assertEq(kittyBridge.getLinkToken(), mockLinkToken);
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

    function test_allowlistSenderIsNotOwner() public {
        address sender = makeAddr("sender");

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(sender);
        kittyBridge.allowlistSender(sender, true);
    }

    function test_allowlistSender() public {
        address sender = makeAddr("sender");

        vm.prank(kittyConnectOwner);
        kittyBridge.allowlistSender(sender, true);

        assert(kittyBridge.allowlistedSenders(sender) == true);
    }

    function test_allowlistReceiver() public {
        address receiver = makeAddr("receiver");

        vm.prank(kittyConnectOwner);
        kittyBridge.allowlistReceiver(receiver, true);

        assert(kittyBridge.allowlistedReceivers(receiver) == true);
    }

    function test_allowlistReceiverIsNotOwner() public {
        address receiver = makeAddr("receiver");

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(receiver);
        kittyBridge.allowlistReceiver(receiver, true);
    }

    function test_allowlistDestinationChain() public {
        uint64 chainId = 1;

        vm.prank(kittyConnectOwner);
        kittyBridge.allowlistDestinationChain(chainId, true);

        assert(kittyBridge.allowlistedDestinationChains(chainId) == true);
    }

    function test_allowlistDestinationChainIsNotOwner() public {
        uint64 chainId = 1;
        address  attacker = makeAddr("attacker");   

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(attacker);
        kittyBridge.allowlistDestinationChain(chainId, true);
    }

    function test_allowlistSourceChain() public {
        uint64 chainId = 1;

        vm.prank(kittyConnectOwner);
        kittyBridge.allowlistSourceChain(chainId, true);

        assert(kittyBridge.allowlistedSourceChains(chainId) == true);
    }

    function test_allowlistSourceChainRevertIfNotOwner() public {
        uint64 chainId = 1;
        address attacker = makeAddr("attacker");
        
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(attacker);
        kittyBridge.allowlistSourceChain(chainId, true);

    }

    function test_bridgeNftWithDataIfCallerIsNotKittyConnect() public {
        address sender = makeAddr("sender");
        uint64 chainId = 1;
        bytes memory data = abi.encode(makeAddr("catOwner"), "meowdy", "ragdoll", "ipfs://QmbxwGgBGrNdXPm84kqYskmcMT3jrzBN8LzQjixvkz4c62", block.timestamp, partnerA);

        vm.expectRevert(KittyBridge.KittyBridge__NotKittyConnect.selector);
        vm.prank(sender);
        kittyBridge.bridgeNftWithData(chainId, sender, data);
    }

    function test_bridgeNftWithDataIfDestinationIsNotAllowlisted() public {
        address sender = makeAddr("sender");
        uint64 chainId = 1;
        bytes memory data = abi.encode(makeAddr("catOwner"), "meowdy", "ragdoll", "ipfs://QmbxwGgBGrNdXPm84kqYskmcMT3jrzBN8LzQjixvkz4c62", block.timestamp, partnerA);

        vm.expectRevert(abi.encodeWithSelector(KittyBridge.DestinationChainNotAllowlisted.selector, chainId));
        vm.prank(address(kittyConnect));
        kittyBridge.bridgeNftWithData(chainId, sender, data);
    }

    function test_bridgeNftWithDataIfReceiverIsNotAllowlisted() public {
        address receiver = makeAddr("receiver");
        uint64 chainId = 1;
        bytes memory data = abi.encode(makeAddr("catOwner"), "meowdy", "ragdoll", "ipfs://QmbxwGgBGrNdXPm84kqYskmcMT3jrzBN8LzQjixvkz4c62", block.timestamp, partnerA);
        
        vm.prank(kittyConnectOwner);
        kittyBridge.allowlistDestinationChain(chainId, true);

        vm.expectRevert(KittyBridge.KittyBridge__ReceiverNotAllowlisted.selector);
        vm.prank(address(kittyConnect));
        kittyBridge.bridgeNftWithData(chainId, receiver, data);
    }

    function test_updateGaslimit() public {
        uint256 newGaslimit = 500000;

        vm.prank(kittyConnectOwner);
        kittyBridge.updateGaslimit(newGaslimit);

        assertEq(kittyBridge.getGaslimit(), newGaslimit);
    }

    function test_updateGaslimitRevertIfNotOwner() public {
        uint256 newGaslimit = 500000;
        address attacker = makeAddr("attacker");

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(attacker);
        kittyBridge.updateGaslimit(newGaslimit);
    }

    function test_withdrawTokenRevertIfNotOwner() public {
        address attacker = makeAddr("attacker");

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(attacker);
        kittyBridge.withdrawToken(attacker, address(kittyToken));
    }
    
    function test_withdrawRevertIfNotOwner() public {
        address attacker = makeAddr("attacker");

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(attacker);
        kittyBridge.withdraw(attacker);
    }
}