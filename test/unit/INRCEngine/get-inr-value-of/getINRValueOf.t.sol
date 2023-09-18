// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import {INRCEngine_Test} from "../INRCEngine.t.sol";
// import {console} from "forge-std/Test.sol";

/// @notice Chainlink doesn't offer INR price feed on testnets.
/// Therefore, we use JPY / USD feed for testnet testing
contract GetINRValueOf_Test is INRCEngine_Test {
    uint256 constant TEST_AMOUNT = 15e18;

    function setUp() public virtual override {
        INRCEngine_Test.setUp();
    }

    /// @dev WETH_JPY_PRICE must be up-to-date with current prices.
    /// Simply use `1 eth to jpy` Google search
    function test_GetINRValueOf_Weth() external {
        uint256 expectedValue = ethToINR(TEST_AMOUNT);
        uint256 actualValue = s_inrcEngine.getINRValueOf(s_weth, TEST_AMOUNT);
        assertApproxEqAbs({a: expectedValue, b: actualValue, maxDelta: expectedValue / 100});
    }

    /// @dev WBTC_JPY_PRICE must be up-to-date with current prices.
    /// Simply use `1 btc to jpy` Google search
    function test_GetINRValueOf_Wbtc() external {
        uint256 expectedValue = btcToINR(TEST_AMOUNT);
        uint256 actualValue = s_inrcEngine.getINRValueOf(s_wbtc, TEST_AMOUNT);
        assertApproxEqAbs({a: expectedValue, b: actualValue, maxDelta: expectedValue / 100});
    }
}
