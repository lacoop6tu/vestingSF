pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC777/IERC777.sol";
import "@openzeppelin/contracts/interfaces/IERC1820Registry.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777Recipient.sol";

/**
 * @title Simple777Recipient
 * @dev Very simple ERC777 Recipient
 * see https://forum.openzeppelin.com/t/simple-erc777-token-example/746
 */
contract Simple777Recipient is IERC777Recipient {

    IERC1820Registry internal _erc1820 = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);
    bytes32 constant internal TOKENS_RECIPIENT_INTERFACE_HASH = keccak256("ERC777TokensRecipient");

    IERC777 internal _token1;
    IERC777 internal _token2;
   
    // event DoneStuff(address operator, address from, address to, uint256 amount, bytes userData, bytes operatorData);

    constructor (address sodaToken, address acceptedToken) {
       _token1 = IERC777(sodaToken);
       _token2 = IERC777(acceptedToken);

        _erc1820.setInterfaceImplementer(address(this), TOKENS_RECIPIENT_INTERFACE_HASH, address(this));
    }


    function tokensReceived(
        address,
        address,
        address,
        uint256,
        bytes calldata,
        bytes calldata
    ) external override {
      
        
        require(msg.sender == address(_token1) || msg.sender == address(_token2), "Simple777Recipient: Invalid token");
        
        

        // do nothing
        // emit DoneStuff(operator, from, to, amount, userData, operatorData);
    }
}