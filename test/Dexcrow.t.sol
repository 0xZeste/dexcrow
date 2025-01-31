// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Dexcrow, LibFee} from "../src/Dexcrow.sol";

contract DexcrowTest is Test {
    Dexcrow public dexcrow;

    function setUp() public {
        LibFee.Fee memory fee = LibFee.Fee(address(this), 100); // 1%

        address proxy =
            Upgrades.deployUUPSProxy("Dexcrow.sol", abi.encodeCall(Dexcrow.initialize, (address(this), fee)));

        dexcrow = Dexcrow(payable(proxy));
    }

    function test_Name() public {
        // assertEq(erc20.name(), keccak256(abi.encode(uint256(keccak256("dexcrow.storage.Dexcrow")) - 1)) & ~bytes32(uint256(0xff)));
    }
}
