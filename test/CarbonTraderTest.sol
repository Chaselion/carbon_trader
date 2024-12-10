// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {Test} from "forge-std/Test.sol";
import {CarbonTrader} from "../src/CarbonTrader.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";

contract CarbonTraderTest is Test{
    CarbonTrader carbonTrader;
    ERC20Mock usdtToken;
    address owner = address(this);
    address user1 = address(0x1);
    address user2 = address(0x2);

    function setUp() public{
        usdtToken = new ERC20Mock("USDT", "USDT", owner, 1000000000000000000000000000);
        carbonTrader = new CarbonTrader(address(usdtToken));
    }

    function testIssueAllowance() public{
        //模拟发放1000个
        carbonTrader.issueAllowance(owner, 1000);
        assertEq(carbonTrader.getAllowance(owner), 1000);
    }

    //冻结测试
    function testFreezeAllowance() public{
        //模拟发放1000个
        carbonTrader.issueAllowance(owner, 1000);
         //模拟冻结500个
        carbonTrader.freezeAllowance(owner, 500);
        assertEq(carbonTrader.getAllowance(owner), 500);
        assertEq(carbonTrader.getFrozenAllowance(owner), 500);
    }

    //解冻测试
    function testUnfreezeAllowance() public{
        //模拟发放1000个
        carbonTrader.issueAllowance(owner, 1000);
        //模拟冻结500个
        carbonTrader.freezeAllowance(owner, 500);
        assertEq(carbonTrader.getAllowance(owner), 500);
        assertEq(carbonTrader.getFrozenAllowance(owner), 500);
        //模拟解冻500个
        carbonTrader.unfreezeAllowance(owner, 500);
        assertEq(carbonTrader.getAllowance(owner), 1000);
        assertEq(carbonTrader.getFrozenAllowance(owner), 0);
    }

    //销毁测试
    function testDestroyAllowance() public{
        //模拟发放1000个
        carbonTrader.issueAllowance(owner, 1000);
        //模拟销毁500个
        carbonTrader.destroyAllowance(owner, 500);
        assertEq(carbonTrader.getAllowance(owner), 500);

        vm.prank(user1);
        vm.expectRevert();
        //模拟销毁全部
        carbonTrader.destroyAllAllowance(owner);
        assertEq(carbonTrader.getAllowance(owner), 500);

        vm.prank(owner);
        carbonTrader.destroyAllAllowance(owner);
        assertEq(carbonTrader.getAllowance(owner), 0);
    }

    //发起交易测试
    function testStartTrade() public{
        string memory tradeID = "tradeID";
        carbonTrader.issueAllowance(owner, 1000);
        carbonTrader.startTrade(tradeID, 500, block.timestamp, block.timestamp + 1000, 100, 10);
        (address seller, uint256 sellAmount, , , ,) = carbonTrader.getTrade(tradeID);
        assertEq(seller, owner);
        assertEq(sellAmount, 500);
    }

    //質押测试
    function testDeposit() public{
        string memory tradeID = "tradeID";
        carbonTrader.issueAllowance(owner, 1000);
        carbonTrader.startTrade(tradeID, 500, block.timestamp, block.timestamp + 1000, 100, 10);
        usdtToken.mint(user2, 1 * 10 ** 6);//給予user2 1个USDT
        
        vm.prank(user2);
        usdtToken.approve(address(carbonTrader), 1 * 10 ** 6);

        vm.prank(user2);
        carbonTrader.deposit(tradeID, 1 * 10 ** 6, "info");

        vm.prank(user2);
        assertEq(carbonTrader.getTradeDeposit(tradeID), 1 * 10 ** 6);
    }

    //测试退还质押
    function testRefundDeposit() public{
        string memory tradeID = "tradeID";
        carbonTrader.issueAllowance(owner, 1000);
        carbonTrader.startTrade(tradeID, 500, block.timestamp, block.timestamp + 1000, 100, 10);
        usdtToken.mint(user2, 1 * 10 ** 6);//給予user2 1个USDT
        
        vm.prank(user2);
        usdtToken.approve(address(carbonTrader), 1 * 10 ** 6);

        vm.prank(user2);
        carbonTrader.deposit(tradeID, 1 * 10 ** 6, "info");

        assertEq(usdtToken.balanceOf(user2), 0);

        vm.prank(user2);
        carbonTrader.refundDeposit(tradeID);
        assertEq(usdtToken.balanceOf(user2), 1 * 10 ** 6);
    }

    //测试结算
    function testSettle() public{
        string memory tradeID = "tradeID";
        carbonTrader.issueAllowance(owner, 1000);
        carbonTrader.startTrade(tradeID, 500, block.timestamp, block.timestamp + 1000, 100, 10);
        usdtToken.mint(user2, 1.5 * 10 ** 6);//給予user2 1个USDT
        
        vm.prank(user2);
        usdtToken.approve(address(carbonTrader), 1.5 * 10 ** 6);

        vm.prank(user2);
        carbonTrader.deposit(tradeID, 1 * 10 ** 6, "info");

        vm.prank(user2);
        carbonTrader.finalizeAuctionAndTransferCarbon(tradeID, 500, 0.5 * 10 ** 6);

        assertEq(usdtToken.balanceOf(user2), 0);
        assertEq(carbonTrader.getAllowance(user2), 500);
        

    }
}