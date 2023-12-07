// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {KittyConnect} from "../src/KittyConnect.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployKittyConnect is Script {
    function run() external returns (KittyConnect, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getNetworkConfig();

        vm.startBroadcast();

        KittyConnect kittyConnect =
        new KittyConnect(networkConfig.initShopPartners, networkConfig.ethUsdPriceFeed, networkConfig.router, networkConfig.link);

        vm.stopBroadcast();

        return (kittyConnect, helperConfig);
    }
}
