// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.0;

import {ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperToken.sol";

/// @title Example Token Interface
/// @author jtriley.eth
/// @notice For demonstration only. You can delete this file.
interface IMySuperToken is ISuperToken {
    function mint(address receiver, uint256 amount) external;

    function initialize(
        string calldata name,
        string calldata symbol,
        uint256 initialSupply
    ) external;
}
