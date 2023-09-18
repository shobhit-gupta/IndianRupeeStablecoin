// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import {console, Test} from "forge-std/Test.sol";
import {BaseScript} from "../../../script/BaseScript.s.sol";

/**
 *
 * @notice After constant effort it has become obvious that
 * Foundry's cheatcode for setting environment variables
 * `vm.setEnv()` is buggy & unreliable making this entire
 * test file useless. Even though each test is passing in
 * isolation when exeecuted with `forge test --mt TEST_NAME`
 *
 * TODO: Come back to this afer sometime with newer versions
 * of Foundry.
 *
 */

/// @title BaseScriptTest__DummyContract
/// @author Shobhit Gupta
/// @dev A helper contract to test BaseScript.
/// @notice This contract just stores the address that deployed it.
// contract BaseScriptTest__DummyContract {
//     address public immutable i_owner;

//     constructor() {
//         i_owner = msg.sender;
//     }
// }

// contract BaseScriptTest__DummyDeployer is BaseScript {
//     function run() public virtual broadcast returns (BaseScriptTest__DummyContract ownedContract) {
//         ownedContract = new BaseScriptTest__DummyContract();
//     }
// }

// contract BaseScriptTest is Test {}

// contract BroadcastWithAddressAndKey_Test is BaseScriptTest {
//     // when non-zero broadcasting address is provided
//     modifier whenNonZeroBroadcasterProvided() {
//         vm.setEnv("ETH_FROM", "0xcb23972804F83be9E4a223357749B0FD4Cc790B1");
//         _;
//     }

//     // when the private key is not available
//     modifier whenNoKeyProvided() {
//         _;
//     }

//     function test_WithAddress_RevertWhen_MissingKey() external whenNonZeroBroadcasterProvided whenNoKeyProvided {
//         /**
//          * @dev (In)conveniently, foundry automatically pranks to $ETH_FROM without the need
//          * of the private key during testing. So far, I haven't find a way to prevent this
//          * behavior.
//          * Threfore, `expectRevert` line is commented out.
//          * @notice On manual verification, such a call fails (as expected) on testnet etc.
//          * This was verified with the following command:
//          * `forge script test/unit/BaseScript/broadcast.t.sol:BaseScriptTest__DummyDeployer --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast`
//          * where both $PRIVATE_KEY & $ETH_FROM, defined in `.env` file,
//          * and were not assoiciated with each other.
//          *
//          * $PRIVATE_KEY was necessary to be defined for the script to attempt contract creation
//          * on Sepolia RPC. It resulted in the following error:
//          * ```
//          * Finding wallets for all the necessary addresses...
//          * No associated wallet for addresses: {$ETH_FROM}.
//          * ```
//          * Therefore, this test passes with manual verification (as it should) but, Foundry
//          * makes it hard/impossible to automate such tests AFAIK.
//          */
//         // vm.expectRevert();
//         BaseScriptTest__DummyDeployer dummyDeployer = new BaseScriptTest__DummyDeployer();
//         dummyDeployer.run();
//     }

//     // when the private key is available
//     modifier whenKeyProvided() {
//         _;
//     }

//     // when the private key is not for the broadcasting address
//     modifier whenKeyIsNotOfBroadcaster() {
//         _;
//     }

//     function test_WithAddress_RevertWhen_KeyMismatch()
//         external
//         whenNonZeroBroadcasterProvided
//         whenKeyProvided
//         whenKeyIsNotOfBroadcaster
//     {
//         /// @dev This will suffer from the same issue as described above.
//     }

//     // when the private key is for the broadcasting address
//     modifier whenKeyIsOfBroadcaster() {
//         _;
//     }

//     function test_WithAddress() external whenNonZeroBroadcasterProvided whenKeyProvided whenKeyIsOfBroadcaster {
//         /**
//          * @dev This is again tested with a similar setup as described above. The only
//          * difference is that this time around `$ETH_FROM` & `$PRIVATE_KEY` were paired.
//          * This time the transactions went through and were deployed to sepolia at:
//          * 0xDB2dA03F14625Ab76123A493AC5a2bEB0ce42136
//          */
//     }
// }

