// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import {BaseScript} from "./BaseScript.s.sol";
import {INRC} from "../src/INRC.sol";

contract INRCDeployer is BaseScript {
    function run() public virtual broadcast returns (INRC inrc) {
        inrc = new INRC();
    }
}
