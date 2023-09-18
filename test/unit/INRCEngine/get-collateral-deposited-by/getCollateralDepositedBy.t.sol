// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import {INRCEngine_Test} from "../INRCEngine.t.sol";
// import {console} from "forge-std/Test.sol";

contract GetCollateralDepositedBy_Test is INRCEngine_Test {
    address s_testTknCxAddr;
    address s_otherToknCxAddr;
    address payable s_depositer;
    uint256 s_testAmount;

    function setUp() public virtual override {
        INRCEngine_Test.setUp();
        s_testTknCxAddr = s_wbtc;
        s_otherToknCxAddr = s_weth;
        s_depositer = users.alice;
        s_testAmount = DEFAULT_ERC20_TEST_AMOUNT;
        changePrank(s_depositer);
    }

    modifier noCollateral() {
        _;
    }

    function test_GetCollateralDepositedBy_NoCollateral() external noCollateral {
        uint256 expectedValue = 0;
        uint256 actualValue = s_inrcEngine.getCollateralDepositedBy(s_depositer, s_testTknCxAddr);
        assertEq({a: expectedValue, b: actualValue});
    }

    modifier depositerHasNoCollateralOfType() {
        approveTransferFrom(s_otherToknCxAddr, s_testAmount);
        s_inrcEngine.depositCollateral(s_otherToknCxAddr, s_testAmount);
        _;
    }

    function test_GetCollateralDepositedBy_NoCollateralOfType() external depositerHasNoCollateralOfType {
        uint256 expectedValue = 0;
        uint256 actualValue = s_inrcEngine.getCollateralDepositedBy(s_depositer, s_testTknCxAddr);
        assertEq({a: expectedValue, b: actualValue});
    }

    modifier depositerHasCollateral() {
        approveTransferFrom(s_testTknCxAddr, s_testAmount);
        s_inrcEngine.depositCollateral(s_testTknCxAddr, s_testAmount);
        _;
    }

    function test_GetCollateralDepositedBy_HasCollateral() external depositerHasCollateral {
        uint256 expectedValue = s_testAmount;
        uint256 actualValue = s_inrcEngine.getCollateralDepositedBy(s_depositer, s_testTknCxAddr);
        assertEq({a: expectedValue, b: actualValue});
    }
}
