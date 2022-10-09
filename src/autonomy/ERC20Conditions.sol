// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Vesting} from "../vesting/Vesting.sol";

// Autonomy registration
interface IRegistry {
    function newReq(
        address target,
        address payable referer,
        bytes calldata callData,
        uint112 ethForCall,
        bool verifyUser,
        bool insertFeeAmount,
        bool isAlive
    ) external payable returns (uint256 id);
}

contract ERC20Conditions {
    /**
     * @notice   ERC20Conditions checks the balance of a erc20
     */

    enum Condition {
        GREATER,
        LOWER,
        EQUAL
    }

    error ConditionNotMeet();
    error TrigerFailed();

    event BalanceConditionActionTrigerred(Condition cond, string msg);
    event Received(address, uint256);

    // AUTONOMY CONDITIONS

    function checkBalance(
        address erc20token,
        address user,
        Condition condition,
        uint256 amount
    ) external view {
        IERC20 erc20 = IERC20(erc20token);
        uint256 userBalance = erc20.balanceOf(user);

        if (condition == Condition.EQUAL) {
            if (userBalance != amount) revert ConditionNotMeet();
        } else if (condition == Condition.GREATER) {
            if (userBalance < amount) revert ConditionNotMeet();
        } else {
            if (userBalance > amount) revert ConditionNotMeet();
        }
    }

    // AUTONOMY REGISTRY

    function createNewRequest(
        address autonomyTarget,
        address erc20token,
        address user,
        Condition condition,
        uint256 amount
    ) internal {
        bytes memory callData = abi.encodeWithSelector(
            ERC20Conditions.checkBalance.selector,
            erc20token,
            user,
            condition,
            amount
        );

        // console.log

        IRegistry registry = IRegistry(autonomyTarget);
        uint256 reqId = registry.newReq(
            autonomyTarget,
            payable(address(0)),
            callData,
            0,
            true,
            true,
            true
        );
    }

    // AUTONOMY ACTIONS

    function balanceLowerAction(address destination) external {
        // Only for testing - Transfer some MATIC from this contract
        (bool success, ) = destination.call{value: 2 gwei}("");
        if (!success) revert TrigerFailed();
        emit BalanceConditionActionTrigerred(
            Condition.LOWER,
            "balance lower trigerred"
        );
    }

    function balanceGreaterAction(address destination) external {
        (bool success, ) = destination.call{value: 2 gwei}("");
        if (!success) revert TrigerFailed();
        emit BalanceConditionActionTrigerred(
            Condition.GREATER,
            "balance greater trigerred"
        );
    }

    function balanceEqualAction(address destination) external {
        (bool success, ) = destination.call{value: 2 gwei}("");
        if (!success) revert TrigerFailed();
        emit BalanceConditionActionTrigerred(
            Condition.EQUAL,
            "balance equal trigerred"
        );
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
}
