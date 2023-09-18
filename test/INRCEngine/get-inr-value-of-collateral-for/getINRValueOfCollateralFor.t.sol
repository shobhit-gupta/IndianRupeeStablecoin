// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import {INRCEngine_Test} from "../INRCEngine.t.sol";
import {console} from "forge-std/Test.sol";

contract GetINRValueOfCollateralFor_Test is INRCEngine_Test {
    // Amount to be deposited as collateral
    uint256 s_testAmount;

    function setUp() public virtual override {
        INRCEngine_Test.setUp();
        changePrank(users.alice);
    }

    modifier userHasZeroCollateral() {
        _;
    }

    function test_GetINRvalueOfCollateralFor_NoCollateralReturnZero() external userHasZeroCollateral {
        uint256 value = s_inrcEngine.getINRValueOfCollateralFor(users.alice);
        assertEq({a: value, b: 0});
    }

    modifier userHasSomeCollateralTkns() {
        s_testAmount = DEFAULT_ERC20_TEST_AMOUNT;
        approveTransferFrom(s_weth, s_testAmount);
        s_inrcEngine.depositCollateral(s_weth, s_testAmount);
        _;
    }

    function test_GetINRvalueOfCollateralFor_SomeCollateralDeposited() external userHasSomeCollateralTkns {
        uint256 expectedValue = ethToINR(s_testAmount);
        uint256 actualValue = s_inrcEngine.getINRValueOfCollateralFor(users.alice);
        assertApproxEqAbs({a: expectedValue, b: actualValue, maxDelta: expectedValue / 100});
    }

    modifier userHasAllCollateralTkns() {
        s_testAmount = DEFAULT_ERC20_TEST_AMOUNT;
        approveTransferFrom(s_weth, s_testAmount);
        approveTransferFrom(s_wbtc, s_testAmount);
        s_inrcEngine.depositCollateral(s_weth, s_testAmount);
        s_inrcEngine.depositCollateral(s_wbtc, s_testAmount);
        _;
    }

    function test_GetINRvalueOfCollateralFor_AllCollateralsDeposited() external userHasAllCollateralTkns {
        uint256 expectedValue = ethToINR(s_testAmount) + btcToINR(s_testAmount);
        uint256 actualValue = s_inrcEngine.getINRValueOfCollateralFor(users.alice);
        assertApproxEqAbs({a: expectedValue, b: actualValue, maxDelta: expectedValue / 100});
    }
}
