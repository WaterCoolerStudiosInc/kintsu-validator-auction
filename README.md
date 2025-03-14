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

Imagine an auction with 4 available slots and a minimum bid of 1 MON:

1. **Initial Bids**:
   - Eve bids 5.5 MON 
   - David bids 5.2 MON
   - Charlie bids 5.0 MON
   - Bob bids 4.8 MON
   - Alice bids 4.5 MON
   - Frank bids 3.5 MON
   - Grace bids 2.5 MON

2. **Auction Results**:

| Participant | Original Bid | Final Payment | Refund | Net Cost | Result |
|-------------|------------:|-------------:|-------:|---------:|--------|
| Eve         | 5.5 MON     | 5.2 MON      | 0.3 MON| 5.2 MON  | 🥉 3rd place (paid most) |
| David       | 5.2 MON     | 5.0 MON      | 0.2 MON| 5.0 MON  | 🥈 2nd place (paid middle) |
| Charlie     | 5.0 MON     | 4.8 MON      | 0.2 MON| 4.8 MON  | 🥇 1st place (tied, with discount) |
| Bob         | 4.8 MON     | 4.8 MON      | 0 MON  | 4.8 MON  | 🥇 1st place (tied, exact bid) |
| Alice       | 4.5 MON     | 0 MON        | 4.5 MON| 0 MON    | ❌ Not selected |
| Frank       | 3.5 MON     | 0 MON        | 3.5 MON| 0 MON    | ❌ Not selected |
| Grace       | 2.5 MON     | 0 MON        | 2.5 MON| 0 MON    | ❌ Not selected |

3. **Winner Analysis**:
   - Notice how Charlie and Bob can both be considered winners:
     - Charlie (5.0 MON bid) paid only 4.8 MON, receiving back a 0.2 MON refund
     - Bob (4.8 MON bid) paid exactly his bid but still secured a slot at the lowest price
   - The bidders with higher bids (Eve and David) paid more for the same slots
   - In this tighter bidding scenario, being the lowest or second-lowest winner is advantageous

4. **Total Proceeds**:
   - The auction contract collects 5.2 + 5.0 + 4.8 + 4.8 = 19.8 MON in proceeds

#### Benefits

1. **Economic Efficiency**: The cascading 2nd price mechanism ensures that slots are allocated to those who value them most.

2. **Truth-Revealing**: Bidders are incentivized to bid their true valuation since they will likely pay less than their maximum bid.

3. **No Duplicate Bids**: The system prevents duplicate bid amounts, ensuring a clear ordering of winners.

4. **Fairness**: Lower-ranked winners pay less than higher-ranked winners, reflecting the relative value of their positions.
