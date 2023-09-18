// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import {INRCEngine_Test} from "../INRCEngine.t.sol";
import {INRCEngine} from "../../../src/INRCEngine.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {MockERC20} from "../../mocks/MockERC20.sol";
import {console, stdError} from "forge-std/Test.sol";

contract RedeemCollateral_Test is INRCEngine_Test {
    // Amount to be redeemed
    uint256 s_testAmount;
    uint256 s_testCollateral;
    uint256 s_testINRCMinted;
    address s_testTknCxAddr;
    address s_otherToknCxAddr;
    address s_redeemer;

    event RedeemedCollateral(
        address indexed from, address indexed to, address indexed collateralTknCxAddr, uint256 amount
    );

    function setUp() public virtual override {
        INRCEngine_Test.setUp();
        s_testTknCxAddr = s_weth;
        s_otherToknCxAddr = s_wbtc;
        s_redeemer = users.alice;
    }

    modifier amountIsZero() {
        s_testAmount = 0;
        _;
    }

    function test_RedeemCollateral_RevertIf_AmountIsZero() external amountIsZero prank(s_redeemer) {
        vm.expectRevert(INRCEngine.INRCEngine__Amount_IsZero.selector);
        s_inrcEngine.redeemCollateral(s_testTknCxAddr, s_testAmount);
    }

    modifier amountGtZero() {
        s_testAmount = DEFAULT_ERC20_TEST_AMOUNT;
        _;
    }

    modifier collateralTknAddrIsNotAllowed() {
        MockERC20 newERC20 = new MockERC20("NEW ERC20", "NEW", msg.sender, ERC20_STARTING_BALANCE);
        s_testTknCxAddr = address(newERC20);
        fundUsersWithERC20Cx(s_testTknCxAddr);
        _;
    }

    function test_RedeemCollateral_RevertWhen_TknNotAllowed()
        external
        amountGtZero
        collateralTknAddrIsNotAllowed
        prank(s_redeemer)
    {
        vm.expectRevert(INRCEngine.INRCEngine__Collateral_Invalid.selector);
        s_inrcEngine.redeemCollateral(s_testTknCxAddr, s_testAmount);
    }

    modifier collateralTknAddrIsAllowed() {
        _;
    }

    modifier userHasZeroCollateral() {
        _;
    }

    function test_RedeemCollateral_RevertWhen_RedeemerHasNoCollateral()
        external
        amountGtZero
        collateralTknAddrIsAllowed
        userHasZeroCollateral
        prank(s_redeemer)
    {
        vm.expectRevert(stdError.arithmeticError);
        s_inrcEngine.redeemCollateral(s_testTknCxAddr, s_testAmount);
    }

    modifier userHasNoCollateralOfType() {
        s_testCollateral = DEFAULT_ERC20_TEST_AMOUNT * 5;
        approveTransferFrom(s_otherToknCxAddr, s_testCollateral);
        s_inrcEngine.depositCollateral(s_otherToknCxAddr, s_testCollateral);
        _;
    }

    function test_RedeemCollateral_RevertWhen_RedeemerHasNoCollateralOfType()
        external
        amountGtZero
        collateralTknAddrIsAllowed
        prank(s_redeemer)
        userHasNoCollateralOfType
    {
        vm.expectRevert(stdError.arithmeticError);
        s_inrcEngine.redeemCollateral(s_testTknCxAddr, s_testAmount);
    }

    modifier userHasCollateralOfType() {
        s_testCollateral = DEFAULT_ERC20_TEST_AMOUNT * 5;
        approveTransferFrom(s_testTknCxAddr, s_testCollateral);
        s_inrcEngine.depositCollateral(s_testTknCxAddr, s_testCollateral);
        _;
    }

    modifier amountGtCollateral() {
        s_testAmount = s_testCollateral + 1;
        _;
    }

    function test_RedeemCollateral_RevertWhen_AmountGtCollateral()
        external
        amountGtZero
        collateralTknAddrIsAllowed
        prank(s_redeemer)
        userHasCollateralOfType
        amountGtCollateral
    {
        vm.expectRevert(stdError.arithmeticError);
        s_inrcEngine.redeemCollateral(s_testTknCxAddr, s_testAmount);
    }

    modifier amountLteCollateral() {
        s_testAmount = s_testCollateral;
        _;
    }

    modifier erc20TransferReturnsFalse() {
        MockERC20(s_testTknCxAddr).setShouldTransfer(false);
        _;
        MockERC20(s_testTknCxAddr).setShouldTransfer(true);
    }

    function test_RedeemCollateral_RevertWhen_ERC20TransferFails()
        external
        runOnAnvil(true)
        amountGtZero
        collateralTknAddrIsAllowed
        prank(s_redeemer)
        userHasCollateralOfType
        amountLteCollateral
        erc20TransferReturnsFalse
    {
        vm.expectRevert(INRCEngine.INRCEngine__Transfer_Failed.selector);
        s_inrcEngine.redeemCollateral(s_testTknCxAddr, s_testAmount);
    }

    modifier erc20TransferSucceeds() {
        _;
    }

    modifier userFinalMintedValueWithinThreshold() {
        // Mint 25% of all the collateral's value
        s_testINRCMinted = s_inrcEngine.getINRValueOfCollateralFor(s_redeemer) / 4;
        s_inrcEngine.mintINRC(s_testINRCMinted);
        // Take out 25% of the collateral
        s_testAmount = s_testCollateral / 4;
        /// @dev At the end 25% of initial collateral's INR value (say x) will be minted and 3x will remain as collateral
        /// In INRCEngine#_healthFactorOf
        /// => adjustedCollateral will be approx. 1.5x
        /// => Health factor will be approx. 1.5e18 > 1e18 (MIN_HEALTH_FACTOR)
        _;
    }

    function test_RedeemCollateral_ReducesUserCollateral()
        external
        amountGtZero
        collateralTknAddrIsAllowed
        prank(s_redeemer)
        userHasCollateralOfType
        amountLteCollateral
        erc20TransferSucceeds
        userFinalMintedValueWithinThreshold
    {
        uint256 preRedeemCollateral = s_inrcEngine.getCollateralDepositedBy(s_redeemer, s_testTknCxAddr);
        s_inrcEngine.redeemCollateral(s_testTknCxAddr, s_testAmount);
        uint256 postRedeemCollateral = s_inrcEngine.getCollateralDepositedBy(s_redeemer, s_testTknCxAddr);
        assertEq({a: preRedeemCollateral, b: postRedeemCollateral + s_testAmount});
    }

    function test_RedeemCollateral_IncreasesUserERC20Balance()
        external
        amountGtZero
        collateralTknAddrIsAllowed
        prank(s_redeemer)
        userHasCollateralOfType
        amountLteCollateral
        erc20TransferSucceeds
        userFinalMintedValueWithinThreshold
    {
        uint256 preRedeemERC20Balance = IERC20(s_testTknCxAddr).balanceOf(s_redeemer);
        s_inrcEngine.redeemCollateral(s_testTknCxAddr, s_testAmount);
        uint256 postRedeemERC20Balance = IERC20(s_testTknCxAddr).balanceOf(s_redeemer);
        assertEq({a: preRedeemERC20Balance + s_testAmount, b: postRedeemERC20Balance});
    }

    function test_RedeemCollateral_EmitRedeemedCollateral()
        external
        amountGtZero
        collateralTknAddrIsAllowed
        prank(s_redeemer)
        userHasCollateralOfType
        amountLteCollateral
        erc20TransferSucceeds
        userFinalMintedValueWithinThreshold
    {
        vm.expectEmit(true, true, true, true);
        emit RedeemedCollateral(s_redeemer, s_redeemer, s_testTknCxAddr, s_testAmount);
        s_inrcEngine.redeemCollateral(s_testTknCxAddr, s_testAmount);
    }

    modifier userFinalMintedValueBeyondThreshold() {
        // Mint 25% of all the collateral's value
        s_testINRCMinted = s_inrcEngine.getINRValueOfCollateralFor(s_redeemer) / 4;
        s_inrcEngine.mintINRC(s_testINRCMinted);
        // Take out 75% of the collateral
        s_testAmount = s_testCollateral * 3 / 4;
        /// @dev At the end 25% of initial collateral's INR value (say x) will be minted and x will remain as collateral
        /// In INRCEngine#_healthFactorOf
        /// => adjustedCollateral will be approx. 0.5x
        /// => Health factor will be approx. 0.5e18 or 5e17
        /// Turns out actual value will be 4.999..e17
        _;
    }

    /**
     * @dev If on Sepolia, you're getting a `FAIL. Reason: Error != expected error:...`
     * then the reason probably is slight error in division. Try the following:
     * 1. Assign `expectedHealthFactor` to `499999999999999999` instead of `500000000000000000` or vice versa.
     * 2. If it still doesn't work then try logging the Health Factor value in INRCEngine#redeemCollateral before
     * calling `_revertIfHealthFactorIsBad`. Use `console.log(getHealthFactor(msg.sender));`
     * A better solution would be to have a version of `expectRevert` method that can test for approximate values.
     */
    function test_RedeemCollateral_RevertWhen_HealthFactorWillBreak()
        external
        amountGtZero
        collateralTknAddrIsAllowed
        prank(s_redeemer)
        userHasCollateralOfType
        amountLteCollateral
        erc20TransferSucceeds
        userFinalMintedValueBeyondThreshold
    {
        /// @dev Read the function's comment first. This indeed is a hack which does seem
        /// to work consistently thus far. I do wish for a better solution in the future.
        uint256 expectedHealthFactor;
        if (isOnAnvil()) {
            expectedHealthFactor = 499999999999999999;
        } else {
            // expectedHealthFactor = 500000000000000000;
            expectedHealthFactor = 499999999999999999;
        }

        vm.expectRevert(
            abi.encodeWithSelector(INRCEngine.INRCEngine__HealthFactor_Breaks.selector, expectedHealthFactor)
        );
        s_inrcEngine.redeemCollateral(s_testTknCxAddr, s_testAmount);
    }
}
