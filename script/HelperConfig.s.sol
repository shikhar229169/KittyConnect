// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import { Script } from "forge-std/Script.sol";

contract HelperConfig is Script {
    struct NetworkConfig{
        address ethUsdPriceFeed;
        address[] initShopPartners;
    }

    NetworkConfig private networkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            networkConfig = getSepoliaConfig();
        }
        else if (block.chainid == 43113) {
            networkConfig = getFujiConfig();
        }
        else {
            networkConfig = getSepoliaConfig();
        }
    }

    function getSepoliaConfig() internal pure returns (NetworkConfig memory) {
        address[] memory shopPartners = new address[](2);
        shopPartners[0] = 0xc15BB2baF07342aad4d311D0bBF2cEaf78ff2930;
        shopPartners[1] = 0xF1c8170181364DeD1C56c4361DED2eB47f2eef1b;

        return NetworkConfig({
            ethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            initShopPartners: shopPartners
        });
    }

    function getFujiConfig() internal pure returns (NetworkConfig memory) {
        address[] memory shopPartners = new address[](2);
        shopPartners[0] = 0xc15BB2baF07342aad4d311D0bBF2cEaf78ff2930;
        shopPartners[1] = 0xF1c8170181364DeD1C56c4361DED2eB47f2eef1b;

        return NetworkConfig({
            ethUsdPriceFeed: 0x86d67c3D38D2bCeE722E601025C25a575021c6EA,
            initShopPartners: shopPartners
        });
    }

    function getNetworkConfig() external view returns (NetworkConfig memory) {
        return networkConfig;
    }
}