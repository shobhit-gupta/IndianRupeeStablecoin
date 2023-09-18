// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import {INRCEngine_Test} from "../INRCEngine.t.sol";
import {INRC} from "../../../src/INRC.sol";
import {INRCEngine} from "../../../src/INRCEngine.sol";
// import {console} from "forge-std/Test.sol";

contract Constructor_Test is INRCEngine_Test {
    address[] listOfCollateralTknCxAddr;
    address[] listOfUSDPriceFeedAddr;
    INRC s_testINRC;

    function setUp() public virtual override {
        s_testINRC = new INRC();
    }

    modifier collateralsAndPriceFeedsLengthsMismatch() {
        listOfCollateralTknCxAddr.push(s_weth);
        listOfUSDPriceFeedAddr.push(s_wethUSDPriceFeed);
        listOfUSDPriceFeedAddr.push(s_wbtcPriceFeed);
        _;
    }

    function test_Constructor_RevertWhen_CollateralsAndPriceFeedsLengthMismatch()
        external
        collateralsAndPriceFeedsLengthsMismatch
    {
        vm.expectRevert(INRCEngine.INRCEngine__CollateralsAndPriceFeeds_LengthsMismatch.selector);
        new INRCEngine(listOfCollateralTknCxAddr, listOfUSDPriceFeedAddr, s_inrToUSDPriceFeed, address(s_testINRC));
    }

    modifier collateralsAndPriceFeedsLengthsMatch() {
        _;
    }

    modifier collateralsAndPriceFeedsAreEmpty() {
        _;
    }

    function test_Constructor_RevertIf_EmptyCollateralsAndPriceFeeds()
        external
        collateralsAndPriceFeedsLengthsMatch
        collateralsAndPriceFeedsAreEmpty
    {
        vm.expectRevert(INRCEngine.INRCEngine__CollateralsAndPriceFeeds_EmptyLists.selector);
        new INRCEngine(listOfCollateralTknCxAddr, listOfUSDPriceFeedAddr, s_inrToUSDPriceFeed, address(s_testINRC));
    }

    modifier collateralsAndPriceFeedsAreNonEmpty() {
        listOfCollateralTknCxAddr.push(s_weth);
        listOfUSDPriceFeedAddr.push(s_wethUSDPriceFeed);
        _;
    }

    function test_Constructor_CollateralsAndPriceFeedsNonEmpty()
        external
        collateralsAndPriceFeedsLengthsMatch
        collateralsAndPriceFeedsAreNonEmpty
    {
        new INRCEngine(listOfCollateralTknCxAddr, listOfUSDPriceFeedAddr, s_inrToUSDPriceFeed, address(s_testINRC));
    }
}
