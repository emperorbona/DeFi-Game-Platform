// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {AdminWallet} from "../../src/admin/AdminWallet.sol"; 
import {MockV3Aggregator} from "../../test/mocks/MockV3Aggregator.sol";

contract HelperConfig is Script{
    struct NetworkConfig{
        address priceFeed;
    }
    uint8 public constant DECIMALS = 8;
    int256 public constant INITIAL_PRICE = 2000e8;

    NetworkConfig public activeNetworkConfig;

    constructor(){
         if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        }
        else if(block.chainid == 43113){
            activeNetworkConfig = getAvalancheFujiConfig();
        }
        else if(block.chainid == 43114){
            activeNetworkConfig = getAvalancheMainnetConfig();
        }
        else if(block.chainid == 84532){
            activeNetworkConfig = getBaseSepoliaConfig();
        }
        else if(block.chainid == 8453){
            activeNetworkConfig = getBaseMainnetConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }
    function getSepoliaEthConfig() public pure returns (NetworkConfig memory sepoliaConfig) {
        sepoliaConfig = NetworkConfig({
            priceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306
        });
    }
    function getAvalancheFujiConfig() public pure returns (NetworkConfig memory fujiConfig) {
        fujiConfig = NetworkConfig({
            priceFeed:0x5498BB86BC934c8D34FDA08E81D444153d0D06aD
        });
    }
    function getAvalancheMainnetConfig() public pure returns (NetworkConfig memory avalancheConfig) {
        avalancheConfig = NetworkConfig({
            priceFeed: 0x0A77230d17318075983913bC2145DB16C7366156
        }); 
    }
    function getBaseSepoliaConfig() public pure returns (NetworkConfig memory baseSepoliaConfig) {
        baseSepoliaConfig = NetworkConfig({
            priceFeed: 0x3ec8593F930EA45ea58c968260e6e9FF53FC934f
        });
    }
    function getBaseMainnetConfig() public pure returns (NetworkConfig memory baseMainnetConfig) {
        baseMainnetConfig = NetworkConfig({
            priceFeed: 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70
        });
    }
   function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory){

        if(activeNetworkConfig.priceFeed !=address(0)){
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        MockV3Aggregator mockPriceFeed = new MockV3Aggregator(
            DECIMALS,
            INITIAL_PRICE
        );
        vm.stopBroadcast();

       NetworkConfig memory anvilConfig = NetworkConfig({priceFeed: address(mockPriceFeed)});

       return anvilConfig;
    }
}