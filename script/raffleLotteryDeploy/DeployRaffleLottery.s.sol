// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {RaffleLottery} from "../../src/raffleLottery/RaffleLottery.sol";
import {GameWallet} from "../../src/wallet/GameWallet.sol"; // Add this import
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployRaffleLottery is Script {
    function run() external returns (RaffleLottery, HelperConfig) {
        RaffleLottery raffleLottery;
        HelperConfig helperConfig = new HelperConfig();
        (
            uint256 ticketFee,
            uint256 interval,
            address vrfCoordinator,
            address priceFeed,
            address gameWallet,
            bytes32 gasLane,
            uint64 subscriptionId,
            uint32 callbackGasLimit,
            address adminWallet,
            address link
        ) = helperConfig.activeNetworkConfig();

        if (subscriptionId == 0) {
            // We are going to create a subscription
            CreateSubscription createSubscription = new CreateSubscription();
            subscriptionId = createSubscription.createSubscription(vrfCoordinator);

            // Fund the subscription
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                vrfCoordinator,
                subscriptionId,
                link
            );
        }

        vm.startBroadcast();
        raffleLottery = new RaffleLottery(
            ticketFee,
            interval,
            vrfCoordinator,
            priceFeed,
            gameWallet,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            payable(adminWallet)
        );
        
        // CRITICAL: Grant RaffleLottery the GAME_CONTRACT_ROLE in GameWallet
        GameWallet(gameWallet).addGameContract(address(raffleLottery));
        
        vm.stopBroadcast();

        

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(
            address(raffleLottery),
            vrfCoordinator,
            subscriptionId  
        );

        return (raffleLottery, helperConfig);
    }
}