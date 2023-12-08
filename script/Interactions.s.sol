// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import { Script, console } from "forge-std/Script.sol";
import { KittyConnect, KittyBridge } from "../src/KittyConnect.sol";
import { HelperConfig } from "./HelperConfig.s.sol";

contract BuyCat is Script {
    function run() external {
        address kittyConnectAddr = 0x8F1D72776F7bA4a8208749f30B7c96C2A3b59DD2;
        // address catOwner = 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720;
        address catOwner = 0xE81502D8c3bec299F44Ef3400Bf2e41f7B8947B2;
        string memory catImageIpfsHash = "ipfs://QmbxwGgBGrNdXPm84kqYskmcMT3jrzBN8LzQjixvkz4c62";

        KittyConnect kittyConnect = KittyConnect(kittyConnectAddr);

        vm.startBroadcast();

        kittyConnect.mintCatToNewOwner(catOwner, catImageIpfsHash, "Meowdy", "Ragdoll", block.timestamp);

        vm.stopBroadcast();

        console.log(kittyConnect.tokenURI(kittyConnect.getTokenCounter() - 1));
    }
}

contract BridgeNFT is Script {
    function run() external {
        address avBridge = 0xE69372fC03e2B23E40B150C073B2ADa19bB24Bd6;
        address sepoliaBridge = 0xb52a9b20423197784f5b42209dB453efA68FD89F;
        address avKittyConnect = 0x8F1D72776F7bA4a8208749f30B7c96C2A3b59DD2;
        address sepoliaKittyConnect = 0xCd07002bd7350cBe5fcD94b5179C15cF1Bf41CfA;

        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getNetworkConfig();
        uint256 tokenId = 0;

        vm.startBroadcast();

        KittyConnect(avKittyConnect).bridgeNftToAnotherChain(networkConfig.otherChainSelector, sepoliaBridge, tokenId);

        vm.stopBroadcast();
    }
}

contract BridgeNFTDiff is Script {
    function run() external {
        address avBridge = 0xE69372fC03e2B23E40B150C073B2ADa19bB24Bd6;
        address sepoliaBridge = 0xb52a9b20423197784f5b42209dB453efA68FD89F;
        address avKittyConnect = 0x8F1D72776F7bA4a8208749f30B7c96C2A3b59DD2;
        address sepoliaKittyConnect = 0xCd07002bd7350cBe5fcD94b5179C15cF1Bf41CfA;

        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getNetworkConfig();
        uint256 tokenId = 0;

        vm.startBroadcast();

        KittyConnect(sepoliaKittyConnect).bridgeNftToAnotherChain(networkConfig.otherChainSelector, avBridge, tokenId);

        vm.stopBroadcast();
    }
}

contract AllowlistSenderReceiver is Script {
    function run() external {
        address avBridge = 0xE69372fC03e2B23E40B150C073B2ADa19bB24Bd6;
        address sepoliaBridge = 0xb52a9b20423197784f5b42209dB453efA68FD89F;

        vm.startBroadcast();

        KittyBridge(avBridge).allowlistReceiver(sepoliaBridge, true);
        KittyBridge(avBridge).allowlistSender(sepoliaBridge, true);

        vm.stopBroadcast();
    }
}