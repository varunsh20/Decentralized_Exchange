//SPDX-License-Identifier:MIT

pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Aave is ERC20{
    constructor(uint256 _totalSupply) ERC20("Aave","Aave"){
        _mint(msg.sender,_totalSupply);
    }
}