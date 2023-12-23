//SPDX-License-Identifier:MIT
//0xe877f3c7de0c0d2B7eCb52eaE138f8a67a8a78b3
pragma solidity 0.8.19;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./DexLiquidityTokens.sol";

contract Pool is LiquidityToken,ReentrancyGuard{

    using SafeMath for uint;
    address public owner;
    IERC20 public immutable tokenA;
    IERC20 public immutable tokenB;
    //uint256 public constant MIN_LIQUIDITY = 10**3; //Min liquidity tokens should be locked to avoid zero division error
    uint256 private reserveA;
    uint256 private reserveB;

    uint256 public totalFeesCollectedTokenA; // Fees collected in tokenA
    uint256 public totalFeesCollectedTokenB; // Fees collected in tokenB

    event LiquidityAdded(
        address indexed tokenIn,
        uint256 tokenA,
        address indexed tokenOut,
        uint256 tokenB,
        uint256 liquidityTokens
    );

    event LiquidityRemoved(
        address indexed tokenIn,
        uint256 tokenA,
        address indexed tokenOut,
        uint256 tokenB,
        uint256 liquidityTokens
    );

    event TokenSwapped(
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        uint256 amountOut
    );

    constructor(address _tokenA,address _tokenB){
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        owner = msg.sender;
    }

    function getReserves() public view returns(uint256,uint256){
        return (reserveA,reserveB);
    }

    function updateReserves(uint256 _amount1,uint256 _amount2) private{
        reserveA = _amount1;
        reserveB = _amount2;
    }

    function updateCollectedFees(uint256 _feeA,uint256 _feeB) private{
        totalFeesCollectedTokenA = _feeA;
        totalFeesCollectedTokenB = _feeB;
    }

    function addLiquidity(uint256 _amountA, uint256 _amountB) public nonReentrant{
        require(_amountA>0 && _amountB>0,"Invalid amount");
        (uint256 _reserveA,uint256 _reserveB) = getReserves();
        if(_reserveA>0 || _reserveB>0){
            require(_reserveA.div(_reserveB) == _amountA.div(_amountB),"Invalid token ratio");
        }
        uint256 _totalSupply = totalSupply();
        uint256 liquidity;
        IERC20 _tokenA = tokenA;
        IERC20 _tokenB = tokenB;
        _tokenA.transferFrom(msg.sender,address(this),_amountA);
        _tokenB.transferFrom(msg.sender,address(this),_amountB);       
        if(_totalSupply==0){
            liquidity = Math.sqrt(_amountA.mul(_amountB));
        }
        else{
            liquidity = Math.min(_amountA.mul(_totalSupply).div(_reserveA),
            _amountB.mul(_totalSupply).div(_reserveB));
        }
        require(liquidity>0,"Insufficient Liquidity Minted");
        mint(msg.sender,liquidity); 
        updateReserves(reserveA.add(_amountA),reserveB.add(_amountB));
        emit LiquidityAdded(address(_tokenA), _amountA, address(_tokenB), _amountB, liquidity);
    }

    function removeLiquidity(uint256 _liquidityTokens) public nonReentrant{
        (uint256 amountA,uint256 amountB) = getAmountsOnRemovingLiquidty(_liquidityTokens);
        (uint256 feeA,uint256 feeB) = getFees(_liquidityTokens);
        burn(msg.sender,_liquidityTokens);
        tokenA.transfer(msg.sender,amountA);
        tokenA.transferFrom(owner,msg.sender,feeA);
        tokenB.transfer(msg.sender,amountB);
        tokenB.transferFrom(owner,msg.sender,feeB);
        updateReserves(reserveA.sub(amountA),reserveB.sub(amountB));
        updateCollectedFees(totalFeesCollectedTokenA.sub(feeA),totalFeesCollectedTokenB.sub(feeB)); 
        emit LiquidityRemoved(address(tokenA),amountA,address(tokenB),amountB,_liquidityTokens);
    }

    function swap(address _tokenIn,uint256 _amountIn) public nonReentrant{

        (uint256 _amountOut,uint256 resIn, uint256 resOut,bool isTokenA,uint256 fee) = getAmountOut(
            _tokenIn,_amountIn);
        require(_amountOut>0,"Invalid output amount");
        (uint256 res0,uint256 res1,IERC20 tokenIn,IERC20 tokenOut) = isTokenA?
        (resIn.add(_amountIn),resOut.sub(_amountOut),tokenA,tokenB):
        (resOut.sub(_amountOut),resIn.add(_amountIn),tokenB,tokenA);
        if(isTokenA){
            updateCollectedFees(totalFeesCollectedTokenA.add(fee),totalFeesCollectedTokenB);
        }
        else{
            updateCollectedFees(totalFeesCollectedTokenA,totalFeesCollectedTokenB.add(fee));
        }
        updateReserves(res0,res1);
        tokenIn.transferFrom(msg.sender,address(this),_amountIn-fee);
        tokenIn.transferFrom(msg.sender,owner,fee);
        tokenOut.transfer(msg.sender,_amountOut);
        emit TokenSwapped(address(tokenIn),_amountIn,address(tokenOut),_amountOut);
    }

    function getAmountOut(address _tokenIn,uint256 _amountIn) public view returns(
        uint256, uint256, uint256, bool,uint256){
        require(_tokenIn==address(tokenA) || _tokenIn==address(tokenB),"Invalid Token Address");
        require(_amountIn>0,"Invalid Amount");
        bool isTokenA = _tokenIn==address(tokenA);
        (uint256 resIn, uint256 resOut) = isTokenA?(reserveA,reserveB):(reserveB,reserveA);
        //r = 997 since protocol fees is 0.3% and converting it to a multiplier of 1000
        //3 will be given to pool and 997 
        //dy = (y*r*dx)/(x+r*dx);
         // Calculate fee amount
        uint256 feeAmount = _amountIn.mul(3).div(1000); // 0.3% fee
        // Adjust input amount after fee deduction
        uint256 amountInAfterFee = _amountIn.sub(feeAmount);
        uint256 amountOut = resOut.mul(amountInAfterFee).div(resIn.add(amountInAfterFee));
        return (amountOut,resIn,resOut,isTokenA,feeAmount);
    }

    function getAmountsOnRemovingLiquidty(uint256 _liquidityTokens) public view returns(uint256,uint256){
        require(_liquidityTokens>0,"Invalid Amount");
        // The change in liquidity/token reserves should be propotional to shares burned
        //calculating liquidity provider's shares in the pool
        uint256 _amount0 = reserveA.mul(_liquidityTokens).div(totalSupply());
        uint256 _amount1 = reserveB.mul(_liquidityTokens).div(totalSupply());
        return (_amount0,_amount1);
    }

    function getFees(uint256 _liquidityTokens) private view returns(uint256,uint256){
        //calculating liquidity provider's shares in fees collected
        uint256 feeShareTokenA = totalFeesCollectedTokenA.mul(_liquidityTokens).div(totalSupply());
        uint256 feeShareTokenB = totalFeesCollectedTokenB.mul(_liquidityTokens).div(totalSupply());
        return (feeShareTokenA,feeShareTokenB);
    }
}