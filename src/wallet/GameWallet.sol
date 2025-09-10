// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {PriceConverter} from "../libraries/PriceConverter.sol";

contract GameWallet is ReentrancyGuard, AccessControl {
    // Errors
    error GameWallet__InsufficientAmount();
    error GameWallet__InsufficientBalance();
    error GameWallet__AmountTooSmall();
    error GameWallet__UnauthorizedGame();
    error GameWallet__TransferFailed();
    
    // Roles
    bytes32 public constant GAME_CONTRACT_ROLE = keccak256("GAME_CONTRACT_ROLE");
    
    // State variables
    mapping(address => uint256) private s_balances;
    mapping(address => mapping(address => bool)) private s_approvedGames; // User -> Game -> Approved
    
    AggregatorV3Interface private s_priceFeed;
    uint256 private constant MINIMUM_DEPOSIT_USD = 1; // $1 minimum
    
    using PriceConverter for uint256;

    // Events
    event FundsDeposited(address indexed user, uint256 amount);
    event FundsWithdrawn(address indexed user, uint256 amount);
    event FundsTransferredToGame(address indexed user, address indexed game, uint256 amount);
    event FundsReceivedFromGame(address indexed user, address indexed game, uint256 amount);
    event GameApprovalChanged(address indexed user, address indexed game, bool approved);

    constructor(address priceFeed) {
        s_priceFeed = AggregatorV3Interface(priceFeed);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    // Add a game contract to the approved list
    function addGameContract(address gameContract) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(GAME_CONTRACT_ROLE, gameContract);
    }

    // User approves/disapproves a game to use their funds
    function setGameApproval(address gameContract, bool approved) external {
        s_approvedGames[msg.sender][gameContract] = approved;
        emit GameApprovalChanged(msg.sender, gameContract, approved);
    }

    function deposit() external payable nonReentrant {
        if (msg.value.getConversionRate(s_priceFeed) < MINIMUM_DEPOSIT_USD) {
            revert GameWallet__InsufficientAmount();
        }
        s_balances[msg.sender] += msg.value;
        emit FundsDeposited(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) {
            revert GameWallet__AmountTooSmall();
        }
        if (amount > s_balances[msg.sender]) {
            revert GameWallet__InsufficientBalance();
        }
        
        s_balances[msg.sender] -= amount;
        
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            revert GameWallet__TransferFailed();
        }
        
        emit FundsWithdrawn(msg.sender, amount);
    }

    // Called by game contracts to deduct funds
    function deductFunds(address user, uint256 amount) 
        external 
        onlyRole(GAME_CONTRACT_ROLE) 
        returns (bool) 
    {
        if (!s_approvedGames[user][msg.sender]) {
            revert GameWallet__UnauthorizedGame();
        }
        if (amount > s_balances[user]) {
            revert GameWallet__InsufficientBalance();
        }
        
        s_balances[user] -= amount;
        return true;
    }

    // Called by game contracts to add funds (winnings)
    function addWinnings(address user, uint256 amount) 
        external 
        onlyRole(GAME_CONTRACT_ROLE) 
    {
        s_balances[user] += amount;
        emit FundsReceivedFromGame(user, msg.sender, amount);
    }

    // View functions
    function getBalance(address user) external view returns (uint256) {
        return s_balances[user];
    }

    function isGameApproved(address user, address game) external view returns (bool) {
        return s_approvedGames[user][game];
    }

    function getMinimumDeposit() external pure returns (uint256) {
        return MINIMUM_DEPOSIT_USD;
    }
}