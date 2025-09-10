// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../../test/mocks/LinkToken.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script{

    function createNewSubscriptionUsingConfig() public returns(uint64){
        HelperConfig helperConfig = new HelperConfig();
        (address vrfCoordinator,,,,,,) = helperConfig.activeNetworkConfig();
        return createSubscription(vrfCoordinator);
    }
    function createSubscription(address vrfCoordinator) public returns(uint64){
        vm.startBroadcast();
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        return subId;
    }


    function run() external returns(uint64){
        return createNewSubscriptionUsingConfig();
    }

    

    function fundSubscription(uint64 subscriptionId) internal {
        // Fund the subscription with LINK tokens
        // The amount of LINK tokens to fund the subscription with
    }
}

contract FundSubscription is Script{
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
         HelperConfig helperConfig = new HelperConfig();
        (address vrfCoordinator,,,,uint64 subId,,address link) = helperConfig.activeNetworkConfig();
        fundSubscription(vrfCoordinator, subId, link);
    }

    function fundSubscription(
        address vrfCoordinator,
        uint64 subId,
        address link
    ) public {
        if(block.chainid == 31337){ 
        vm.startBroadcast();
        VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(
            subId,
            FUND_AMOUNT
        );
        
        vm.stopBroadcast();
        }
        else{
            vm.startBroadcast();
            LinkToken(link).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subId)
            );
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script{

    function addConsumer(address diceGame,address vrfCoordinator,uint64 subId) public{
        vm.startBroadcast();
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subId,diceGame);
        vm.stopBroadcast();
    }

    function addConsumerUsingConfig(address diceGame) public{
        HelperConfig helperConfig = new HelperConfig();
        (address vrfCoordinator,,,,uint64 subId,,) = helperConfig.activeNetworkConfig();
        addConsumer(diceGame,vrfCoordinator,subId);
    }
    function run() external{
        address diceGame = DevOpsTools.get_most_recent_deployment("DiceGame", block.chainid);
        addConsumerUsingConfig(diceGame);
    }
}