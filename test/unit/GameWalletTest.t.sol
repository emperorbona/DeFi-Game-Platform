// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {Test} from "forge-std/Test.sol";
import {GameWallet} from "../../src/wallet/GameWallet.sol";
import {DeployGameWallet} from "../../script/gameWalletDeploy/DeployGameWallet.s.sol";

contract GameWalletTest is Test{
    
    GameWallet gameWallet;
    address USER = makeAddr("user");
    address SECONDUSER = makeAddr("secondUser");
    address ADMIN = makeAddr("admin");
    address GAME = makeAddr("game");
    address GAME2 = makeAddr("game2");
    address NON_GAME = makeAddr("nonGame");
    address NONADMIN = makeAddr("nonadmin");
    uint256 public constant SEND_VALUE = 0.1 ether;
    uint256 STARTING_BALANCE = 10 ether;
    uint256 DEDUCTION_AMOUNT = 0.05 ether;


    event FundsDeposited(address indexed user, uint256 amount);
    event FundsWithdrawn(address indexed user, uint256 amount);
    event FundsTransferredToGame(address indexed user, address indexed game, uint256 amount);
    event FundsReceivedFromGame(address indexed user, address indexed game, uint256 amount);
    event GameApprovalChanged(address indexed user, address indexed game, bool approved);
    


    function setUp() external{
        DeployGameWallet deployGameWallet = new DeployGameWallet();
        gameWallet = deployGameWallet.run(); 
        vm.deal(USER,STARTING_BALANCE);
        vm.deal(SECONDUSER,STARTING_BALANCE);
        gameWallet.grantRole(gameWallet.DEFAULT_ADMIN_ROLE(), ADMIN);
    }
    function testMinimumDepositIsADollar() public view{
        assertEq(gameWallet.getMinimumDeposit(), 1e18);
    }
    function testAddGameContractAsAdmin() public{
        vm.prank(ADMIN);
        gameWallet.addGameContract(GAME);

        bytes32 GAME_CONTRACT_ROLE = keccak256("GAME_CONTRACT_ROLE");
        bool hasRole = gameWallet.hasRole(GAME_CONTRACT_ROLE, GAME);
        assertTrue(hasRole, "Game contract should have GAME_CONTRACT_ROLE");
    }
      function testAddGameContractAsNonAdminReverts() public {
        // Try as non-admin
        vm.prank(NONADMIN);
        vm.expectRevert(); // should revert due to missing DEFAULT_ADMIN_ROLE
        gameWallet.addGameContract(GAME);
    }
    function testSetGameApprovalToTrue() public {
        vm.prank(USER);
        gameWallet.setGameApproval(GAME, true);

        bool isApproved = gameWallet.isGameApproved(USER, GAME);
        assertTrue(isApproved, "Game should be approved for user");
    }
     function testSetGameApprovalToFalse() public {
        // First approve, then disapprove
        vm.prank(USER);
        gameWallet.setGameApproval(GAME, true);
        
        vm.prank(USER);
        gameWallet.setGameApproval(GAME, false);

        bool isApproved = gameWallet.isGameApproved(USER, GAME);
        assertFalse(isApproved, "Game should not be approved for user");
    }
    function testGameApprovalIsUserSpecific() public {
        // User1 approves game
        vm.prank(USER);
        gameWallet.setGameApproval(GAME, true);

        // User2 does not approve game
        vm.prank(SECONDUSER);
        gameWallet.setGameApproval(GAME, false);

        // Check that approvals are separate
        bool user1Approval = gameWallet.isGameApproved(USER, GAME);
        bool user2Approval = gameWallet.isGameApproved(SECONDUSER, GAME);

        assertTrue(user1Approval, "Game should be approved for USER");
        assertFalse(user2Approval, "Game should not be approved for SECONDUSER");
    }
    function testDifferentGamesDifferentApprovals() public {
        vm.prank(USER);
        gameWallet.setGameApproval(GAME, true);

        vm.prank(USER);
        gameWallet.setGameApproval(GAME2, false);

        bool game1Approval = gameWallet.isGameApproved(USER, GAME);
        bool game2Approval = gameWallet.isGameApproved(USER, GAME2);

        assertTrue(game1Approval, "GAME should be approved");
        assertFalse(game2Approval, "GAME2 should not be approved");
    }
     function testGameApprovalDefaultsToFalse() public view {
        bool isApproved = gameWallet.isGameApproved(USER, GAME);
        assertFalse(isApproved, "Game approval should default to false");
    }
    function testMsgSenderIsUsedForApproval() public {
        // USER calls the function but tries to set approval for SECONDUSER
        // This should set approval for USER, not SECONDUSER
        vm.prank(USER);
        gameWallet.setGameApproval(GAME, true);

        // Check that USER has approval, not SECONDUSER
        bool userApproval = gameWallet.isGameApproved(USER, GAME);
        bool secondUserApproval = gameWallet.isGameApproved(SECONDUSER, GAME);

        assertTrue(userApproval, "USER should have approval");
        assertFalse(secondUserApproval, "SECONDUSER should not have approval");
    }
        function testSetGameApprovalEmitsEvent() public {
        vm.expectEmit(true, true, true, true);
        emit GameWallet.GameApprovalChanged(USER, GAME, true);
        
        vm.prank(USER);
        gameWallet.setGameApproval(GAME, true);
    }
     function testMultipleApprovalsSameUser() public {
        vm.startPrank(USER);
        gameWallet.setGameApproval(GAME, true);
        gameWallet.setGameApproval(GAME2, true);
        vm.stopPrank();

        bool game1Approval = gameWallet.isGameApproved(USER, GAME);
        bool game2Approval = gameWallet.isGameApproved(USER, GAME2);

        assertTrue(game1Approval, "GAME should be approved");
        assertTrue(game2Approval, "GAME2 should be approved");
    }
    function testToggleGameApprovalMultipleTimes() public {
        vm.startPrank(USER);
        gameWallet.setGameApproval(GAME, true);
        gameWallet.setGameApproval(GAME, false);
        gameWallet.setGameApproval(GAME, true);
        gameWallet.setGameApproval(GAME, false);
        vm.stopPrank();

        bool isApproved = gameWallet.isGameApproved(USER, GAME);
        assertFalse(isApproved, "Game should not be approved after multiple toggles");
    }

    function testDepositFailsWithoutEnoughBalance() public {
        vm.expectRevert();
        gameWallet.deposit();
    }

    function testDepositUpdatesDataStructure() public{
        vm.prank(USER);
        gameWallet.deposit{value:SEND_VALUE}();
        uint256 amountDeposited = gameWallet.getBalance(USER);
        assertEq(amountDeposited, SEND_VALUE);
    }
    function testOnlyDepositorCanWithdraw() public{
        vm.prank(USER);
        vm.expectRevert();
        gameWallet.withdraw(1e18);
    }

    function testCanOnlyWithdrawMoreThanZero() public{
        vm.prank(USER);
        gameWallet.deposit{value:SEND_VALUE}();
        vm.expectRevert();
        gameWallet.withdraw(0);
    }
    function testCannotWithdrawAmountGreaterThanBalance() public{
        vm.prank(USER);
        gameWallet.deposit{value:SEND_VALUE}();
        vm.expectRevert();
        gameWallet.withdraw(0.3 ether);
    }

    function testWithdrawAsASinglePlayer() public {
        vm.prank(USER);
        gameWallet.deposit{value:SEND_VALUE}();

        uint256 startingUserBalance = USER.balance;
        uint256 startingPlayerWalletBalance = gameWallet.getBalance(USER);

        vm.prank(USER);
        gameWallet.withdraw(SEND_VALUE);

        uint256 endingUserBalance = USER.balance;
        uint256 endingPlayerWalletBalance = gameWallet.getBalance(USER);

        assertEq(endingUserBalance, startingPlayerWalletBalance + startingUserBalance);
        assertEq(endingPlayerWalletBalance, 0);
    }

    function testNonUserCannotWithdraw() public {
        vm.prank(USER);
        gameWallet.deposit{value:SEND_VALUE}();
        vm.expectRevert();
        vm.prank(SECONDUSER);
        gameWallet.withdraw(0.1 ether);
    }

    function testWithdrawEmitsEvent() public {
        vm.prank(USER);
        gameWallet.deposit{value: SEND_VALUE}();

        vm.expectEmit(true, true, true, true);
        emit GameWallet.FundsWithdrawn(USER, SEND_VALUE);

        vm.prank(USER);
        gameWallet.withdraw(SEND_VALUE);
    }

    function testGameCannotDeductFundsIfBalanceIsNotEnough() public{
        vm.prank(USER);
        vm.expectRevert();
        gameWallet.deductFunds(USER, 0.1 ether);
    }
    function testGameCannotDeductFundsIfGameIsNotApproved() public{
        vm.prank(USER);
        gameWallet.deposit{value:SEND_VALUE}();
        vm.expectRevert();
        gameWallet.deductFunds(USER, 0.1 ether);
    }
      function testDeductFundsSuccessfully() public {
        // Setup within test
        vm.prank(ADMIN);
        gameWallet.addGameContract(GAME);
        
        vm.prank(USER);
        gameWallet.deposit{value: SEND_VALUE}();
        
        vm.prank(USER);
        gameWallet.setGameApproval(GAME, true);
        
        uint256 initialBalance = gameWallet.getBalance(USER);
        
        vm.prank(GAME);
        bool success = gameWallet.deductFunds(USER, DEDUCTION_AMOUNT);
        
        uint256 finalBalance = gameWallet.getBalance(USER);
        
        assertTrue(success, "Deduction should be successful");
        assertEq(finalBalance, initialBalance - DEDUCTION_AMOUNT, "Balance should be reduced by deduction amount");
    }
    function testWithdrawFromMultipleUsers() public {
        // First user
        vm.prank(USER);
        gameWallet.deposit{value: SEND_VALUE}();
        
        // Second user
        vm.prank(SECONDUSER);
        gameWallet.deposit{value: SEND_VALUE}();

        uint256 user1StartBalance = USER.balance;
        uint256 user2StartBalance = SECONDUSER.balance;
        uint256 user1WalletBalance = gameWallet.getBalance(USER);
        uint256 user2WalletBalance = gameWallet.getBalance(SECONDUSER);

        // Both users withdraw
        vm.prank(USER);
        gameWallet.withdraw(user1WalletBalance);
        
        vm.prank(SECONDUSER);
        gameWallet.withdraw(user2WalletBalance);

        // Verify both withdrawals worked correctly
        assertEq(USER.balance, user1StartBalance + user1WalletBalance);
        assertEq(SECONDUSER.balance, user2StartBalance + user2WalletBalance);
        assertEq(gameWallet.getBalance(USER), 0);
        assertEq(gameWallet.getBalance(SECONDUSER), 0);
    }

    // Test deduction without game approval should revert
    function testDeductFundsWithoutApprovalReverts() public {
        // Setup within test
        vm.prank(ADMIN);
        gameWallet.addGameContract(GAME);
        
        vm.prank(USER);
        gameWallet.deposit{value: SEND_VALUE}();
        
        // User does NOT approve the game contract
        
        vm.prank(GAME);
        vm.expectRevert(GameWallet.GameWallet__UnauthorizedGame.selector);
        gameWallet.deductFunds(USER, DEDUCTION_AMOUNT);
    }

    // Test deduction by non-game contract should revert
    function testDeductFundsByNonGameContractReverts() public {
        // Setup within test
        vm.prank(ADMIN);
        gameWallet.addGameContract(GAME);
        
        vm.prank(USER);
        gameWallet.deposit{value: SEND_VALUE}();
        
        vm.prank(USER);
        gameWallet.setGameApproval(GAME, true);
        
        bytes32 GAME_CONTRACT_ROLE = keccak256("GAME_CONTRACT_ROLE");
        vm.prank(NON_GAME);
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("AccessControlUnauthorizedAccount(address,bytes32)")),
                NON_GAME,
                GAME_CONTRACT_ROLE
            )
        );
        gameWallet.deductFunds(USER, DEDUCTION_AMOUNT);
    }

    // Test deduction with insufficient balance should revert
    function testDeductFundsInsufficientBalanceReverts() public {
        // Setup within test
        vm.prank(ADMIN);
        gameWallet.addGameContract(GAME);
        
        vm.prank(USER);
        gameWallet.deposit{value: SEND_VALUE}();
        
        vm.prank(USER);
        gameWallet.setGameApproval(GAME, true);
        
        uint256 largeAmount = gameWallet.getBalance(USER) + 1 ether;
        
        vm.prank(GAME);
        vm.expectRevert(GameWallet.GameWallet__InsufficientBalance.selector);
        gameWallet.deductFunds(USER, largeAmount);
    }

    // Test deduction of zero amount should work
    function testCannotDeductFundsZeroAmount() public {
        // Setup within test
        vm.prank(ADMIN);
        gameWallet.addGameContract(GAME);
        
        vm.prank(USER);
        gameWallet.deposit{value: SEND_VALUE}();
        
        vm.prank(USER);
        gameWallet.setGameApproval(GAME, true);
        vm.expectRevert();
        gameWallet.deductFunds(USER, 0);
        
    }

    // Test deduction for different users by same game
    function testDeductFundsForDifferentUsers() public {
        // Setup within test
        vm.prank(ADMIN);
        gameWallet.addGameContract(GAME);
        
        vm.prank(USER);
        gameWallet.deposit{value: SEND_VALUE}();
        
        vm.prank(SECONDUSER);
        gameWallet.deposit{value: SEND_VALUE}();
        
        vm.prank(USER);
        gameWallet.setGameApproval(GAME, true);
        
        vm.prank(SECONDUSER);
        gameWallet.setGameApproval(GAME, true);
        
        uint256 user1Initial = gameWallet.getBalance(USER);
        uint256 user2Initial = gameWallet.getBalance(SECONDUSER);
        
        vm.prank(GAME);
        gameWallet.deductFunds(USER, DEDUCTION_AMOUNT);
        
        vm.prank(GAME);
        gameWallet.deductFunds(SECONDUSER, DEDUCTION_AMOUNT);
        
        uint256 user1Final = gameWallet.getBalance(USER);
        uint256 user2Final = gameWallet.getBalance(SECONDUSER);
        
        assertEq(user1Final, user1Initial - DEDUCTION_AMOUNT, "User1 balance should be reduced");
        assertEq(user2Final, user2Initial - DEDUCTION_AMOUNT, "User2 balance should be reduced");
    }

    // Test deduction by different game contracts
    function testDeductFundsByDifferentGameContracts() public {
        // Setup within test
        vm.prank(ADMIN);
        gameWallet.addGameContract(GAME);
        
        vm.prank(ADMIN);
        gameWallet.addGameContract(GAME2);
        
        vm.prank(USER);
        gameWallet.deposit{value: SEND_VALUE}();
        
        vm.prank(USER);
        gameWallet.setGameApproval(GAME2, true);
        
        uint256 initialBalance = gameWallet.getBalance(USER);
        
        vm.prank(GAME2);
        bool success = gameWallet.deductFunds(USER, DEDUCTION_AMOUNT);
        
        uint256 finalBalance = gameWallet.getBalance(USER);
        
        assertTrue(success, "Deduction by GAME2 should be successful");
        assertEq(finalBalance, initialBalance - DEDUCTION_AMOUNT, "Balance should be reduced");
    }

    // Test multiple deductions
    function testMultipleDeductions() public {
        // Setup within test
        vm.prank(ADMIN);
        gameWallet.addGameContract(GAME);
        
        vm.prank(USER);
        gameWallet.deposit{value: SEND_VALUE}();
        
        vm.prank(USER);
        gameWallet.setGameApproval(GAME, true);
        
        uint256 initialBalance = gameWallet.getBalance(USER);
        uint256 smallAmount = DEDUCTION_AMOUNT / 2;
        
        vm.startPrank(GAME);
        gameWallet.deductFunds(USER, smallAmount);
        gameWallet.deductFunds(USER, smallAmount);
        vm.stopPrank();
        
        uint256 finalBalance = gameWallet.getBalance(USER);
        
        assertEq(finalBalance, initialBalance - (smallAmount * 2), "Balance should be reduced by total deductions");
    }

    // Test deduction after approval change
    function testDeductFundsAfterApprovalChange() public {
        // Setup within test
        vm.prank(ADMIN);
        gameWallet.addGameContract(GAME);
        
        vm.prank(USER);
        gameWallet.deposit{value: SEND_VALUE}();
        
        vm.prank(USER);
        gameWallet.setGameApproval(GAME, true);
        
        // First deduction should work
        vm.prank(GAME);
        gameWallet.deductFunds(USER, DEDUCTION_AMOUNT);
        
        // User revokes approval
        vm.prank(USER);
        gameWallet.setGameApproval(GAME, false);
        
        // Second deduction should fail
        vm.prank(GAME);
        vm.expectRevert(GameWallet.GameWallet__UnauthorizedGame.selector);
        gameWallet.deductFunds(USER, DEDUCTION_AMOUNT);
        
        // User re-approves
        vm.prank(USER);
        gameWallet.setGameApproval(GAME, true);
        
        // Third deduction should work again
        vm.prank(GAME);
        bool success = gameWallet.deductFunds(USER, DEDUCTION_AMOUNT);
        
        assertTrue(success, "Deduction should work after re-approval");
    }

    // Test return value is true on success
    function testDeductFundsReturnsTrue() public {
        // Setup within test
        vm.prank(ADMIN);
        gameWallet.addGameContract(GAME);
        
        vm.prank(USER);
        gameWallet.deposit{value: SEND_VALUE}();
        
        vm.prank(USER);
        gameWallet.setGameApproval(GAME, true);
        
        vm.prank(GAME);
        bool success = gameWallet.deductFunds(USER, DEDUCTION_AMOUNT);
        
        assertTrue(success, "Function should return true on success");
    }

    // Test adding winnings successfully
    function testAddWinningsSuccessfully() public {
        // Setup within test
        vm.prank(ADMIN);
        gameWallet.addGameContract(GAME);
        
        vm.prank(USER);
        gameWallet.deposit{value: SEND_VALUE}();
        
        uint256 initialBalance = gameWallet.getBalance(USER);
        uint256 winningsAmount = 0.02 ether;
        
        vm.prank(GAME);
        gameWallet.addWinnings(USER, winningsAmount);
        
        uint256 finalBalance = gameWallet.getBalance(USER);
        
        assertEq(finalBalance, initialBalance + winningsAmount, "Balance should be increased by winnings amount");
    }

    // Test adding winnings by non-game contract should revert
    function testAddWinningsByNonGameContractReverts() public {
        // Setup within test
        vm.prank(ADMIN);
        gameWallet.addGameContract(GAME);
        
        bytes32 GAME_CONTRACT_ROLE = keccak256("GAME_CONTRACT_ROLE");
        uint256 winningsAmount = 0.02 ether;
        
        vm.prank(NON_GAME);
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("AccessControlUnauthorizedAccount(address,bytes32)")),
                NON_GAME,
                GAME_CONTRACT_ROLE
            )
        );
        gameWallet.addWinnings(USER, winningsAmount);
    }

    // Test adding zero winnings should work
    function testCannotAddWinningsZeroAmount() public {
        // Setup within test
        vm.prank(ADMIN);
        gameWallet.addGameContract(GAME);
        
        vm.prank(USER);
        gameWallet.deposit{value: SEND_VALUE}();
        
        
        vm.prank(GAME);
        vm.expectRevert();
        gameWallet.addWinnings(USER, 0);
    }

    // // Test adding winnings to different users
    // function testAddWinningsToDifferentUsers() public {
    //     // Setup within test
    //     vm.prank(ADMIN);
    //     gameWallet.addGameContract(GAME);
        
    //     vm.prank(USER);
    //     gameWallet.deposit{value: SEND_VALUE}();
        
    //     vm.prank(SECONDUSER);
    //     gameWallet.deposit{value: SEND_VALUE}();
        
    //     uint256 user1Initial = gameWallet.getBalance(USER);
    //     uint256 user2Initial = gameWallet.getBalance(SECONDUSER);
    //     uint256 winningsAmount = 0.02 ether;
        
    //     vm.prank(GAME);
    //     gameWallet.addWinnings(USER, winningsAmount);
        
    //     vm.prank(GAME);
    //     gameWallet.addWinnings(SECONDUSER, winningsAmount);
        
    //     uint256 user1Final = gameWallet.getBalance(USER);
    //     uint256 user2Final = gameWallet.getBalance(SECONDUSER);
        
    //     assertEq(user1Final, user1Initial + winningsAmount, "User1 balance should be increased");
    //     assertEq(user2Final, user2Initial + winningsAmount, "User2 balance should be increased");
    // }

    // Test adding winnings from different game contracts
    // function testAddWinningsFromDifferentGameContracts() public {
    //     // Setup within test
    //     vm.prank(ADMIN);
    //     gameWallet.addGameContract(GAME);
        
    //     vm.prank(ADMIN);
    //     gameWallet.addGameContract(GAME2);
        
    //     vm.prank(USER);
    //     gameWallet.deposit{value: SEND_VALUE}();
        
    //     uint256 initialBalance = gameWallet.getBalance(USER);
    //     uint256 winningsAmount = 0.02 ether;
        
    //     vm.prank(GAME);
    //     gameWallet.addWinnings(USER, winningsAmount);
        
    //     vm.prank(GAME2);
    //     gameWallet.addWinnings(USER, winningsAmount);
        
    //     uint256 finalBalance = gameWallet.getBalance(USER);
        
    //     assertEq(finalBalance, initialBalance + (winningsAmount * 2), "Balance should be increased by total winnings from both games");
    // }

    // Test adding multiple winnings from same game
    // function testAddMultipleWinnings() public {
    //     // Setup within test
    //     vm.prank(ADMIN);
    //     gameWallet.addGameContract(GAME);
        
    //     vm.prank(USER);
    //     gameWallet.deposit{value: SEND_VALUE}();
        
    //     uint256 initialBalance = gameWallet.getBalance(USER);
    //     uint256 smallWinnings = 0.01 ether;
        
    //     vm.startPrank(GAME);
    //     gameWallet.addWinnings(USER, smallWinnings);
    //     gameWallet.addWinnings(USER, smallWinnings);
    //     vm.stopPrank();
        
    //     uint256 finalBalance = gameWallet.getBalance(USER);
        
    //     assertEq(finalBalance, initialBalance + (smallWinnings * 2), "Balance should be increased by total winnings");
    // }

    // Test event emission for addWinnings
    function testAddWinningsEmitsEvent() public {
        // Setup within test
        vm.prank(ADMIN);
        gameWallet.addGameContract(GAME);
        
        vm.prank(USER);
        gameWallet.deposit{value: SEND_VALUE}();
        
        uint256 winningsAmount = 0.02 ether;
        
        vm.expectEmit(true, true, true, true);
        emit GameWallet.FundsReceivedFromGame(USER, GAME, winningsAmount);
        
        vm.prank(GAME);
        gameWallet.addWinnings(USER, winningsAmount);
    }

    // Test adding winnings to user with zero balance
    // function testAddWinningsToUserWithZeroBalance() public {
    //     // Setup within test
    //     vm.prank(ADMIN);
    //     gameWallet.addGameContract(GAME);
        
    //     // USER has not deposited any funds (zero balance)
    //     uint256 initialBalance = gameWallet.getBalance(USER);
    //     uint256 winningsAmount = 0.02 ether;
        
    //     assertEq(initialBalance, 0, "User should start with zero balance");
        
    //     vm.prank(GAME);
    //     gameWallet.addWinnings(USER, winningsAmount);
        
    //     uint256 finalBalance = gameWallet.getBalance(USER);
        
    //     assertEq(finalBalance, winningsAmount, "Balance should equal the winnings amount");
    // }

    // Test adding large winnings
    // function testAddLargeWinnings() public {
    //     // Setup within test
    //     vm.prank(ADMIN);
    //     gameWallet.addGameContract(GAME);
        
    //     vm.prank(USER);
    //     gameWallet.deposit{value: SEND_VALUE}();
        
    //     uint256 initialBalance = gameWallet.getBalance(USER);
    //     uint256 largeWinnings = 5 ether; // Large amount
        
    //     vm.prank(GAME);
    //     gameWallet.addWinnings(USER, largeWinnings);
        
    //     uint256 finalBalance = gameWallet.getBalance(USER);
        
    //     assertEq(finalBalance, initialBalance + largeWinnings, "Balance should be increased by large winnings amount");
    // }

 }