// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title PriceConverter
 * @dev Library for converting ETH amounts to USD values and vice-versa,
 * assuming ETH amounts are 18 decimals and USD values are scaled to 18 decimals.
 */
library PriceConverter {
    // Standard scale for fixed-point math
    uint256 private constant ETH_USD_SCALE = 1e18;
    int256 private constant PRICE_FEED_SCALE_ADJUSTMENT = 10000000000; // 10^10

    /**
     * @notice Fetches the current ETH price from the Chainlink feed.
     * @param priceFeed The AggregatorV3Interface for the ETH/USD pair (typically 8 decimals).
     * @return The ETH price in USD, scaled to 18 decimals (standard Solidity fixed-point).
     */
    function getPrice(AggregatorV3Interface priceFeed) internal view returns (uint256) {
        (, int256 answer, , , ) = priceFeed.latestRoundData();

        // Chainlink's ETH/USD feeds typically return 8 decimals.
        // We scale it up by 10^10 to achieve 18-decimal precision.
        return uint256(answer * PRICE_FEED_SCALE_ADJUSTMENT);
    }

    /**
     * @notice Converts an amount of ETH (in 18 decimals) to its USD equivalent (in 18 decimals).
     * @param ethAmount The amount of ETH to convert (18 decimals).
     * @param priceFeed The AggregatorV3Interface for the ETH/USD pair.
     * @return The USD value of the ETH amount (18 decimals).
     */
    function getUsdAmountInEth(
        uint256 ethAmount,
        AggregatorV3Interface priceFeed
    ) internal view returns (uint256) {
        uint256 ethPrice = getPrice(priceFeed);
        
        // (ethPrice * ethAmount) / 1e18
        // (18 decimals * 18 decimals) / 18 decimals = 18 decimals (USD amount)
        uint256 usdAmount = (ethPrice * ethAmount) / ETH_USD_SCALE;
        return usdAmount;
    }

    /**
     * @notice Converts a USD amount (in 18 decimals) to the required ETH amount (in 18 decimals).
     * @dev This is the inverse of getUsdAmountInEth and is required for USD-stable fees.
     * @param usdAmount The required USD amount (18 decimals).
     * @param priceFeed The AggregatorV3Interface for the ETH/USD pair.
     * @return The required ETH amount (18 decimals). Returns 0 if price is 0.
     */
    function getEthAmountOutUsd(
        uint256 usdAmount,
        AggregatorV3Interface priceFeed
    ) internal view returns (uint256) {
        uint256 ethPrice = getPrice(priceFeed); // ETH Price in USD (18 decimals)

        if (ethPrice == 0) return 0;

        // (usdAmount * 1e18) / ethPrice
        // (18 decimals * 1e18) / 18 decimals = 18 decimals (required ETH)
        uint256 requiredEth = (usdAmount * ETH_USD_SCALE) / ethPrice;
        return requiredEth;
    }
}
