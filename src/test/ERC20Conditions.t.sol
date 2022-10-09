// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../autonomy/ERC20Conditions.sol";
import "../utils/mocks/MockERC20.sol";

contract ERC20ConditionsTest is Test {
    address user = address(0xAA);
    MockERC20 mockEc20;
    ERC20Conditions conditions;
    uint256 initialAmount = 1e25;

    function setUp() public {
        vm.startPrank(user);
        mockEc20 = new MockERC20(user, "MockERC20", "MCK");
        vm.stopPrank();
        conditions = new ERC20Conditions();
    }

    function testGreater() public {
        conditions.checkBalance(
            address(mockEc20),
            user,
            ERC20Conditions.Condition.GREATER,
            initialAmount - 10000
        );
    }

    function testEqual() public {
        conditions.checkBalance(
            address(mockEc20),
            user,
            ERC20Conditions.Condition.EQUAL,
            initialAmount
        );
    }

    function testLower() public {
        conditions.checkBalance(
            address(mockEc20),
            user,
            ERC20Conditions.Condition.LOWER,
            initialAmount + 1000
        );
    }

    function testGreaterRevert() public {
        vm.expectRevert(
            abi.encodeWithSelector(ERC20Conditions.ConditionNotMeet.selector)
        );
        conditions.checkBalance(
            address(mockEc20),
            user,
            ERC20Conditions.Condition.GREATER,
            initialAmount + 10000
        );
    }

    function testEqualRevert() public {
        vm.expectRevert(
            abi.encodeWithSelector(ERC20Conditions.ConditionNotMeet.selector)
        );
        conditions.checkBalance(
            address(mockEc20),
            user,
            ERC20Conditions.Condition.EQUAL,
            initialAmount + 10
        );
    }

    function testLowerRevert() public {
        vm.expectRevert(
            abi.encodeWithSelector(ERC20Conditions.ConditionNotMeet.selector)
        );
        conditions.checkBalance(
            address(mockEc20),
            user,
            ERC20Conditions.Condition.LOWER,
            initialAmount - 1000
        );
    }
}
