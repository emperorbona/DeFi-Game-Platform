// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {GameWallet} from "../../src/wallet/GameWallet.sol"; 
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployGameWallet is Script{
    function run() external returns(GameWallet){

    HelperConfig helperConfig = new HelperConfig();
    address ethPriceFeed = helperConfig.activeNetworkConfig();

    GameWallet gameWallet;

    vm.startBroadcast();
    gameWallet= new GameWallet(ethPriceFeed);
    gameWallet.grantRole(gameWallet.DEFAULT_ADMIN_ROLE(), msg.sender);
    vm.stopBroadcast();
    return(gameWallet);
    }
}
