// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title INRC (INdian Rupee stableCoin)
/// @author Shobhit Gupta
/// Relative Stability: Pegged to INR
/// Stability Method: Algorithmic
/// Collateral: Exogenous (wETH, wBTC)
/// @dev This contract is meant to be goverend by INRCEngine.
/// This contract is just the ERC20 implementation of that
/// stablecoin system.
contract INRC is ERC20Burnable, Ownable {
    constructor() ERC20("IndianRupeeStablecoin", "INRC") {}

    function burn(uint256 amount) public override onlyOwner {
        super.burn(amount);
    }

    function mint(address to, uint256 amount) external onlyOwner returns (bool) {
        _mint(to, amount);
        return true;
    }
}
