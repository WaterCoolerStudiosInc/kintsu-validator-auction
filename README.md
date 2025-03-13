# kintsu-validator-auction

## Contracts

### Build Contracts
```shell
cd contracts
forge soldeer install
forge build
```

### Test Contracts
```shell
cd contracts
forge soldeer install
forge test
```

### Deploy contracts locally

- Open new terminal and run
  ```shell
  anvil
  ```
- Create `.env` file (if not already present) from [.env.local](.env.local) template
- Change `.env` file if desired, currently configured with default anvil wallet
- Change [DeploySlotAuction.s.sol](script/DeploySlotAuction.s.sol) constructor parameters for SlotAuction if you want faster times
- Deploy in separate terminal window with:
  ```shell
  forge script script/DeploySlotAuction.s.sol --rpc-url anvil --broadcast
  ```

## Auction Mechanism

### Cascading 2nd Price Auction

This project implements a novel auction mechanism called a "cascading 2nd price auction" for allocating validator slots. This approach combines elements of traditional second-price (Vickrey) auctions with a cascading refund system to create a fair and efficient allocation mechanism.

#### How It Works

1. **Fixed Slots Available**: Each auction has a predetermined number of slots available (e.g., 3, 5, or 8 slots).

2. **Bidding Phase**: 
   - Bidders submit their maximum bid amount
   - The system maintains an ordered list of the highest bids
   - Only bids higher than the current lowest winning bid are accepted
   - Each bidder can only have one active bid in the winning set

3. **Price Determination**:
   - Winning bidders don't necessarily pay their full bid amount
   - Each winner (except the lowest winning bidder) pays the amount of the next-lowest winning bid
   - The lowest winning bidder pays their full bid amount

4. **Refund Mechanism**:
   - Higher bidders receive automatic partial refunds equal to the difference between their bid and the next-lowest bid
   - The lowest winning bidder receives no refund
   - Losing bidders receive a full refund of their bid

#### Example

Imagine an auction with 3 available slots and a minimum bid of 1 ETH:

1. **Initial Bids**:
   - Eve bids 6 ETH
   - David bids 4 ETH
   - Charlie bids 3 ETH
   - Bob bids 2 ETH

2. **Final Winning Bids (in descending order)**:
   - Eve: 6 ETH
   - David: 4 ETH
   - Charlie: 3 ETH (lowest winning bid)
   - Bob: 2 ETH (not a winner)

3. **Actual Payments and Refunds**:
   - Eve pays 4 ETH (David's bid) and receives a 2 ETH refund
   - David pays 3 ETH (Charlie's bid) and receives a 1 ETH refund
   - Charlie pays 3 ETH (full amount, no refund)
   - Bob receives a full refund of 2 ETH

4. **Total Proceeds**:
   - The auction contract collects 4 + 3 + 3 = 10 ETH in proceeds

#### Benefits

1. **Economic Efficiency**: The cascading 2nd price mechanism ensures that slots are allocated to those who value them most.

2. **Truth-Revealing**: Bidders are incentivized to bid their true valuation since they will likely pay less than their maximum bid.

3. **No Duplicate Bids**: The system prevents duplicate bid amounts, ensuring a clear ordering of winners.

4. **Fairness**: Lower-ranked winners pay less than higher-ranked winners, reflecting the relative value of their positions.
