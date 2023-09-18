// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import {BaseTest} from "../BaseTest.t.sol";
import {INRC} from "../../src/INRC.sol";
import {INRCEngine} from "../../src/INRCEngine.sol";
import {INRCEngineDeployer} from "../../script/INRCEngine.s.sol";
import {Config} from "../../script/BaseScript.s.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

abstract contract INRCEngine_Test is BaseTest {
    uint256 public constant ERC20_STARTING_BALANCE = 0.1 ether;
    uint256 public constant DEFAULT_ERC20_TEST_AMOUNT = 0.001 ether;

    /// @dev
    /// 1. These values must be updated to the current value at the time of testing
    /// for the tests to work.
    /// 2. On Sepolia, we use JPY instead of INR as Chainlink doesn't offer INR price
    /// feeds on Testnets.
    /// 3. Simply use a query such as `1 eth to jpy` on Google to get these values.
    uint256 public constant WETH_JPY_PRICE = 241_360;
    uint256 public constant WBTC_JPY_PRICE = 3_937_470;
    uint256 public constant WETH_INR_PRICE = 135_911;
    uint256 public constant WBTC_INR_PRICE = 2_217_215;

    INRC s_inrc;
    INRCEngine s_inrcEngine;
    Config s_config;

    address s_weth;
    address s_wbtc;
    address s_wethUSDPriceFeed;
    address s_wbtcPriceFeed;
    address s_inrToUSDPriceFeed;

    function setUp() public virtual override {
        BaseTest.setUp();
        INRCEngineDeployer deployer = new INRCEngineDeployer();
        deployer.setBroadcaster(users.admin);
        (s_inrc, s_inrcEngine, s_config) = deployer.run();
        (s_weth, s_wbtc, s_wethUSDPriceFeed, s_wbtcPriceFeed, s_inrToUSDPriceFeed) = s_config.current();

        if (isOnAnvil()) {
            _fundUsers();
        }

        // Admin will be the default caller, i.e. `msg.sender` for all the subsequent calls
        vm.startPrank({msgSender: users.admin});
    }

    function _fundUsers() private {
        fundUsersWithERC20Cx(s_weth);
        fundUsersWithERC20Cx(s_wbtc);
    }

    function fundUsersWithERC20Cx(address erc20CxAddr) internal {
        MockERC20 cx = MockERC20(erc20CxAddr);
        cx.mint(users.admin, ERC20_STARTING_BALANCE);
        cx.mint(users.alice, ERC20_STARTING_BALANCE);
        cx.mint(users.bob, ERC20_STARTING_BALANCE);
        cx.mint(users.eve, ERC20_STARTING_BALANCE);
    }

    function approveTransferFrom(address collateralCxAddr, uint256 amount) internal {
        MockERC20(collateralCxAddr).approve(address(s_inrcEngine), amount);
    }

    function ethToINR(uint256 amount) public view returns (uint256 value) {
        if (isOnAnvil()) {
            value = amount * uint256(s_config.WETH_USD_PRICE()) / uint256(s_config.INR_USD_PRICE());
        } else if (isOnSepolia()) {
            value = amount * WETH_JPY_PRICE;
        } else {
            value = amount * WETH_INR_PRICE;
        }
    }

    function btcToINR(uint256 amount) public view returns (uint256 value) {
        if (isOnAnvil()) {
            value = amount * uint256(s_config.WBTC_USD_PRICE()) / uint256(s_config.INR_USD_PRICE());
        } else if (isOnSepolia()) {
            value = amount * WBTC_JPY_PRICE;
        } else {
            value = amount * WBTC_INR_PRICE;
        }
    }

    /// @dev This is a convenience function that helps in changing the price of a token
    /// to get to a desired `health factor`. It calculates a fraction of form `p / q` which
    /// when divided with the current price returns the new price:
    /// ∴ new_price = current_price / (p / q) = current_price * q / p
    ///
    /// @notice Formula derivation:
    /// Let (for a user), c_i: ith TokenCxAddr Collateral Deposited
    /// ∴ Total Collateral Value (C) = ∑[INRValueOf(c_i)]
    ///
    /// Also, say a certain ratio of the total collateral's value has been minted. This fraction
    /// maybe called mintedCollateralFactor
    /// ∴ INRCMinted (M) = C / mintedCollateralFactor
    ///
    /// Also, according to INRCEngine#_healthFactorOf
    ///    Health Factor = Adjusted Collateral Value * PRECESION / inrcMinted
    /// => Health Factor = {(C * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION} * PRECESION / M
    ///
    /// Say, the price of the token changes and it changes by a price change factor `p / q`
    /// ∴ C_new = C / Price Change Factor  = C / (p / q) = C * q / p
    ///
    /// ∴ New Health Factor
    /// = {(C_new * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION} * PRECESION / M
    /// = [{(C * q / p) * LIQUIDATION_THRESHOLD} / LIQUIDATION_PRECISION] * PRECESION / M
    /// = {(C * q * LIQUIDATION_THRESHOLD * PRECESION) / (p * LIQUIDATION_PRECISION)} / M
    /// = {(C * q * LIQUIDATION_THRESHOLD * PRECESION) / (p * LIQUIDATION_PRECISION)} / (C / mintedCollateralFactor)
    /// = (C * q * LIQUIDATION_THRESHOLD * PRECESION * mintedCollateralFactor) / (p * LIQUIDATION_PRECISION * C)
    /// => New Health Factor = (q * LIQUIDATION_THRESHOLD * PRECESION * mintedCollateralFactor) / (p * LIQUIDATION_PRECISION)
    /// => p / q = (mintedCollateralFactor * LIQUIDATION_THRESHOLD * PRECESION) / (New Health Factor * LIQUIDATION_PRECISION)
    ///
    /// @notice M = C / mintedCollateralFactor and not C_new / mintedCollateralFactor because price update doesn't
    /// change the INRC already minted.
    ///
    /// @param mintedCollateralFactor (Reciprocal of) Fraction of collateral that is minted
    /// @param healthFactor Desired health factor. Is precision adjusted, i.e. is multiplied with 1e18
    /// @return p Numerator of the factor
    /// @return q Denominator of the factor

    function getPriceChangeFactor(uint256 mintedCollateralFactor, uint256 healthFactor)
        public
        view
        returns (uint256 p, uint256 q)
    {
        p = mintedCollateralFactor * s_inrcEngine.LIQUIDATION_THRESHOLD() * s_inrcEngine.PRECISION();
        q = healthFactor * s_inrcEngine.LIQUIDATION_PRECISION();
    }
}
