// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Lending.sol";
import "../src/DreamOracle.sol";
import "openzeppelin-contracts/token/ERC20/ERC20.sol";


contract USDC is ERC20 {
    constructor(string memory tokenName) ERC20(tokenName,tokenName) {}


    function mint(address to,uint256 amount) public {
        _mint(to,amount);
    }
}



contract CounterTest is Test {
    Lending lending;
    DreamOracle oracle;
    USDC usdc;
    address eth = address(0x1234);


    address depositor1;
    address borrower1;

    function setUp() public {
        usdc = new USDC("USDC");
        oracle = new DreamOracle();
        lending = new Lending(address(usdc),address(oracle));

        oracle.setPrice(eth,1400 * 10 ** 6);

        depositor1 = address(0x11);
        borrower1 = address(0x10);

    }
    function testDepositUSDC1() public {
        usdc.mint(depositor1,100 * 10 ** 6);

        vm.startPrank(depositor1);
        usdc.approve(address(lending),100 * 10 **6);
        lending.deposit(address(usdc),100 * 10 **6);


        assertEq(usdc.balanceOf(address(lending)), 100 * 10 ** 6, "Error USDC deposit");
        vm.stopPrank();

    }

    function testDepositCollateral1() public {
        vm.deal(borrower1,10 ether);
        vm.prank(borrower1);
        lending.deposit{value : 10 ether}(address(0),0);

        assertEq(address(lending).balance , 10 ether,"Error Ether deposit");
    }

    function testBorrow1() public {
        uint256 amount = 10 ether;
        usdc.mint(depositor1,7000 * 10 ** 6);


        // deposit
        vm.startPrank(depositor1);
        usdc.approve(address(lending),7000 * 10 **6);
        lending.deposit(address(usdc),7000 *10 **6);
        vm.stopPrank();
        // borrow
        vm.deal(borrower1, 10 ether);
        vm.startPrank(borrower1);
        lending.deposit{value : amount }(address(0),0);

        assertEq(address(lending).balance , 10 ether , "Check collateral deposit" );

        lending.borrow(address(usdc), 7000 * 10 **6 );
        assertEq(usdc.balanceOf(address(borrower1)),7000 * 10 **6);

        vm.expectRevert("Amount greater than the borrowable amount");
        lending.borrow(address(usdc), 7000 * 10 **6 );
        vm.stopPrank();

    }
    function testBorrow2() public {
        uint256 amount = 10 ether;
        usdc.mint(depositor1,7000 * 10 ** 6);


        // deposit
        vm.startPrank(depositor1);
        usdc.approve(address(lending),7000 * 10 **6);
        lending.deposit(address(usdc),7000 *10 **6);
        vm.stopPrank();
        // borrow
        vm.deal(borrower1, 10 ether);
        vm.startPrank(borrower1);
        
        // ????????? ??????  ????????? ??????
        //lending.deposit{value : amount }(address(0),0);

        vm.expectRevert("Input your collateral first");
        lending.borrow(address(usdc), 7000 * 10 **6 );
        vm.stopPrank();

    }

    // ????????? ??????????????? ???
    function testRepay1() public {
       uint256 amount = 10 ether;
        usdc.mint(depositor1,7000 * 10 ** 6);
      usdc.mint(borrower1,70315841);

        // deposi???
        vm.startPrank(depositor1);
        usdc.approve(address(lending),7000 * 10 **6);
        lending.deposit(address(usdc),7000 *10 **6);
        vm.stopPrank();

        // borrow
        vm.deal(borrower1, 10 ether);
        vm.startPrank(borrower1);
        lending.deposit{value : amount }(address(0),0);

        assertEq(address(lending).balance , 10 ether , "Check collateral deposit" );

        lending.borrow(address(usdc), 7000 * 10 **6 );

        
        // repay
        // 10?????? ?????? ??? (??????)
        console.log(usdc.balanceOf(borrower1));
        usdc.approve(address(lending),7070315841);
        vm.warp(block.timestamp + 10 days);
        lending.repay(address(usdc),7070315841 );
        
        lending.withdraw(address(0),0);
        assertEq(borrower1.balance,10 ether,"Check repay function, Collateral did not come in properly");
        vm.stopPrank();
    }

    // ?????? ??????
    function testRepay2() public {
       uint256 amount = 10 ether;
        usdc.mint(depositor1,7000 * 10 ** 6);
        usdc.mint(borrower1,70315841);

        // deposit
        vm.startPrank(depositor1);
        usdc.approve(address(lending),7000 * 10 **6);
        lending.deposit(address(usdc),7000 *10 **6);
        vm.stopPrank();

        // borrow
        vm.deal(borrower1, 10 ether);
        vm.startPrank(borrower1);
        lending.deposit{value : amount }(address(0),0);

        assertEq(address(lending).balance , 10 ether , "Check collateral deposit" );

        lending.borrow(address(usdc), 7000 * 10 **6 );

        
        // repay
        // 10?????? ?????? ??? (??????)
        console.log(usdc.balanceOf(borrower1));
        usdc.approve(address(lending),7070315841);
        vm.warp(block.timestamp + 10 days);
        lending.repay(address(usdc),4000000000 );
        assertEq(usdc.balanceOf(borrower1),7070315841-4000000000,"Did not repay");
        vm.stopPrank();
    }
    
    // Deposit??? USDC ?????? ??????
    function testWithdraw1() public {
        usdc.mint(depositor1,100 * 10 ** 6);

        vm.startPrank(depositor1);
        usdc.approve(address(lending),100 * 10 **6);
        lending.deposit(address(usdc),100 * 10 **6);
        assertEq(usdc.balanceOf(address(lending)), 100 * 10 ** 6, "Error USDC deposit");

        lending.withdraw(address(usdc), 100 * 10 **6);
        assertEq(usdc.balanceOf(depositor1),100 * 10 **6);        
        vm.stopPrank();  

    }
    // Deposit??? USDC ?????? ??????
    function testWithdraw2() public {
        usdc.mint(depositor1,100 * 10 ** 6);

        vm.startPrank(depositor1);
        usdc.approve(address(lending),100 * 10 **6);
        lending.deposit(address(usdc),100 * 10 **6);
        assertEq(usdc.balanceOf(address(lending)), 100 * 10 ** 6, "Error USDC deposit");

        lending.withdraw(address(usdc), 50* 10 **6);
        assertEq(usdc.balanceOf(depositor1),50 * 10 **6);        
        vm.stopPrank();  

    }
    // 5??? ??? ?????? ???????????? ??????
    function testWithdraw3() public {
        // 35070070 5??? ??????
        usdc.mint(depositor1,7000 * 10 ** 6);
        vm.deal(borrower1,10 ether);
        usdc.mint(borrower1,35070070);

        // deposit
        vm.startPrank(depositor1);
        usdc.approve(address(lending),7000 * 10 **6);
        console.log("before deposit" , usdc.balanceOf(depositor1));
        lending.deposit(address(usdc),7000 *10 **6);
        vm.stopPrank();

        // borrow
        vm.startPrank(borrower1);
        usdc.approve(address(lending),100 * 10 **6);
        lending.deposit{value : 10 ether }(address(0),0);
        lending.borrow(address(usdc), 7000 *10 **6 );
        
        // repay
        usdc.approve(address(lending),	7035070070);
        vm.warp(block.timestamp + 5 days);
        lending.repay(address(usdc),  7035070070);
        assertEq(usdc.balanceOf(address(lending)), 7035070070,"Check repay");       
        vm.stopPrank();    

        vm.startPrank(depositor1);
        lending.withdraw(address(usdc), 7035070070 );
        assertEq(usdc.balanceOf(depositor1),7035070070, "dont receive welfare" );

    }
   function testWithdraw4() public {
        // 35070070 5??? ??????
        usdc.mint(depositor1,7000 * 10 ** 6);
        vm.deal(borrower1,10 ether);
        usdc.mint(borrower1,35070070);

        // deposit
        vm.startPrank(depositor1);
        usdc.approve(address(lending),7000 * 10 **6);
        console.log("before deposit" , usdc.balanceOf(depositor1));
        lending.deposit(address(usdc),7000 *10 **6);
        vm.stopPrank();

        // borrow
        vm.startPrank(borrower1);
        usdc.approve(address(lending),100 * 10 **6);
        lending.deposit{value : 10 ether }(address(0),0);
        lending.borrow(address(usdc), 7000 *10 **6 );
        
        // repay
        usdc.approve(address(lending),	7035070070);
        vm.warp(block.timestamp + 5 days);
        lending.repay(address(usdc),  7035070070);
        assertEq(usdc.balanceOf(address(lending)), 7035070070,"Check repay");       
        vm.stopPrank();    

        vm.startPrank(depositor1);
        lending.withdraw(address(usdc), 3000 * 10 **6 );
        

    }

    function testLiquidate1() public {
        // 35070070 5??? ??????
        usdc.mint(depositor1,7000 * 10 ** 6);
        vm.deal(borrower1,10 ether);
        usdc.mint(borrower1,35070070);

        // deposit
        vm.startPrank(depositor1);
        usdc.approve(address(lending),7000 * 10 **6);
        lending.deposit(address(usdc),7000 *10 **6);
        vm.stopPrank();

        // borrow
        vm.startPrank(borrower1);
        usdc.approve(address(lending),100 * 10 **6);
        lending.deposit{value : 10 ether }(address(0),0);
        lending.borrow(address(usdc), 7000 *10 **6 ); 
        vm.stopPrank();

        address liquidator1 = address(0x90);
        usdc.mint(liquidator1,7000 * 10 ** 6);
        // Threshold 75%
        oracle.setPrice(eth,1000* 10 ** 6);

        vm.startPrank(liquidator1);
        // vm.warp(block.timestamp + 5 days);///
        usdc.approve(address(lending),7000 * 10 ** 6);
        vm.warp(block.timestamp + 5 days);
        lending.liquidate(borrower1, address(usdc),7000 * 10 **6);
        assertEq(liquidator1.balance, 7350000000000000000 );
        assertEq(address(lending).balance,10 ether - 7350000000000000000);
        vm.stopPrank();
    }

    function testLiquidate2() public {
        // 35070070 5??? ??????
        usdc.mint(depositor1,7000 * 10 ** 6);
        vm.deal(borrower1,10 ether);
        usdc.mint(borrower1,35070070);

        // deposit
        vm.startPrank(depositor1);
        usdc.approve(address(lending),7000 * 10 **6);
        lending.deposit(address(usdc),7000 *10 **6);
        vm.stopPrank();

        // borrow
        vm.startPrank(borrower1);
        usdc.approve(address(lending),100 * 10 **6);
        lending.deposit{value : 10 ether }(address(0),0);
        lending.borrow(address(usdc), 7000 *10 **6 ); 
        vm.stopPrank();

        address liquidator1 = address(0x90);
        usdc.mint(liquidator1,7000 * 10 ** 6);
        // Threshold 75%
        oracle.setPrice(eth,1000 * 10 ** 6);

        vm.startPrank(liquidator1);
        // vm.warp(block.timestamp + 5 days);///
        usdc.approve(address(lending),7000 * 10 ** 6);
        vm.warp(block.timestamp + 5 days);
        lending.liquidate(borrower1, address(usdc),7000 * 10 **6);
        assertEq(liquidator1.balance, 7350000000000000000 );
        vm.stopPrank();


        vm.startPrank(borrower1);

        // ????????? ????????? ??? ????????? ???????????? ????????? ?????? ?????? 
        uint256 lendingEther = address(lending).balance;
        lending.repay(address(usdc), 35070070);
        lending.withdraw(address(0),0);
        assertEq(borrower1.balance,lendingEther, "dont repay remainder" );
    }


    function testLiquidate3() public {
        // 35070070 5??? ??????
        usdc.mint(depositor1,7000 * 10 ** 6);
        vm.deal(borrower1,10 ether);
        usdc.mint(borrower1,35070070);

        // deposit
        vm.startPrank(depositor1);
        usdc.approve(address(lending),7000 * 10 **6);
        lending.deposit(address(usdc),7000 *10 **6);
        vm.stopPrank();

        // borrow
        vm.startPrank(borrower1);
        usdc.approve(address(lending),100 * 10 **6);
        lending.deposit{value : 10 ether }(address(0),0);
        lending.borrow(address(usdc), 7000 *10 **6 ); 
        vm.stopPrank();

        address liquidator1 = address(0x90);
        usdc.mint(liquidator1,7000 * 10 ** 6);

        oracle.setPrice(eth,300* 10 ** 6);
        uint256 getPrice = oracle.getPrice(eth);

        vm.startPrank(liquidator1);
        // vm.warp(block.timestamp + 5 days);///
        usdc.approve(address(lending),7000 * 10 ** 6);
        vm.warp(block.timestamp + 5 days);
        //????????? ?????????50%????????? ???????????? 45% ?????? ?????????????????? ????????????  ?????? ??????
        lending.liquidate(borrower1, address(usdc),6600 * 10 **6);
        assertEq(liquidator1.balance,10 ether);
        console.log(liquidator1.balance);
        vm.stopPrank();

    }
    function testLiquidate4() public {
        // 35070070 5??? ??????
        usdc.mint(depositor1,7000 * 10 ** 6);
        vm.deal(borrower1,10 ether);
        usdc.mint(borrower1,35070070);

        // deposit
        vm.startPrank(depositor1);
        usdc.approve(address(lending),7000 * 10 **6);
        lending.deposit(address(usdc),7000 *10 **6);
        vm.stopPrank();

        // borrow
        vm.startPrank(borrower1);
        usdc.approve(address(lending),100 * 10 **6);
        lending.deposit{value : 10 ether }(address(0),0);
        lending.borrow(address(usdc), 7000 *10 **6 ); 
        vm.stopPrank();

        address liquidator1 = address(0x90);
        usdc.mint(liquidator1,7000 * 10 ** 6);

        oracle.setPrice(eth,400* 10 ** 6);
        uint256 getPrice = oracle.getPrice(eth);

        vm.startPrank(liquidator1);
        // vm.warp(block.timestamp + 5 days);///
        usdc.approve(address(lending),7000 * 10 ** 6);
        vm.warp(block.timestamp + 5 days);
        //????????? ?????????50%????????? ???????????? 45% ?????? ?????????????????? ????????????  ?????? ??????
        lending.liquidate(borrower1, address(usdc),2000 * 10 **6);
        assertEq(liquidator1.balance, 5.25 ether);
        vm.stopPrank();

    }
}
