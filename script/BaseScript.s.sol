// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";

/**
 * @title Broadcaster
 * @author Shobhit Gupta
 * @notice Abstract contract meant to be used with `BaseScript` contract.
 * This contract manages the broadcaster i.e. the address that broadcasts on the chain.
 */
abstract contract Broadcaster is Script {
    /*

                            TYPE DECLARATIONS

                                                                  */

    enum BroadcasterType {
        ALREADY_IN_WALLET,
        PRIVATE_KEY,
        MNEMONIC
    }

    /*

                                 STATE

                                                                  */

    /// @notice If the none of the environment variable are provided, the Anvil Wallet will be used by default.
    string internal constant ANVIL_MNEMONIC = "test test test test test test test test test test test junk";

    /// @notice The address of the transaction broadcaster.
    address internal s_broadcaster;

    /// @notice The current mechanism through which the broadcaster is set.
    BroadcasterType internal s_broadcasterType;

    /// @notice Used to define a wallet.
    string internal s_mnemonic;

    /*

                                 ERRORS

                                                                  */

    error Broadcaster__Type_NotMnemonic();

    /*

                                MODIFIERS

                                                                  */

    modifier broadcast() {
        vm.startBroadcast(s_broadcaster);
        _;
        vm.stopBroadcast();
    }

    /*

                                FUNCTIONS

                                                                  */

    /**
     * @dev Initializes the transaction broadcaster as follows:
     * - If broadcaster's address `$ETH_FROM` is defined,
     *     - use it.
     *     - @notice private key is either stored in Forge's local wallet or provided through CLI.
     * - Otherwise,
     *     - If `$PRIVATE_KEY` is defined,
     *         - derive the broadcaster address & remember the private key in forge's local wallet.
     *     - Otherwise, if `$MNEMONIC` is defined,
     *         - derive & remember a private key & corresponding broadcaster address from it.
     *     - If `$MNEMONIC` is not defined,
     *         - default to a test mnemonic.
     *         - derive & remember a private key & corresponding broadcaster address from it.
     */
    constructor() {
        address from = vm.envOr({name: "ETH_FROM", defaultValue: address(0)});

        if (from != address(0)) {
            setBroadcaster(from);
        } else {
            uint256 key = vm.envOr({name: "PRIVATE_KEY", defaultValue: uint256(0)});
            if (key != 0) {
                setBroadcaster(key);
            } else {
                s_mnemonic = vm.envOr({name: "MNEMONIC", defaultValue: ANVIL_MNEMONIC});
                setBroadcaster(s_mnemonic);
            }
        }
    }

    /**
     * @notice Sets a label `label` for `broadcaster` in test traces.
     * If an address is labelled, the label will show up in test traces instead of the address.
     */
    function setLabel(string memory label) public {
        vm.label(s_broadcaster, label);
    }

    /**
     * @notice Set the broadcaster either from
     * 1. default Forge's wallet, or
     * 2. User provided private key from CLI
     * Therefore, user is already "known" i.e. user's private key is already known
     * to the wallet => address is enough to determine the user.
     * @dev Foundry may pretend or prank to be a particular user
     * even if the key is not known as long as broadcast is done on it's local chain.
     */
    function setBroadcaster(address anAddress) public {
        s_broadcaster = anAddress;
        s_broadcasterType = BroadcasterType.ALREADY_IN_WALLET;
    }

    /**
     * @notice Set the broadcaster by
     * - Generating address from the private key.
     */
    function setBroadcaster(uint256 privateKey) public {
        s_broadcaster = vm.rememberKey(privateKey);
        s_broadcasterType = BroadcasterType.PRIVATE_KEY;
    }

    /**
     * @notice Set the broadcaster by
     * - Generating a wallet from mnemonic, and
     * - Using the account at index 0.
     */
    function setBroadcaster(string memory mnemonic) public {
        (s_broadcaster,) = deriveRememberKey(mnemonic, 0);
        s_broadcasterType = BroadcasterType.MNEMONIC;
    }

    /**
     * @notice Set the broadcaster by
     * - Using already generated wallet as defined by
     * `setBroadcaster(string mnemonic)`, and
     * - Using the account at the new index
     */
    function setBroadcaster(uint32 index) public {
        if (s_broadcasterType != BroadcasterType.MNEMONIC) {
            revert Broadcaster__Type_NotMnemonic();
        }
        (s_broadcaster,) = deriveRememberKey(s_mnemonic, index);
    }

    function setAnvilBroadcaster() public {
        setBroadcaster(ANVIL_MNEMONIC);
        setLabel("Anvil/0");
    }

    /*
                         FUNCTIONS / View & Pure
                                                                  */

    function currentBradcasterType() public view returns (BroadcasterType) {
        return s_broadcasterType;
    }

    function getBroadcaster() public view returns (address) {
        return s_broadcaster;
    }
}

