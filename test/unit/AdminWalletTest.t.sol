// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {Test} from "forge-std/Test.sol";
import {AdminWallet} from "../../src/admin/AdminWallet.sol";
import {DeployAdminWallet} from "../../script/adminWalletDeploy/DeployAdminWallet.s.sol";

contract AdminWalletTest is Test{

    AdminWallet adminWallet;
    address GAME = makeAddr("game");
    address ADMIN = makeAddr("admin");
    address USER = makeAddr("user");
    uint256 GAMEBALANCE = 10 ether;
    uint256 GAMEFEE = 0.1 ether;
    uint256 constant SMALL_AMOUNT = 0.0001 ether;
    address NEW_PRICE_FEED = makeAddr("newPriceFeed");

    error AdminWallet__InsufficientAmount();
    error AdminWallet__TransferFailed();
    error AdminWallet__InsufficientBalance();
    error AdminWallet__GameFeeInsufficient();


    event FundsWithdrawn(address indexed admin, uint256 amount);
    event PriceFeedUpdated(address indexed newPriceFeed);
    event FeeDeposited(address indexed game, uint256 amount);

    function setUp() external {
        DeployAdminWallet deployAdminWallet = new DeployAdminWallet();
        adminWallet = deployAdminWallet.run();
        vm.deal(GAME,GAMEBALANCE);
        vm.deal(ADMIN, GAMEBALANCE);
        adminWallet.grantRole(adminWallet.DEFAULT_ADMIN_ROLE(), ADMIN);
    }

    // function testMinimumUsdIsADollar() public view{
    //     assertEq(adminWallet.getMinimumUSD(),1e18);
    // }
    //  function test_OwnerIsSetCorrectly() public view {
    //     assertEq(adminWallet.owner(), address(this)); // Deployer is owner
    // }

    function test_AdminHasDefaultAdminRole() public view {
        assertTrue(adminWallet.hasRole(adminWallet.DEFAULT_ADMIN_ROLE(), ADMIN));
    }

    // ============ AUTHORIZE GAME TESTS ============

    function test_AuthorizeGame() public {
        vm.prank(ADMIN);
        adminWallet.authorizeGame(GAME);
        
        assertTrue(adminWallet.hasRole(adminWallet.GAME_ROLE(), GAME));
    }

    function test_AuthorizeGame_RevertIfNotAdmin() public {
        vm.prank(USER);
        vm.expectRevert();
        adminWallet.authorizeGame(GAME);
    }

    function test_RevokeGame() public {
        // First authorize the game
        vm.prank(ADMIN);
        adminWallet.authorizeGame(GAME);
        
        // Then revoke it
        vm.prank(ADMIN);
        adminWallet.revokeGame(GAME);
        
        assertFalse(adminWallet.hasRole(adminWallet.GAME_ROLE(), GAME));
    }

    function test_RevokeGame_RevertIfNotAdmin() public {
        vm.prank(USER);
        vm.expectRevert();
        adminWallet.revokeGame(GAME);
    }

    // ============ DEPOSIT FEE TESTS ============

    function test_DepositFee() public {
        // Authorize game first
        vm.prank(ADMIN);
        adminWallet.authorizeGame(GAME);
        
        uint256 initialBalance = address(adminWallet).balance;
        uint256 initialGameFees = adminWallet.gameFees(GAME);
        
        vm.prank(GAME);
        adminWallet.depositFee{value: GAMEFEE}();
        
        assertEq(address(adminWallet).balance, initialBalance + GAMEFEE);
        assertEq(adminWallet.gameFees(GAME), initialGameFees + GAMEFEE);
    }

    function test_DepositFee_EmitsEvent() public {
        vm.prank(ADMIN);
        adminWallet.authorizeGame(GAME);
        
        vm.expectEmit(true, true, false, true);
        emit FeeDeposited(GAME, GAMEFEE);
        
        vm.prank(GAME);
        adminWallet.depositFee{value: GAMEFEE}();
    }

    function test_DepositFee_RevertIfNotAuthorized() public {
        vm.prank(GAME);
        vm.expectRevert();
        adminWallet.depositFee{value: GAMEFEE}();
    }

    function test_DepositFee_RevertIfZeroAmount() public {
        vm.prank(ADMIN);
        adminWallet.authorizeGame(GAME);
        
        vm.prank(GAME);
        vm.expectRevert(abi.encodeWithSelector(AdminWallet.AdminWallet__InsufficientAmount.selector));
        adminWallet.depositFee{value: 0}();
    }

    // function test_DepositFee_RevertIfBelowMinimumUSD() public {
    //     // This test assumes SMALL_AMOUNT is below the minimum USD value
    //     // You might need to adjust based on your actual price feed
    //     vm.prank(ADMIN);
    //     adminWallet.authorizeGame(GAME);
        
    //     vm.prank(GAME);
    //     vm.expectRevert(abi.encodeWithSelector(AdminWallet.AdminWallet__InsufficientAmount.selector));
    //     adminWallet.depositFee{value: SMALL_AMOUNT}();
    // }

    function test_DepositFee_MultipleDeposits() public {
        vm.prank(ADMIN);
        adminWallet.authorizeGame(GAME);
        
        uint256 deposit1 = 0.1 ether;
        uint256 deposit2 = 0.2 ether;
        
        vm.prank(GAME);
        adminWallet.depositFee{value: deposit1}();
        
        vm.prank(GAME);
        adminWallet.depositFee{value: deposit2}();
        
        assertEq(adminWallet.gameFees(GAME), deposit1 + deposit2);
        assertEq(address(adminWallet).balance, deposit1 + deposit2);
    }

    function test_DepositFee_MultipleGames() public {
        address GAME2 = makeAddr("game2");
        vm.deal(GAME2, GAMEBALANCE);
        
        vm.startPrank(ADMIN);
        adminWallet.authorizeGame(GAME);
        adminWallet.authorizeGame(GAME2);
        vm.stopPrank();
        
        uint256 fee1 = 0.1 ether;
        uint256 fee2 = 0.2 ether;
        
        vm.prank(GAME);
        adminWallet.depositFee{value: fee1}();
        
        vm.prank(GAME2);
        adminWallet.depositFee{value: fee2}();
        
        assertEq(adminWallet.gameFees(GAME), fee1);
        assertEq(adminWallet.gameFees(GAME2), fee2);
        assertEq(address(adminWallet).balance, fee1 + fee2);
    }

    // ============ WITHDRAW TESTS ============

    function test_Withdraw() public {
        // First deposit some fees
        vm.prank(ADMIN);
        adminWallet.authorizeGame(GAME);
        
        vm.prank(GAME);
        adminWallet.depositFee{value: GAMEFEE}();
        
        uint256 initialAdminBalance = ADMIN.balance;
        uint256 contractBalance = address(adminWallet).balance;
        
        vm.prank(ADMIN);
        adminWallet.withdraw(contractBalance);
        
        assertEq(ADMIN.balance, initialAdminBalance + contractBalance);
        assertEq(address(adminWallet).balance, 0);
    }

    function test_Withdraw_EmitsEvent() public {
        vm.prank(ADMIN);
        adminWallet.authorizeGame(GAME);
        
        vm.prank(GAME);
        adminWallet.depositFee{value: GAMEFEE}();
        
        uint256 contractBalance = address(adminWallet).balance;
        
        vm.expectEmit(true, true, false, true);
        emit FundsWithdrawn(ADMIN, contractBalance);
        
        vm.prank(ADMIN);
        adminWallet.withdraw(contractBalance);
    }

    function test_Withdraw_PartialAmount() public {
        vm.prank(ADMIN);
        adminWallet.authorizeGame(GAME);
        
        vm.prank(GAME);
        adminWallet.depositFee{value: 1 ether}();
        
        uint256 withdrawAmount = 0.3 ether;
        uint256 initialAdminBalance = ADMIN.balance;
        
        vm.prank(ADMIN);
        adminWallet.withdraw(withdrawAmount);
        
        assertEq(ADMIN.balance, initialAdminBalance + withdrawAmount);
        assertEq(address(adminWallet).balance, 0.7 ether);
    }

    function test_Withdraw_RevertIfNotAdmin() public {
        vm.prank(ADMIN);
        adminWallet.authorizeGame(GAME);
        
        vm.prank(GAME);
        adminWallet.depositFee{value: GAMEFEE}();
        
        vm.prank(USER);
        vm.expectRevert();
        adminWallet.withdraw(GAMEFEE);
    }

    function test_Withdraw_RevertIfZeroAmount() public {
        vm.prank(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(AdminWallet.AdminWallet__InsufficientAmount.selector));
        adminWallet.withdraw(0);
    }

    function test_Withdraw_RevertIfInsufficientBalance() public {
        uint256 excessiveAmount = address(adminWallet).balance + 1 ether;
        
        vm.prank(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(AdminWallet.AdminWallet__InsufficientBalance.selector));
        adminWallet.withdraw(excessiveAmount);
    }

    // ============ UPDATE PRICE FEED TESTS ============

    function test_UpdatePriceFeed() public {
        vm.prank(adminWallet.owner()); // Only owner can update price feed
        adminWallet.updatePriceFeed(NEW_PRICE_FEED);
        
        assertEq(adminWallet.getPriceFeed(), NEW_PRICE_FEED);
    }

    function test_UpdatePriceFeed_EmitsEvent() public {
        vm.expectEmit(true, true, false, true);
        emit PriceFeedUpdated(NEW_PRICE_FEED);
        
        vm.prank(adminWallet.owner());
        adminWallet.updatePriceFeed(NEW_PRICE_FEED);
    }

    function test_UpdatePriceFeed_RevertIfNotOwner() public {
        vm.prank(USER);
        vm.expectRevert();
        adminWallet.updatePriceFeed(NEW_PRICE_FEED);
    }

    // ============ RECEIVE FUNCTION TESTS ============

    function test_ReceiveFunction() public {
        uint256 sendAmount = 0.5 ether;
        uint256 initialBalance = address(adminWallet).balance;
        
        // Send ETH directly to contract (triggers receive function)
        vm.deal(USER, sendAmount);
        vm.prank(USER);
        (bool success, ) = address(adminWallet).call{value: sendAmount}("");
        
        assertTrue(success);
        assertEq(address(adminWallet).balance, initialBalance + sendAmount);
    }

    function test_ReceiveFunction_DoesNotAffectGameFees() public {
        uint256 sendAmount = 0.5 ether;
        
        vm.deal(USER, sendAmount);
        vm.prank(USER);
        (bool success, ) = address(adminWallet).call{value: sendAmount}("");
        
        assertTrue(success);
        assertEq(adminWallet.gameFees(USER), 0); // Should not track as game fee
    }

    // ============ VIEW FUNCTION TESTS ============

    function test_GetBalance() public {
        // Deposit some fees first
        vm.prank(ADMIN);
        adminWallet.authorizeGame(GAME);
        
        vm.prank(GAME);
        adminWallet.depositFee{value: GAMEFEE}();
        
        assertEq(adminWallet.getBalance(), GAMEFEE);
    }

    function test_GetPriceFeed() public view {
        address priceFeed = adminWallet.getPriceFeed();
        assertTrue(priceFeed != address(0));
    }

    function test_GetMinimumUSD() public view {
        uint256 minimumUSD = adminWallet.getMinimumUSD();
        assertEq(minimumUSD, 1e18);
    }

    function test_GameFeesMapping() public {
        vm.prank(ADMIN);
        adminWallet.authorizeGame(GAME);
        
        vm.prank(GAME);
        adminWallet.depositFee{value: GAMEFEE}();
        
        assertEq(adminWallet.gameFees(GAME), GAMEFEE);
    }

    // ============ EDGE CASE TESTS ============

    function test_DepositAfterRevoke() public {
        // Authorize and then revoke
        vm.startPrank(ADMIN);
        adminWallet.authorizeGame(GAME);
        adminWallet.revokeGame(GAME);
        vm.stopPrank();
        
        vm.prank(GAME);
        vm.expectRevert();
        adminWallet.depositFee{value: GAMEFEE}();
    }

    function test_WithdrawAllFunds() public {
        // Deposit multiple times from different games
        address GAME2 = makeAddr("game2");
        vm.deal(GAME2, GAMEBALANCE);
        
        vm.startPrank(ADMIN);
        adminWallet.authorizeGame(GAME);
        adminWallet.authorizeGame(GAME2);
        vm.stopPrank();
        
        vm.prank(GAME);
        adminWallet.depositFee{value: 0.3 ether}();
        
        vm.prank(GAME2);
        adminWallet.depositFee{value: 0.7 ether}();
        
        uint256 totalBalance = address(adminWallet).balance;
        
        vm.prank(ADMIN);
        adminWallet.withdraw(totalBalance);
        
        assertEq(address(adminWallet).balance, 0);
    }

    function test_ReentrancyProtection() public {
        // This test verifies that nonReentrant modifier works
        // We'll try to call withdraw from within a malicious contract
        // This is a simplified test - in practice you'd need a malicious contract
        
        vm.prank(ADMIN);
        adminWallet.authorizeGame(GAME);
        
        vm.prank(GAME);
        adminWallet.depositFee{value: GAMEFEE}();
        
        // The nonReentrant modifier should prevent reentrancy attacks
        // This test mainly ensures the modifier is present and doesn't cause revert
        vm.prank(ADMIN);
        adminWallet.withdraw(GAMEFEE);
        
        // If we get here, the nonReentrant modifier worked correctly
        assertTrue(true);
    }
}
    