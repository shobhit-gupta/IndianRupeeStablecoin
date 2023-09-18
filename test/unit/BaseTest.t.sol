// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import {Test} from "forge-std/Test.sol";

abstract contract BaseTest is Test {
    /*

                            TYPE DECLARATIONS

                                                                  */

    struct Users {
        address payable admin;
        address payable alice;
        address payable bob;
        address payable eve;
    }

    /*

                                 STATE

                                                                  */

    uint256 constant STARTING_BALANCE = 0.399 ether;
    Users internal users;

    /*

                                MODIFIERS

                                                                  */

    modifier prank(address user) {
        changePrank(user);
        _;
        vm.stopPrank();
    }

    // flag    isOnSepolia         Run         Skip
    // 0               0           1              0
    // 0               1           0              1
    // 1               0           0              1
    // 1               1           1              0
    //
    // !flag^isOnSepolia V flag^!isOnSepolia

    modifier runOnSepolia(bool flag) {
        vm.skip((flag && !isOnSepolia()) || (!flag && isOnSepolia()));
        _;
    }

    modifier runOnAnvil(bool flag) {
        vm.skip((flag && !isOnAnvil()) || (!flag && isOnAnvil()));
        _;
    }

    modifier runOnMainnet(bool flag) {
        vm.skip((flag && !isOnMainnet()) || (!flag && isOnMainnet()));
        _;
    }

    /*

                                FUNCTIONS

                                                                  */

    /// @dev Setup function called before each testcase
    function setUp() public virtual {
        users = Users({
            admin: createUser("ADMIN"),
            alice: createUser("ALICE"),
            bob: createUser("BOB"),
            eve: createUser("EVE")
        });

        // Admin will be the default caller, i.e. `msg.sender` for all the subsequent calls
        // vm.startPrank({msgSender: users.admin});
    }

    /// @notice Uses the provided name to create a payable address, label it and add some funds to it.
    function createUser(string memory name) internal virtual returns (address payable addr) {
        uint256 key = vm.envUint(name);
        addr = payable(vm.rememberKey(key));
        // addr = payable(makeAddr(name));
        vm.deal({account: addr, newBalance: STARTING_BALANCE});
    }

    function isOnAnvil() public view returns (bool) {
        return block.chainid == 31337;
    }

    function isOnSepolia() public view returns (bool) {
        return block.chainid == 11155111;
    }

    function isOnMainnet() public view returns (bool) {
        return block.chainid == 1;
    }
}
