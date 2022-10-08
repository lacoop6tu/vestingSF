// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.0;

import {ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperToken.sol";
import {PureSuperToken} from "@superfluid-finance/ethereum-contracts/contracts/tokens/PureSuperToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title Example Super Token
/// @author jtriley.eth
/// @notice For demonstration only. You can delete this file.
contract MySuperToken is PureSuperToken, Ownable {
    /// @notice Mints to any receiver
    /// @param receiver Receiving address of mint
    /// @param amount Amount to mint
    /// @dev Only owner
    function mint(address receiver, uint256 amount) external onlyOwner {
        ISuperToken(address(this)).selfMint(receiver, amount, new bytes(0));
    }
}
