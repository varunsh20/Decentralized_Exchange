//SPDX-License-Identifier:MIT

pragma solidity 0.8.19;

import "./DexPair.sol";
contract DexFactory{

    address[] private allPairs;
    mapping(address=>mapping(address=>address)) public getPair;

    event PoolCreated(
        address indexed tokenA,
        address indexed tokenB,
        address poolAddress
    );

    function createPair(address _tokenA, address _tokenB) public{
        require(_tokenA!=address(0) || _tokenB!=address(0),"Invalid Token address");
        require(_tokenA!=_tokenB,"Can not create pool with same token address");
        (address tokenA,address tokenB) = _tokenA<_tokenB?(_tokenA,_tokenB):(_tokenB,_tokenA);
        Pool pool = new Pool(tokenA,tokenB);
        address poolAddress = address(pool);
        getPair[tokenA][tokenB] = poolAddress;
        getPair[tokenB][tokenA] = poolAddress;
        allPairs.push(poolAddress);
        emit PoolCreated(tokenA,tokenB,poolAddress);
    }

    function getPairsLength() public view returns(uint256){
        return allPairs.length;
    }
}