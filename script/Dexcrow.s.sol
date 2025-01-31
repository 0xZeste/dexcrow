// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Dexcrow, LibFee} from "../src/Dexcrow.sol";

contract CounterScript is Script {
    Dexcrow public dexcrow;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        LibFee.Fee memory fee = LibFee.Fee(address(this), 30); // 0.3%

        address proxy =
            Upgrades.deployUUPSProxy("Dexcrow.sol", abi.encodeCall(Dexcrow.initialize, (address(this), fee)));

        dexcrow = Dexcrow(payable(proxy));

        vm.stopBroadcast();
    }
}
