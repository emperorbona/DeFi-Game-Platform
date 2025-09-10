// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {DiceGame} from "../../src/dice-game/DiceGame.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";


contract DeployDiceGame is Script {
    function run() external returns (DiceGame){
        DiceGame diceGame;
        HelperConfig helperConfig = new HelperConfig();
        (
        address vrfCoordinator,
        address priceFeed,
        address gameWallet,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        address link) = helperConfig.activeNetworkConfig();

        if(subscriptionId == 0){
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
        diceGame = new DiceGame(
         vrfCoordinator,
         priceFeed,
         gameWallet,
         gasLane,
         subscriptionId,
         callbackGasLimit
        );
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(
          address(diceGame),
          vrfCoordinator,
          subscriptionId  
        );

        return diceGame;
    }
    
}