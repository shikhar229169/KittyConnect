// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import { Script } from "forge-std/Script.sol";
import { MockV3Aggregator } from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";

contract HelperConfig is Script {
    struct NetworkConfig{
        address ethUsdPriceFeed;
        address[] initShopPartners;
        address router;
        address link;
        uint64 chainSelector;
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
            networkConfig = getAnvilConfig();
        }
    }

    function getSepoliaConfig() internal pure returns (NetworkConfig memory) {
        address[] memory shopPartners = new address[](2);
        shopPartners[0] = 0xc15BB2baF07342aad4d311D0bBF2cEaf78ff2930;
        shopPartners[1] = 0xF1c8170181364DeD1C56c4361DED2eB47f2eef1b;

        return NetworkConfig({
            ethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            initShopPartners: shopPartners,
            router: 0xD0daae2231E9CB96b94C8512223533293C3693Bf,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            chainSelector: 16015286601757825753
        });
    }

    function getFujiConfig() internal pure returns (NetworkConfig memory) {
        address[] memory shopPartners = new address[](2);
        shopPartners[0] = 0xc15BB2baF07342aad4d311D0bBF2cEaf78ff2930;
        shopPartners[1] = 0xF1c8170181364DeD1C56c4361DED2eB47f2eef1b;

        return NetworkConfig({
            ethUsdPriceFeed: 0x86d67c3D38D2bCeE722E601025C25a575021c6EA,
            initShopPartners: shopPartners,
            router: 0x554472a2720E5E7D5D3C817529aBA05EEd5F82D8,
            link: 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846,
            chainSelector: 14767482510784806043
        });
    }

    function getAnvilConfig() internal returns (NetworkConfig memory) {
        address[] memory shopPartners = new address[](2);
        shopPartners[0] = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        shopPartners[1] = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;

        return NetworkConfig({
            ethUsdPriceFeed: address(new MockV3Aggregator(8, 226549810000)),
            initShopPartners: shopPartners,
            router: 0xD0daae2231E9CB96b94C8512223533293C3693Bf,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            chainSelector: 16015286601757825753
        });
    }

    function getNetworkConfig() external view returns (NetworkConfig memory) {
        return networkConfig;
    }
}