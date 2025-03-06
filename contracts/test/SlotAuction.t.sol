// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console} from "forge-std/src/Test.sol";
import {SlotAuction} from "../src/SlotAuction.sol";

contract SlotAuctionTest is Test {
    SlotAuction public slotAuction;

    address public ALICE = vm.addr(101);
    address public BOB = vm.addr(102);
    address public CHARLIE = vm.addr(103);
    address public DAVID = vm.addr(104);
    address public EVE = vm.addr(105);

    uint256 public constant FUNDING_AMOUNT = 1_000_000 ether;

    uint256 public constant slotsAvailable = 3;
    uint40 public constant bidDuration = 30 days;
    uint96 public constant startingBid = 1 ether;

    function setUp() public {
        vm.label(ALICE, "//Alice");
        vm.label(BOB, "//Bob");
        vm.label(CHARLIE, "//Charlie");
        vm.label(DAVID, "//David");
        vm.label(EVE, "//Eve");

        vm.deal(ALICE, FUNDING_AMOUNT);
        vm.deal(BOB, FUNDING_AMOUNT);
        vm.deal(CHARLIE, FUNDING_AMOUNT);
        vm.deal(DAVID, FUNDING_AMOUNT);
        vm.deal(EVE, FUNDING_AMOUNT);

        vm.prank(ALICE);
        slotAuction = new SlotAuction(slotsAvailable, bidDuration, startingBid);
    }

    function test_only_owner_can_start() public {
        vm.startPrank(BOB);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", BOB));
        slotAuction.start();

        vm.startPrank(ALICE);
        slotAuction.start();
    }

    function test_only_owner_can_end() public {
        vm.startPrank(ALICE);
        slotAuction.start();

        vm.warp(vm.getBlockTimestamp() + bidDuration + 1);

        vm.startPrank(BOB);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", BOB));
        slotAuction.end();

        vm.startPrank(ALICE);
        slotAuction.end();
    }

    function test_cannot_end_before_starting() public {
        vm.startPrank(ALICE);
        vm.expectRevert("Auction never started");
        slotAuction.end();
    }

    function test_cannot_bid_before_start() public {
        vm.startPrank(BOB);
        vm.expectRevert("Auction not started");
        slotAuction.bid{value: 2 ether}();
    }

    function test_ending_is_final() public {
        vm.startPrank(ALICE);
        slotAuction.start();
        vm.warp(vm.getBlockTimestamp() + bidDuration + 1);
        slotAuction.end();

        // Cannot end again
        vm.expectRevert("Already ended");
        slotAuction.end();

        vm.startPrank(BOB);
        vm.expectRevert("Auction ended");
        slotAuction.bid{value: 2 ether}();
    }

    function test_first_bid_is_large_enough() public {
        vm.startPrank(ALICE);
        slotAuction.start();

        vm.startPrank(BOB);
        vm.expectRevert("Bid too low");
        slotAuction.bid{value: 0.1 ether}();
    }

    function test_first_bid_happy_path() public {
        vm.startPrank(ALICE);
        slotAuction.start();

        vm.startPrank(BOB);

        uint96 bidAmount = 2 ether;
        slotAuction.bid{value: bidAmount}();

        SlotAuction.Bid[] memory winningBids = slotAuction.getWinningBids();
        assertEq(winningBids[0].bidder, BOB);
        assertEq(winningBids[0].amount, bidAmount);
    }

    function test_increase_bid() public {
        vm.startPrank(ALICE);
        slotAuction.start();

        // Bob makes initial winning bid 1/3
        vm.startPrank(BOB);
        slotAuction.bid{value: 2 ether}();

        // Charlie makes winning bid 2/3
        vm.startPrank(CHARLIE);
        slotAuction.bid{value: 3 ether}();

        // David makes winning bid 3/3
        vm.startPrank(DAVID);
        slotAuction.bid{value: 4 ether}();

        // Eve makes winning bid and removing Bob from the winning set
        vm.startPrank(EVE);
        slotAuction.bid{value: 5 ether}();

        // Eve cannot increase her bid because she already has a winning bid
        vm.expectRevert("Already winning");
        slotAuction.bid{value: 1 ether}();

        vm.startPrank(BOB);

        // Bob must increase bid enough to be in winning set
        // Bob has to beat the lowest bid which is Charlie's bid of 3 ether
        vm.expectRevert("Bid too low");
        slotAuction.bid{value: 0.1 ether}();

        slotAuction.bid{value: 1.1 ether}();

        SlotAuction.Bid[] memory winningBids = slotAuction.getWinningBids();
        assertEq(winningBids[2].bidder, BOB);
        assertEq(winningBids[2].amount, 2 ether + 1.1 ether);
    }

    function test_cannot_duplicate_bid() public {
        vm.startPrank(ALICE);
        slotAuction.start();

        uint96 bidAmount = 2 ether;

        vm.startPrank(BOB);
        slotAuction.bid{value: bidAmount}();

        vm.startPrank(CHARLIE);
        vm.expectRevert("Duplicate bid");
        slotAuction.bid{value: bidAmount}();
    }

    function test_end_with_no_bids() public {
        vm.startPrank(ALICE);
        slotAuction.start();

        // End bidding
        vm.warp(vm.getBlockTimestamp() + bidDuration + 1);
        slotAuction.end();

        vm.assertTrue(slotAuction.isComplete());
    }

    function test_refunds_with_no_empty_bids() public {
        vm.startPrank(ALICE);
        slotAuction.start();

        // Bob makes initial winning bid 1/3
        vm.startPrank(BOB);
        slotAuction.bid{value: 2 ether}();

        // Charlie makes winning bid 2/3
        vm.startPrank(CHARLIE);
        slotAuction.bid{value: 3 ether}();

        // David makes winning bid 3/3
        vm.startPrank(DAVID);
        slotAuction.bid{value: 4 ether}();

        // Eve makes winning bid and removing Bob from the winning set
        vm.startPrank(EVE);
        slotAuction.bid{value: 6 ether}();

        // Bob cannot withdraw until bidding has ended
        vm.startPrank(BOB);
        vm.expectRevert("Auction is not complete");
        slotAuction.withdraw();

        // End bidding
        vm.warp(vm.getBlockTimestamp() + bidDuration + 1);
        vm.startPrank(ALICE);
        slotAuction.end();

        // Eve (1st) has partial refund
        vm.startPrank(EVE);
        uint256 balanceEve = address(EVE).balance;
        slotAuction.withdraw();
        vm.assertEq(address(EVE).balance - balanceEve, 6 ether - 4 ether);

        // David (2nd) has partial refund
        vm.startPrank(DAVID);
        uint256 balanceDavid = address(DAVID).balance;
        slotAuction.withdraw();
        vm.assertEq(address(DAVID).balance - balanceDavid, 4 ether - 3 ether);

        // Charlie (3rd) was the lowest winning bid so he has no refund
        vm.startPrank(CHARLIE);
        uint256 balanceCharlie = address(CHARLIE).balance;
        vm.expectRevert("Zero refund");
        slotAuction.withdraw();
        vm.assertEq(address(CHARLIE).balance, balanceCharlie);

        // Bob (4th) barely didn't win and therefore has a full refund
        vm.startPrank(BOB);
        uint256 balanceBob = address(BOB).balance;
        slotAuction.withdraw();
        vm.assertEq(address(BOB).balance - balanceBob, 2 ether);

        // Bob cannot withdraw again
        vm.expectRevert("Zero refund");
        slotAuction.withdraw();
    }

    function test_refunds_with_some_empty_bids() public {
        vm.startPrank(ALICE);
        slotAuction.start();

        // Bob makes initial winning bid 1/3
        vm.startPrank(BOB);
        slotAuction.bid{value: 5 ether}();

        // Charlie makes winning bid 2/3
        vm.startPrank(CHARLIE);
        slotAuction.bid{value: 2 ether}();

        // Charlie cannot withdraw until bidding has ended
        vm.expectRevert("Auction is not complete");
        slotAuction.withdraw();

        // End bidding
        vm.warp(vm.getBlockTimestamp() + bidDuration + 1);
        vm.startPrank(ALICE);
        slotAuction.end();

        // Bob (1st) has partial refund
        vm.startPrank(BOB);
        uint256 balanceBob = address(BOB).balance;
        slotAuction.withdraw();
        vm.assertEq(address(BOB).balance - balanceBob, 5 ether - 2 ether);

        // Bob cannot withdraw again
        vm.expectRevert("Zero refund");
        slotAuction.withdraw();

        // Charlie (2rd) was the lowest non-empty winning bid so he has no refund
        vm.startPrank(CHARLIE);
        uint256 balanceCharlie = address(CHARLIE).balance;
        vm.expectRevert("Zero refund");
        slotAuction.withdraw();
        vm.assertEq(address(CHARLIE).balance, balanceCharlie);
    }
}
