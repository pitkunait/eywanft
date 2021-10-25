// SPDX-License-Identifier: MIT
pragma solidity  ^0.8.0;

import "@openzeppelin/contracts-newone/access/Ownable.sol";
import '@openzeppelin/contracts-newone/utils/math/SafeMath.sol';
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';
import "./IBridge.sol";
import "./RelayRecipient.sol";


contract Portal is RelayRecipient {
    using SafeMath for uint256;

    mapping(address => uint) public balanceOf;
    address public bridge;

    enum RequestState { Default, Sent, Reverted }
    enum UnsynthesizeState { Default, Unsynthesized, RevertRequest }

    // struct TxState {
    //     address recipient;
    //     address chain2address;
    //     uint256 amount;
    //     address rtoken;
    //     RequestState state;
    // }

    struct TxState {
        bytes32 recipient;
        bytes32 chain2address;
        uint256 amount;
        bytes32 rtoken;
        RequestState state;
    }

    uint256 requestCount = 1;
    mapping (bytes32 => TxState) public requests;
    mapping (bytes32 => UnsynthesizeState) public unsynthesizeStates;

    event SynthesizeRequest(bytes32 indexed _id, address indexed _from, address indexed _to, uint _amount, address _token);
    event SynthesizeRequestSolana(bytes32 indexed _id, address indexed _from, bytes32 indexed _to, uint _amount, address _token);
    event RevertBurnRequest(bytes32 indexed _id, address indexed _to);
    event BurnCompleted(bytes32 indexed _id, address indexed _to, uint _amount, address _token);
    event RevertSynthesizeCompleted(bytes32 indexed _id, address indexed _to, uint _amount, address _token);

    constructor(address _bridge, address _trustedForwarder) RelayRecipient(_trustedForwarder) {
        bridge = _bridge;
    }

    modifier onlyBridge {
        require(bridge == msg.sender);
        _;
    }

    // Token -> sToken on a second chain
    function synthesize(
        address _token,
        uint256 _amount,
        address _chain2address,
        address _receiveSide,
        address _oppositeBridge,
        uint _chainID,
        uint256 _nonce
    ) external returns (bytes32 txID) {
        TransferHelper.safeTransferFrom(_token, _msgSender(), address(this), _amount);
        balanceOf[_token] = balanceOf[_token].add(_amount);

        txID = IBridge(bridge).prepareRqId(
            bytes32(uint256(uint160(_oppositeBridge))),
            _chainID,
            bytes32(uint256(uint160(_receiveSide))),
            bytes32(uint256(uint160(_msgSender()))),
            _nonce
        );

        bytes memory out  = abi.encodeWithSelector(bytes4(keccak256(bytes('mintSyntheticToken(bytes32,address,uint256,address)'))), txID, _token, _amount, _chain2address);
        // TODO add payment by token
        IBridge(bridge).transmitRequestV2(out,_receiveSide, _oppositeBridge, _chainID, txID, _msgSender(), _nonce);
        TxState storage txState = requests[txID];
        txState.recipient    = bytes32(uint256(uint160(_msgSender())) << 96);
        txState.chain2address    = bytes32(uint256(uint160(_chain2address)) << 96);
        txState.rtoken     = bytes32(uint256(uint160(_token)) << 96);
        txState.amount     = _amount;
        txState.state = RequestState.Sent;

        // requestCount +=1;

        emit SynthesizeRequest(txID, _msgSender(), _chain2address, _amount, _token);
    }

    function synthesize(
        address _token,
        uint256 _amount,
        bytes32 _chain2address,
        bytes32 _receiveSide,
        bytes32 _oppositeBridge,
        uint _chainID,
        uint256 _nonce
    ) external returns (bytes32 txID) {
        TransferHelper.safeTransferFrom(_token, _msgSender(), address(this), _amount);
        balanceOf[_token] = balanceOf[_token].add(_amount);

        txID = IBridge(bridge).prepareRqId(_oppositeBridge, _chainID, _receiveSide, bytes32(uint256(uint160(_msgSender()))), _nonce);


        bytes memory out  = abi.encodeWithSelector(bytes4(keccak256(bytes('mintSyntheticToken(bytes32,address,uint256,address)'))), txID, _token, _amount, _chain2address);
        // TODO add payment by token
        IBridge(bridge).transmitRequestV2(out,_receiveSide, _oppositeBridge, _chainID, txID, _msgSender(), _nonce);
        TxState storage txState = requests[txID];
        txState.recipient    = bytes32(uint256(uint160(_msgSender()))<< 96);
        txState.chain2address    = _chain2address;
        txState.rtoken     = bytes32(uint256(uint160(_token))<< 96);
        txState.amount     = _amount;
        txState.state = RequestState.Sent;

        // requestCount +=1;

        emit SynthesizeRequestSolana(txID, _msgSender(), _chain2address, _amount, _token);
    }

    // // Token -> sToken on a second chain withPermit
    // function synthesizeWithPermit(
    //     bytes calldata _approvalData,
    //     address _token,
    //     uint256 _amount,
    //     address _chain2address,
    //     address _receiveSide,
    //     address _oppositeBridge,
    //     uint _chainID,
    //     uint256 _nonce
    // )  external returns (bytes32 txID) {

    //     (bool _success1, ) = _token.call(_approvalData);
    //     require(_success1, "Approve call failed");

    //     TransferHelper.safeTransferFrom(_token, _msgSender(), address(this), _amount);
    //     balanceOf[_token] = balanceOf[_token].add(_amount);

    //     txID = IBridge(bridge).prepareRqId(_oppositeBridge, _chainID, _receiveSide, _msgSender(), _nonce);

    //     bytes memory out  = abi.encodeWithSelector(bytes4(keccak256(bytes('mintSyntheticToken(bytes32,address,uint256,address)'))), txID, _token, _amount, _chain2address);
    //     // TODO add payment by token
    //     IBridge(bridge).transmitRequestV2(out,_receiveSide, _oppositeBridge, _chainID, txID, _msgSender(), _nonce);
    //     TxState storage txState = requests[txID];
    //     txState.recipient    = _msgSender();
    //     txState.chain2address    = _chain2address;
    //     txState.rtoken     = _token;
    //     txState.amount     = _amount;
    //     txState.state = RequestState.Sent;

    //     // requestCount +=1;

    //     emit SynthesizeRequest(txID, _msgSender(), _chain2address, _amount, _token);
    // }

    // // can called only by bridge after initiation on a second chain
    // function emergencyUnsynthesize(bytes32 _txID) external onlyBridge {
    //     TxState storage txState = requests[_txID];
    //     require(txState.state == RequestState.Sent , 'Portal:state not open or tx does not exist');

    //     txState.state = RequestState.Reverted; // close
    //     TransferHelper.safeTransfer(txState.rtoken, txState.recipient, txState.amount);

    //     emit RevertSynthesizeCompleted(_txID, txState.recipient, txState.amount, txState.rtoken);
    // }

    // // can called only by bridge after initiation on a second chain
    // function unsynthesize(bytes32 _txID, address _token, uint256 _amount, address _to) external onlyBridge {
    //     require(unsynthesizeStates[_txID] == UnsynthesizeState.Default, "Portal: syntatic tokens emergencyUnburn");

    //     TransferHelper.safeTransfer(_token, _to, _amount);
    //     balanceOf[_token] = balanceOf[_token].sub(_amount);

    //     unsynthesizeStates[_txID] = UnsynthesizeState.Unsynthesized;

    //     emit BurnCompleted(_txID, _to, _amount, _token);
    // }

    // // Revert burnSyntheticToken() operation, can be called several times
    // function emergencyUnburnRequest(bytes32 _txID, address _receiveSide, address _oppositeBridge, uint _chainId, uint256 _nonce) external {
    //     require(unsynthesizeStates[_txID] != UnsynthesizeState.Unsynthesized, "Portal: Real tokens already transfered");
    //     unsynthesizeStates[_txID] = UnsynthesizeState.RevertRequest;

    //     bytes memory out  = abi.encodeWithSelector(bytes4(keccak256(bytes('emergencyUnburn(bytes32)'))),_txID);
    //     // TODO add payment by token
    //     bytes32 txID = IBridge(bridge).prepareRqId(_oppositeBridge, _chainId, _receiveSide, _msgSender(), _nonce);
    //     IBridge(bridge).transmitRequestV2(out, _receiveSide, _oppositeBridge, _chainId, txID, _msgSender(), _nonce);

    //     emit RevertBurnRequest(txID, _msgSender());
    // }

    // should be restricted in mainnets
    function changeBridge(address _bridge) external onlyOwner {
        bridge = _bridge;
    }

    function versionRecipient() public view returns (string memory) {
        return "2.0.1";
    }
}
