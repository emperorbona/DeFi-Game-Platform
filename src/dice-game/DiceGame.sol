// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import {PriceConverter} from "../libraries/PriceConverter.sol";
import {GameWallet} from "../wallet/GameWallet.sol";

contract DiceGame is ReentrancyGuard, VRFConsumerBaseV2 {
    // Errors
    error DiceGame__InsufficientAmountForStake();
    error DiceGame__InvalidGame();
    error DiceGame__AlreadyJoined();
    error DiceGame__StakeMismatch();
    error DiceGame__Unauthorized();
    error DiceGame__NotYourTurnYet();
    error DiceGame__NotAParticipant();
    error DiceGame__WalletInteractionFailed();
    error DiceGame__InsufficientWalletBalance();
    error DiceGame__RequestAlreadyPending();

    using PriceConverter for uint256;

    // Chainlink VRF
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    AggregatorV3Interface private s_priceFeed;
    GameWallet private immutable i_gameWallet;

    uint16 private constant REQUEST_CONFIRMATION = 2;
    uint32 private constant NUM_WORDS = 1;

    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    // Game Management
    uint256 private constant MINIMUM_STAKE_USD = 1; // $1 minimum stake
    uint256 private gameCounter;

    // Game Structure
    struct GAMEPLAY {
        address player1;
        address player2;
        uint8 dice1;
        uint8 dice2;
        address nextTurn;
        uint256 stake;
        address winner;
        bool fundsLocked;
    }

    // Storage
    mapping(uint256 => GAMEPLAY) private s_gameInPlay;
    mapping(uint256 => address) private s_reqToPlayer;
    mapping(uint256 => uint256) private s_reqToGame;
    mapping(uint256 => bool) private s_gameHasPendingRequest; // gameId => pending

    // Events
    event GameCreated(uint256 indexed gameId, address indexed creator, uint256 stake);
    event GameJoined(uint256 indexed gameId, address indexed joiner);
    event RollRequested(uint256 indexed gameId, address indexed roller, uint256 requestId);
    event DiceRolled(uint256 indexed gameId, address player, uint8 roll);
    event GameResolved(uint256 indexed gameId, address winner, uint8 dice1, uint8 dice2);
    event FundsLocked(uint256 indexed gameId, uint256 totalStake);

    constructor(
        address vrfCoordinator,
        address priceFeed,
        address gameWallet,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        s_priceFeed = AggregatorV3Interface(priceFeed);
        i_gameWallet = GameWallet(gameWallet);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
    }

    // Helper view to check approval
    // function _isApprovedForUser(address user) internal view returns (bool) {
    //     return GameWallet(address(i_gameWallet)).isGameApproved(user, address(this));
    // }

    function createGame(uint256 stakeAmount) external nonReentrant returns(uint256 gameId) {
        if (stakeAmount.getConversionRate(s_priceFeed) < MINIMUM_STAKE_USD) {
            revert DiceGame__InsufficientAmountForStake();
        }

        // Check wallet balance and lock funds
        if (i_gameWallet.getBalance(msg.sender) < stakeAmount) {
            revert DiceGame__InsufficientWalletBalance();
        }
        if (!GameWallet(address(i_gameWallet)).isGameApproved(msg.sender, address(this))) {
            revert DiceGame__Unauthorized(); // create a new error to indicate approval missing
        }
        
        bool success = i_gameWallet.deductFunds(msg.sender, stakeAmount);
        if (!success) {
            revert DiceGame__WalletInteractionFailed();
        }

        gameId = gameCounter++;
        s_gameInPlay[gameId] = GAMEPLAY({
            player1: msg.sender,
            player2: address(0),
            dice1: 0,
            dice2: 0,
            nextTurn: address(0),
            stake: stakeAmount,
            winner: address(0),
            fundsLocked: true
        });

        emit GameCreated(gameId, msg.sender, stakeAmount);
        emit FundsLocked(gameId, stakeAmount);
    }

    function joinGame(uint256 gameId, uint256 stakeAmount) external nonReentrant {
        GAMEPLAY storage game = s_gameInPlay[gameId];

        if (game.player1 == address(0)) revert DiceGame__InvalidGame();
        if (game.player2 != address(0)) revert DiceGame__AlreadyJoined();
        if (stakeAmount != game.stake) revert DiceGame__StakeMismatch();

        // Check wallet balance and lock funds
        if (i_gameWallet.getBalance(msg.sender) < stakeAmount) {
            revert DiceGame__InsufficientWalletBalance();
        }
        if (!GameWallet(address(i_gameWallet)).isGameApproved(msg.sender, address(this))) {
            revert DiceGame__Unauthorized(); // create a new error to indicate approval missing
        }
        
        bool success = i_gameWallet.deductFunds(msg.sender, stakeAmount);
        if (!success) {
            revert DiceGame__WalletInteractionFailed();
        }

        game.player2 = msg.sender;
        game.nextTurn = game.player1;
        game.fundsLocked = true;

        emit GameJoined(gameId, msg.sender);
        emit FundsLocked(gameId, game.stake * 2);
    }

    function rollDice(uint256 gameId) external {
        GAMEPLAY storage game = s_gameInPlay[gameId];

        if (msg.sender != game.nextTurn) revert DiceGame__NotYourTurnYet();
        if (msg.sender != game.player1 && msg.sender != game.player2) {
            revert DiceGame__NotAParticipant();
        }
        if (!game.fundsLocked) revert DiceGame__InvalidGame(); // or GameNotActive
        if (s_gameHasPendingRequest[gameId]) {
            revert DiceGame__RequestAlreadyPending();
        }

        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATION,
            i_callbackGasLimit,
            NUM_WORDS
        );


        s_reqToPlayer[requestId] = msg.sender;
        s_reqToGame[requestId] = gameId;

        emit RollRequested(gameId, msg.sender, requestId);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        uint256 gameId = s_reqToGame[requestId];
        GAMEPLAY storage game = s_gameInPlay[gameId];
        address player = s_reqToPlayer[requestId];

        uint8 roll = uint8((randomWords[0] % 6) + 1);

        if (player == game.player1) {
            game.dice1 = roll;
            game.nextTurn = game.player2;
        } else {
            game.dice2 = roll;
            game.nextTurn = address(0);
        }

        emit DiceRolled(gameId, player, roll);

        if (game.dice1 != 0 && game.dice2 != 0) {
            _resolveGame(gameId);
        }
    }

    function _resolveGame(uint256 gameId) internal {
        GAMEPLAY storage game = s_gameInPlay[gameId];
        uint256 totalPot = game.stake * 2;

        if (game.dice1 > game.dice2) {
            game.winner = game.player1;
            i_gameWallet.addWinnings(game.player1, totalPot);
        } else if (game.dice1 < game.dice2) {
            game.winner = game.player2;
            i_gameWallet.addWinnings(game.player2, totalPot);
        } else {
            // Tie - refund both players
            i_gameWallet.addWinnings(game.player1, game.stake);
            i_gameWallet.addWinnings(game.player2, game.stake);
            game.winner = address(0);
        }

        game.fundsLocked = false;
        emit GameResolved(gameId, game.winner, game.dice1, game.dice2);
    }

    // Emergency refund function (admin only in case of issues)
    function emergencyRefund(uint256 gameId) external {
        // Implementation for admin to refund locked funds
    }

    // View functions
    function getGameCounter() external view returns(uint256) {
        return gameCounter;
    }

    function getGameInPlay(uint256 gameId) external view returns(GAMEPLAY memory) {
        return s_gameInPlay[gameId];
    }

    function getMinimumStake() external pure returns(uint256) {
        return MINIMUM_STAKE_USD;
    }

    function getGameWallet() external view returns(address) {
        return address(i_gameWallet);
    }
}