//SPDX-License-Identifier:MIT

pragma solidity 0.8.19;
//0xEBdD7E9e0fEC8bc8fe50483323885b6577F2DCb5
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Cardano is ERC20{
    constructor(uint256 _totalSupply) ERC20("Cardano","ADA"){
        _mint(msg.sender,_totalSupply);
    }
}