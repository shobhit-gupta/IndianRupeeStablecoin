// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import {BaseScript, Config} from "./BaseScript.s.sol";
import {INRC} from "../src/INRC.sol";
import {INRCEngine} from "../src/INRCEngine.sol";

contract INRCEngineDeployer is BaseScript {
    address[] public listOfCollateralTknCxAddr;
    address[] public listOfUSDPriceFeedAddr;
    address public inrToUSDPriceFeed;

    function _deployContracts() private broadcast returns (INRC inrc, INRCEngine inrcEngine, Config config) {
        inrc = new INRC();
        inrcEngine = new INRCEngine(listOfCollateralTknCxAddr, listOfUSDPriceFeedAddr, inrToUSDPriceFeed, address(inrc));
        inrc.transferOwnership(address(inrcEngine));
        config = getConfig();
    }

    function run() external returns (INRC, INRCEngine, Config) {
        (address weth, address wbtc, address wethUSDPriceFeed, address wbtcPriceFeed, address inrToUSDPriceFeed_) =
            getConfig().current();

        listOfCollateralTknCxAddr = [weth, wbtc];
        listOfUSDPriceFeedAddr = [wethUSDPriceFeed, wbtcPriceFeed];
        inrToUSDPriceFeed = inrToUSDPriceFeed_;

        return _deployContracts();
    }
}
