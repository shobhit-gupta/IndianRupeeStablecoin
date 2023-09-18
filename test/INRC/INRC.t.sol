// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {INRCDeployer} from "../script/INRC.s.sol";
import {INRC} from "../src/INRC.sol";

contract INRCTest is Test {
    INRC internal s_inrc;

    function setUp() external {
        INRCDeployer deployer = new INRCDeployer();
        s_inrc = deployer.run();
    }
}
