// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../autonomy/VestingConditions.sol";
import {ActionEndVesting} from "../autonomy/ActionEndVesting.sol";
import {Vesting} from "../vesting/Vesting.sol";

contract VestingConditionsTest is Test {
    VestingConditions vestingConditions;
    ActionEndVesting actionEndVesting;
    address internal constant vestingContract = address(1);
    address[] contributors;
    uint256[] vestingFlows;

    function setUp() public {
        vestingConditions = new VestingConditions(vestingContract);
        actionEndVesting = new ActionEndVesting(vestingContract);
    }

    function testCheckEndVesting() public {
        uint256 endingTime = block.timestamp + 1000;
        contributors.push(address(1));
        vestingFlows.push(0);
        bytes memory data = abi.encodeWithSelector(
            Vesting.updateVesting.selector,
            contributors,
            vestingFlows
        );
        vm.mockCall(vestingContract, data, abi.encode());
        actionEndVesting.closeVestingFlow(contributors, vestingFlows);
    }

    function testCheckEndVestingRevert() public {
        uint256 endingTime = block.timestamp + 1000;
        contributors.push(address(1));
        vestingFlows.push(1);
        vm.expectRevert(VestingConditions.VestingFlowNotZero.selector);
        actionEndVesting.closeVestingFlow(contributors, vestingFlows);
    }
}
