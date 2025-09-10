// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {DiceGame} from "../../src/dice-game/DiceGame.sol";
import {GameWallet} from "../../src/wallet/GameWallet.sol";
import {DeployGameWallet} from "../gameWalletDeploy/DeployGameWallet.s.sol";
import {MockV3Aggregator} from "../../test/mocks/MockV3Aggregator.sol";
import {LinkToken} from "../../test/mocks/LinkToken.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address vrfCoordinator;
        address priceFeed;
        address gameWallet;
        bytes32 gasLane;
        uint64 subscriptionId;
        uint32 callbackGasLimit;
        address link;
    }

    NetworkConfig public activeNetworkConfig;
   
    DeployGameWallet deployWallet = new DeployGameWallet();

    GameWallet gameWallet = deployWallet.run();

    uint8 public constant DECIMALS = 8;
    int256 public constant INITIAL_PRICE = 2000e8;



    constructor() {
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

    function getSepoliaEthConfig() public view returns (NetworkConfig memory sepoliaConfig) {
        sepoliaConfig = NetworkConfig({
            vrfCoordinator: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            priceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            gameWallet: address(gameWallet), // Replace with actual deployed GameWallet address
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId:0, // Add your subscription ID here
            callbackGasLimit: 500000,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789
        });
    }
    function getAvalancheFujiConfig() public view returns (NetworkConfig memory fujiConfig) {
        fujiConfig = NetworkConfig({
            vrfCoordinator: 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846,
            priceFeed:0x5498BB86BC934c8D34FDA08E81D444153d0D06aD,
            gameWallet: address(gameWallet), // Replace with actual deployed GameWallet address
            gasLane: 0xc799bd1e3bd4d1a41cd4968997a4e03dfd2a3c7c04b695881138580163f42887,
            subscriptionId:0, // Add your subscription ID here
            callbackGasLimit: 500000,
            link: 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846
        });
    }
    function getAvalancheMainnetConfig() public view returns (NetworkConfig memory avalancheConfig) {
        avalancheConfig = NetworkConfig({
            vrfCoordinator: 0xE40895D055bccd2053dD0638C9695E326152b1A4,
            priceFeed: 0x0A77230d17318075983913bC2145DB16C7366156,
            gameWallet: address(gameWallet), // Replace with actual deployed GameWallet address
            gasLane: 0xe227ebd10a873dde8e58841197a07b410038e405f1180bd117be6f6557fa491c,
            subscriptionId:0, // Add your subscription ID here
            callbackGasLimit: 500000,
            link:0x5947BB275c521040051D82396192181b413227A3
        });
    }
    function getBaseSepoliaConfig() public view returns (NetworkConfig memory baseSepoliaConfig) {
        baseSepoliaConfig = NetworkConfig({
            vrfCoordinator: 0x5C210eF41CD1a72de73bF76eC39637bB0d3d7BEE, 
            priceFeed: 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70, 
            gameWallet: address(gameWallet), // Replace with actual deployed GameWallet address
            gasLane: 0x9e1344a1247c8a1785d0a4681a27152bffdb43666ae5bf7d14d24a5efd44bf71, 
            subscriptionId:0, // Add your subscription ID here
            callbackGasLimit: 500000,
            link: 0xE4aB69C077896252FAFBD49EFD26B5D171A32410
        });
    }
    function getBaseMainnetConfig() public view returns (NetworkConfig memory baseMainnetConfig) {
        baseMainnetConfig = NetworkConfig({
            vrfCoordinator: 0xd5D517aBE5cF79B7e95eC98dB0f0277788aFF634, 
            priceFeed: 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70, 
            gameWallet: address(gameWallet), // Replace with actual deployed GameWallet address
            gasLane: 0xdc2f87677b01473c763cb0aee938ed3341512f6057324a584e5944e786144d70, 
            subscriptionId:0, // Add your subscription ID here
            callbackGasLimit: 500000,
            link: 0x88Fb150BDc53A65fe94Dea0c9BA0a6dAf8C6e196
        });
    }   

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory anvilConfig) {
         if(activeNetworkConfig.vrfCoordinator !=address(0)){
            return activeNetworkConfig;
        }

        uint96 baseFee = 0.25 ether;
        uint96 gasPriceLink = 1e9;

        vm.startBroadcast();
        VRFCoordinatorV2Mock vrfCoordinatorV2Mock = new VRFCoordinatorV2Mock(
            baseFee,
            gasPriceLink
        );
        LinkToken link = new LinkToken();
        
        MockV3Aggregator mockPriceFeed = new MockV3Aggregator(
            DECIMALS,
            INITIAL_PRICE
        );
        vm.stopBroadcast();
       

        anvilConfig = NetworkConfig({
            vrfCoordinator: address(vrfCoordinatorV2Mock),
            priceFeed: address(mockPriceFeed),
            gameWallet: address(gameWallet),
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            subscriptionId: 1, // Mock subscription ID
            callbackGasLimit: 500000,
            link: address(link)
        });
    }
}