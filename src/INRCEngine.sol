// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import {INRC} from "./INRC.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {console} from "forge-std/console.sol";

/**
 * @title INRCEngine
 * @author Shobhit Gupta
 *
 * 1 token == ₹1
 * A minimal stablecoin system that is similar to MakerDAO DSS (DAI) if DAI
 * had no governance, no fees and was only backd by wETH and wBTC.
 *
 * INRC system should always be over-collateralized, i.e. At all times
 * `Total Collateral > ₹ Backed Value of all the INRC`
 *
 * Example:
 * In a INRCEngine with 150% threshold, consider a user with
 * ₹100 worth wETH Collateral, INRC50 loan
 * => For INRC50 the user needs to maintain collateral worth at least ₹75.
 * Now say, the market fluctuates, ETH drops and now the collateral is worth only ₹74.
 * => User is under collateralized. So anyone can liquidate them.
 * i.e. Any user can pay back INRC50 that was borrowed and get collateral worth ₹74.
 *
 * @notice This contract is the core of the INRC system. It handles all the logic for
 * mining and redeeming INRC, as well as depositing and withdrawing collateral.
 */
contract INRCEngine is ReentrancyGuard {
    /*

                                 STATE

                                                                  */

    uint256 public constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 public constant PRECISION = 1e18;

    /// @notice This value is to protect the protocol from the risk of under-collateralisation
    uint256 public constant LIQUIDATION_THRESHOLD = 50; // => 200% over-collaterized
    uint256 public constant LIQUIDATION_PRECISION = 100;
    uint256 public constant LIQUIDATION_BONUS = 10; // => 10% bonus

    /// @notice This value is/maybe used for protecting the user from the risk of liquidation.
    /// A value of `1` is bare minimum & offers no protection to the user.
    uint256 public constant MIN_HEALTH_FACTOR = 1 * PRECISION;

    /*

                          STATE / VARIABLES

                                                                  */

    INRC private immutable i_inrc;

    address private s_inrToUSDPriceFeed;

    /**
     * @notice It's a common misnomer to use the word `token` in place of `Token Contract` or
     * `Address of Token Contract`. `Token` is perhaps more correctly defined as the `balance`
     * of some asset in a `Token Contract`. At times, this causes some confusion amongst
     * those who are new to Smart Contract development.
     * For *this* project, as an exercise for clarity, I have chosen to be more pedantic and use the
     * naming like `tknCx` or `tknCxAddr` short for `Token Contract` or `Token Contract Address`
     */
    address[] private s_listOfCollateralTknCxAddr;
    mapping(address collateralTknCxAddr => address usdPriceFeedAddr) private s_usdPriceFeedOf;

    mapping(address user => mapping(address collateralTknCxAddr => uint256 amount)) s_collateralBy;
    mapping(address user => uint256 amount) s_inrcMintedBy;

    /*

                                EVENTS

                                                                  */

    event DepositedCollateral(address indexed user, address indexed collateralTknCxAddr, uint256 amount);
    event RedeemedCollateral(
        address indexed from, address indexed to, address indexed collateralTknCxAddr, uint256 amount
    );

    /*

                                ERRORS

                                                                  */

    error INRCEngine__Amount_IsZero();
    error INRCEngine__Collateral_Invalid();
    error INRCEngine__CollateralsAndPriceFeeds_LengthsMismatch();
    error INRCEngine__CollateralsAndPriceFeeds_EmptyLists();
    error INRCEngine__HealthFactor_Breaks(uint256 healthFactor);
    error INRCEngine__HealthFactor_IsOkay(uint256 healthFactor);
    error INRCEngine__HealthFactor_NotImproved();
    error INRCEngine__Mint_Failed();
    error INRCEngine__Transfer_Failed();
    error INRCEngine__PriceFeed_ReturnsZero();

    /*

                                MODIFIERS

                                                                  */

    modifier isAmountGtZero(uint256 amount) {
        if (amount == 0) {
            revert INRCEngine__Amount_IsZero();
        }
        _;
    }

    modifier isCollateralAllowed(address collateralTknCxAddr) {
        if (s_usdPriceFeedOf[collateralTknCxAddr] == address(0)) {
            revert INRCEngine__Collateral_Invalid();
        }
        _;
    }

    /*

                                FUNCTIONS

                                                                  */

    /**
     * @dev Constructor is parametrised to support multiple chains
     * @param listOfCollateralTknCxAddr List of allowed collateral token contract's address
     * @param listOfUSDPriceFeedAddr List of addresses of corresponding price feeds of form CollateralToken / USD.
     * @param inrcTknCxAddr Address of INRC Token Contract
     * Example: For chain C -
     * listOfCollateralTknCxAddr = [0x34...., 0x74...] where,
     * - 0x34...: Address of wETH token contract on chain C.
     * - 0x74...: Address of wBTC token contract on chain C.
     * listOfUSDPriceFeedAddr = [0x9f..., 0xfa...] where,
     * - 0x9f...: Address of chainlink price feed contract for wETH / INR on chain C.
     * - 0xfa...: Address of chainlink price feed contract for wBTC / INR on chain C.
     */
    constructor(
        address[] memory listOfCollateralTknCxAddr,
        address[] memory listOfUSDPriceFeedAddr,
        address inrToUSDPriceFeed,
        address inrcTknCxAddr
    ) {
        if (listOfCollateralTknCxAddr.length != listOfUSDPriceFeedAddr.length) {
            revert INRCEngine__CollateralsAndPriceFeeds_LengthsMismatch();
        }

        if (listOfCollateralTknCxAddr.length == 0) {
            revert INRCEngine__CollateralsAndPriceFeeds_EmptyLists();
        }

        for (uint256 i = 0; i < listOfCollateralTknCxAddr.length; i++) {
            address tknCxAddr = listOfCollateralTknCxAddr[i];
            s_usdPriceFeedOf[tknCxAddr] = listOfUSDPriceFeedAddr[i];
            s_listOfCollateralTknCxAddr.push(tknCxAddr);
        }

        s_inrToUSDPriceFeed = inrToUSDPriceFeed;
        i_inrc = INRC(inrcTknCxAddr);
    }

    /*
                        FUNCTIONS / EXTERNAL
                                                                  */

    /**
     * @notice This function allows a user to deposit a collateral of their choosing.
     * The user must `approve` the transfer before calling this function.
     * @param collateralTknCxAddr Address of collateral token contract.
     * @param amount The amount of tokens of `collateralTknCx` to be deposited
     */
    function depositCollateral(address collateralTknCxAddr, uint256 amount)
        public
        isAmountGtZero(amount)
        isCollateralAllowed(collateralTknCxAddr)
        nonReentrant
    {
        s_collateralBy[msg.sender][collateralTknCxAddr] += amount;
        emit DepositedCollateral(msg.sender, collateralTknCxAddr, amount);
        bool success = IERC20(collateralTknCxAddr).transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert INRCEngine__Transfer_Failed();
        }
    }

    /**
     * @notice Caller must have more collateral than the minimum threshold
     * @param amount The amount of INRC stablecoin to mint
     */
    function mintINRC(uint256 amount) public isAmountGtZero(amount) nonReentrant {
        s_inrcMintedBy[msg.sender] += amount;
        _revertIfHealthFactorIsBad(msg.sender);
        bool minted = i_inrc.mint(msg.sender, amount);
        if (!minted) {
            revert INRCEngine__Mint_Failed();
        }
        // Should emit an event
    }

    /**
     * @notice deposit collateral & mint INRC in a single transaction.
     * @param collateralTknCxAddr Address of collateral token contract.
     * @param amountCollateral The amount of tokens of `collateralTknCx` to be deposited
     * @param amountINRC The amount of INRC stablecoin to mint
     */
    function depositCollateralAndMintINRC(address collateralTknCxAddr, uint256 amountCollateral, uint256 amountINRC)
        external
    {
        depositCollateral(collateralTknCxAddr, amountCollateral);
        mintINRC(amountINRC);
    }

    /**
     * @notice health factor must be oer 1 after collateral is redeemed
     * @param collateralTknCxAddr Address of collateral token contract.
     * @param amount The amount of collateral to redeem
     */
    function redeemCollateral(address collateralTknCxAddr, uint256 amount)
        public
        isAmountGtZero(amount)
        isCollateralAllowed(collateralTknCxAddr)
        nonReentrant
    {
        _redeemCollateral({collateralTknCxAddr: collateralTknCxAddr, amount: amount, from: msg.sender, to: msg.sender});
        // console.log(getHealthFactor(msg.sender));
        _revertIfHealthFactorIsBad(msg.sender);
    }

    /**
     * @notice burn INRC tokens and redeem underlying collateral in a single transaction.
     * @param collateralTknCxAddr Address of collateral token contract.
     * @param amountCollateral The amount of collateral to redeem
     * @param inrcAmountToBurn The amount of INRC token to burn
     */
    function redeemCollateralForINRC(address collateralTknCxAddr, uint256 amountCollateral, uint256 inrcAmountToBurn)
        external
    {
        burnINRC(inrcAmountToBurn);
        redeemCollateral(collateralTknCxAddr, amountCollateral);
        // Health Factor should be checked here but, `redeemCollateral` already does that.
    }

    /**
     * @notice this function transfers the INRC tokens to this contract itself & then
     * calls the INRC's `burn` function.
     * @param amount The amount of INRC token to burn
     */
    function burnINRC(uint256 amount) public isAmountGtZero(amount) {
        _burnINRC({from: msg.sender, onBehalfOf: msg.sender, amount: amount});
    }

    /**
     * @notice If a user (defaulter) starts nearing undercollateralization, the protocol needs someone to liquidate positions.
     * @notice The protocol in turn rewards liquidators with liquidation bonus for their service.
     * @notice Liquidator can partially liquidate a defaulter.
     * @notice This function assumes the protocol will be roughly 200% overcollateralized in order for this to work.
     *
     * @notice A known bug: If the protocol was just- (100%) or under-collateralized, then it cannot incentivize the liquidators.
     * Example, if price of collateral plumeted before anyone could be liquidated.
     *
     * @param defaulter Address of user with broken health factor, whose debt the liquidator wishes to cover.
     * @param collateralTknCxAddr Address of collateral token contract.
     * @param debtToCover Amount of debt (in INRC) the liquidator wishes to cover
     */
    function liquidate(address defaulter, address collateralTknCxAddr, uint256 debtToCover)
        external
        isAmountGtZero(debtToCover)
        isCollateralAllowed(collateralTknCxAddr)
        nonReentrant
    {
        // Check if the user who is going to be liquidated is actually a defaulter
        uint256 preLiquidationHealthFactor = _healthFactorOf(defaulter);
        if (preLiquidationHealthFactor >= MIN_HEALTH_FACTOR) {
            revert INRCEngine__HealthFactor_IsOkay(preLiquidationHealthFactor);
        }

        // Redeem defaulter's collateral to reward the liquidator
        uint256 debtToCoverInTkns = getTknCxEquivalentOfINRC(collateralTknCxAddr, debtToCover);
        uint256 reward = debtToCoverInTkns * LIQUIDATION_BONUS / LIQUIDATION_PRECISION;
        uint256 amountToRedeem = debtToCoverInTkns + reward;
        _redeemCollateral({
            collateralTknCxAddr: collateralTknCxAddr,
            amount: amountToRedeem,
            from: defaulter,
            to: msg.sender
        });

        // Burn INRC from the liquidator to cover defaulter's debt
        _burnINRC({from: msg.sender, onBehalfOf: defaulter, amount: debtToCover});

        uint256 postLiquidationHealthFactor = _healthFactorOf(defaulter);

        if (postLiquidationHealthFactor <= preLiquidationHealthFactor) {
            revert INRCEngine__HealthFactor_NotImproved();
        }
    }

    /*
                  FUNCTIONS / Private & Internal View
                                                                  */

    function _getUSDValueOf(address tknCxAddr, uint256 amount) private view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_usdPriceFeedOf[tknCxAddr]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }

    function _getBalanceOf(address user) private view returns (uint256 inrcMinted, uint256 inrCollateralValue) {
        inrcMinted = s_inrcMintedBy[user];
        inrCollateralValue = getINRValueOfCollateralFor(user);
    }

    /**
     * @notice Returns how close to liquidation a user *currently* is.
     * As the value of collateral fluctuates, so will the health factor.
     * @dev Actual returned value is multiplied by 1e18.
     * @return healthFactor In accordance with the liquidation threshold, a measure which,
     *  - if < 1 => user is currently under-collaterised
     *  - if > 1 => user is currently over-collaterised
     *  - if = 1 => user is on the brink of liquidation
     */
    function _healthFactorOf(address user) private view returns (uint256 healthFactor) {
        // Compare
        // - Total INRC Minted
        // - Value(Total Collateral)
        (uint256 inrcMinted, uint256 inrCollateralValue) = _getBalanceOf(user);

        if (inrCollateralValue == 0) {
            healthFactor = 0;
        } else if (inrcMinted == 0) {
            healthFactor = type(uint256).max;
        } else {
            uint256 adjustedCollateral = (inrCollateralValue * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
            healthFactor = (adjustedCollateral * PRECISION) / inrcMinted;
        }
    }

    // 1. Check if the user has a good health factor
    //      - Do they have enough collateral?
    // 2. Revert if the user doesn't
    function _revertIfHealthFactorIsBad(address user) internal view {
        uint256 userHealthFactor = _healthFactorOf(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert INRCEngine__HealthFactor_Breaks(userHealthFactor);
        }
    }

    function _redeemCollateral(address collateralTknCxAddr, uint256 amount, address from, address to) private {
        s_collateralBy[from][collateralTknCxAddr] -= amount;
        emit RedeemedCollateral(from, to, collateralTknCxAddr, amount);
        bool success = IERC20(collateralTknCxAddr).transfer(to, amount);
        if (!success) {
            revert INRCEngine__Transfer_Failed();
        }
    }

    /**
     * @dev Low-level internal function. Do not call unless the caller checks for health factor etc.
     */
    function _burnINRC(address from, address onBehalfOf, uint256 amount) private {
        s_inrcMintedBy[onBehalfOf] -= amount;
        bool success = i_inrc.transferFrom(from, address(this), amount);
        // This condition is hypothetically unreachable
        if (!success) {
            revert INRCEngine__Transfer_Failed();
        }
        i_inrc.burn(amount);
        // it should emit a burn event
    }

    /*
                         FUNCTIONS / View & Pure
                                                                  */

    /**
     *
     */
    function getTknCxEquivalentOfINRC(address tknCxAddr, uint256 inrcAmountInWei)
        public
        view
        isCollateralAllowed(tknCxAddr)
        returns (uint256)
    {
        // inrcAmountInWei * 1 INR * (u USD / 1 INR) * (t TKN / 1 USD)
        AggregatorV3Interface inrPriceFeed = AggregatorV3Interface(s_inrToUSDPriceFeed);
        (, int256 usdToINRPrice,,,) = inrPriceFeed.latestRoundData();
        AggregatorV3Interface usdPriceFeed = AggregatorV3Interface(s_usdPriceFeedOf[tknCxAddr]);
        (, int256 usdToTknPrice,,,) = usdPriceFeed.latestRoundData();

        if (usdToTknPrice == 0) {
            revert INRCEngine__PriceFeed_ReturnsZero();
        }

        /// @dev Use of PRECISION & ADDITIONAL_FEED_PRECISION is probably not required
        // Example,
        // 150K INR ≈ 1 ETH
        // => 75K INR ≈ 0.5 ETH
        // Therefore, if inrcAmountInWei = 75_000e18
        // inrcAmountInWei * uint256(usdToINRPrice) / uint256(usdToTknPrice)
        // = 75_000e18 * (0.012e8) / (1631e8)
        // = 75_000e18 * (0.012 / 1631)
        // ≈ 0.55e18
        return inrcAmountInWei * uint256(usdToINRPrice) / uint256(usdToTknPrice);
    }

    /**
     * For each collateral token, get the amount the user has deposited, use
     * chainlink price feed to map the it to it's value in ₹.
     */
    function getINRValueOfCollateralFor(address user) public view returns (uint256 totalCollateralValueInINR) {
        for (uint256 i = 0; i < s_listOfCollateralTknCxAddr.length; i++) {
            address tknCxAddr = s_listOfCollateralTknCxAddr[i];
            uint256 amount = s_collateralBy[user][tknCxAddr];
            totalCollateralValueInINR += getINRValueOf(tknCxAddr, amount);
        }
    }

    /**
     * @dev Chainlink doesn't provide price feeds for direct conversions between INR & cryptos
     * Hence, this function first gets the USD value for the amount of specific token.
     */
    function getINRValueOf(address tknCxAddr, uint256 amount)
        public
        view
        isCollateralAllowed(tknCxAddr)
        returns (uint256)
    {
        uint256 usdValue = _getUSDValueOf(tknCxAddr, amount);
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_inrToUSDPriceFeed);
        (, int256 price,,,) = priceFeed.latestRoundData();
        if (price == 0) {
            revert INRCEngine__PriceFeed_ReturnsZero();
        }
        return (usdValue * PRECISION) / ((uint256(price) * ADDITIONAL_FEED_PRECISION));
    }

    /**
     * @notice Returns the collateral deposited by the `depositer` of type `collateralTknCxAddr`
     */
    function getCollateralDepositedBy(address depositer, address collateralTknCxAddr) public view returns (uint256) {
        return s_collateralBy[depositer][collateralTknCxAddr];
    }

    function getINRCMintedBy(address user) public view returns (uint256) {
        return s_inrcMintedBy[user];
    }

    function getHealthFactor(address user) public view returns (uint256) {
        return _healthFactorOf(user);
    }
}
