// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import {INRCEngine_Test} from "../INRCEngine.t.sol";
import {INRCEngine} from "../../../../src/INRCEngine.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {MockERC20} from "../../../mocks/MockERC20.sol";
import {MockV3Aggregator} from "../../../mocks/MockV3Aggregator.sol";
import {console, stdError} from "forge-std/Test.sol";

contract Liquidate_Test is INRCEngine_Test {
    uint256 constant DEFAULT_MINTED_COLLATERAL_FACTOR = 3;

    uint256 s_testDebtToCover;
    address s_testTknCxAddr;
    address s_otherToknCxAddr;
    address s_testTknPriceFeed;
    address s_otherTknPriceFeed;
    address s_defaulter;
    address s_liquidator;
    uint256 s_testDefaulterCollateral;
    uint256 s_testDefaulterINRCMinted;
    uint256 s_preHealthFactor;

    event RedeemedCollateral(
        address indexed from, address indexed to, address indexed collateralTknCxAddr, uint256 amount
    );

    function setUp() public virtual override {
        INRCEngine_Test.setUp();
        s_defaulter = users.bob;
        s_liquidator = users.alice;
        s_testTknCxAddr = s_weth;
        s_testTknPriceFeed = s_wethUSDPriceFeed;
        s_otherToknCxAddr = s_wbtc;
        s_otherTknPriceFeed = s_wbtcPriceFeed;
    }

    modifier debtToCoverIsZero() {
        s_testDebtToCover = 0;
        _;
    }

    function test_Liquidate_RevertIf_DebtToCoverIsZero() external debtToCoverIsZero {
        vm.expectRevert(INRCEngine.INRCEngine__Amount_IsZero.selector);
        s_inrcEngine.liquidate(s_defaulter, s_testTknCxAddr, s_testDebtToCover);
    }

    modifier debtToCoverGtZero(uint256 amount) {
        if (amount > 0) {
            s_testDebtToCover = amount;
            _;
        }
    }

    modifier collateralTknAddrIsNotAllowed() {
        MockERC20 newERC20 = new MockERC20("NEW ERC20", "NEW", msg.sender, ERC20_STARTING_BALANCE);
        s_testTknCxAddr = address(newERC20);
        fundUsersWithERC20Cx(s_testTknCxAddr);
        _;
    }

    function test_Liquidate_RevertWhen_TknNotAllowed()
        external
        debtToCoverGtZero(DEFAULT_ERC20_TEST_AMOUNT)
        collateralTknAddrIsNotAllowed
        prank(s_liquidator)
    {
        vm.expectRevert(INRCEngine.INRCEngine__Collateral_Invalid.selector);
        s_inrcEngine.liquidate(s_defaulter, s_testTknCxAddr, s_testDebtToCover);
    }

    modifier collateralTknAddrIsAllowed() {
        _;
    }

    modifier defaulterHealthFactorIsOkay() {
        s_testDefaulterCollateral = DEFAULT_ERC20_TEST_AMOUNT * 5;
        changePrank(s_defaulter);
        approveTransferFrom(s_testTknCxAddr, s_testDefaulterCollateral);
        s_inrcEngine.depositCollateral(s_testTknCxAddr, s_testDefaulterCollateral);
        s_preHealthFactor = type(uint256).max;
        _;
    }

    function test_Liquidate_RevertWhen_NotDefaulter()
        external
        debtToCoverGtZero(DEFAULT_ERC20_TEST_AMOUNT)
        collateralTknAddrIsAllowed
        defaulterHealthFactorIsOkay
        prank(s_liquidator)
    {
        vm.expectRevert(abi.encodeWithSelector(INRCEngine.INRCEngine__HealthFactor_IsOkay.selector, s_preHealthFactor));
        s_inrcEngine.liquidate(s_defaulter, s_testTknCxAddr, s_testDebtToCover);
    }

    modifier defaulterHealthFactorIsBroken(uint256 desiredHealthFactor) {
        s_testDefaulterCollateral = DEFAULT_ERC20_TEST_AMOUNT * 5;
        uint256 mintedCollateralFactor = DEFAULT_MINTED_COLLATERAL_FACTOR;

        changePrank(s_defaulter);
        approveTransferFrom(s_testTknCxAddr, s_testDefaulterCollateral);
        s_inrcEngine.depositCollateral(s_testTknCxAddr, s_testDefaulterCollateral);
        uint256 inrcMinted =
            s_inrcEngine.getINRValueOf(s_testTknCxAddr, s_testDefaulterCollateral) / mintedCollateralFactor;
        s_inrcEngine.mintINRC(inrcMinted);
        s_testDefaulterINRCMinted += inrcMinted;

        changePrank(users.admin);
        MockV3Aggregator priceFeed = MockV3Aggregator(s_testTknPriceFeed);
        (uint256 p, uint256 q) = getPriceChangeFactor(mintedCollateralFactor, desiredHealthFactor);
        int256 newPrice = priceFeed.latestAnswer() * int256(q) / int256(p);
        priceFeed.updateAnswer(newPrice);
        s_preHealthFactor = desiredHealthFactor;
        _;
    }

    modifier defaulterHasNoCollateralOfType() {
        s_testTknCxAddr = s_otherToknCxAddr;
        _;
    }

    function test_Liquidate_RevertWhen_NoCollateralOfType()
        external
        runOnAnvil(true)
        debtToCoverGtZero(DEFAULT_ERC20_TEST_AMOUNT)
        collateralTknAddrIsAllowed
        defaulterHealthFactorIsBroken(0.75e18)
        defaulterHasNoCollateralOfType
        prank(s_liquidator)
    {
        // Ensure the setup is as expected
        assertApproxEqAbs({
            a: s_inrcEngine.getHealthFactor(s_defaulter),
            b: s_preHealthFactor,
            maxDelta: s_preHealthFactor / 100
        });

        vm.expectRevert(stdError.arithmeticError);
        s_inrcEngine.liquidate(s_defaulter, s_testTknCxAddr, s_testDebtToCover);
    }

    modifier defaulterHasCollateralOfType() {
        _;
    }

    modifier amountToRedeemGtDefaulterCollateralOfType() {
        _;
    }

    function test_Liquidate_RevertWhen_AmountToRedeemGtCollateralOfType()
        external
        runOnAnvil(true)
        collateralTknAddrIsAllowed
        defaulterHealthFactorIsBroken(0.45e18)
        debtToCoverGtZero(s_inrc.balanceOf(s_defaulter))
        defaulterHasCollateralOfType
        amountToRedeemGtDefaulterCollateralOfType
        prank(s_liquidator)
    {
        // Ensure the setup is as expected
        assertApproxEqAbs({
            a: s_inrcEngine.getHealthFactor(s_defaulter),
            b: s_preHealthFactor,
            maxDelta: s_preHealthFactor / 100
        });
        vm.expectRevert(stdError.arithmeticError);
        s_inrcEngine.liquidate(s_defaulter, s_testTknCxAddr, s_testDebtToCover);
    }

    modifier amountToRedeemLteDefaulterCollateralOfType() {
        _;
    }

    modifier tknCxTransferReturnsFalse() {
        MockERC20(s_testTknCxAddr).setShouldTransfer(false);
        _;
        MockERC20(s_testTknCxAddr).setShouldTransfer(true);
    }

    function test_Liquidate_RevertWhen_TknCxTransferFails()
        external
        runOnAnvil(true)
        collateralTknAddrIsAllowed
        defaulterHealthFactorIsBroken(0.75e18)
        debtToCoverGtZero(s_inrc.balanceOf(s_defaulter))
        defaulterHasCollateralOfType
        amountToRedeemLteDefaulterCollateralOfType
        tknCxTransferReturnsFalse
        prank(s_liquidator)
    {
        vm.expectRevert(INRCEngine.INRCEngine__Transfer_Failed.selector);
        s_inrcEngine.liquidate(s_defaulter, s_testTknCxAddr, s_testDebtToCover);
    }

    modifier tknCxTransferSucceeds() {
        _;
    }

    modifier debtLtDebtToCover() {
        _;
    }

    function test_Liquidate_RevertWhen_DebtLtDebtToCover()
        external
        runOnAnvil(true)
        collateralTknAddrIsAllowed
        defaulterHealthFactorIsBroken(0.75e18)
        debtToCoverGtZero(s_inrc.balanceOf(s_defaulter) + 1)
        defaulterHasCollateralOfType
        amountToRedeemLteDefaulterCollateralOfType
        tknCxTransferSucceeds
        debtLtDebtToCover
        prank(s_liquidator)
    {
        vm.expectRevert(stdError.arithmeticError);
        s_inrcEngine.liquidate(s_defaulter, s_testTknCxAddr, s_testDebtToCover);
    }

    modifier debtGteDebtToCover() {
        _;
    }

    modifier liquidatorINRCLtDebtToCover() {
        s_testDefaulterCollateral = DEFAULT_ERC20_TEST_AMOUNT * 10;
        changePrank(s_liquidator);
        approveTransferFrom(s_testTknCxAddr, s_testDefaulterCollateral);
        s_inrcEngine.depositCollateral(s_testTknCxAddr, s_testDefaulterCollateral);
        uint256 inrcMinted = s_testDebtToCover - 1;
        s_inrcEngine.mintINRC(inrcMinted);
        approveTransferFrom(address(s_inrc), s_testDebtToCover);
        _;
    }

    function test_liquidate_RevertWhen_LiquidatorINRCLtDebtToCover()
        external
        runOnAnvil(true)
        collateralTknAddrIsAllowed
        defaulterHealthFactorIsBroken(0.75e18)
        debtToCoverGtZero(s_inrc.balanceOf(s_defaulter))
        defaulterHasCollateralOfType
        amountToRedeemLteDefaulterCollateralOfType
        tknCxTransferSucceeds
        debtGteDebtToCover
        liquidatorINRCLtDebtToCover
        prank(s_liquidator)
    {
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        s_inrcEngine.liquidate(s_defaulter, s_testTknCxAddr, s_testDebtToCover);
    }

    modifier liquidatorINRCGteDebtToCover() {
        s_testDefaulterCollateral = DEFAULT_ERC20_TEST_AMOUNT * 10;
        changePrank(s_liquidator);
        approveTransferFrom(s_testTknCxAddr, s_testDefaulterCollateral);
        s_inrcEngine.depositCollateral(s_testTknCxAddr, s_testDefaulterCollateral);
        uint256 inrcMinted = s_testDebtToCover;
        s_inrcEngine.mintINRC(inrcMinted);
        approveTransferFrom(address(s_inrc), s_testDebtToCover);
        _;
    }

    /// @dev This condition is hypothetically unreachable
    /// Even so, to test it requires INRCEngine with a mock INRC contract
    /// This may be completed later.
    modifier inrcTransferReturnsFalse() {
        _;
    }

    modifier inrcTransferSucceeds() {
        _;
    }

    modifier healthFctorNotImproved() {
        _;
    }

    function test_Liquidate_RevertWhen_HealthFactorNotImproved()
        external
        runOnAnvil(true)
        collateralTknAddrIsAllowed
        defaulterHealthFactorIsBroken(0.25e18)
        debtToCoverGtZero(s_inrc.balanceOf(s_defaulter) / 10)
        defaulterHasCollateralOfType
        amountToRedeemLteDefaulterCollateralOfType
        tknCxTransferSucceeds
        debtGteDebtToCover
        liquidatorINRCGteDebtToCover
        inrcTransferSucceeds
        healthFctorNotImproved
        prank(s_liquidator)
    {
        vm.expectRevert(INRCEngine.INRCEngine__HealthFactor_NotImproved.selector);
        s_inrcEngine.liquidate(s_defaulter, s_testTknCxAddr, s_testDebtToCover);
    }

    modifier healthFactorIsImproved() {
        _;
    }

    function test_Liquidate_ReducesDefaulterCollateral()
        external
        runOnAnvil(true)
        collateralTknAddrIsAllowed
        defaulterHealthFactorIsBroken(0.75e18)
        debtToCoverGtZero(s_inrc.balanceOf(s_defaulter))
        defaulterHasCollateralOfType
        amountToRedeemLteDefaulterCollateralOfType
        tknCxTransferSucceeds
        debtGteDebtToCover
        liquidatorINRCGteDebtToCover
        inrcTransferSucceeds
        healthFactorIsImproved
        prank(s_liquidator)
    {
        uint256 preLiquidationCollateral = s_inrcEngine.getINRValueOfCollateralFor(s_defaulter);
        s_inrcEngine.liquidate(s_defaulter, s_testTknCxAddr, s_testDebtToCover);
        uint256 postLiquidationCollateral = s_inrcEngine.getINRValueOfCollateralFor(s_defaulter);
        uint256 reward = s_testDebtToCover * s_inrcEngine.LIQUIDATION_BONUS() / s_inrcEngine.LIQUIDATION_PRECISION();
        assertApproxEqAbs({
            a: preLiquidationCollateral - s_testDebtToCover - reward,
            b: postLiquidationCollateral,
            maxDelta: postLiquidationCollateral / 100
        });
    }

    function test_Liquidate_EmitRedeemedCollateral()
        external
        runOnAnvil(true)
        collateralTknAddrIsAllowed
        defaulterHealthFactorIsBroken(0.75e18)
        debtToCoverGtZero(s_inrc.balanceOf(s_defaulter))
        defaulterHasCollateralOfType
        amountToRedeemLteDefaulterCollateralOfType
        tknCxTransferSucceeds
        debtGteDebtToCover
        liquidatorINRCGteDebtToCover
        inrcTransferSucceeds
        healthFactorIsImproved
        prank(s_liquidator)
    {
        uint256 debtToCoverInTkns = s_inrcEngine.getTknCxEquivalentOfINRC(s_testTknCxAddr, s_testDebtToCover);
        uint256 reward = debtToCoverInTkns * s_inrcEngine.LIQUIDATION_BONUS() / s_inrcEngine.LIQUIDATION_PRECISION();
        uint256 amountToRedeem = debtToCoverInTkns + reward;

        vm.expectEmit(true, true, true, true);
        emit RedeemedCollateral(s_defaulter, s_liquidator, s_testTknCxAddr, amountToRedeem);
        s_inrcEngine.liquidate(s_defaulter, s_testTknCxAddr, s_testDebtToCover);
    }

    function test_Liquidate_IncreasesLiquidatorCollateralTknCxAddrBalance()
        external
        runOnAnvil(true)
        collateralTknAddrIsAllowed
        defaulterHealthFactorIsBroken(0.75e18)
        debtToCoverGtZero(s_inrc.balanceOf(s_defaulter))
        defaulterHasCollateralOfType
        amountToRedeemLteDefaulterCollateralOfType
        tknCxTransferSucceeds
        debtGteDebtToCover
        liquidatorINRCGteDebtToCover
        inrcTransferSucceeds
        healthFactorIsImproved
        prank(s_liquidator)
    {
        uint256 preLiquidationERC20Balance = IERC20(s_testTknCxAddr).balanceOf(s_liquidator);
        s_inrcEngine.liquidate(s_defaulter, s_testTknCxAddr, s_testDebtToCover);
        uint256 postLiquidationERC20Balance = IERC20(s_testTknCxAddr).balanceOf(s_liquidator);

        uint256 debtToCoverInTkns = s_inrcEngine.getTknCxEquivalentOfINRC(s_testTknCxAddr, s_testDebtToCover);
        uint256 reward = debtToCoverInTkns * s_inrcEngine.LIQUIDATION_BONUS() / s_inrcEngine.LIQUIDATION_PRECISION();
        uint256 amountToRedeem = debtToCoverInTkns + reward;

        assertApproxEqAbs({
            a: preLiquidationERC20Balance + amountToRedeem,
            b: postLiquidationERC20Balance,
            maxDelta: postLiquidationERC20Balance / 100
        });
    }

    function test_Liquidate_ReducesDefaulterINRCMinted()
        external
        runOnAnvil(true)
        collateralTknAddrIsAllowed
        defaulterHealthFactorIsBroken(0.75e18)
        debtToCoverGtZero(s_inrc.balanceOf(s_defaulter))
        defaulterHasCollateralOfType
        amountToRedeemLteDefaulterCollateralOfType
        tknCxTransferSucceeds
        debtGteDebtToCover
        liquidatorINRCGteDebtToCover
        inrcTransferSucceeds
        healthFactorIsImproved
        prank(s_liquidator)
    {
        uint256 preLiquidationINRCMinted = s_inrcEngine.getINRCMintedBy(s_defaulter);
        s_inrcEngine.liquidate(s_defaulter, s_testTknCxAddr, s_testDebtToCover);
        uint256 postLiquidationINRCMinted = s_inrcEngine.getINRCMintedBy(s_defaulter);
        assertEq({a: preLiquidationINRCMinted - s_testDebtToCover, b: postLiquidationINRCMinted});
    }

    function test_Liquidate_ReducesLiquidatorINRCTokens()
        external
        runOnAnvil(true)
        collateralTknAddrIsAllowed
        defaulterHealthFactorIsBroken(0.75e18)
        debtToCoverGtZero(s_inrc.balanceOf(s_defaulter))
        defaulterHasCollateralOfType
        amountToRedeemLteDefaulterCollateralOfType
        tknCxTransferSucceeds
        debtGteDebtToCover
        liquidatorINRCGteDebtToCover
        inrcTransferSucceeds
        healthFactorIsImproved
        prank(s_liquidator)
    {
        uint256 preLiquidationINRCTokens = s_inrc.balanceOf(s_liquidator);
        s_inrcEngine.liquidate(s_defaulter, s_testTknCxAddr, s_testDebtToCover);
        uint256 postLiquidationINRCTokens = s_inrc.balanceOf(s_liquidator);
        assertEq({a: preLiquidationINRCTokens - s_testDebtToCover, b: postLiquidationINRCTokens});
    }

    function test_Liquidate_ReducesTotalINRCTokens()
        external
        runOnAnvil(true)
        collateralTknAddrIsAllowed
        defaulterHealthFactorIsBroken(0.75e18)
        debtToCoverGtZero(s_inrc.balanceOf(s_defaulter))
        defaulterHasCollateralOfType
        amountToRedeemLteDefaulterCollateralOfType
        tknCxTransferSucceeds
        debtGteDebtToCover
        liquidatorINRCGteDebtToCover
        inrcTransferSucceeds
        healthFactorIsImproved
        prank(s_liquidator)
    {
        uint256 preLiquidationINRCTokens = s_inrc.totalSupply();
        s_inrcEngine.liquidate(s_defaulter, s_testTknCxAddr, s_testDebtToCover);
        uint256 postLiquidationINRCTokens = s_inrc.totalSupply();
        assertEq({a: preLiquidationINRCTokens - s_testDebtToCover, b: postLiquidationINRCTokens});
    }
}
