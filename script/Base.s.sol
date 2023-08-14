// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import {Script} from "forge-std/Script.sol";

/// @title Base Script
/// @author Shobhit Gupta
/// @notice Abstract contract to be used as a base for all of the Foundry scripts
/// @dev Adapted from https://github.com/PaulRBerg/prb-contracts/blob/main/script/Base.s.sol
abstract contract BaseScript is Script {
    /// @dev If the $MNEMONIC environment variable is not provided, the Anvil Wallet will be used by default.
    string internal constant TEST_MNEMONIC = "test test test test test test test test test test test junk";

    /// @dev Used to derive broadcaster's address.
    string internal mnemonic;

    /// @dev The address of the transaction broadcaster.
    address internal broadcaster;

    /// @dev Initializes the transaction broadcaster like this:
    ///
    /// - If broadcaster's address `$ETH_FROM` is defined,
    ///     - use it.
    ///     - @notice private key is either stored in Forge's local wallet or provided through CLI.
    /// - Otherwise,
    ///     - If `$PRIVATE_KEY` is defined,
    ///         - derive the broadcaster address & remember the private key in forge's local wallet.
    ///     - Otherwise, if `$MNEMONIC` is defined,
    ///         - derive & remember a private key & corresponding broadcaster address from it.
    ///     - If `$MNEMONIC` is not defined,
    ///         - default to a test mnemonic.
    ///         - derive & remember a private key & corresponding broadcaster address from it.
    constructor() {
        address from = vm.envOr({name: "ETH_FROM", defaultValue: address(0)});
        if (from != address(0)) {
            broadcaster = from;
        } else {
            uint256 key = vm.envOr({name: "PRIVATE_KEY", defaultValue: uint256(0)});
            if (key != 0) {
                broadcaster = vm.rememberKey(key);
            } else {
                mnemonic = vm.envOr({name: "MNEMONIC", defaultValue: TEST_MNEMONIC});
                (broadcaster,) = deriveRememberKey({mnemonic: mnemonic, index: 0});
            }
        }
    }

    modifier broadcast() {
        vm.startBroadcast(broadcaster);
        _;
        vm.stopBroadcast();
    }
}
