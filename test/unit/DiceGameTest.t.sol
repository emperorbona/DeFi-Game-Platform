// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {Test} from "forge-std/Test.sol";
import {DiceGame} from "../../src/dice-game/DiceGame.sol";
import {DeployDiceGame} from "../../script/diceGameDeploy/DeployDiceGame.s.sol";

contract DiceGameTest is Test{

        address vrfCoordinator;
        address priceFeed;
        address gameWallet;
        bytes32 gasLane;
        uint64 subscriptionId;
        uint32 callbackGasLimit;
        address link;

    DiceGame diceGame;
    function setUp() external{
       
        DeployDiceGame deployDiceGame = new DeployDiceGame();
        diceGame = deployDiceGame.run();


    } 
}