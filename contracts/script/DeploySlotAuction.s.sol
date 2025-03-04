// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Script, console} from "forge-std/src/Script.sol";
import {SlotAuction} from "../src/SlotAuction.sol";
/*
 * Deploys the beta NFT:
 *     - SlotAuction
 *
 * @dev These environment variables must be set:
 * @param PRIVATE_KEY - Private key of the deploying account
 */
contract DeploySlotAuction is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deployer: %s", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy SlotAuction
        SlotAuction slotAuction = new SlotAuction(10, 2 days, 1 ether);
        console.log("SlotAuction deployed to: %s", address(slotAuction));

        vm.stopBroadcast();

        writeDeploymentAddress("SlotAuction", address(slotAuction));
    }

    function writeDeploymentAddress(string memory contractName, address deployment) internal {
        string memory path = string(abi.encodePacked("./out/", contractName, ".sol/", vm.toString(block.chainid), "_", "deployment.json"));
        string memory json = vm.serializeAddress("deployment.json", "address", deployment);
        vm.writeJson(json, path);
    }
}
