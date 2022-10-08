// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {SuperfluidTester, Superfluid, ConstantFlowAgreementV1, CFAv1Library, SuperTokenFactory} from "./SuperfluidTester.sol";
import {IMySuperToken} from "../interfaces/IMySuperToken.sol";
import {Vesting} from "../vesting/Vesting.sol";
import {MySuperToken} from "../MySuperToken.sol";
import {MockChainlink} from "../utils/mocks/MockChainlink.sol";
import {AggregatorV2V3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";
import {CallAgreementHelper} from "../utils/CallAgreementHelper.sol";

/// @title Example Super Token Test
/// @author jtriley.eth
/// @notice For demonstration only. You can delete this file.
contract StreamswapSetupTest is SuperfluidTester {
    /// @dev This is required by solidity for using the CFAv1Library in the tester
    using CFAv1Library for CFAv1Library.InitData;

    /// @dev Example Super Token to test
    IMySuperToken internal eth;
    IMySuperToken internal fiat;
    Vesting internal vesting;

    AggregatorV2V3Interface internal chainlinkETH;
    CallAgreementHelper internal helper;

    /// @dev Constants for Testing
    uint256 internal constant ethInitialSupply = 10000000 ether; // 10 millions
    uint256 internal constant fiatInitialSupply = 100000000 ether; // 100 millions
    address internal constant admin = address(1);
    address internal constant manager = address(2);
    address internal constant alice = address(3);
    address internal constant bob = address(4);
    address internal constant charlie = address(5);

    address[] internal contributors;
    uint256[] internal vestingFlows;
    uint256[] internal payrollFlows;

    constructor() SuperfluidTester(admin) {}

    function setUp() public {
        // Become admin
        vm.startPrank(admin);

        // Deploy SuperTokens
        eth = IMySuperToken(address(new MySuperToken()));

        fiat = IMySuperToken(address(new MySuperToken()));

        // Upgrade SuperTokens with the SuperTokenFactory
        sf.superTokenFactory.initializeCustomSuperToken(address(eth));
        sf.superTokenFactory.initializeCustomSuperToken(address(fiat));

        // initialize SuperTokens
        eth.initialize("Super ETH", "ETHx", ethInitialSupply);
        fiat.initialize("Super FIAT", "FIATx", fiatInitialSupply);

        // Mint some amount
        uint256 amountETH = 10 ether;
        eth.mint(alice, amountETH);
        eth.mint(bob, amountETH);
        eth.mint(charlie, amountETH);

        uint256 amountFIAT = 100000 ether; // 100k per user
        fiat.mint(alice, amountFIAT);
        fiat.mint(bob, amountFIAT);
        fiat.mint(charlie, amountFIAT);

        helper = new CallAgreementHelper(sf.host, sf.cfa);

        vesting = new Vesting(
            sf.host,
            sf.cfa,
            address(eth),
            address(fiat),
            admin,
            manager
        );

        vm.stopPrank();
    }

    function testDeployment() public {
        assertEq(address(vesting.vestingToken()), address(eth));
        assertEq(address(vesting.payrollToken()), address(fiat));
        assertEq(vesting.dao(), admin);
        assertEq(vesting.manager(), manager);
        assertEq(fiat.balanceOf(address(vesting)), 0);
        assertEq(eth.balanceOf(address(vesting)), 0);
    }

    function testFail_no_tokens_in_contract() public {
        uint96 amount = 385802469136; // 1 ether (1e18) per month
        vm.startPrank(admin);
        contributors.push(alice);
        vestingFlows.push(amount);
        payrollFlows.push(amount);

        vesting.addCoreContributors(contributors, vestingFlows, payrollFlows);
    }

    function testFail_not_DAO() public {
        uint96 amount = 385802469136; // 1 ether (1e18) per month
        contributors.push(alice);
        vestingFlows.push(amount);
        payrollFlows.push(amount);

        vesting.addCoreContributors(contributors, vestingFlows, payrollFlows);
    }

    function test_addCoreContributors() public {
        // Alice has no incoming flows
        (, int96 initFlowRateVesting, , ) = sf.cfa.getFlow(
            eth,
            address(vesting),
            alice
        );

        assertEq(initFlowRateVesting, 0);

        (, int96 initFlowRatePayroll, , ) = sf.cfa.getFlow(
            fiat,
            address(vesting),
            alice
        );

        assertEq(initFlowRatePayroll, 0);

        uint96 amountVesting = 385802469136; // 1 ether (1e18) per month
        uint96 amountPayroll = 3858024691360000; // 10000 fiat (1e18) per month
        vm.startPrank(admin);
        contributors.push(alice);
        vestingFlows.push(amountVesting);
        payrollFlows.push(amountPayroll);

        // Mint/Add/Send token to the contract
        eth.mint(address(vesting), 10000 ether); //10000 gov token
        fiat.mint(address(vesting), 1000000 ether); //1000000 fiat

        vesting.addCoreContributors(contributors, vestingFlows, payrollFlows);

        (, int96 flowRateVesting, , ) = sf.cfa.getFlow(
            eth,
            address(vesting),
            alice
        );
        assertEq(flowRateVesting, int96(amountVesting));

        (, int96 flowRatePayroll, , ) = sf.cfa.getFlow(
            fiat,
            address(vesting),
            alice
        );
        assertEq(flowRatePayroll, int96(amountPayroll));

        delete contributors;
        delete vestingFlows;
        delete payrollFlows;
    }

    function test_updateVesting() public {
        uint96 amountVesting = 385802469136; // 1 ether (1e18) per month

        vm.startPrank(admin);
        contributors.push(alice);
        vestingFlows.push(amountVesting);
        payrollFlows.push(0);
        // Mint/Add/Send token to the contract
        eth.mint(address(vesting), 10000 ether); //10000 gov token

        vesting.addCoreContributors(contributors, vestingFlows, payrollFlows);

        (, int96 flowRateVesting, , ) = sf.cfa.getFlow(
            eth,
            address(vesting),
            alice
        );

        assertEq(flowRateVesting, int96(amountVesting));

        uint96 newAmountVesting = 38580246913600; // 100 ether (1e18) per month
        vestingFlows[0] = newAmountVesting;
        vesting.updateVesting(contributors, vestingFlows);

        (, int96 newFlowRateVesting, , ) = sf.cfa.getFlow(
            eth,
            address(vesting),
            alice
        );
        assertEq(newFlowRateVesting, int96(newAmountVesting));

        delete contributors;
        delete vestingFlows;
        delete payrollFlows;
    }

    function test_addPayrolls() public {
        // Bob has no incoming flows
        (, int96 initFlowRateVesting, , ) = sf.cfa.getFlow(
            eth,
            address(vesting),
            bob
        );

        assertEq(initFlowRateVesting, 0);

        (, int96 initFlowRatePayroll, , ) = sf.cfa.getFlow(
            fiat,
            address(vesting),
            bob
        );

        assertEq(initFlowRatePayroll, 0);

        uint96 amountPayroll = 3858024691360000; // 10000 fiat (1e18) per month

        contributors.push(bob);
        payrollFlows.push(amountPayroll);

        // Mint/Add/Send token to the contract
        vm.prank(admin);
        fiat.mint(address(vesting), 1000000 ether); //1000000 fiat

        vm.prank(manager);
        vesting.addPayrolls(contributors, payrollFlows);

        (, int96 flowRatePayroll, , ) = sf.cfa.getFlow(
            fiat,
            address(vesting),
            bob
        );
        assertEq(flowRatePayroll, int96(amountPayroll));

        delete contributors;
        delete payrollFlows;
    }

    function test_addPayrolls_remove() public {
        // Bob has no incoming flows
        (, int96 initFlowRatePayroll, , ) = sf.cfa.getFlow(
            fiat,
            address(vesting),
            bob
        );

        assertEq(initFlowRatePayroll, 0);

        uint96 amountPayroll = 3858024691360000; // 10000 fiat (1e18) per month

        contributors.push(bob);
        payrollFlows.push(amountPayroll);

        // Mint/Add/Send token to the contract
        vm.prank(admin);
        fiat.mint(address(vesting), 1000000 ether); //1000000 fiat

        vm.prank(manager);
        vesting.addPayrolls(contributors, payrollFlows);

        (, int96 flowRatePayroll, , ) = sf.cfa.getFlow(
            fiat,
            address(vesting),
            bob
        );
        assertEq(flowRatePayroll, int96(amountPayroll));

        payrollFlows[0] = 0;
        
        vm.prank(manager);
        vesting.addPayrolls(contributors, payrollFlows);

        (, int96 lastFlowRatePayroll, , ) = sf.cfa.getFlow(
            fiat,
            address(vesting),
            bob
        );
        assertEq(lastFlowRatePayroll, 0);

        delete contributors;
        delete payrollFlows;
    }

    // function testBasicStreamswap() public {
    //     assertEq(factory.isPool(address(eth), address(fiat)), ethfiatPool);
    //     assertEq(chainlinkETH.latestAnswer(), 200000000000);

    //     vm.startPrank(alice);

    //     int96 amount = 385802469136; // 1 ether (1e18) per month

    //     bytes memory callData = helper.getCallDataCreate(eth,ethfiatPool,amount);
    //     sf.host.callAgreement(sf.cfa,callData,"0x00");

    //     // sf.cfaLib.createFlow(
    //     //     ethfiatPool,
    //     //     eth,
    //     //     amount// flowRate
    //     // );

    //    (, int96 flowRate, , ) = sf.cfa.getFlow(eth, alice, ethfiatPool);
    //    (, int96 fiatInFlowRate,, ) = sf.cfa.getFlow(fiat,ethfiatPool,alice);
    //    //assertEq(fiatInFlowRate,uint96(amount*1e8/IStreamSwapPool(ethfiatPool).latestPrice()));
    //     require(fiatInFlowRate > 0, 'failed to streamswap');
    //     assertEq(flowRate, amount);

    //     sf.cfaLib.updateFlow(ethfiatPool,eth,amount*3);

    //      (, int96 updatedFlowRate, , ) = sf.cfa.getFlow(eth, alice, ethfiatPool);
    //    (, int96 updatedFiatInFlowRate,, ) = sf.cfa.getFlow(fiat,ethfiatPool,alice);

    //     assertEq(updatedFlowRate, amount*3);
    //     require(updatedFiatInFlowRate == fiatInFlowRate*3, 'failed to update');

    //     sf.cfaLib.deleteFlow(
    //         alice,
    //         ethfiatPool,
    //         eth
    //     );

    //     (, int96 newflowRate, , ) = sf.cfa.getFlow(eth, alice, ethfiatPool);
    //     (, int96 newfiatInFlowRate,, ) = sf.cfa.getFlow(fiat,ethfiatPool,alice);

    //      assertEq(newflowRate, 0);
    //      assertEq(newfiatInFlowRate, 0);

    // }

    // function testMultipleUsers() public {
    //     assertEq(factory.isPool(address(eth), address(fiat)), ethfiatPool);
    //     assertEq(chainlinkETH.latestAnswer(), 200000000000);

    //     int96 amount = 385802469136; // 1 ether (1e18) per month

    //     bytes memory callData = helper.getCallDataCreate(eth,ethfiatPool,amount);
    //     vm.prank(alice);
    //     sf.host.callAgreement(sf.cfa,callData,"0x00");
    //     vm.prank(bob);
    //     sf.host.callAgreement(sf.cfa,callData,"0x00");
    //     vm.prank(charlie);
    //     sf.host.callAgreement(sf.cfa,callData,"0x00");

    //    (, int96 aliceflowRate, , ) = sf.cfa.getFlow(eth, alice, ethfiatPool);
    //    (, int96 aliceFiatInFlowRate,, ) = sf.cfa.getFlow(fiat,ethfiatPool,alice);

    //     require(aliceFiatInFlowRate > 0, 'failed to streamswap');
    //     assertEq(aliceflowRate, amount);

    //      (, int96 bobFlowRate, , ) = sf.cfa.getFlow(eth, bob, ethfiatPool);
    //    (, int96 bobFiatInFlowRate,, ) = sf.cfa.getFlow(fiat,ethfiatPool,bob);

    //     assertEq(bobFlowRate, amount);
    //     require(bobFiatInFlowRate == aliceFiatInFlowRate, 'failed to update');

    //     (, int96 charlieflowRate, , ) = sf.cfa.getFlow(eth, charlie, ethfiatPool);
    //     (, int96 charliefiatInFlowRate,, ) = sf.cfa.getFlow(fiat,ethfiatPool,charlie);

    //      assertEq(charlieflowRate, amount);
    //      assertEq(charliefiatInFlowRate, aliceFiatInFlowRate);

    //     // 3000$ ether from $2000
    //     MockChainlink(address(chainlinkETH)).updateAnswer(300000000000);

    //     IStreamSwapPool(ethfiatPool).checkPrice();

    //     (, int96 aliceAfterflowRate, , ) = sf.cfa.getFlow(eth, alice, ethfiatPool);
    //    (, int96 aliceAfterFiatInFlowRate,, ) = sf.cfa.getFlow(fiat,ethfiatPool,alice);

    //     require(aliceAfterFiatInFlowRate > aliceFiatInFlowRate, 'failed for alice');
    //     assertEq(aliceAfterflowRate, amount);
    //     assertEq(aliceflowRate, amount);

    //       (, int96 bobAfterFlowRate, , ) = sf.cfa.getFlow(eth, bob, ethfiatPool);
    //    (, int96 bobAfterFiatInFlowRate,, ) = sf.cfa.getFlow(fiat,ethfiatPool,bob);

    //     assertEq(bobAfterFlowRate, amount);
    //     require(bobAfterFiatInFlowRate == aliceAfterFiatInFlowRate, 'failed for bob');
    // }

    // function testGasForCheckPriceWith100Users() public {
    //     assertEq(factory.isPool(address(eth), address(fiat)), ethfiatPool);
    //     assertEq(chainlinkETH.latestAnswer(), 200000000000);
    //     IStreamSwapPool(ethfiatPool).checkPrice();

    //     int96 amount = 385802469136; // 1 ether (1e18) per month
    //     bytes memory callData = helper.getCallDataCreate(eth,ethfiatPool,amount);
    //     for (uint160 i=1 ;i<=100;++i){
    //          vm.prank(admin);
    //          address test = address(i);
    //          eth.mint(test,uint96(amount)*1000000000000);
    //          vm.prank(test);
    //          sf.host.callAgreement(sf.cfa,callData,"0x00");
    //     }

    //     // 3000$ ether from $2000
    //     MockChainlink(address(chainlinkETH)).updateAnswer(300000000000);

    //    IStreamSwapPool(ethfiatPool).checkPrice();

    // }

    // function testGasForCheckPriceWith100UsersWhoAlwaysUpdateTheOracle() public {
    //     assertEq(factory.isPool(address(eth), address(fiat)), ethfiatPool);
    //     IStreamSwapPool(ethfiatPool).checkPrice();

    //     int96 amount = 385802469136; // 1 ether (1e18) per month
    //     bytes memory callData = helper.getCallDataCreate(eth,ethfiatPool,amount);

    //     for (uint160 i=1 ;i<=50;++i){
    //         int256 newOraclePrice = chainlinkETH.latestAnswer();
    //         newOraclePrice = newOraclePrice * 1.03 ether / 1 ether;
    //         address test = address(i);
    //         vm.prank(admin);
    //         eth.mint(test,uint96(amount)*1000000000000);
    //         vm.prank(test);
    //         MockChainlink(address(chainlinkETH)).updateAnswer(int96(newOraclePrice));
    //         vm.prank(test);
    //         sf.host.callAgreement(sf.cfa,callData,"0x00");
    //     }

    //     int256 newOraclePrice = chainlinkETH.latestAnswer();
    //     newOraclePrice = newOraclePrice * 1.03 ether / 1 ether;
    //     MockChainlink(address(chainlinkETH)).updateAnswer(int96(newOraclePrice));
    //     // 3000$ ether from $2000

    //    IStreamSwapPool(ethfiatPool).checkPrice();

    // }

    // function testSwaps() public {

    //     vm.startPrank(alice);
    //     eth.increaseAllowance(ethfiatPool,1000e18);

    //     assertEq(eth.balanceOf(alice),10 ether);
    //     assertEq(fiat.balanceOf(alice),100000 ether);

    //     (uint256 tokenAmountOut,) = IStreamSwapPool(ethfiatPool).swapExactAmountIn([address(eth),address(fiat)], [uint256(0.5 ether),uint256(990 ether),uint256(2050 ether)]);
    //     emit log_uint(tokenAmountOut);
    //     require(eth.balanceOf(alice) == 9.5 ether, 'Wrong swap amount in');
    //     require(fiat.balanceOf(alice) >= 100990 ether, 'Wrong swap amount out'); // First swap with fee 0.1%
    //     require(tokenAmountOut >= 990 ether, 'Wrong amount out');
    //     //console.log(tokenAmountOut);
    //     vm.stopPrank();

    // }

    // /// @dev Tests metadata functions
    // function testMetaData() public {
    //     assertEq(eth.name(), "Super ETH");
    //     assertEq(eth.symbol(), "ETHx");
    //     assertEq(eth.decimals(), 18);

    //     assertEq(fiat.name(), "Super FIAT");
    //     assertEq(fiat.symbol(), "FIATx");
    //     assertEq(fiat.decimals(), 18);
    // }

    // /// @dev Tests transfer function
    // function testTransfer() public {
    //     vm.startPrank(admin);
    //     fiat.transfer(alice, 10 ether);

    //     assertEq(eth.balanceOf(admin), ethInitialSupply - 100 ether);
    //     assertEq(eth.balanceOf(alice), 10 ether);
    //     assertEq(eth.balanceOf(bob), 10 ether);

    //     assertEq(fiat.balanceOf(admin), fiatInitialSupply - 200010 ether);
    //     assertEq(fiat.balanceOf(alice), 100010 ether);
    // }

    // /// @dev Tests stream creation
    // function testStreamCreation() public {
    //     vm.warp(0);
    //     vm.startPrank(admin);

    //     int96 amount = 385802469136; // 1 ether (1e18) per month

    //     sf.cfaLib.createFlow(
    //         alice,
    //         eth,
    //         amount // flowRate
    //     );

    //     (, int96 flowRate, , ) = sf.cfa.getFlow(eth, admin, alice);

    //     assertEq(flowRate, amount);
    // }
}
