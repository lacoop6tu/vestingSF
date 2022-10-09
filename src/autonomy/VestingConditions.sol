// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IVesting {
    function endVesting() external returns (uint256);

    function updateVesting(
        address[] calldata contributors,
        uint256[] calldata vestingFlows
    ) external;
}

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
    IVesting internal _vestingSF;

    error VestingEndingTimeNotReached();
    error VestingFlowNotZero();

    constructor(address vestingSF) {
        _vestingSF = IVesting(vestingSF);
    }

    // AUTONOMY CONDITIONS
    function checkVestingEndingTime(address contributor) external {
        uint256 endVesting = _vestingSF.endVesting();
        if (block.timestamp < endVesting) revert VestingEndingTimeNotReached();
    }

    function setVesting(address vesting) external {
        _vestingSF = IVesting(vesting);
    }
}
