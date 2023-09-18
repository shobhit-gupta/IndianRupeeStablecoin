// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import {INRCEngine_Test} from "../INRCEngine.t.sol";
import {INRCEngine} from "../../../src/INRCEngine.sol";
import {console} from "forge-std/Test.sol";

contract MintINRC_Test is INRCEngine_Test {
    address s_minter;
    // Amount to be minted
    uint256 s_testAmount;

    function setUp() public virtual override {
        INRCEngine_Test.setUp();
        s_minter = users.alice;
        changePrank(s_minter);
    }

    modifier amountIsZero() {
        s_testAmount = 0;
        _;
    }

    function test_MintINRC_RevertIf_AmountIsZero() external amountIsZero {
        vm.expectRevert(INRCEngine.INRCEngine__Amount_IsZero.selector);
        s_inrcEngine.mintINRC(s_testAmount);
    }

    modifier amountGtZero() {
        s_testAmount = DEFAULT_ERC20_TEST_AMOUNT;
        _;
    }

    modifier userHasZeroCollateral() {
        _;
    }

    function test_MintINRC_RevertIf_MinterHasZeroCollateral() external amountGtZero userHasZeroCollateral {
        vm.expectRevert(abi.encodeWithSelector(INRCEngine.INRCEngine__HealthFactor_Breaks.selector, 0));
        s_inrcEngine.mintINRC(s_testAmount);
    }

    modifier userHasSomeCollateral() {
        approveTransferFrom(s_weth, DEFAULT_ERC20_TEST_AMOUNT);
        s_inrcEngine.depositCollateral(s_weth, DEFAULT_ERC20_TEST_AMOUNT);
        _;
    }

    modifier userFinalMintedValueWithinThreshold() {
        s_testAmount = s_inrcEngine.getINRValueOfCollateralFor(s_minter) / 4;
        _;
    }

    modifier inrcMintingFails() {
        _;
    }

    /// [TODO] This is an unlikely case, as INRC contract is likely to be deployed by us.
    /// To test, we may use a mock INRC contract.
    function test_MintINRC_RevertWhen_MintingFails()
        external
        amountGtZero
        userHasSomeCollateral
        userFinalMintedValueWithinThreshold
        inrcMintingFails
    {}

    modifier inrcMintingSucceeds() {
        _;
    }

    function test_MintINRC_IncreasesINRCMintedBy()
        external
        amountGtZero
        userHasSomeCollateral
        userFinalMintedValueWithinThreshold
        inrcMintingSucceeds
    {
        s_inrcEngine.mintINRC(s_testAmount);
        assertEq({a: s_testAmount, b: s_inrcEngine.getINRCMintedBy(s_minter)});
    }

    modifier userFinalMintedValueBeyondThreshold() {
        s_testAmount = s_inrcEngine.getINRValueOfCollateralFor(s_minter) * 3 / 4;
        _;
    }

    function test_MintINRC_RevertWhen_FinalMintedValueBeyondThreshold()
        external
        amountGtZero
        userHasSomeCollateral
        userFinalMintedValueBeyondThreshold
    {
        /// @dev the `userHealthFactor` 0.666e18 was calculated manually on paper
        vm.expectRevert(abi.encodeWithSelector(INRCEngine.INRCEngine__HealthFactor_Breaks.selector, 666666666666666666));
        s_inrcEngine.mintINRC(s_testAmount);
    }
}
