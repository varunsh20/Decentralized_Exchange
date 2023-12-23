//SPDX-License-Identifier:MIT

pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Optimism is ERC20{
    constructor(uint256 _totalSupply) ERC20("Optimism","OP"){
        _mint(msg.sender,_totalSupply);
    }
}