//SPDX-License-Identifier:MIT
//0x7f6AE96FEBC5c58cC97656392927dD27b7070FE8
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Polygon is ERC20{
    constructor(uint256 _totalSupply) ERC20("Polygon","MATIC"){
        _mint(msg.sender,_totalSupply);
    }
}