// contract BroadcastWithPrivateKey_Test is BaseScriptTest {
//     // when non-zero broadcasting address is not provided
//     modifier whenNonZeroBroadcasterNotProvided() {
//         //vm.setEnv("ETH_FROM", vm.toString(address(0)));
//         // if (isZero) {
//         //     //vm.setEnv("ETH_FROM", vm.toString(address(0)));
//         // }
//         _;
//     }

//     // when a non-zero private key is provided
//     modifier whenNonZeroKeyProvided() {
//         // vm.setEnv("PRIVATE_KEY", "0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6");
//         _;
//     }

//     function test_WithKey() external whenNonZeroBroadcasterNotProvided whenNonZeroKeyProvided {
//         vm.setEnv("ETH_FROM", "0x0");
//         vm.setEnv("PRIVATE_KEY", "0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6");

//         BaseScriptTest__DummyDeployer dummyDeployer = new BaseScriptTest__DummyDeployer();
//         console.log(dummyDeployer.getBroadcaster());
//         assert(dummyDeployer.getBroadcaster() == 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720);

//         BaseScriptTest__DummyContract dummyContract = dummyDeployer.run();

//         assert(dummyContract.i_owner() == 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720);
//     }
// }

// contract BroadcastWithMnemonic_Test is BaseScriptTest {
//     // when non-zero broadcasting address is not provided
//     modifier whenNonZeroBroadcasterNotProvided(bool isZero) {
//         vm.setEnv("ETH_FROM", vm.toString(address(0)));
//         // if (isZero) {
//         //     //vm.setEnv("ETH_FROM", vm.toString(address(0)));
//         // }
//         _;
//     }

//     // when a non-zero private key is not provided
//     modifier whenNonZeroKeyNotProvided() {
//         vm.setEnv("PRIVATE_KEY", "0");
//         _;
//     }

//     // when a mnemonic is provided
//     modifier whenMnemonicProvided() {
//         string memory mnemonic = "current cute also dismiss duck one figure weather slot color rhythm source";
//         vm.setEnv("MNEMONIC", mnemonic);
//         _;
//     }

//     function test_WithMnemonic()
//         external
//         whenNonZeroBroadcasterNotProvided(false)
//         whenNonZeroKeyNotProvided
//         whenMnemonicProvided
//     {
//         BaseScriptTest__DummyDeployer dummyDeployer = new BaseScriptTest__DummyDeployer();
//         assert(dummyDeployer.getBroadcaster() == 0xcc8587d7f16DFE176BE40396A3748d8f4E34e9D2);

//         BaseScriptTest__DummyContract dummyContract = dummyDeployer.run();
//         assert(dummyContract.i_owner() == 0xcc8587d7f16DFE176BE40396A3748d8f4E34e9D2);
//     }
// }

// contract BroadcastWithAnvilMnemonic_Test is Test {
//     // when non-zero broadcasting address is not provided
//     modifier whenNonZeroBroadcasterNotProvided(bool isZero) {
//         // vm.setEnv("ETH_FROM", vm.toString(address(0)));
//         // if (isZero) {
//         //     //vm.setEnv("ETH_FROM", vm.toString(address(0)));
//         // }
//         _;
//     }

//     // when a non-zero private key is not provided
//     modifier whenNonZeroKeyNotProvided() {
//         // vm.setEnv("PRIVATE_KEY", "0");
//         _;
//     }

//     // when a mnemonic is not provided
//     modifier whenMnemonicNotProvided() {
//         // vm.setEnv("MNEMONIC", "");
//         _;
//     }

//     function test_DefaultsToAnvil()
//         external
//         whenNonZeroBroadcasterNotProvided(false)
//         whenNonZeroKeyNotProvided
//         whenMnemonicNotProvided
//     {
//         BaseScriptTest__DummyDeployer dummyDeployer = new BaseScriptTest__DummyDeployer();
//         assert(dummyDeployer.getBroadcaster() == 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);

//         BaseScriptTest__DummyContract dummyContract = dummyDeployer.run();
//         assert(dummyContract.i_owner() == 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
//     }
// }
