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

    function test_updatePayrolls_remove() public {
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
        vesting.updatePayrolls(contributors, payrollFlows);

        (, int96 lastFlowRatePayroll, , ) = sf.cfa.getFlow(
            fiat,
            address(vesting),
            bob
        );
        assertEq(lastFlowRatePayroll, 0);

        delete contributors;
        delete payrollFlows;
    }

  
}
