// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import {Test, console} from "forge-std/Test.sol";
import {PuppyRaffle} from "../src/PuppyRaffle.sol";

contract ProofOfCodes is Test {
    PuppyRaffle raffle;
    uint256 entranceFee = 1e18;
    address feeAddress = address(99);
    uint256 duration = 1 days;

    function setUp() external {
        raffle = new PuppyRaffle(entranceFee, feeAddress, duration);
    }
}
