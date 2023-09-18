// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import {INRCEngine_Test} from "../INRCEngine.t.sol";
import {INRCEngine} from "../../../../src/INRCEngine.sol";
import {MockERC20} from "../../../mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {console} from "forge-std/Test.sol";

contract DepositCollateral_Test is INRCEngine_Test {
    // Amount to be deposited
    uint256 s_testAmount;
    address s_testTknCxAddr;

    event DepositedCollateral(address indexed user, address indexed collateralTknCxAddr, uint256 amount);

    function setUp() public virtual override {
        INRCEngine_Test.setUp();
        s_testTknCxAddr = s_weth;
    }

    modifier amountIsZero() {
        s_testAmount = 0;
        _;
    }

    function test_DepositCollateral_RevertIf_AmountIsZero() external prank(users.alice) amountIsZero {
        vm.expectRevert(INRCEngine.INRCEngine__Amount_IsZero.selector);
        s_inrcEngine.depositCollateral(s_testTknCxAddr, s_testAmount);
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

    function test_DepositCollateral_RevertWhen_TknNotAllowed()
        external
        amountGtZero
        collateralTknAddrIsNotAllowed
        prank(users.alice)
    {
        approveTransferFrom(s_testTknCxAddr, s_testAmount);

        vm.expectRevert(INRCEngine.INRCEngine__Collateral_Invalid.selector);
        s_inrcEngine.depositCollateral(s_testTknCxAddr, s_testAmount);
    }

    modifier collateralTknAddrIsAllowed() {
        _;
    }

    modifier erc20TransferReverts() {
        _;
    }

    function test_DepositCollateral_RevertWhen_ERC20TransferReverts()
        external
        amountGtZero
        collateralTknAddrIsAllowed
        erc20TransferReverts
        prank(users.alice)
    {
        // ERC20 transferFrom should fail if the inrcEngine is not approved to transfer on user's behalf

        uint256 initialBalance = MockERC20(s_testTknCxAddr).balanceOf(address(s_inrcEngine));

        // Check INRCEngine contract
        vm.expectRevert();
        s_inrcEngine.depositCollateral(s_testTknCxAddr, s_testAmount);

        // Confirm from ERC20 contract
        uint256 finalBalance = MockERC20(s_testTknCxAddr).balanceOf(address(s_inrcEngine));
        assertEq(initialBalance, finalBalance);
    }

    modifier erc20TransferReturnsFalse() {
        MockERC20(s_testTknCxAddr).setShouldTransfer(false);
        _;
        MockERC20(s_testTknCxAddr).setShouldTransfer(true);
    }

    function test_DepositCollateral_RevertWhen_ERC20TransferReturnsFalse()
        external
        runOnAnvil(true)
        amountGtZero
        collateralTknAddrIsAllowed
        erc20TransferReturnsFalse
        prank(users.alice)
    {
        approveTransferFrom(s_testTknCxAddr, s_testAmount);

        uint256 initialBalance = MockERC20(s_testTknCxAddr).balanceOf(address(s_inrcEngine));

        // Check INRCEngine contract
        vm.expectRevert(INRCEngine.INRCEngine__Transfer_Failed.selector);
        s_inrcEngine.depositCollateral(s_testTknCxAddr, s_testAmount);

        // Confirm from ERC20 contract
        uint256 finalBalance = MockERC20(s_testTknCxAddr).balanceOf(address(s_inrcEngine));
        assertEq(initialBalance, finalBalance);
    }

    /// @dev Make sure this modifier is called after the appropriate msg.sender is set
    /// for the next transaction. For instance, call this after pranking the user.
    modifier erc20TransferSucceeds() {
        approveTransferFrom(s_testTknCxAddr, s_testAmount);
        _;
    }

    function test_DepositCollateral_IncreasesSenderDeposit()
        external
        amountGtZero
        collateralTknAddrIsAllowed
        prank(users.alice)
        erc20TransferSucceeds
    {
        uint256 initialBalance = s_inrcEngine.getCollateralDepositedBy(users.alice, s_testTknCxAddr);
        s_inrcEngine.depositCollateral(s_testTknCxAddr, s_testAmount);
        uint256 finalBalance = s_inrcEngine.getCollateralDepositedBy(users.alice, s_testTknCxAddr);
        assertEq({a: initialBalance + s_testAmount, b: finalBalance});
    }

    function test_DepositCollateral_EmitsDepositedCollateral()
        external
        amountGtZero
        collateralTknAddrIsAllowed
        prank(users.alice)
        erc20TransferSucceeds
    {
        vm.expectEmit(true, true, true, true);
        emit DepositedCollateral(users.alice, s_testTknCxAddr, s_testAmount);
        s_inrcEngine.depositCollateral(s_testTknCxAddr, s_testAmount);
    }

    function test_DepositCollateral_IncreasesContractTknAmount()
        external
        amountGtZero
        collateralTknAddrIsAllowed
        prank(users.alice)
        erc20TransferSucceeds
    {
        uint256 initialBalance = MockERC20(s_testTknCxAddr).balanceOf(address(s_inrcEngine));
        s_inrcEngine.depositCollateral(s_testTknCxAddr, s_testAmount);
        uint256 finalBalance = MockERC20(s_testTknCxAddr).balanceOf(address(s_inrcEngine));
        assertEq({a: initialBalance + s_testAmount, b: finalBalance});
    }
}
