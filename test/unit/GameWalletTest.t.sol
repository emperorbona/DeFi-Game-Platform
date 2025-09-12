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
    address NONADMIN = makeAddr("nonadmin");
    uint256 public constant SEND_VALUE = 0.1 ether;
    uint256 STARTING_BALANCE = 10 ether;

    event FundsDeposited(address indexed user, uint256 amount);
    event FundsWithdrawn(address indexed user, uint256 amount);
    event FundsTransferredToGame(address indexed user, address indexed game, uint256 amount);
    event FundsReceivedFromGame(address indexed user, address indexed game, uint256 amount);
    event GameApprovalChanged(address indexed user, address indexed game, bool approved);
    


    function setUp() external{
        DeployGameWallet deployGameWallet = new DeployGameWallet();
        gameWallet = deployGameWallet.run(); 
        vm.deal(USER,STARTING_BALANCE);
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
     function testGameApprovalDefaultsToFalse() public {
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

 }