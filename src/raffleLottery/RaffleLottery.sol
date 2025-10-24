// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import {PriceConverter} from "../libraries/PriceConverter.sol";
import {GameWallet} from "../wallet/GameWallet.sol";
import {AdminWallet} from "../admin/AdminWallet.sol";

contract RaffleLottery is VRFConsumerBaseV2,ReentrancyGuard,Ownable{

    error RaffleLottery__NotEnoughEthSent();
    error RaffleLottery__InsufficientWalletBalance();
    error RaffleLottery__EntryLimitReached();
    error RaffleLottery__Unauthorized();
    error RaffleLottery__NotOpen();
    error RaffleLottery__WalletInteractionFailed();
    error RaffleLottery__UpkeepNotNeeded(
        uint256 currentBalance,
        uint256 numPlayers,
        uint256 raffleState
    );
    error RaffleLottery__WinnerPaymentFail();
    error RaffleLottery__FeeDepositFailed();
    

    enum RaffleState {
        OPEN,
        CALCULATING
    }

    GameWallet private immutable i_gameWallet;
    AdminWallet private immutable i_adminWallet;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    AggregatorV3Interface private s_priceFeed;

    uint16 private constant REQUEST_CONFIRMATION = 2;
    uint32 private constant NUM_WORDS = 1;

    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    uint256 private immutable i_ticketFee;
    uint256 private s_ticketCounter;
    // uint256 private gameTurns;
    uint256 private currentRoundId;
    uint256 private i_interval;
    uint256 private maxTicketPurchaseLimit = 5;
    RaffleState private s_raffleState;
    uint256 private s_lastTimeStamp;
    uint256 private  s_lastRequestTimestamp;
    
    struct TicketInfo{
        address payable playerAddress;
        uint256 ticketId;
    }
    TicketInfo[] private s_rafflePlayers;
    // mapping (uint256 => TicketInfo) s_playersToAmountOfTimesPlayed;
    mapping(uint256 => mapping(address => uint256)) private s_playerEntries;
    using PriceConverter for uint256;

    event EnteredRaffle(address indexed player, uint256 indexed ticketId);
    event RequestedRaffleWinner(uint256 indexed requestId);
    event WinnerPicked(address indexed winner, uint256 indexed winnerTicketId,uint256 indexed totalWin);

    constructor(
        uint256 ticketFee,
        uint256 interval,
        address vrfCoordinator,
        address priceFeed,
        address gameWallet,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        address adminWallet
    )VRFConsumerBaseV2(vrfCoordinator)Ownable(msg.sender){
        i_ticketFee = ticketFee;
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        s_priceFeed = AggregatorV3Interface(priceFeed);
        i_gameWallet = GameWallet(gameWallet);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        i_adminWallet = AdminWallet(payable(adminWallet));
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
        currentRoundId = 1;

    }

        function enterRaffle() external nonReentrant {
        uint256 ticketPrice = i_ticketFee.getEthAmountOutUsd(s_priceFeed);

        if (i_gameWallet.getBalance(msg.sender) < ticketPrice) {
            revert RaffleLottery__InsufficientWalletBalance();
        }

        if (!i_gameWallet.isGameApproved(msg.sender, address(this))) {
            revert RaffleLottery__Unauthorized();
        }

        if (s_raffleState != RaffleState.OPEN) {
            revert RaffleLottery__NotOpen();
        }

        if (s_playerEntries[currentRoundId][msg.sender] >= maxTicketPurchaseLimit) {
            revert RaffleLottery__EntryLimitReached();
        }

        bool success = i_gameWallet.deductFunds(msg.sender, ticketPrice);
        if (!success) revert RaffleLottery__WalletInteractionFailed();

        s_ticketCounter++;
        s_playerEntries[currentRoundId][msg.sender]++;
        s_rafflePlayers.push(TicketInfo(payable(msg.sender), s_ticketCounter));

        emit EnteredRaffle(msg.sender, s_ticketCounter);
    }

            

    

    function checkUpkeep(
        bytes memory /*checkData*/) 
        public view returns(bool upkeepNeeded, bytes memory /*performData*/
    ){
        // Check to see if enough time has passed.
        bool timeHasPassed = block.timestamp >= (i_interval + s_lastTimeStamp);
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool hasBalance = (s_ticketCounter * i_ticketFee) > 0;
        bool hasPlayers = s_rafflePlayers.length > 0;
        upkeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, "0x0");
    }

    function performUpkeep(bytes calldata /*performData*/) external {
        (bool upkeepNeeded,) = checkUpkeep("");
        if(!upkeepNeeded){
            revert RaffleLottery__UpkeepNotNeeded(
                address(this).balance,
                s_rafflePlayers.length,
                uint256(s_raffleState)
            );
        }
         s_lastRequestTimestamp= block.timestamp;
        
        s_raffleState = RaffleState.CALCULATING;
            uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATION,
            i_callbackGasLimit,
            NUM_WORDS
        );

        emit RequestedRaffleWinner(requestId);
        
    }


    function fulfillRandomWords(uint256 /*requestId*/, uint256[] memory randomWords) internal override {
        uint256 indexOfWinner = randomWords[0] % s_rafflePlayers.length;
        address payable raffleWinner = s_rafflePlayers[indexOfWinner].playerAddress;
        uint256 raffleWinnerTicket = s_rafflePlayers[indexOfWinner].ticketId;
        uint256 totalTickets = s_rafflePlayers.length;
        // totalPotUSD = Total tickets * Fixed USD price per ticket
        uint256 totalPotUSD = totalTickets * i_ticketFee; 
        // totalPotETH = Convert total USD pot to ETH at current exchange rate for payout
        uint256 totalPotETH = totalPotUSD.getEthAmountOutUsd(s_priceFeed); 

        // 5% game fee on the total ETH pot
        uint256 gameFee = (totalPotETH * 5) / 100;
        uint256 prizePool = totalPotETH - gameFee;

        // Reset for the next round
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
        currentRoundId ++;
        // Use a cheaper method to reset the dynamic array
        delete s_rafflePlayers;


        s_ticketCounter = 0; // Reset ticket count for the new round

        // Pay winner
        i_gameWallet.addWinnings(raffleWinner, prizePool);
        
        // Forward game fee to admin wallet
        if (gameFee > 0) {
            bool success = i_gameWallet.forwardGameFee(payable(i_adminWallet), gameFee);
            if(!success){
                revert RaffleLottery__FeeDepositFailed();
            }
        }
        
        emit WinnerPicked(raffleWinner, raffleWinnerTicket, prizePool);
    }

        /* ========== Emergency / Admin Functions ========== */
    // Allow the owner to force-reset a stuck raffle if VRF fails for too long
    function forceResetIfStuck() external onlyOwner {
        require(s_raffleState == RaffleState.CALCULATING, "Not in calculating state");
        // require at least 1 hour passed since request to avoid race conditions
        require(block.timestamp > s_lastRequestTimestamp + 1 hours, "VRF not timed out");


        // Re-open raffle but keep players (so they don't lose entries). This allows a new upkeep to be attempted.
        s_raffleState = RaffleState.OPEN;
    }

    function getPlayerEntries(uint256 currentRound, address player) external view returns(uint256){
        return s_playerEntries[currentRound][player];
    }
    function getRafflePlayers(uint256 index) external view returns(TicketInfo memory){
        return s_rafflePlayers[index];
    }
    function getTicketCounter() external view returns(uint256){
        return s_ticketCounter;
    }
    function getLastTimeStamp() external view returns(uint256){
        return s_lastTimeStamp;
    }
    function getRaffleState() external view returns(RaffleState){
        return s_raffleState;
    }
    function getNumWords() external pure returns(uint32){
        return NUM_WORDS;
    }
}