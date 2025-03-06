// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Script, console} from "forge-std/src/Script.sol";
import {SlotAuction} from "../src/SlotAuction.sol";

/*
 * @dev These environment variables must be set:
 * @param PRIVATE_KEY - Private key of the deploying account
 */
contract DeploySlotAuction is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deployer: %s", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy SlotAuction 5%
        SlotAuction slotAuction5 = new SlotAuction(5, 30 days, 3 ether);
        console.log("SlotAuction 5% deployed to: %s", address(slotAuction5));

        // Deploy SlotAuction 4%
        SlotAuction slotAuction4 = new SlotAuction(8, 30 days, 2 ether);
        console.log("SlotAuction 4% deployed to: %s", address(slotAuction4));

        // Deploy SlotAuction 3%
        SlotAuction slotAuction3 = new SlotAuction(10, 30 days, 1 ether);
        console.log("SlotAuction 3% deployed to: %s", address(slotAuction3));

        vm.stopBroadcast();

        writeDeploymentAddress("SlotAuction", "5", address(slotAuction5));
        writeDeploymentAddress("SlotAuction", "4", address(slotAuction4));
        writeDeploymentAddress("SlotAuction", "3", address(slotAuction3));
    }

    function writeDeploymentAddress(string memory contractName, string memory percentage, address deployment) internal {
        string memory path = string(abi.encodePacked("./out/", contractName, ".sol/", vm.toString(block.chainid), "_", percentage, "_deployment.json"));
        string memory json = vm.serializeAddress("deployment.json", "address", deployment);
        vm.writeJson(json, path);
    }
}
