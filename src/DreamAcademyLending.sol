// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "forge-std/Test.sol";

import "./DreamOracle.sol";
import "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

contract DreamAcademyLending {

    using SafeERC20 for IERC20;
    // USDC
    address private _token;
    // Ether 
    address private _ether = address(0x0);

    uint256 constant private _ltv = 500;
    uint256 constant private _threshold = 750; 
    uint256 constant private _bonus = 50;
    uint256 constant private _BASE_POINT = 1000;
     

    DreamOracle private _oracle; 

    struct sCollateral {
        uint256 ethAmount; // ETH
        uint256 time; // Block timestamp
        uint256 borrowableAmount; // borrowable amount
        uint256 thresholdAmount; // threshold amount
        uint256 limitThresholdAmount;
        uint256 borrowedAmount; // borrowed amount
    }

    struct sDeposit {
        uint256 usdcAmount; // USDC
        uint256 time; // Block timestamp
    }



    mapping(address => sCollateral) public  borrowers;
    mapping(address => sDeposit) public depositors;


    event DepositUSDC(address from , uint256 amount);
    event DepositETHER(address from , uint256 amount);

    event DepositorInfo(address depositorAddr, uint256 usdcAmount, uint256 time);
    event BorrowerInfo(address borrowerAddr, uint256 ethAmount, uint256 time, uint256 borrowableAmount , uint256 threshold, uint256 borrowedAmount);


    constructor(IPriceOracle oracle,address token) {
        _token = token;
        _oracle = DreamOracle(address(oracle));
    }

    function deposit(address tokenAddress, uint256 amount) external  payable {
        require(tokenAddress == address(0) || tokenAddress == _token,"only USDC,ETHER is supported");
        if(tokenAddress == address(0x0)) {
            require(msg.value>0,"Do not deposit 0");
            require(amount == msg.value,"not equal amount");
        }
        // Collateral
        if(msg.value > 0)  {
            uint256 ethToUsdc = msg.value * _oracle.getPrice(_ether) / 10 ** 18;
            sCollateral memory collateral;
            if(borrowers[msg.sender].ethAmount == 0 ) {
                collateral=  sCollateral({
                ethAmount : msg.value,
                time : 0,
                borrowableAmount : ethToUsdc * _ltv / _BASE_POINT,
                thresholdAmount : ethToUsdc * _threshold / _BASE_POINT,
                limitThresholdAmount : ethToUsdc * _ltv / _BASE_POINT,
                borrowedAmount : 0
                });
                
            }
            else {
                collateral = borrowers[msg.sender];
                collateral.ethAmount += msg.value;
                collateral.borrowableAmount += ethToUsdc * _ltv / _BASE_POINT;
                collateral.thresholdAmount += ethToUsdc * _threshold / _BASE_POINT;
                collateral.limitThresholdAmount += ethToUsdc * _ltv / _BASE_POINT;
            }
            borrowers[msg.sender] = collateral;


            emit DepositETHER(msg.sender, msg.value);
            emit BorrowerInfo(msg.sender, borrowers[msg.sender].ethAmount, borrowers[msg.sender].time,borrowers[msg.sender].borrowableAmount, borrowers[msg.sender].thresholdAmount,borrowers[msg.sender].borrowedAmount);
        }
        // USDC
        else if(tokenAddress == _token){
            require(amount > 0 , "Amount must be greater than 0 ");
            sDeposit memory deposit;
            if(depositors[msg.sender].usdcAmount == 0){
                deposit = sDeposit( {
                    usdcAmount : amount,
                    time : block.timestamp
                });
            }
            else {
                deposit = depositors[msg.sender];
                deposit.usdcAmount += amount;
            }


            depositors[msg.sender] = deposit;
            IERC20(tokenAddress).safeTransferFrom(msg.sender,address(this),amount);

            emit DepositUSDC(msg.sender, amount);
            emit DepositorInfo(msg.sender, depositors[msg.sender].usdcAmount,depositors[msg.sender].time);

        }
    }


    function borrow(address tokenAddress, uint256 amount) external {
        require(tokenAddress == _token, "Only USDC is supported");
        sCollateral memory collateral = borrowers[msg.sender];
        require(collateral.ethAmount > 0, "Input your collateral first");
        require(collateral.borrowableAmount >= amount, "Amount greater than the borrowable amount" );
        
       collateral.borrowedAmount += amount;
       collateral.borrowableAmount -= amount; 
       collateral.time = block.timestamp;
       borrowers[msg.sender] = collateral;
       IERC20(tokenAddress).safeTransfer(msg.sender,amount);
    
        emit BorrowerInfo(msg.sender, borrowers[msg.sender].ethAmount, borrowers[msg.sender].time,borrowers[msg.sender].borrowableAmount, borrowers[msg.sender].thresholdAmount,borrowers[msg.sender].borrowedAmount);


    }


    function repay(address tokenAddress, uint256 amount) external {
      require(tokenAddress == _token,"Only USDC is supported");  

      sCollateral memory collateral = borrowers[msg.sender];
      uint256 borrowedPeriod = (block.timestamp - collateral.time) / 1 days; // 빌린 기간

      uint256 currentBorrowedAmount = calcInterest(collateral.borrowedAmount,borrowedPeriod);
      uint256 fee = calcInterest(collateral.borrowedAmount,borrowedPeriod) - collateral.borrowedAmount; // 수수료 
      uint256 originAmount = amount - fee;
      // 빌린 금액 보다 적은 금액을 상환 했을 때
      if(currentBorrowedAmount > amount) {
        collateral.borrowedAmount = currentBorrowedAmount - amount;
        collateral.borrowableAmount += originAmount;
        collateral.time = block.timestamp;
      }
      // 빌린 금액을 다 상환 했을 때
      else {
        collateral.borrowedAmount = 0;
        collateral.time = 0;
        collateral.borrowableAmount += collateral.borrowedAmount;
        collateral.thresholdAmount = 0;
      }
      IERC20(tokenAddress).safeTransferFrom(msg.sender,address(this),amount);
      borrowers[msg.sender] = collateral;
      emit BorrowerInfo(msg.sender, borrowers[msg.sender].ethAmount, borrowers[msg.sender].time,borrowers[msg.sender].borrowableAmount, borrowers[msg.sender].thresholdAmount,borrowers[msg.sender].borrowedAmount);
      
    }


    function withdraw(address tokenAddress, uint256 amount) external payable{
        require(tokenAddress == _token || tokenAddress == address(0) ,"Only USDC is supported");
        // Depositor
        if(tokenAddress == _token) {
            sDeposit memory deposit = depositors[msg.sender];
            require(deposit.usdcAmount > 0 ,"you must be deposit usdc");

            uint256 depositedPeriod = (block.timestamp - deposit.time) / 1 days;
            deposit.usdcAmount = calcInterest(deposit.usdcAmount,depositedPeriod); // 0.1% 복리 이자
            if(deposit.usdcAmount == amount) {
                delete depositors[msg.sender];
            }
            else {
                deposit.time = block.timestamp;
                deposit.usdcAmount -= amount;
                depositors[msg.sender] = deposit;
            }
            IERC20(_token).safeTransfer(msg.sender,amount) ;
            emit DepositorInfo(msg.sender, depositors[msg.sender].usdcAmount,depositors[msg.sender].time);


        }
        // commplete redeem 
        else {
            sCollateral memory collateral = borrowers[msg.sender];
            require(collateral.borrowedAmount ==0, "You didnt redeem complete");
            uint256 balance = collateral.ethAmount;
            delete borrowers[msg.sender];

            // send Ether
            bool success = payable(msg.sender).send(balance);
            require(success,"Failed to send ether");  
            emit BorrowerInfo(msg.sender, borrowers[msg.sender].ethAmount, borrowers[msg.sender].time,borrowers[msg.sender].borrowableAmount, borrowers[msg.sender].thresholdAmount,borrowers[msg.sender].borrowedAmount);

        }


    }


    function liquidate(address user, address tokenAddress, uint256 amount) external payable{
        require(tokenAddress == _token ,"Only USDC is supported");
        require(borrowers[user].ethAmount > 0 , "this user is not applicable" );

        //Threshold check
        sCollateral memory collateral = borrowers[user];
        uint256 ethToUsdc = collateral.ethAmount * _oracle.getPrice(_ether) / 10 ** 18;

        require(ethToUsdc <= collateral.thresholdAmount ,"The price has not been reached");
        uint256 liquidatorBonus;
        uint256 liquidatorAmountEther;    
        // 75%  ~ 51% 이면 빌린양의 1/2 까지만 상환 가능
        if(ethToUsdc > collateral.limitThresholdAmount) {
            require(collateral.borrowedAmount <= amount * 2, "The amount that can be repaid has been exceeded");
            //Bonus + amount -> ether
            liquidatorBonus = amount * _bonus / _BASE_POINT;
            liquidatorAmountEther = ((amount+liquidatorBonus) * 10 ** 18 / _oracle.getPrice(_ether));

            uint256 borrowedPeriod = (block.timestamp - collateral.time) / 1 days; 
            collateral.borrowedAmount = calcInterest(collateral.borrowedAmount,borrowedPeriod);

            collateral.ethAmount -= liquidatorAmountEther;
            collateral.borrowedAmount -= amount;
            collateral.time = block.timestamp;
            collateral.borrowableAmount= collateral.borrowableAmount + amount >= collateral.limitThresholdAmount  ? collateral.limitThresholdAmount :  collateral.borrowableAmount + amount;
            borrowers[user] = collateral;
            

        }
        else {
             //  50% 아래 면 45% 이상 상환 하면 바로 청산(5%는 수수료)
            if( amount >= (collateral.limitThresholdAmount*2) * 450 / 1000 ) {
                liquidatorAmountEther = collateral.ethAmount;
                delete borrowers[user];
            }
            else {
                liquidatorAmountEther = amount * 10 ** 18 /_oracle.getPrice(_ether);
                liquidatorBonus = liquidatorAmountEther * _bonus /_BASE_POINT;
                liquidatorAmountEther += liquidatorBonus;

                collateral.ethAmount -= liquidatorAmountEther;
                collateral.borrowedAmount -= amount;
                collateral.time = block.timestamp;
                collateral.borrowableAmount= collateral.borrowableAmount + amount >= collateral.limitThresholdAmount  ? collateral.limitThresholdAmount :  collateral.borrowableAmount + amount;
                borrowers[user] = collateral;
            }

        }


        IERC20(_token).safeTransferFrom(msg.sender,address(this),amount);

        bool success = payable(msg.sender).send(liquidatorAmountEther);
        require(success,"Failed to send Ether");

        {
        sCollateral memory borrower = borrowers[user];
        emit BorrowerInfo(user, borrower.ethAmount, borrower.time,borrower.borrowableAmount, borrower.thresholdAmount,borrower.borrowedAmount);
        }
        
    }

    function calcInterest(uint256 amount ,uint256 n) private returns(uint256) {
        return (amount* 1001 ** n ) / (1000 ** n);
     }


    function getBorrowedAmount() public view returns(uint256 amount) {
        amount = borrowers[msg.sender].borrowableAmount;
    }
    function getCollateral() public view returns(uint256 amount) {
        amount = borrowers[msg.sender].ethAmount;
    }
    
    function initializeLendingProtocol(address token) external payable {
        IERC20(token).transferFrom(msg.sender,address(this),msg.value);
    }

    function getAccruedSupplyAmount(address token) public returns(uint256) {
        return 1;
    }
}