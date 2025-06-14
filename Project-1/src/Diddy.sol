//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Diddy is ERC20{
    // ERC20 e vikane na constructor 
    constructor(uint256 initialSupply) ERC20("Diddy", "DDS"){
        _mint(msg.sender, initialSupply);
    }

}