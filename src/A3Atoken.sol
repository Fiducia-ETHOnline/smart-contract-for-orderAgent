// SPDX-License-Identifier: MIT

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.18;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";


contract A3AToken is ERC20Burnable, Ownable {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error A3AToken__BurnAmountMustBeMoreThanZero();
    error A3AToken__BurnAmountMustBeMoreThanBalance();
    error A3AToken__MintToTheZeroAddress();
    error A3AToken__MintAmountMustBeMoreThanZero();
    
    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    constructor() ERC20("A3A Token", "A3A") Ownable(msg.sender) {}

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);

        if (_amount <= 0) {
            revert A3AToken__BurnAmountMustBeMoreThanZero();
        }
        if (balance < _amount) {
            revert A3AToken__BurnAmountMustBeMoreThanBalance();
        }
        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert A3AToken__MintToTheZeroAddress();
        }
        if (_amount <= 0) {
            revert A3AToken__MintAmountMustBeMoreThanZero();
        }
        _mint(_to, _amount);
        return true;
    }
}
