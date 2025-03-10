// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract SlotAuction is Ownable {

    event Start();
    event NewBid(address indexed sender, uint256 amount);
    event RefundAvailable(address bidder, uint256 amount);
    event Withdraw(address indexed bidder, uint256 amount);
    event End(uint256 proceeds);

    struct Bid {
        address bidder; // 20 bytes
        uint96 amount; // 12 bytes
    }

    uint40 public immutable BID_DURATION;
    uint256 public immutable SLOTS_AVAILABLE;
    uint256 public immutable FINAL_SLOT_INDEX;

    uint40 public endTime;
    bool public isComplete;

    uint96 public lowestWinningBid;

    /// List of bids sorted by highest bid first
    Bid[] public winningBids;

    mapping(address => Bid) public allBids;

    constructor(uint256 slotsAvailable, uint40 bidDuration, uint96 startingBid) Ownable(msg.sender) {
        require(slotsAvailable > 0, "No slots");
        require(bidDuration > 0, "No bid duration");
        require(startingBid > 0, "Zero starting bid");

        SLOTS_AVAILABLE = slotsAvailable;
        FINAL_SLOT_INDEX = slotsAvailable - 1;
        BID_DURATION = bidDuration;
        lowestWinningBid = startingBid;

        /// @dev Dynamic array to enforce a "fixed" array length at deployment
        for (uint256 i; i < slotsAvailable; ++i) {
            winningBids.push(Bid({
                bidder: address(0),
                amount: 0
            }));
        }
    }

    /**
     * @notice Allows bids to be placed
     */
    function start() external onlyOwner {
        require(endTime == 0, "Auction already started");
        endTime = uint40(block.timestamp) + BID_DURATION;
        emit Start();
    }

    /**
     * @notice Bid on a slot
     * @notice Value specified will increase previous bid if this is not the first time calling `bid()`
     * @notice Cannot make a bid that duplicates an existing winning bid
     * @notice Cannot increase bid if caller already has a winning bid
     */
    function bid() external payable {
        uint256 _endTime = endTime; // shadow

        require(_endTime != 0, "Auction not started");
        require(block.timestamp < _endTime, "Auction ended");

        uint256 _lowestWinningBid = lowestWinningBid; // shadow

        // User can only have 1 winning bid
        uint96 previousBid = allBids[msg.sender].amount;
        require(previousBid < _lowestWinningBid, "Already winning");

        // Increase previous bid if user has already bid
        uint96 bidAmount = previousBid + uint96(msg.value);
        require(bidAmount > _lowestWinningBid, "Bid too low");

        Bid memory newBid = Bid({
            bidder: msg.sender,
            amount: bidAmount
        });

        // Insert new bid while maintaining winning bid descending order
        for (uint256 i; i < SLOTS_AVAILABLE; ++i) {
            // Iterate winning bids until we find one that is lower than new bid
            if (bidAmount > winningBids[i].amount) {
                // This maintains a descending sorted list without duplicates
                require(i == 0 || bidAmount < winningBids[i - 1].amount, "Duplicate bid");

                // Shift remaining bids down to make space for newBid
                for (uint256 j = FINAL_SLOT_INDEX; j > i; --j) {
                    winningBids[j] = winningBids[j - 1];
                }

                // Add newBid and maintain sorted order
                winningBids[i] = newBid;

                allBids[msg.sender] = newBid;

                /// @dev Only update `lowestWinningBid` when no empty bids remain
                uint96 newLowestWinningBid = winningBids[FINAL_SLOT_INDEX].amount;
                if (newLowestWinningBid > 0) {
                    lowestWinningBid = newLowestWinningBid;
                }

                emit NewBid(msg.sender, bidAmount);

                return;
            }
        }

        // Should never get here
        revert("Unknown error");
    }

    /**
     * @notice Called after the auction has ended for users to get unspent funds back
     * @notice Winners (except for the winner with lowest bid) will get a partial refund back
     * @notice Losers will get a 100% refund of their bid(s)
     */
    function withdraw() external {
        require(isComplete, "Auction is not complete");

        Bid storage userBid = allBids[msg.sender];

        uint256 refund = userBid.amount;
        require(refund > 0, "Zero refund");

        userBid.amount = 0;

        payable(msg.sender).transfer(refund);

        emit Withdraw(msg.sender, refund);
    }

    /**
     * @notice End the auction and enable partial refunds for winning bids
     * @notice The lowest winning bid is not eligible for any refund
     * @notice Non-winning bids will be eligible for a 100% refund
     * @notice Refunds can be claimed by calling `withdraw()`
     * @dev Transfers proceeds from all winning bids minus refunds to the owner
     * @dev Enables `withdraw()` to be called
     */
    function end() external onlyOwner {
        uint256 _endTime = endTime; // shadow

        require(_endTime != 0, "Auction never started");
        require(block.timestamp > _endTime, "Auction in progress");
        require(isComplete == false, "Already ended");

        isComplete = true;

        uint256 proceeds;

        /// @dev Refund the difference between self and next lowest bid
        /// @dev The lowest winning bidder will not get a refund
        for (uint256 i; i < SLOTS_AVAILABLE; ++i) {
            Bid memory winningBid = winningBids[i];

            /// @dev This is the final and lowest winning bid
            if (i == FINAL_SLOT_INDEX) {
                // No refund
                allBids[winningBid.bidder].amount = 0;
                proceeds += winningBid.amount;
                break;
            }

            /// @dev Safe because i < FINAL_SLOT_INDEX
            Bid memory nextBid = winningBids[i + 1];

            /// @dev Special case where empty bids still remain
            if (nextBid.bidder == address(0)) {
                // No refund
                allBids[winningBid.bidder].amount = 0;
                proceeds += winningBid.amount;
                break;
            }

            /// @dev Cannot underflow because `winningBids` is sorted in descending order
            uint96 refund = winningBid.amount - nextBid.amount;

            /// @dev Refund the difference between bid and next lowest bid
            allBids[winningBid.bidder].amount = refund;

            proceeds += winningBid.amount - refund;

            emit RefundAvailable(winningBid.bidder, refund);
        }

        if (proceeds > 0) {
            payable(owner()).transfer(proceeds);
        }

        emit End(proceeds);
    }

    function getWinningBids() external view returns (Bid[] memory) {
        return winningBids;
    }
}
