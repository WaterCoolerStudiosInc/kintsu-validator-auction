// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract SlotAuction is Ownable {

    event Start();
    event NewBid(address indexed sender, uint256 amount);
    event Withdraw(address indexed bidder, uint256 amount);
    event End();

    struct Bid {
      address bidder;
      uint256 amount;
    }

    bool public ended;

    uint40 public immutable BID_DURATION;
    uint8 public immutable SLOTS_AVAILABLE;

    uint40 public endAt;

    uint256 public lowestWinningBid;
    bool public started;
    Bid[] public winningBids;

    mapping(address => Bid) public allBids;

    constructor(uint256 _startingBid, uint40 _bidDuration, uint8 _slotsAvailable) Ownable(msg.sender) {
        BID_DURATION = _bidDuration;
        SLOTS_AVAILABLE = _slotsAvailable;
        lowestWinningBid = _startingBid;
    }

    function start() external {
        require(!started, "started");
        started = true;
        endAt = uint40(block.timestamp) + BID_DURATION;

        emit Start();
    }

    function bid() external payable {
      // increase in user bid
      uint256 amount = allBids[msg.sender].amount + msg.value;

      require(started, "Auction not started");
      require(block.timestamp < endAt, "Auction ended");
      require(amount > lowestWinningBid, "Bid too low");

      _bid(amount);

      emit NewBid(msg.sender, amount);
    }

    function _bid(uint256 amount) internal {
        uint256 len = winningBids.length;
        
        // add the new bid and replace in mapping
        Bid memory newBid = Bid(msg.sender, amount);
        winningBids.push(newBid);
        allBids[msg.sender] = newBid;
        
        // sort the bids if slots are full
        if (len > SLOTS_AVAILABLE) {
          for (uint256 j = 0; j < len - 1; j++) {
              for (uint256 i = 0; i < len - 1 - j; i++) {
                  if (winningBids[i].amount < winningBids[i + 1].amount) {
                      Bid memory temp = winningBids[i];
                      winningBids[i] = winningBids[i + 1];
                      winningBids[i + 1] = temp;
                  }
              }
          }
          // remove lowest bid
          winningBids.pop();
        }

        // update the lowest winning bid
        lowestWinningBid = winningBids[len - 1].amount;
    }

    function withdraw() external {
        require(ended, "Auction not ended");

        Bid storage userBid = allBids[msg.sender];
        require(userBid.amount > 0, "no balance");

        uint256 refundableBal = 0;

        refundableBal = userBid.amount;

        payable(msg.sender).transfer(refundableBal);
        userBid.amount = 0;
        
        emit Withdraw(msg.sender, refundableBal);
    }

    function end() external onlyOwner {
        require(started, "not started");
        require(block.timestamp >= endAt, "Auction not ended");

        ended = true;

        uint256 ownerWithdrawableBal;
        uint256 len = winningBids.length;

        // if winner, refund the difference between self and next lowest bid
        // everyone but the lowest bidder gets a refund
        for (uint256 i = 0; i < len - 1; i++) {
            Bid storage currentBid = winningBids[i];
            uint256 refundableBal = currentBid.amount - winningBids[i + 1].amount;
            ownerWithdrawableBal += refundableBal - currentBid.amount;

            currentBid.amount = refundableBal;
        }

        payable(owner()).transfer(ownerWithdrawableBal);
        
        emit End();
    }
}
