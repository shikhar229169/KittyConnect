// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title KittyToken
 * @author Shikhar Agarwal
 * @notice This contract maintains the Kitty Tokens and allows users to purchase tokens in exchange of eth
 * @notice Users needs to purchase Kitty Tokens in order to make payments for vet visits, etc.
 */
contract KittyToken is ERC20 {
    // errors
    error KittyToken__NotKittyConnect();
    error KittyToken__ZeroEthSent();

    // storage variables
    address private immutable i_kittyConnect;
    AggregatorV3Interface private immutable i_ethUsdcPriceFeeds;
    uint8 private constant MAX_DECIMALS = 18;

    modifier onlyKittyConnect() {
        if (msg.sender != i_kittyConnect) {
            revert KittyToken__NotKittyConnect();
        }
        _;
    }

    constructor(address kittyConnect, address ethUsdcPriceFeeds) ERC20("KittyToken", "KT") {
        i_kittyConnect = kittyConnect;
        i_ethUsdcPriceFeeds = AggregatorV3Interface(ethUsdcPriceFeeds);
    }

    /**
     * @notice Users can buy KittyTokens for eth
     * @notice KittyToken is used for making payments on KittyConnect
     * @notice The price of KittyToken is same as the USDC price
     */
    function mintKittyTokenForEth() external payable {
        if (msg.value == 0) {
            revert KittyToken__ZeroEthSent();
        }
        uint256 mintAmount = _getMintAmount(msg.value);
        _mint(msg.sender, mintAmount);
    }

    function _getMintAmount(uint256 ethAmount) internal view returns (uint256) {
        (, int256 answer, , , ) = i_ethUsdcPriceFeeds.latestRoundData();
        uint8 remainingDecimals = MAX_DECIMALS - i_ethUsdcPriceFeeds.decimals();


        uint256 ethPrice = uint256(answer) * (10 ** remainingDecimals);
        
        return (ethPrice * ethAmount) / (10 ** MAX_DECIMALS);
    }

    function burnFrom(address user, uint256 amount) external onlyKittyConnect {
        _burn(user, amount);
    }
}