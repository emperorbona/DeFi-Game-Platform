// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {PriceConverter} from "../libraries/PriceConverter.sol";

contract AdminWallet is Ownable, ReentrancyGuard,AccessControl {
    using PriceConverter for uint256;

    // Errors
    error AdminWallet__InsufficientAmount();
    error AdminWallet__TransferFailed();
    error AdminWallet__InsufficientBalance();
    error AdminWallet__GameFeeInsufficient();

    bytes32 public constant GAME_ROLE = keccak256("GAME_ROLE");

    AggregatorV3Interface private s_priceFeed;
    uint256 private constant MINIMUM_USD = 1e18; // $1 minimum
    mapping(address => uint256) public gameFees;

    event FundsWithdrawn(address indexed admin, uint256 amount);
    event PriceFeedUpdated(address indexed newPriceFeed);
    event FeeDeposited(address indexed game, uint256 amount);

    constructor(address priceFeed) Ownable(msg.sender) {
        s_priceFeed = AggregatorV3Interface(priceFeed);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
      /**
     * @notice Grant a game contract permission to deposit.
     * @dev Only admin can grant.
     */
    function authorizeGame(address game) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(GAME_ROLE, game);
    }

    /**
     * @notice Revoke a game contract’s permission.
     */
    function revokeGame(address game) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(GAME_ROLE, game);
    }

    function depositFee() external payable onlyRole(GAME_ROLE) {
        // Accept deposits
        if (msg.value == 0) {
            revert AdminWallet__InsufficientAmount();
        }
        if (msg.value.getConversionRate(s_priceFeed) < MINIMUM_USD) {
            revert AdminWallet__InsufficientAmount();
        }
        gameFees[msg.sender] += msg.value;
        emit FeeDeposited(msg.sender, msg.value);
    }


    // Function to receive Ether. msg.data must be empty
    // receive() external payable {}

    // // Fallback function is called when msg.data is not empty
    // fallback() external payable {}

    function withdraw(uint256 amount) external onlyOwner {
        if (amount == 0) {
            revert AdminWallet__InsufficientAmount();
        }
        if (amount.getConversionRate(s_priceFeed) < MINIMUM_USD) {
            revert AdminWallet__InsufficientAmount();
        }
        if (address(this).balance < amount) {
            revert AdminWallet__InsufficientBalance();
        }
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            revert AdminWallet__TransferFailed();
        }

        emit FundsWithdrawn(msg.sender, amount);
    }

    function updatePriceFeed(address newPriceFeed) external onlyOwner {
        s_priceFeed = AggregatorV3Interface(newPriceFeed);
        emit PriceFeedUpdated(newPriceFeed);
    }

   

    receive() external payable {
        // Fallback to accept ETH if sent directly (not counted as game fee).
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getPriceFeed() external view returns (address) {
        return address(s_priceFeed);
    }
}