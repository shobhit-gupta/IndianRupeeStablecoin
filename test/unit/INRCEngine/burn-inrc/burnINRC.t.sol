// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import {INRCEngine_Test} from "../INRCEngine.t.sol";
import {INRCEngine} from "../../../../src/INRCEngine.sol";
// import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
// import {MockERC20} from "../../../mocks/MockERC20.sol";
import {console, stdError} from "forge-std/Test.sol";

contract BurnINRC_Test is INRCEngine_Test {
    // Amount to be burned
    uint256 s_testAmount;
    uint256 s_testCollateral;
    address s_burner;

    function setUp() public virtual override {
        INRCEngine_Test.setUp();
        s_burner = users.alice;
        s_testCollateral = DEFAULT_ERC20_TEST_AMOUNT * 5;
    }

    modifier amountIsZero() {
        s_testAmount = 0;
        _;
    }

    function test_BurnINRC_RevertIf_AmountIsZero() external amountIsZero prank(s_burner) {
        vm.expectRevert(INRCEngine.INRCEngine__Amount_IsZero.selector);
        s_inrcEngine.burnINRC(s_testAmount);
    }

    modifier amountGtZero() {
        s_testAmount = DEFAULT_ERC20_TEST_AMOUNT;
        _;
    }

    modifier zeroINRCMinted() {
        _;
    }

    function test_BurnINRC_RevertWhen_ZeroINRCMinted() external amountGtZero prank(s_burner) zeroINRCMinted {
        vm.expectRevert(stdError.arithmeticError);
        s_inrcEngine.burnINRC(s_testAmount);
    }

    modifier ltAmountINRCMinted() {
        approveTransferFrom(s_weth, s_testCollateral);
        s_inrcEngine.depositCollateral(s_weth, s_testCollateral);
        s_inrcEngine.mintINRC(s_testAmount - 1);
        _;
    }

    function test_BurnINRC_RevertWhen_LessINRCMinted() external amountGtZero prank(s_burner) ltAmountINRCMinted {
        vm.expectRevert(stdError.arithmeticError);
        s_inrcEngine.burnINRC(s_testAmount);
    }

    modifier gteAmountINRCMinted() {
        approveTransferFrom(s_weth, s_testCollateral);
        s_inrcEngine.depositCollateral(s_weth, s_testCollateral);
        s_inrcEngine.mintINRC(s_testAmount);
        approveTransferFrom(address(s_inrc), s_testAmount);
        _;
    }

    modifier ltAmountINRCTokens() {
        s_inrc.transfer(users.bob, 1);
        _;
    }

    function test_BurnINRC_RevertWhen_LessINRCTokens()
        external
        amountGtZero
        prank(s_burner)
        gteAmountINRCMinted
        ltAmountINRCTokens
    {
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        s_inrcEngine.burnINRC(s_testAmount);
    }

    modifier gteAmountINRCTokens() {
        _;
    }

    /// @dev This condition is hypothetically unreachable
    /// Even so, to test it requires INRCEngine with a mock INRC contract
    /// This may be completed later.
    modifier erc20TransferReturnsFalse() {
        // MockERC20(s_testTknCxAddr).setShouldTransfer(false);
        _;
        // MockERC20(s_testTknCxAddr).setShouldTransfer(true);
    }

    // function test_BurnINRC_RevertWhen_ERC20TransferFails()
    //     external
    //     amountGtZero
    //     prank(s_burner)
    //     gteAmountINRCMinted
    //     gteAmountINRCTokens
    //     erc20TransferReturnsFalse
    // {
    //     vm.expectRevert(INRCEngine.INRCEngine__Transfer_Failed.selector);
    //     s_inrcEngine.burnINRC(s_testAmount);
    // }

    modifier erc20TransferSucceeds() {
        _;
    }

    function test_BurnINRC_ReducesINRCMinted()
        external
        amountGtZero
        prank(s_burner)
        gteAmountINRCMinted
        gteAmountINRCTokens
        erc20TransferSucceeds
    {
        uint256 preINRCMinted = s_inrcEngine.getINRCMintedBy(s_burner);
        s_inrcEngine.burnINRC(s_testAmount);
        uint256 postINRCMinted = s_inrcEngine.getINRCMintedBy(s_burner);
        assertEq({a: preINRCMinted - s_testAmount, b: postINRCMinted});
    }

    function test_BurnINRC_ReducesUserINRCTokens()
        external
        amountGtZero
        prank(s_burner)
        gteAmountINRCMinted
        gteAmountINRCTokens
        erc20TransferSucceeds
    {
        uint256 preINRCTokens = s_inrc.balanceOf(s_burner);
        s_inrcEngine.burnINRC(s_testAmount);
        uint256 postINRCTokens = s_inrc.balanceOf(s_burner);
        assertEq({a: preINRCTokens - s_testAmount, b: postINRCTokens});
    }

    function test_BurnINRC_ReducesTotalINRCTokens()
        external
        amountGtZero
        prank(s_burner)
        gteAmountINRCMinted
        gteAmountINRCTokens
        erc20TransferSucceeds
    {
        uint256 preINRCTokens = s_inrc.totalSupply();
        s_inrcEngine.burnINRC(s_testAmount);
        uint256 postINRCTokens = s_inrc.totalSupply();
        assertEq({a: preINRCTokens - s_testAmount, b: postINRCTokens});
    }
}
