// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import { Script } from "forge-std/Script.sol";
import { HelperConfig } from "./HelperConfig.s.sol";
import { KittyConnect } from "../src/KittyConnect.sol";
import { KittyInsuranceProvider } from "../src/KittyInsuranceProvider.sol";
import { KittyInsurance } from "../src/KittyInsurance.sol";

contract DeployKittyInsuranceProvider is Script {
    function run() external returns (KittyConnect, KittyInsuranceProvider, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getNetworkConfig();
        KittyInsuranceProvider kittyInsuranceProvider;
        // KittyInsurance kittyInsurance;

        vm.startBroadcast();

        KittyConnect kittyConnect = new KittyConnect(
            networkConfig.initShopPartners, networkConfig.ethUsdPriceFeed, networkConfig.router, networkConfig.link
        );

        kittyInsuranceProvider = new KittyInsuranceProvider(kittyConnect.getKittyToken(), address(kittyConnect));
        // kittyInsurance =
        //     KittyInsurance(kittyInsuranceProvider.getTokenIdToInsuranceContract(kittyConnect.getTokenCounter()));

        vm.stopBroadcast();

        return (kittyConnect, kittyInsuranceProvider, helperConfig);
    }
}
