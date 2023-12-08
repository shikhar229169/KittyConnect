// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import { Script, console } from "forge-std/Script.sol";
import { KittyConnect, KittyBridge } from "../src/KittyConnect.sol";
import { HelperConfig } from "./HelperConfig.s.sol";

contract BuyCat is Script {
    function run() external {
        address kittyConnectAddr = 0xAb9823eBb878c53f61AE8B7100bed2182eF9fb04;
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
        address avBridge = 0xBbb5e9f418e4c524f3D778aa7810004cd1E2F984;
        address sepoliaBridge = 0x08883bAC7170A2C5e4891B15a976122BB1194CDB;
        address avKittyConnect = 0xAb9823eBb878c53f61AE8B7100bed2182eF9fb04;
        address sepoliaKittyConnect = 0x0468CD4bd0Ade2c3a7f3ba109AAb6349D915eA3d;

        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getNetworkConfig();
        uint256 tokenId = 0;

        vm.startBroadcast();

        KittyConnect(avKittyConnect).bridgeNftToAnotherChain(networkConfig.otherChainSelector, sepoliaBridge, tokenId);

        vm.stopBroadcast();
    }
}

contract AllowlistSenderReceiver is Script {
    function run() external {
        address avBridge = 0xBbb5e9f418e4c524f3D778aa7810004cd1E2F984;
        address sepoliaBridge = 0x08883bAC7170A2C5e4891B15a976122BB1194CDB;

        vm.startBroadcast();

        KittyBridge(sepoliaBridge).allowlistReceiver(avBridge, true);
        KittyBridge(sepoliaBridge).allowlistSender(avBridge, true);

        vm.stopBroadcast();
    }
}