/**
 * @title Config
 * @author Shobhit Gupta
 * @notice Abstract contract meant to be used with `BaseScript` contract.
 * This contract maanages the configuration i.e. the data that is required to initiate
 * relevant contracts on specific chains.
 */
contract Config is Broadcaster {
    /*

                            TYPE DECLARATIONS

                                                                  */

    /**
     * @dev This needs to be modified for each project's requirement.
     * Typically it contains all the data the contract's constructor needs
     * and any other setting or data that might be needed for correct working
     * of the contract to depoly.
     */
    struct Data {
        address weth;
        address wbtc;
        address wethUSDPriceFeed;
        address wbtcPriceFeed;
        address inrToUSDPriceFeed;
    }

    /*

                                 STATE

                                                                  */

    uint256 public constant CHAINID_MAINNET = 1;
    uint256 public constant CHAINID_SEPOLIA = 11155111;
    uint256 public constant CHAINID_ANVIL = 31337;
    uint256 public constant ERC20_STARTING_BALANCE = 1000e18;
    uint8 public constant DECIMALS = 8;
    int256 public constant WETH_USD_PRICE = 2000e8;
    int256 public constant WBTC_USD_PRICE = 25000e8;
    int256 public constant INR_USD_PRICE = 0.012e8;

    Data public current;

    /*

                                FUNCTIONS

                                                                  */

    constructor() {
        if (block.chainid == CHAINID_MAINNET) {
            current = _mainnet();
        } else if (block.chainid == CHAINID_SEPOLIA) {
            current = _sepolia();
        } else if (block.chainid == CHAINID_ANVIL) {
            current = _anvil();
        }
    }

    function _anvil() private returns (Data memory) {
        if (current.weth != address(0)) {
            return current;
        }
        setAnvilBroadcaster();
        return _deployMockContracts();
    }

    function _sepolia() private pure returns (Data memory) {
        return Data({
            weth: 0x66be7F22C8A7be7203CDD56D5292dF7156C37878,
            wbtc: 0xf470576384c8f2b031BF6321a6c15cB7d626e9F9,
            wethUSDPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            wbtcPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            // Chainlink doesn't offer INR feed on testnets. Therefore, we use JPY / USD feed for testnet testing
            inrToUSDPriceFeed: 0x8A6af2B75F23831ADc973ce6288e5329F63D86c6
        });
    }

    function _mainnet() private pure returns (Data memory) {
        return Data({
            weth: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            wbtc: 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599,
            wethUSDPriceFeed: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419,
            wbtcPriceFeed: 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c,
            inrToUSDPriceFeed: 0x605D5c2fBCeDb217D7987FC0951B5753069bC360
        });
    }

    function _deployMockContracts() private broadcast returns (Data memory) {
        MockERC20 weth = new MockERC20("WETH", "WETH", msg.sender, ERC20_STARTING_BALANCE);
        MockERC20 wbtc = new MockERC20("WBTC", "WBTC", msg.sender, ERC20_STARTING_BALANCE);
        MockV3Aggregator wethUSDPriceFeed = new MockV3Aggregator(DECIMALS, WETH_USD_PRICE);
        MockV3Aggregator wbtcPriceFeed = new MockV3Aggregator(DECIMALS, WBTC_USD_PRICE);
        MockV3Aggregator inrToUSDPriceFeed = new MockV3Aggregator(DECIMALS, INR_USD_PRICE);

        return Data(
            address(weth), address(wbtc), address(wethUSDPriceFeed), address(wbtcPriceFeed), address(inrToUSDPriceFeed)
        );
    }
}

/// @notice Abstract contract to be used as a base for all of the Foundry scripts
abstract contract BaseScript is Broadcaster {
    Config private s_config;

    constructor() {
        s_config = new Config();
    }

    function getConfig() internal view returns (Config) {
        return s_config;
    }
}
