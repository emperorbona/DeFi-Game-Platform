// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {AdminWallet} from "../../src/admin/AdminWallet.sol"; 
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployAdminWallet is Script{
    function run() external returns(AdminWallet){

    HelperConfig helperConfig = new HelperConfig();
    address ethPriceFeed = helperConfig.activeNetworkConfig();

    AdminWallet adminWallet;

    vm.startBroadcast();
    adminWallet= new AdminWallet(ethPriceFeed);
    adminWallet.grantRole(adminWallet.DEFAULT_ADMIN_ROLE(), msg.sender);
    vm.stopBroadcast();
    return(adminWallet);
    }
}