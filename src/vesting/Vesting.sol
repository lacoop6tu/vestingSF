pragma solidity >=0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {ISuperfluid, SuperAppDefinitions, ISuperToken, ISuperAgreement} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {Simple777Recipient} from "./../utils/Simple777Recipient.sol";
import {IConstantFlowAgreementV1} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";
import {SuperAppBase} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperAppBase.sol";

// TODO: ADD SUPPORT FOR MULTIPLES LPTs on this contract or CREATE MULTIPLE ONES. It would be better to use this one if possible or not too complicated.

// forked from https://github.com/SetProtocol/index-coop-contracts/blob/master/contracts/staking/StakingRewardsV2.sol
// NOTE: V2 allows setting of rewardsDuration in constructor
contract Vesting is ReentrancyGuard, Simple777Recipient {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */
  
    uint256 public totalDepositsVesting;
    uint256 public totalDepositsPayroll;


    // SUPERFLUID PART
    ISuperfluid internal _host; // host
    IConstantFlowAgreementV1 internal _cfa; // the stored constant flow agreement class address

    ISuperToken public vestingToken; // StreamSwap Token
    ISuperToken public payrollToken; // StreamSwap Token

    address public dao;
    address public manager;

    mapping(address => mapping(IERC20 => Data)) public contributors;

    struct Data {
        bool active;
        uint256 inFlowRate;
        uint256 outFlowRate;
        uint256 totalFlows;
    }

    struct Info {
        uint256 vestingPerSecond;
        uint256 payrollPerSecond;
    }

    /* ========== EVENTS ========== */

   

    /* ========== CONSTRUCTOR ========== */

    constructor(
        ISuperfluid host,
        IConstantFlowAgreementV1 cfa,
        address _vestingToken,
        address _payrollToken,
        address _dao,
        address _manager
    ) public Simple777Recipient(_vestingToken, _payrollToken) {
        _host = host;
        _cfa = cfa;
        dao = _dao;
        manager = _manager;

        vestingToken = ISuperToken(_vestingToken);
        payrollToken = ISuperToken(_payrollToken);
    
        uint256 configWord = SuperAppDefinitions.APP_LEVEL_FINAL |
            SuperAppDefinitions.BEFORE_AGREEMENT_CREATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_UPDATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_TERMINATED_NOOP;
        //  require(host =! address(0),'BOOM');
        _host.registerApp(configWord);
    }

    modifier onlyDAO() {
        require(msg.sender == dao, "ONLY DAO");
        _;
    }

    modifier onlyManager() {
        require(msg.sender == manager, "ONLY MANAGER");
        _;
    }

    /* ========== VIEWS ========== */

 


    /* ========== MUTATIVE FUNCTIONS ========== */

    function addCoreContributors(
        address[] calldata contributors,
        uint256[] calldata vestingFlows,
        uint256[] calldata payrollFlows
    ) external onlyDAO {
        require(contributors.length == vestingFlows.length, "Length mismatch");
        require(vestingFlows.length == payrollFlows.length, "Length mismatch ");

        for (uint256 i; i < contributors.length; i++) {
            if (vestingFlows[i] != 0) {
                _createOutflow(vestingToken, contributors[i], vestingFlows[i]);
            }
        }
        for (uint256 j; j < contributors.length; j++) {
            if (payrollFlows[j] != 0) {
                _createOutflow(payrollToken, contributors[j], payrollFlows[j]);
            }
        }
    }

    function updateVesting(
        address[] calldata contributors,
        uint256[] calldata vestingFlows
    ) external onlyDAO {
        require(contributors.length == vestingFlows.length, "Length mismatch");

        for (uint256 i; i < contributors.length; i++) {
            if (vestingFlows[i] != 0) {
                _updateOutflow(vestingToken, contributors[i], vestingFlows[i]);
            } else {
                _deleteOutflow(vestingToken, contributors[i]);
            }
        }
    }

    // Manager role
    
    function addPayrolls(
        address[] calldata contributors,
        uint256[] calldata payrollFlows
    ) external onlyManager {
        require(contributors.length == payrollFlows.length, "Length mismatch");

        for (uint256 i; i < contributors.length; i++) {
            if (payrollFlows[i] != 0) {
                _createOutflow(payrollToken, contributors[i], payrollFlows[i]);
            }
        }
    }

    function updatePayrolls(
        address[] calldata contributors,
        uint256[] calldata payrollFlows
    ) external onlyManager {
        require(contributors.length == payrollFlows.length, "Length mismatch");

        for (uint256 i; i < contributors.length; i++) {
            if (payrollFlows[i] != 0) {
                _updateOutflow(payrollToken, msg.sender, payrollFlows[i]);
            } else {
                _deleteOutflow(payrollToken, msg.sender);
            }
        }
    }

    /**************************************************************************
     * SatisfyFlows Logic
     *************************************************************************/
    /// @dev If a new stream is opened, or an existing one is opened
    function _createOutflow(
        ISuperToken _tokenOut,
        address customer,
        uint256 flow
    ) internal {

        (   uint256 timestamp,
            int96 outFlowRate,
            uint256 deposit,
            uint256 owedDeposit) = _cfa.getFlow(
            _tokenOut,
            address(this),
            customer
        );

        require(outFlowRate == 0, "OUTFLOW RATE > 0");

        outFlowRate = int96(int256(flow));

        _host.callAgreement(
            _cfa,
            abi.encodeWithSelector(
                _cfa.createFlow.selector,
                _tokenOut,
                customer,
                outFlowRate,
                new bytes(0) // placeholder
            ),
            "0x"
        );

        contributors[customer][_tokenOut].outFlowRate = uint256(
            uint96(outFlowRate)
        );
    }

    function _updateOutflow(
        ISuperToken _tokenOut,
        address customer,
        uint256 flow
    ) internal {
        (, int96 outFlowRate, , ) = _cfa.getFlow(
            _tokenOut,
            address(this),
            customer
        );

        require(outFlowRate != 0, "OUT FLOW RATE IS ZERO");

        outFlowRate = int96(int256(flow));

        _host.callAgreement(
            _cfa,
            abi.encodeWithSelector(
                _cfa.updateFlow.selector,
                _tokenOut,
                customer,
                outFlowRate,
                new bytes(0) // placeholder
            ),
            "0x"
        );

        contributors[customer][_tokenOut].outFlowRate = uint256(
            uint96(outFlowRate)
        );
    }

    function _deleteOutflow(ISuperToken _tokenOut, address customer) internal {
        (, int96 outFlowRate, , ) = _cfa.getFlow(
            _tokenOut,
            address(this),
            customer
        );

        require(outFlowRate != 0, "OUT FLOW RATE IS ZERO");

        contributors[customer][_tokenOut].outFlowRate = 0;

        _host.callAgreement(
            _cfa,
            abi.encodeWithSelector(
                _cfa.deleteFlow.selector,
                _tokenOut,
                address(this),
                customer,
                new bytes(0) // placeholder
            ),
            "0x"
        );
    }

    //     /**************************************************************************
    //  * SuperApp callbacks
    //  *************************************************************************/
    // function afterAgreementCreated(
    //     ISuperToken _superToken,
    //     address _agreementClass,
    //     bytes32 _agreementId,
    //     bytes calldata, /*_agreementData*/
    //     bytes calldata, // _cbdata,
    //     bytes calldata _ctx
    // )
    //     external
    //     override
    //     onlyHost
    //     returns (bytes memory newCtx)
    // {
    //     require(_isCFAv1(_agreementClass), "SatisfyFlows: only CFAv1 supported");
    //     address customer = _host.decodeCtx(_ctx).msgSender;

    //     return _createOutflow(_superToken,_ctx, customer, _agreementId);
    // }

    // function afterAgreementUpdated(
    //     ISuperToken _superToken,
    //     address _agreementClass,
    //     bytes32 _agreementId,
    //     bytes calldata, /*_agreementData*/
    //     bytes calldata, //_cbdata,
    //     bytes calldata _ctx
    // )
    //     external
    //     override
    //     onlyHost
    //     returns (bytes memory newCtx)
    // {
    //     require(_isCFAv1(_agreementClass), "SatisfyFlows: only CFAv1 supported");
    //     address customer = _host.decodeCtx(_ctx).msgSender;
    //     return _updateOutflow(_superToken,_ctx, customer, _agreementId);
    // }

    // function afterAgreementTerminated(
    //     ISuperToken _superToken,
    //     address _agreementClass,
    //     bytes32 _agreementId,
    //     bytes calldata _agreementData,
    //     bytes calldata, //_cbdata,
    //     bytes calldata _ctx
    // ) external override onlyHost returns (bytes memory newCtx) {
    //     // According to the app basic law, we should never revert in a termination callback
    //     if (!_isCFAv1(_agreementClass))
    //         return _ctx;
    //     (address customer, ) = abi.decode(_agreementData, (address, address));
    //     return _deleteOutflow(_superToken,_ctx, customer, _agreementId);
    // }

    // function _isCFAv1(address agreementClass) private view returns (bool) {
    //     return
    //         ISuperAgreement(agreementClass).agreementType() ==
    //         keccak256(
    //             "org.superfluid-finance.agreements.ConstantFlowAgreement.v1"
    //         );
    // }

    // modifier onlyHost() {
    //     require(
    //         msg.sender == address(_host),
    //         "SatisfyFlows: support only one host"
    //     );
    //     _;
    // }
}
