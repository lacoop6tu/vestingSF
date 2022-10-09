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

contract VestingConditions {
    Vesting internal _vestingSF;

    error VestingEndingTimeNotReached();
    error VestingFlowNotZero();

    constructor(address vestingSF) {
        _vestingSF = Vesting(vestingSF);
    }

    // AUTONOMY CONDITIONS

    // TODO add mapping ending time per contributor
    function checkVestingEndingTime(address contributor) external view {
        uint256 endVesting = _vestingSF.endVesting();
        if (block.timestamp < endVesting) revert VestingEndingTimeNotReached();
    }

    // AUTONOMY REGISTRY
    // TODO test this
    function createNewRequest(address autonomyTarget, address contributor)
        internal
        returns (uint256)
    {
        bytes memory callData = abi.encodeWithSelector(
            VestingConditions.checkVestingEndingTime.selector,
            contributor
        );

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
        return reqId;
    }

    // AUTONOMY ACTIONS

    function closeVestingFlow(
        address[] calldata contributors,
        uint256[] calldata vestingFlows
    ) external {
        require(contributors.length == vestingFlows.length, "Length mismatch");
        // Check vestingFlows are set to 0
        for (uint256 i; i < contributors.length; i++) {
            if (vestingFlows[i] != 0) revert VestingFlowNotZero();
        }
        _vestingSF.updateVesting(contributors, vestingFlows);
    }
}
