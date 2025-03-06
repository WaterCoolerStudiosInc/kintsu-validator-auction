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
