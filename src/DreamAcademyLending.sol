// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "./Math.sol";
import "./Quad.sol";
interface IPriceOracle {
    function getPrice(address) external view returns(uint256);
    function setPrice(address,uint256) external;
}   
contract LPToken is ERC20 {
    address private owner;
    constructor() ERC20("LPToken","LP") {
        owner = msg.sender;
    }
    
    function mint(address target , uint amount) external {
        require(msg.sender == owner);
        _mint(target,amount);
    }

}
contract DreamAcademyLending {
    using SafeERC20 for IERC20;
    uint256 constant LTV = 500;
    uint256 constant BASE_POINT = 1000;
    uint256 constant THRESHOLD = 750;

    address public token0;
    address public token1;

    uint256 public totalToken0;
    uint256 public totalToken1;


    uint256 public preFee;
    struct sCollateral {
        uint256 sCollAmount; // ether
        uint256 sBorrowedAmount;
        uint256 sBlockNum;
    }

    struct sStaking {
        uint256 sStakingAmount;
        uint256 sPreFee;
        uint256 sProfit;
    }

    IPriceOracle public oracle;
    mapping(address => sCollateral) public borrowers;
    mapping(address => sStaking) public depositors;
    
    address[] borrowerList;
    address[] depositList;
    constructor(IPriceOracle aOracle , address aToken) {

        token0 = address(0x0); // ether
        token1 = aToken; // usdc

        oracle = aOracle;
    }

    function deposit(address aToken,uint256 aAmount) external payable {
        require(aToken == token0 || aToken == token1,"Deposit : Error");
        // ether
        if(aToken == token0) {
            require(aAmount == msg.value , "DEPOSIT: Does not match aAmount and msg.value");
            borrowers[msg.sender].sCollAmount += aAmount;
            totalToken0 += aAmount;
        } 
        // usdc
        else if(aToken == token1) {
            IERC20(token1).safeTransferFrom(msg.sender,address(this),aAmount);
            depositors[msg.sender].sStakingAmount += aAmount; 
            depositList.push(msg.sender);
            totalToken1 += aAmount;
        }
    }
    function borrow(address aToken, uint256 aAmount) external{


        sCollateral memory col = borrowers[msg.sender];
        uint256 token0Price = oracle.getPrice(token0);
        uint256 token1Price = oracle.getPrice(token1);
        uint256 ltv = col.sCollAmount * token0Price / 2;

        col.sBorrowedAmount =  updateInterest(msg.sender,block.number);
        require(ltv >= token1Price * (aAmount + col.sBorrowedAmount), "Borrow: amount is greater than ltv");
        if(col.sBorrowedAmount ==  0) {
            borrowerList.push(msg.sender);
            col.sBlockNum = block.number;
        }
        col.sBorrowedAmount += aAmount;
        borrowers[msg.sender] = col;
        totalToken1 -= aAmount;

        IERC20(token1).safeTransfer(msg.sender, aAmount);
    }

    function repay(address aToken, uint256 aAmount) external {

        sCollateral memory col = borrowers[msg.sender];
        col.sBorrowedAmount = updateInterest(msg.sender,block.number);
        if(aAmount == col.sBorrowedAmount) {
            col.sBorrowedAmount = 0;
            col.sBlockNum = 0;
        }
        else {
            col.sBorrowedAmount -= aAmount;
        }

        borrowers[msg.sender] = col;
        totalToken1 += aAmount;
        IERC20(token1).safeTransferFrom(msg.sender,address(this),aAmount);

    }



    
    function initializeLendingProtocol(address aToken) external payable{
       IERC20(aToken).transferFrom(msg.sender, address(this), msg.value);
       totalToken0 += msg.value;
       totalToken1 += msg.value;
    }


    function calcInterest(uint256 aAmount , uint256 n) private returns(uint256) {
        // uint ret = aAmount;        
        // for(uint i=0;i<n; ++i) {
        //     ret += ret / 100000000000 * 13882 ;
        // }
        uint qout = n / 7200;
        uint rem = n % 7200;
        uint blockAPY =  interest(aAmount,1e15,1) / 7200 * rem;

        uint ret = interest(aAmount,1e15,qout) + blockAPY;
        return ret;

    }

    function updateInterest(address sender , uint blockNum) private returns(uint256){
        sCollateral memory col = borrowers[sender];
        blockNum -= col.sBlockNum;
        col.sBorrowedAmount = calcInterest(col.sBorrowedAmount,blockNum);
        return col.sBorrowedAmount;
    }

    function getAccruedSupplyAmount(address aToken ) public  returns(uint256){
        uint256 feeStorage = 0;
        address[] memory borrowL = borrowerList;
        address[] memory depositL = depositList;
        for(uint i=0;i<borrowL.length;++i) {
            uint amount = updateInterest(borrowL[i],block.number);
            feeStorage += amount - borrowers[borrowL[i]].sBorrowedAmount;
        }
        // 나중에 다시 update하는 함수로 만들어야함
        for(uint i=0;i<depositL.length;++i) {
            uint256 profit = (feeStorage-preFee) * depositors[depositL[i]].sStakingAmount / totalToken1;
            depositors[depositL[i]].sProfit += profit;
            console.log("profit",depositors[depositL[i]].sProfit);
        }
        preFee = feeStorage;
        return depositors[msg.sender].sProfit + depositors[msg.sender].sStakingAmount ;
    }

    function withdraw(address aToken, uint256 aAmount) external payable{
        uint256 token0Price = oracle.getPrice(token0);
        uint256 token1Price = oracle.getPrice(token1);

        if(aToken == token0) {
            sCollateral memory col = borrowers[msg.sender]; 
            col.sBorrowedAmount = updateInterest(msg.sender,block.number);
            uint256 possibleAmount = (col.sCollAmount - aAmount) * token0Price / token1Price * THRESHOLD / BASE_POINT;
            require(possibleAmount >= col.sBorrowedAmount,"Widthdraw : Error");
            payable(msg.sender).transfer(aAmount);
            totalToken0 -= aAmount;
        }
        else if(aToken == token1) {
            uint256 amount  =  getAccruedSupplyAmount(token1);
            require(amount > aAmount, "Withdraw: Error");
            IERC20(token1).safeTransfer(msg.sender,aAmount);
            depositors[msg.sender].sStakingAmount = 0;
            totalToken1 -= aAmount;
        }
    }
    function liquidate(address aUser, address aTokenAddress, uint256 aAmount) external payable{
        require(aTokenAddress == token1,"Liquidate");
        uint256 token0Price = oracle.getPrice(token0);
        uint256 token1Price = oracle.getPrice(token1);
        sCollateral memory col = borrowers[aUser];
        uint256 healthFactor = (col.sCollAmount * THRESHOLD / BASE_POINT) / (col.sBorrowedAmount * token1Price / token0Price );

        require(healthFactor < 1, "Liquidate : Health");
        require(aAmount <=  col.sBorrowedAmount   * 250 / BASE_POINT, "Liquidate : 25%");

        uint256 sBorrowedAmountInEther = aAmount * token1Price / token0Price;
        col.sBorrowedAmount -= aAmount;
        col.sCollAmount -= sBorrowedAmountInEther;
        borrowers[aUser] = col;

        payable(msg.sender).transfer(sBorrowedAmountInEther);
    }



/*
x : percent
y : amount 
z : 1000
 */


function pow (int128 x, uint n)
private pure returns (int128 r) {
  r = ABDKMath64x64.fromUInt (1);
  while (n > 0) {
    if (n % 2 == 1) {
      r = ABDKMath64x64.mul (r, x);
      n -= 1;
    } else {
      x = ABDKMath64x64.mul (x, x);
      n /= 2;
    }
  }
}
function interest (uint principal, uint ratio, uint n)
private pure returns (uint) {
  return ABDKMath64x64.mulu (
    pow (
      ABDKMath64x64.add (
        ABDKMath64x64.fromUInt (1), 
        ABDKMath64x64.divu (
          ratio,
          10**18)),
      n),
    principal);
}

}
