pragma solidity >=0.8.0;
pragma abicoder v2;
// Copyright BigchainDB GmbH and Ocean Protocol contributors
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0

//import { StreamSwap } from "./../StreamSwap.sol";
import {ISuperfluid, SuperAppDefinitions, ISuperToken, ISuperAgreement } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {IConstantFlowAgreementV1} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";
import {SuperAppBase} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperAppBase.sol";
import {AggregatorV2V3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";
/**
 * @title BPool
 *
 * @dev Used by the (Ocean version) BFactory contract as a bytecode reference to
 *      deploy new BPools.
 *
 * This contract is is nearly identical to the BPool.sol contract at [1]
 *  The only difference is the "Proxy contract functionality" section
 *  given below. We'd inherit from BPool if we could, for simplicity.
 *  But we can't, because the proxy section needs to access private
 *  variables declared in BPool, and Solidity disallows this. Therefore
 *  the best we can do for now is clearly demarcate the proxy section.
 *
 *  [1] https://github.com/balancer-labs/balancer-core/contracts/.
 */
contract CallAgreementHelper  {

    // SUPERFLUID PART
    ISuperfluid internal _host; // host
    IConstantFlowAgreementV1 internal _cfa; // the stored constant flow agreement class address
  



    constructor (ISuperfluid host,
        IConstantFlowAgreementV1 cfa)  {
         _host = host;
        _cfa = cfa;
      
        }



    function getCallDataUpdate(address token, address to,int96 rate) external view returns (bytes memory){
            return abi.encodeWithSelector(
                        _cfa.updateFlow.selector,
                        token,
                        to,
                        rate,
                        new bytes(0) // placeholder
                    );
    }


    function getCallDataCreate(ISuperToken token, address to,int96 rate) external view returns (bytes memory){
            return   abi.encodeWithSelector(
                _cfa.createFlow.selector,
                token,
                to,
                rate,
                new bytes(0) // placeholder
            );
    }

    function getCallDataDelete(address token, address to) external view returns (bytes memory){
            return  abi.encodeWithSelector(
                _cfa.deleteFlow.selector,
                token,
                msg.sender,
                to,
                new bytes(0) // placeholder
            );
    }
        
       

   
}
