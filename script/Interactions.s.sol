// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import { Script, console } from "forge-std/Script.sol";
import { KittyConnect } from "../src/KittyConnect.sol";

contract BuyCat is Script {
    function run() external {
        address kittyConnectAddr = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
        address catOwner = 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720;
        string memory catImageIpfsHash = "ipfs://QmbxwGgBGrNdXPm84kqYskmcMT3jrzBN8LzQjixvkz4c62";

        KittyConnect kittyConnect = KittyConnect(kittyConnectAddr);

        vm.startBroadcast();

        kittyConnect.mintCatToNewOwner(catOwner, catImageIpfsHash, "Meowdy", "Ragdoll", block.timestamp);

        vm.stopBroadcast();

        console.log(kittyConnect.tokenURI(kittyConnect.getTokenCounter() - 1));
    }
}