// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import { Test, console } from "forge-std/Test.sol";
import { KittyInsuranceProvider } from "../src/KittyInsuranceProvider.sol";
import { HelperConfig } from "../script/HelperConfig.s.sol";
import { DeployKittyInsuranceProvider } from "../script/DeployKittyInsuranceProvider.s.sol";
import { KittyConnect } from "../src/KittyConnect.sol";
import { KittyToken } from "../src/KittyToken.sol";
import { KittyInsurance } from "../src/KittyInsurance.sol";

contract KittyInsuranceProviderTest is Test {
    KittyConnect kittyConnect;
    KittyInsuranceProvider kittyInsuranceProvider;
    HelperConfig helperConfig;
    HelperConfig.NetworkConfig networkConfig;
    KittyToken kittyToken;
    address partnerA;
    address partnerB;
    address policyHolder;
    address kittyConnectOwner;
    address user;
    string catImageIpfsHash;
    uint256 tokenId;

    event InsuranceProvided(address indexed policyHolder, address indexed insuranceContract);

    function setUp() external {
        DeployKittyInsuranceProvider deployer = new DeployKittyInsuranceProvider();

        (kittyConnect, kittyInsuranceProvider, helperConfig) = deployer.run();
        networkConfig = helperConfig.getNetworkConfig();

        kittyToken = KittyToken(kittyConnect.getKittyToken());
        kittyConnectOwner = kittyConnect.getKittyConnectOwner();
        partnerA = kittyConnect.getKittyShopAtIdx(0);
        partnerB = kittyConnect.getKittyShopAtIdx(1);
        policyHolder = kittyInsuranceProvider.getPolicyHolder();
        user = makeAddr("user");

        catImageIpfsHash = "ipfs://QmbxwGgBGrNdXPm84kqYskmcMT3jrzBN8LzQjixvkz4c62";
        vm.prank(partnerA);
        kittyConnect.mintCatToNewOwner(user, catImageIpfsHash, "Meowdy", "Ragdoll", block.timestamp);
        vm.stopPrank();
    }

    function testkittyInsuranceProviderConstructor() public {
        assertEq(kittyInsuranceProvider.getPolicyHolder(), policyHolder);
        assertEq(kittyInsuranceProvider.getKittyToken(), address(kittyToken));
        assertEq(kittyInsuranceProvider.getKittyConnect(), address(kittyConnect));
    }

    function testProvideInsurance() public {
        uint256 premiumAmount = 1 ether;
        uint256 coverageAmount = 15 ether;
        bool isOneYear = true;
        address tokenAddress = kittyInsuranceProvider.getKittyToken();

        vm.prank(policyHolder);
        kittyInsuranceProvider.provideInsurance(user, premiumAmount, coverageAmount, isOneYear, tokenAddress, tokenId);
        KittyInsurance kittyInsurance = KittyInsurance(kittyInsuranceProvider.getTokenIdToInsuranceContract(tokenId));
        vm.stopPrank();

        assertEq(kittyInsuranceProvider.isPolicyActive(tokenId), true);
        assertEq(kittyInsuranceProvider.getTokenIdToInsuranceContract(0), address(kittyInsurance));
    }

    function testProvideInsuranceAfterfifteenDays() public {
        uint256 premiumAmount = 1 ether;
        uint256 coverageAmount = 15 ether;
        bool isOneYear = true;
        address tokenAddress = kittyInsuranceProvider.getKittyToken();

        vm.warp(block.timestamp + (16 * 1 days));

        vm.expectRevert(KittyInsuranceProvider.KittyInsuranceProvider__OfferTimeExpired.selector);
        vm.prank(policyHolder);
        kittyInsuranceProvider.provideInsurance(user, premiumAmount, coverageAmount, isOneYear, tokenAddress, tokenId);
        vm.stopPrank();
    }

    function testProvideInsuranceAlreadyIssued() public {
        uint256 premiumAmount = 1 ether;
        uint256 coverageAmount = 15 ether;
        bool isOneYear = true;
        address tokenAddress = kittyInsuranceProvider.getKittyToken();

        vm.prank(policyHolder);
        kittyInsuranceProvider.provideInsurance(user, premiumAmount, coverageAmount, isOneYear, tokenAddress, tokenId);
        vm.stopPrank();

        vm.expectRevert(KittyInsuranceProvider.KittyInsuranceProvider__AlreadyIssued.selector);
        vm.prank(policyHolder);
        kittyInsuranceProvider.provideInsurance(user, premiumAmount, coverageAmount, isOneYear, tokenAddress, tokenId);
        vm.stopPrank();
    }

    function testSetPolicyActiveAfterExpirationByArbitaryAddress() public {
        uint256 premiumAmount = 1 ether;
        uint256 coverageAmount = 15 ether;
        bool isOneYear = true;
        address tokenAddress = kittyInsuranceProvider.getKittyToken();
        address arbitaryAddress = makeAddr("arbitaryAddress");

        vm.prank(policyHolder);
        kittyInsuranceProvider.provideInsurance(user, premiumAmount, coverageAmount, isOneYear, tokenAddress, tokenId);
        KittyInsurance kittyInsurance = KittyInsurance(kittyInsuranceProvider.getTokenIdToInsuranceContract(tokenId));
        vm.stopPrank();

        vm.expectRevert(KittyInsuranceProvider.KittyInsuranceProvider__NotPolicyHolder.selector);
        vm.prank(arbitaryAddress);
        kittyInsuranceProvider.setPolicyActiveAfterExpiration(address(kittyInsurance), tokenId);
        vm.stopPrank();
    }

    function testSetPolicyActiveAfterExpiration() public {
        uint256 premiumAmount = 1 ether;
        uint256 coverageAmount = 15 ether;
        bool isOneYear = true;
        address tokenAddress = kittyInsuranceProvider.getKittyToken();

        vm.prank(policyHolder);
        kittyInsuranceProvider.provideInsurance(user, premiumAmount, coverageAmount, isOneYear, tokenAddress, tokenId);
        KittyInsurance kittyInsurance = KittyInsurance(kittyInsuranceProvider.getTokenIdToInsuranceContract(tokenId));
        vm.stopPrank();

        vm.prank(user);
        kittyInsurance.payPremiumForOneYearPolicy(premiumAmount * 12);
        vm.stopPrank();

        vm.warp(kittyInsurance.getExpirationTimestamp() + 1);

        vm.prank(policyHolder);
        kittyInsuranceProvider.setPolicyActiveAfterExpiration(address(kittyInsurance), tokenId);

        assertEq(kittyInsuranceProvider.isPolicyActive(tokenId), false);
        vm.stopPrank();
    }

    function testSetPolicyActiveByArbitaryAddress() public {
        uint256 premiumAmount = 1 ether;
        uint256 coverageAmount = 15 ether;
        bool isOneYear = true;
        address tokenAddress = kittyInsuranceProvider.getKittyToken();
        address arbitaryAddress = makeAddr("arbitaryAddress");

        vm.prank(policyHolder);
        kittyInsuranceProvider.provideInsurance(user, premiumAmount, coverageAmount, isOneYear, tokenAddress, tokenId);
        vm.stopPrank();

        vm.expectRevert(KittyInsuranceProvider.KittyInsuranceProvider__NotInsuranceContract.selector);
        vm.prank(arbitaryAddress);
        kittyInsuranceProvider.setPolicyActive(tokenId, false);
        vm.stopPrank();
    }

    function testSetPolicyActive() public {
        uint256 premiumAmount = 1 ether;
        uint256 coverageAmount = 15 ether;
        bool isOneYear = true;
        address tokenAddress = kittyInsuranceProvider.getKittyToken();

        vm.prank(policyHolder);
        kittyInsuranceProvider.provideInsurance(user, premiumAmount, coverageAmount, isOneYear, tokenAddress, tokenId);
        KittyInsurance kittyInsurance = KittyInsurance(kittyInsuranceProvider.getTokenIdToInsuranceContract(tokenId));
        vm.stopPrank();

        vm.prank(partnerA);
        kittyInsurance.claim();
        vm.stopPrank();

        assertEq(kittyInsuranceProvider.isPolicyActive(tokenId), false);
    }

    function testkittyInsuranceConstructor() public {
        uint256 premiumAmount = 1 ether;
        uint256 coverageAmount = 15 ether;
        bool isOneYear = true;
        address tokenAddress = kittyInsuranceProvider.getKittyToken();

        vm.prank(policyHolder);
        kittyInsuranceProvider.provideInsurance(user, premiumAmount, coverageAmount, isOneYear, tokenAddress, tokenId);
        KittyInsurance kittyInsurance = KittyInsurance(kittyInsuranceProvider.getTokenIdToInsuranceContract(tokenId));
        vm.stopPrank();

        assertEq(kittyInsurance.getPolicyHolder(), policyHolder);
        assertEq(kittyInsurance.getKittyConnect(), address(kittyConnect));
        assertEq(kittyInsurance.getKittyToken(), address(kittyToken));
        assertEq(kittyInsurance.getKittyOwner(), user);
        assertEq(kittyInsurance.getPremiumAmount(), premiumAmount);
        assertEq(kittyInsurance.getCoverageAmount(), coverageAmount);
        assertEq(kittyInsurance.getIsOneYear(), isOneYear);
        assertEq(kittyInsurance.getExpirationTimestamp(), block.timestamp + (1 * 365 days));
        assertEq(kittyInsurance.getNetPremiumToBepaid(), premiumAmount * 12);
        assertEq(kittyInsurance.getIsClaimed(), false);
        assertEq(kittyInsurance.getTokenId(), tokenId);
    }

    function testPayPremiumForOneYearPolicy() public {
        uint256 premiumAmount = 1 ether;
        uint256 coverageAmount = 15 ether;
        bool isOneYear = true;
        address tokenAddress = kittyInsuranceProvider.getKittyToken();

        vm.prank(policyHolder);
        kittyInsuranceProvider.provideInsurance(user, premiumAmount, coverageAmount, isOneYear, tokenAddress, tokenId);
        KittyInsurance kittyInsurance = KittyInsurance(kittyInsuranceProvider.getTokenIdToInsuranceContract(tokenId));
        vm.stopPrank();

        vm.prank(user);
        kittyInsurance.payPremiumForOneYearPolicy(premiumAmount * 12);
        vm.stopPrank();

        assertEq(kittyInsurance.getTotalPremiumPaidByOwner(), kittyInsurance.getPremiumAmount() * 12);
    }

    function testPayPremiumForSixMonthPolicy() public {
        uint256 premiumAmount = 1 ether;
        uint256 coverageAmount = 15 ether;
        bool isOneYear = false;
        address tokenAddress = kittyInsuranceProvider.getKittyToken();

        vm.prank(policyHolder);
        kittyInsuranceProvider.provideInsurance(user, premiumAmount, coverageAmount, isOneYear, tokenAddress, tokenId);
        KittyInsurance kittyInsurance = KittyInsurance(kittyInsuranceProvider.getTokenIdToInsuranceContract(tokenId));
        vm.stopPrank();

        vm.prank(user);
        kittyInsurance.payPremiumForSixMonthPolicy(premiumAmount * 6);
        vm.stopPrank();

        assertEq(kittyInsurance.getTotalPremiumPaidByOwner(), kittyInsurance.getPremiumAmount() * 6);
    }

    function testClaim() public {
        uint256 premiumAmount = 1 ether;
        uint256 coverageAmount = 15 ether;
        bool isOneYear = true;
        address tokenAddress = kittyInsuranceProvider.getKittyToken();

        vm.prank(policyHolder);
        kittyInsuranceProvider.provideInsurance(user, premiumAmount, coverageAmount, isOneYear, tokenAddress, tokenId);
        KittyInsurance kittyInsurance = KittyInsurance(kittyInsuranceProvider.getTokenIdToInsuranceContract(tokenId));
        vm.stopPrank();

        vm.prank(user);
        kittyInsurance.payPremiumForOneYearPolicy(premiumAmount * 12);
        vm.stopPrank();

        vm.prank(partnerA);
        kittyInsurance.claim();
        vm.stopPrank();

        assertEq(kittyInsurance.getIsClaimed(), true);
    }
}
