// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interface/IERC998ERC721TopDown.sol";
import "./interface/IERC998ERC721TopDownEnumerable.sol";
import "./interface/IERC998ERC20TopDown.sol";
import "./interface/IERC998ERC20TopDownEnumerable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "hardhat/console.sol";


error ERC998Enumerable_InvalidContractIndex(uint256 tokenId, uint256 index);
error ERC998Enumerable_InvalidTokenIndex(uint256 tokenId, address childContract, uint256 index);
error ERC998_HasNoRootOwner(uint256 tokenId);
error ERC998_CallerIsNotOwnerNorApprovedOperator(uint256 tokenId);
error ERC998_ApprovalToCurrentOwner(uint256 tokenId);
error ERC998_ChildTokenAlreadyExists(uint256 tokenId, address childContract, uint256 childTokenId);
error ERC998_InvalidReceiver(address to);
error ERC998_InvalidFromTokenId(uint256 fromTokenId, uint256 tokenId);
error ERC998_ChildContractNotFound(address childContract);
error ERC998_ChildTokenNotFound(address childContract, uint256 childTokenId);
error ERC998_InvalidChildContract(address childContract);
error ERC998_InvalidFromAddress(address from);
error ERC998_FromAddressIsNotOwnerOfChildToken(address from);
error ERC998_CircularOwnership();
error ERC998_TooDeepComposable(uint256 parentTokenId, uint256 childTokenId, uint16 maxDepth);
error ERC998_InvalidERC20Value(uint256 tokenId, address erc20Contract, uint256 value);
error ERC998_InsufficientERC20Balance(uint256 tokenId, address erc20Contract, uint256 value);
error ERC998_InsufficientAllowance(address from, address erc20Contract, uint256 value);
error ERC998_AllowanceCallFailed(address from, address erc20Contract, uint256 value);

/// @title ERC998
/// @author Maxime Normandin <m.normandin@tranqilo.ca>
/// @notice ERC998 is a contract that implements the ERC998 interface.
/// @notice This contract is a updated version of the ERC998 contract by Nick Mudge <nick@perfectabstractions.com>,
/// @notice Original implementation: https://github.com/mattlockyer/composables-998/blob/master/contracts/ComposableTopDown.sol
/// @dev This contract is used to create a top-down composable NFT with ERC721 and ERC20. 
abstract contract ERC998 is
  ERC721, 
  IERC721Receiver,
  IERC998ERC721TopDown, 
  IERC998ERC721TopDownEnumerable,
  IERC998ERC20TopDown,
  IERC998ERC20TopDownEnumerable,
  ReentrancyGuard
{
  using SafeERC20 for IERC20;

  /// @notice ERC998 magic value for root ownership identification
  /// @notice This value was taken from the original implementation
  /// @dev return this.rootOwnerOf.selector ^ this.rootOwnerOfChild.selector ^ this.tokenOwnerOf.selector ^ this.ownerOfChild.selector;
  bytes32 constant ERC998_MAGIC_VALUE = IERC998ERC721TopDown.rootOwnerOf.selector ^ IERC998ERC721TopDown.rootOwnerOfChild.selector ^ IERC998ERC721TopDown.ownerOfChild.selector;
  
  /// @notice Interface ID for IERC721Receiver
  bytes4 private constant _ERC721_RECEIVED = IERC721Receiver.onERC721Received.selector;

  /// @notice Maximum depth of nested composable tokens
  /// @dev This constant is used to prevent too deep composable
  /// @dev If a composable becomes too deep, it would hit gas limit and make the composable unusable
  uint16 public constant MAX_DEPTH = 100;

  /// @notice Structure to hold data for a token
  struct TokenData {
    /// @notice ERC721 Management
    address[] erc721Contracts;
    mapping(address erc721childContract => uint256 index) erc721childContractIndex;
    mapping(address erc721Contract => uint256[] childTokenIds) erc721ChildTokenIds;
    mapping(address erc721Contract => mapping(uint256 childTokenId => uint256 index)) erc721ChildTokenIndex;

    /// @notice ERC20 Management
    address[] erc20Contracts;
    mapping(address erc20Contract => uint256 balance) erc20Balances;
    mapping(address erc20Contract => uint256 index) erc20ContractIndex;
  }

  /// @notice Mapping from token ID to its composable data
  mapping(uint256 tokenId => TokenData) private _tokenData;

  /// @notice Mapping from root owner to its allowance
  mapping(address rootOwner => mapping(uint256 childTokenId => address approvedAddress)) internal _rootOwnerTokenApprovals;

  /// @notice Mapping to track which parent owns which child
  mapping(address childContract => mapping(uint256 childTokenId => uint256 parentTokenId)) internal _childTokenOwner;

  constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

  function mint(address to, uint256 tokenId) external virtual returns (uint256) {
    _mint(to, tokenId);
    return tokenId;
  }

  // ========================================================
  // Approval Functions based on ERC721 & the Root Owner
  // ========================================================

  /// @notice Approve an address to transfer a child token
  /// @param to The address to approve
  /// @param tokenId The token ID of the parent token
  /// @dev This function is used to approve an address to transfer a child token
  function approve(address to, uint256 tokenId) public virtual override(ERC721) {
    _requireOwned(tokenId);
    address rootOwner = _getRootOwnerAddress(tokenId);
    require(rootOwner != address(0), ERC998_HasNoRootOwner(tokenId));
    require(
      msg.sender == rootOwner || 
      super.isApprovedForAll(rootOwner, msg.sender) ||
      _rootOwnerTokenApprovals[rootOwner][tokenId] == msg.sender,
      ERC998_CallerIsNotOwnerNorApprovedOperator(tokenId)
    );
    require(to != rootOwner, ERC998_ApprovalToCurrentOwner(tokenId));
        
    _rootOwnerTokenApprovals[rootOwner][tokenId] = to;
    super.approve(to, tokenId);
    emit Approval(rootOwner, to, tokenId);
  }

  /// @notice Get the approved address for a child token
  /// @param tokenId The token ID of the parent token
  /// @return The approved address
  function getApproved(uint256 tokenId) public view virtual override(ERC721) returns (address) {
    _requireOwned(tokenId);
    address rootOwner = _getRootOwnerAddress(tokenId);
    return _rootOwnerTokenApprovals[rootOwner][tokenId];
  }

  // ========================================================
  // IERC998ERC721TopDown Implementation 
  // ========================================================
  
  /// @notice Get the root owner of a token (the ultimate owner in the composable hierarchy)
  /// @param tokenId The token ID to check
  /// @return rootOwner The root owner encoded as bytes32
  function rootOwnerOf(uint256 tokenId) public view returns (bytes32 rootOwner) {
    return rootOwnerOfChild(address(0), tokenId);
  }

  /// @notice Get the root owner of a child token
  /// @notice This function traverses the ownership hierarchy to find the ultimate owner
  /// @dev It's a O(n) operation where n is the depth of the composable
  /// @param childContract The child contract address
  /// @param childTokenId The child token ID
  /// @return bytes32 The root owner encoded as bytes32
  function rootOwnerOfChild(
    address childContract,
    uint256 childTokenId
  ) public view returns (bytes32) {
    address currentOwner;
    uint256 currentTokenId = childTokenId;
    address currentContract = childContract == address(0) ? address(this) : childContract;

    if (childContract != address(0)) {
      currentOwner = ERC721(childContract).ownerOf(childTokenId);
      currentTokenId = _childTokenOwner[childContract][childTokenId] == 0 ? childTokenId : _childTokenOwner[childContract][childTokenId];
    } else {
      currentOwner = ownerOf(childTokenId);
    }

    for (uint16 depth = 0; depth < MAX_DEPTH; depth++) {
      // Try to call ownerOfChild on the current owner to check if it's composable
      (bool ok, bytes memory ret) = currentOwner.staticcall(
        abi.encodeWithSelector(
          IERC998ERC721TopDown.ownerOfChild.selector,
          currentContract,
          currentTokenId
        )
      );

      // If call fails, currentOwner is EOA or non-composable contract → root reached
      if (!ok || ret.length < 64) {
        return _addressToBytes32(currentOwner);
      }

      bytes32 nextOwner;
      uint256 nextTokenId;
      assembly { 
        nextOwner := mload(add(ret, 0x20))
        nextTokenId := mload(add(ret, 0x40)) 
      }

      currentContract = currentOwner;
      currentTokenId = nextTokenId;
      currentOwner = bytes32ToAddress(nextOwner);
    }

    return _addressToBytes32(currentOwner);
  }

  /// @notice Transfer a child token to another address
  /// @param fromTokenId The token ID of the parent token
  /// @param to The address to transfer the child token to
  /// @param childContract The child contract address
  /// @param childTokenId The child token ID
  /// @dev This function is used to transfer a child token to another address
  function transferChild(uint256 fromTokenId, address to, address childContract, uint256 childTokenId) public nonReentrant {
    require(to != address(0), ERC998_InvalidReceiver(to));

    uint256 parentTokenId = _childTokenOwner[childContract][childTokenId];
    require(parentTokenId == fromTokenId, ERC998_InvalidFromTokenId(fromTokenId, parentTokenId));

    TokenData storage tokenData = _tokenData[parentTokenId];
    require(tokenData.erc721ChildTokenIds[childContract].length > 0, ERC998_ChildContractNotFound(childContract));
    require(tokenData.erc721ChildTokenIndex[childContract][childTokenId] > 0, ERC998_ChildTokenNotFound(childContract, childTokenId));

    address rootOwner = bytes32ToAddress(rootOwnerOf(parentTokenId));
    require(
      rootOwner == msg.sender || 
      super.isApprovedForAll(rootOwner, msg.sender) ||
      _rootOwnerTokenApprovals[rootOwner][parentTokenId] == msg.sender,
      ERC998_CallerIsNotOwnerNorApprovedOperator(parentTokenId)
    );

    _removeChild(parentTokenId, childContract, childTokenId);
    ERC721(childContract).transferFrom(address(this), to, childTokenId);
    emit TransferChild(parentTokenId, to, childContract, childTokenId);
  }

  /// @notice Safe transfer a child token to another address
  /// @param fromTokenId The token ID of the parent token
  /// @param to The address to transfer the child token to
  /// @param childContract The child contract address  
  /// @param childTokenId The child token ID
  function safeTransferChild(uint256 fromTokenId, address to, address childContract, uint256 childTokenId) public {
    safeTransferChild(fromTokenId, to, childContract, childTokenId, "");
  }

  /// @notice Safe transfer a child token to another address with data
  /// @param fromTokenId The token ID of the parent token
  /// @param to The address to transfer the child token to
  /// @param childContract The child contract address
  /// @param childTokenId The child token ID
  /// @param data Additional data to be passed to the child contract's onERC721Received function
  function safeTransferChild(uint256 fromTokenId, address to, address childContract, uint256 childTokenId, bytes memory data) public virtual {
    transferChild(fromTokenId, to, childContract, childTokenId);
    ERC721Utils.checkOnERC721Received(msg.sender, address(this), to, childTokenId, data);
  }

  /// @notice Transfer a child token to a parent token
  /// @param fromTokenId The token ID of the parent token
  /// @param toContract The address of the parent token
  /// @param toTokenId The token ID of the parent token
  /// @param childContract The child contract address
  /// @param childTokenId The child token ID
  function transferChildToParent(uint256 fromTokenId, address toContract, uint256 toTokenId, address childContract, uint256 childTokenId) external nonReentrant {
    require(toContract != address(0), ERC998_InvalidReceiver(toContract));

    uint256 parentTokenId = _childTokenOwner[childContract][childTokenId];
    require(parentTokenId == fromTokenId, ERC998_InvalidFromTokenId(fromTokenId, parentTokenId));

    TokenData storage tokenData = _tokenData[parentTokenId];
    require(tokenData.erc721ChildTokenIds[childContract].length > 0, ERC998_ChildContractNotFound(childContract));
    require(tokenData.erc721ChildTokenIndex[childContract][childTokenId] > 0, ERC998_ChildTokenNotFound(childContract, childTokenId));

    address rootOwner = bytes32ToAddress(rootOwnerOf(parentTokenId));
    require(
      rootOwner == msg.sender || 
      super.isApprovedForAll(rootOwner, msg.sender) ||
      _rootOwnerTokenApprovals[rootOwner][parentTokenId] == msg.sender,
      ERC998_CallerIsNotOwnerNorApprovedOperator(parentTokenId)
    );

    _removeChild(parentTokenId, childContract, childTokenId);
    ERC721(childContract).safeTransferFrom(
        address(this), 
        toContract, 
        childTokenId,
        abi.encode(toTokenId)
    );
    emit TransferChild(parentTokenId, toContract, childContract, childTokenId);
  }

  /// @notice Get a child token from another address
  /// @notice The contract must be approved to transfer the child token to this contract
  /// @param from The address that owns the child token
  /// @param tokenId The token ID to receive the child token
  /// @param childContract The child contract address
  /// @param childTokenId The child token ID
  /// @dev This function is used to get a child token from another address
  /// @dev If msg.sender is the token owner, they must use their own address as 'from'
  /// @dev If msg.sender is an approved operator, they can specify a different 'from' address
  function getChild(address from, uint256 tokenId, address childContract, uint256 childTokenId) external nonReentrant {
    _receiveChild(from, tokenId, childContract, childTokenId);
    require(
      msg.sender == from ||
      ERC721(childContract).isApprovedForAll(from, msg.sender) ||
      ERC721(childContract).getApproved(childTokenId) == msg.sender,
      ERC998_CallerIsNotOwnerNorApprovedOperator(tokenId)
    );
    ERC721(childContract).transferFrom(msg.sender, address(this), childTokenId);
  }

  /// @notice Check if a child token exists
  /// @param tokenId The token ID of the parent token
  /// @param childContract The child contract address
  /// @param childTokenId The child token ID
  /// @return True if the child token exists, false otherwise
  function childExists(uint256 tokenId, address childContract, uint256 childTokenId) external view returns (bool) {
    return _tokenData[tokenId].erc721ChildTokenIndex[childContract][childTokenId] > 0;
  }

  /// @notice Get the owner of a child token
  /// @param childContract The child contract address
  /// @param childTokenId The child token ID
  /// @return parentTokenOwner The owner of the parent token encoded as bytes32
  /// @return parentTokenId The ID of the parent token
  function ownerOfChild(address childContract, uint256 childTokenId) external view returns (bytes32 parentTokenOwner, uint256 parentTokenId) {
    parentTokenId = _childTokenOwner[childContract][childTokenId];
    require(parentTokenId > 0 || _childTokenOwner[address(this)][parentTokenId] > 0, ERC998_ChildTokenNotFound(childContract, childTokenId));
    return (_addressToBytes32(ownerOf(parentTokenId)), parentTokenId);
  }

  /// @notice Get the owner of a child token (internal function)
  /// @param childContract The child contract address
  /// @param childTokenId The child token ID
  /// @return parentTokenOwner The owner of the parent token
  /// @return parentTokenId The ID of the parent token
  function _ownerOfChild(address childContract, uint256 childTokenId) internal view returns (address parentTokenOwner, uint256 parentTokenId) {
    parentTokenId = _childTokenOwner[childContract][childTokenId];
    require(parentTokenId > 0 || _childTokenOwner[address(this)][parentTokenId] > 0, ERC998_ChildTokenNotFound(childContract, childTokenId));
    return (ownerOf(parentTokenId), parentTokenId);
  }

  /// @notice Receive a child token from another contract
  /// @param from The address that sent the child token
  /// @param tokenId The token ID of the parent token
  /// @param childContract The child contract address
  /// @param childTokenId The child token ID
  /// @dev This function is used to receive a child token from another contract
  function _receiveChild(address from, uint256 tokenId, address childContract, uint256 childTokenId) internal {
    _requireOwned(tokenId);

    require(
      _childTokenOwner[childContract][childTokenId] == 0,
      ERC998_ChildTokenAlreadyExists(tokenId, childContract, childTokenId)
    );

    require(
      _tokenData[tokenId].erc721ChildTokenIndex[childContract][childTokenId] == 0, 
      ERC998_ChildTokenAlreadyExists(tokenId, childContract, childTokenId)
    );

    _checkForInheritanceLoop(childTokenId, childContract, tokenId, address(this));

    if (_tokenData[tokenId].erc721childContractIndex[childContract] == 0) {
      _tokenData[tokenId].erc721childContractIndex[childContract] = _tokenData[tokenId].erc721Contracts.length + 1;
      _tokenData[tokenId].erc721Contracts.push(childContract);
    }

    _tokenData[tokenId].erc721ChildTokenIds[childContract].push(childTokenId);
    _tokenData[tokenId].erc721ChildTokenIndex[childContract][childTokenId] = _tokenData[tokenId].erc721ChildTokenIds[childContract].length;
    _childTokenOwner[childContract][childTokenId] = tokenId;

    emit ReceivedChild(from, tokenId, childContract, childTokenId);
  }

  /// @notice Remove a child token from a parent token
  /// @param tokenId The token ID of the parent token
  /// @param childContract The child contract address
  /// @param childTokenId The child token ID
  /// @dev This function is used to remove a child token from a parent token
  function _removeChild(uint256 tokenId, address childContract, uint256 childTokenId) private {
    TokenData storage tokenData = _tokenData[tokenId];
     
    uint256 tokenIndex = tokenData.erc721ChildTokenIndex[childContract][childTokenId];
    require(tokenIndex > 0, ERC998_ChildTokenNotFound(childContract, childTokenId));

    uint256 lastTokenIndex = tokenData.erc721ChildTokenIds[childContract].length - 1;
    uint256 lastTokenId = tokenData.erc721ChildTokenIds[childContract][lastTokenIndex];

    // Token Swap Logic if we are not removing the last token
    if (childTokenId != lastTokenId) {
      tokenData.erc721ChildTokenIds[childContract][tokenIndex - 1] = lastTokenId;
      tokenData.erc721ChildTokenIndex[childContract][lastTokenId] = tokenIndex;
    }

    tokenData.erc721ChildTokenIds[childContract].pop();
    delete tokenData.erc721ChildTokenIndex[childContract][childTokenId];
    delete _childTokenOwner[childContract][childTokenId];

    if (tokenData.erc721ChildTokenIds[childContract].length == 0) {
      uint256 contractIndex = tokenData.erc721childContractIndex[childContract];
      uint256 lastContractIndex = tokenData.erc721Contracts.length - 1;
      address lastContract = tokenData.erc721Contracts[lastContractIndex];

      if (childContract != lastContract) {
        tokenData.erc721Contracts[contractIndex] = lastContract;
        tokenData.erc721childContractIndex[lastContract] = contractIndex;
      }

      tokenData.erc721Contracts.pop();
      delete tokenData.erc721childContractIndex[childContract];
    }
  }

  /// @notice Check for inheritance loop
  /// @param childTokenId The token ID of the child token
  /// @param childContract The contract address of the child token
  /// @param parentTokenId The token ID of the parent token
  /// @param parentContract The contract address of the parent token
  /// @dev This function is used to check for circular ownership and too deep composable
  /// @dev It's a O(n) operation where n is the depth of the composable.
  function _checkForInheritanceLoop(
    uint256  childTokenId,
    address  childContract,
    uint256  parentTokenId,
    address  parentContract
  ) internal view {

    address currentContract = parentContract;
    uint256 currentTokenId  = parentTokenId;

    for (uint16 depth = 0; depth < MAX_DEPTH; depth++) {

      if (currentContract == childContract && currentTokenId == childTokenId) {
        revert ERC998_CircularOwnership();
      }

      address ownerAddr = IERC721(currentContract).ownerOf(currentTokenId);

      (bool ok, bytes memory ret) = ownerAddr.staticcall(
        abi.encodeWithSelector(
          IERC998ERC721TopDown.ownerOfChild.selector,
          currentContract,
          currentTokenId
        )
      );

      // ownerAddr is not a composable → root reached
      if (!ok || ret.length < 64) {
        if (depth >= MAX_DEPTH - 1) {
          revert ERC998_TooDeepComposable(parentTokenId, childTokenId, MAX_DEPTH);
        }
        return;
      }

      uint256 nextTokenId;
      assembly { nextTokenId := mload(add(ret, 0x40)) }

      currentContract = ownerAddr;
      currentTokenId  = nextTokenId;
    }

    revert ERC998_TooDeepComposable(parentTokenId, childTokenId, MAX_DEPTH);
  }

  /// @notice Get the root owner address from bytes32 root owner value
  /// @dev Extracts address from magic value + address combination
  /// @param tokenId The token ID of the parent token
  /// @return address of the root owner
  function _getRootOwnerAddress(uint256 tokenId) internal view returns (address) {
    return bytes32ToAddress(rootOwnerOf(tokenId));
  }

  // ========================================================
  // IERC998ERC721TopDownEnumerable Implementation
  // ========================================================

  /// @notice Get the total number of child contracts for a token
  /// @param tokenId The parent token ID
  /// @return The number of child contracts
  function totalChildContracts(uint256 tokenId) external view returns (uint256 ) {
    return _tokenData[tokenId].erc721Contracts.length;
  }

  /// @notice Get the child contract at a specific index
  /// @param tokenId The parent token ID
  /// @param index The index of the child contract
  /// @return childContract The child contract address
  function childContractByIndex(uint256 tokenId, uint256 index) external view returns (address childContract) {
    require(index < _tokenData[tokenId].erc721Contracts.length, ERC998Enumerable_InvalidContractIndex(tokenId, index));
    return _tokenData[tokenId].erc721Contracts[index];
  }

  /// @notice Get the total number of child tokens for a specific contract
  /// @param tokenId The parent token ID
  /// @param childContract The child contract address
  /// @return The number of child tokens
  function totalChildTokens(uint256 tokenId, address childContract) external view returns (uint256) {
    return _tokenData[tokenId].erc721ChildTokenIds[childContract].length;
  }

  /// @notice Get the child token at a specific index
  /// @param tokenId The parent token ID
  /// @param childContract The child contract address
  /// @param index The index of the child token
  /// @return childTokenId The child token ID
  function childTokenByIndex(uint256 tokenId, address childContract, uint256 index) external view returns (uint256 childTokenId) {
    require(index < _tokenData[tokenId].erc721ChildTokenIds[childContract].length, ERC998Enumerable_InvalidTokenIndex(tokenId, childContract, index));
    return _tokenData[tokenId].erc721ChildTokenIds[childContract][index];
  }

  // ========================================================
  // IERC998ERC20TopDown Implementation
  // ========================================================

  /// @notice Get the balance of an ERC20 contract for a token
  /// @param _tokenId The parent token ID
  /// @param _erc20Contract The ERC20 contract address
  /// @return The balance of the ERC20 contract
  function balanceOfERC20(uint256 _tokenId, address _erc20Contract) external view returns (uint256) {
    return _tokenData[_tokenId].erc20Balances[_erc20Contract];
  }

  /// @notice Transfer an ERC20 token from a token to an address
  /// @param _tokenId The parent token ID
  /// @param _to The address to transfer the ERC20 token to
  /// @param _erc20Contract The ERC20 contract address
  /// @param _value The value of the ERC20 token
  /// @dev This function is used to transfer an ERC20 token from a token to an address
  /// @dev The caller must be the root owner of the token or an approved operator
  function transferERC20(uint256 _tokenId, address _to, address _erc20Contract, uint256 _value) external nonReentrant {
    require(_to != address(0), ERC998_InvalidReceiver(_to));

    address rootOwner = bytes32ToAddress(rootOwnerOf(_tokenId));
    require(
      rootOwner == msg.sender || 
      super.isApprovedForAll(rootOwner, msg.sender) ||
      _rootOwnerTokenApprovals[rootOwner][_tokenId] == msg.sender,
      ERC998_CallerIsNotOwnerNorApprovedOperator(_tokenId)
    );

    _removeERC20(_tokenId, _erc20Contract, _value);
    IERC20(_erc20Contract).safeTransfer(_to, _value);
    emit TransferERC20(_tokenId, _to, _erc20Contract, _value);
  }

  /// @notice Get an ERC20 token from an address
  /// @param _from The address that owns the ERC20 token
  /// @param _tokenId The parent token ID
  /// @param _erc20Contract The ERC20 contract address
  /// @param _value The value of the ERC20 token
  /// @dev This function is used to get an ERC20 token from an address
  /// @dev The caller must be the root owner of the token or an approved operator
  function getERC20(address _from, uint256 _tokenId, address _erc20Contract, uint256 _value) external nonReentrant {
    address rootOwner = bytes32ToAddress(rootOwnerOf(_tokenId));
    require(
      rootOwner == msg.sender || 
      super.isApprovedForAll(rootOwner, msg.sender) ||
      _rootOwnerTokenApprovals[rootOwner][_tokenId] == msg.sender,
      ERC998_CallerIsNotOwnerNorApprovedOperator(_tokenId)
    );
    _receiveERC20(_from, _tokenId, _erc20Contract, _value);
    IERC20(_erc20Contract).safeTransferFrom(_from, address(this), _value);
  }

  /// @notice Handle the receipt of an ERC223 token
  /// @notice https://ethereum.org/en/developers/docs/standards/tokens/erc-223/
  /// @param _from The address that sent the ERC20 token
  /// @param _value The value of the ERC20 token
  /// @param _data Additional data with no specified format
  /// @dev --- This function is not implemented ---
  /*
  function tokenFallback(address _from, uint256 _value, bytes calldata _data) external {
    revert("Not implemented yet");
  }
  */

  /// @notice Receive an ERC20 token for a token
  /// @param _from The address that sent the ERC20 token
  /// @param _tokenId The parent token ID
  /// @param _erc20Contract The ERC20 contract address
  /// @param _value The value of the ERC20 token
  /// @dev This function is used to receive an ERC20 token for a token
  function _receiveERC20(address _from, uint256 _tokenId, address _erc20Contract, uint256 _value) internal {
    _requireOwned(_tokenId);
    require(_value > 0, ERC998_InvalidERC20Value(_tokenId, _erc20Contract, _value));

    uint256 erc20Balance = _tokenData[_tokenId].erc20Balances[_erc20Contract];

    if (erc20Balance == 0) {
      _tokenData[_tokenId].erc20ContractIndex[_erc20Contract] = _tokenData[_tokenId].erc20Contracts.length;
      _tokenData[_tokenId].erc20Contracts.push(_erc20Contract);
    }

    _tokenData[_tokenId].erc20Balances[_erc20Contract] += _value;
    emit ReceivedERC20(_from, _tokenId, _erc20Contract, _value);
  }

  /// @notice Remove an ERC20 token from a token
  /// @param _tokenId The parent token ID
  /// @param _erc20Contract The ERC20 contract address
  /// @param _value The value of the ERC20 token
  /// @dev This function is used to remove an ERC20 token from a token
  function _removeERC20(uint256 _tokenId, address _erc20Contract, uint256 _value) internal {
    _requireOwned(_tokenId);
    require(_value > 0, ERC998_InvalidERC20Value(_tokenId, _erc20Contract, _value));

    uint256 balance = _tokenData[_tokenId].erc20Balances[_erc20Contract];
    require(balance >= _value, ERC998_InsufficientERC20Balance(_tokenId, _erc20Contract, _value));

    uint256 newBalance = balance - _value;
    _tokenData[_tokenId].erc20Balances[_erc20Contract] = newBalance;

    if (newBalance == 0) {
      uint256 lastContractIndex = _tokenData[_tokenId].erc20Contracts.length - 1;
      address lastContract = _tokenData[_tokenId].erc20Contracts[lastContractIndex];

      if (_erc20Contract != lastContract) {
        uint256 contractIndex = _tokenData[_tokenId].erc20ContractIndex[_erc20Contract];
        _tokenData[_tokenId].erc20Contracts[contractIndex] = lastContract;
        _tokenData[_tokenId].erc20ContractIndex[lastContract] = contractIndex;
      }

      _tokenData[_tokenId].erc20Contracts.pop();
      delete _tokenData[_tokenId].erc20ContractIndex[_erc20Contract];
    }
  }

  // ========================================================
  // IERC998ERC20TopDownEnumerable Implementation
  // ========================================================

  /// @notice Get the total number of ERC20 contracts for a token
  /// @param _tokenId The parent token ID
  /// @return The number of ERC20 contracts
  function totalERC20Contracts(uint256 _tokenId) external view returns (uint256) {
    return _tokenData[_tokenId].erc20Contracts.length;
  }

  /// @notice Get the ERC20 contract at a specific index
  /// @param _tokenId The parent token ID
  /// @param _index The index of the ERC20 contract
  /// @return The ERC20 contract address
  function erc20ContractByIndex(uint256 _tokenId, uint256 _index) external view returns (address) {
    require(_index < _tokenData[_tokenId].erc20Contracts.length, ERC998Enumerable_InvalidContractIndex(_tokenId, _index));
    return _tokenData[_tokenId].erc20Contracts[_index];
  }

  // ========================================================
  // IERC165 Implementation 
  // ========================================================

  /// @notice Check if the contract supports an interface
  /// @param interfaceId The interface ID to check
  /// @return True if the interface is supported
  function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721) returns (bool) 
  {
    return interfaceId == type(IERC998ERC721TopDown).interfaceId ||
        interfaceId == type(IERC998ERC721TopDownEnumerable).interfaceId ||
        interfaceId == type(IERC998ERC20TopDown).interfaceId ||
        interfaceId == type(IERC998ERC20TopDownEnumerable).interfaceId ||
        interfaceId == type(IERC721Receiver).interfaceId ||
        super.supportsInterface(interfaceId);
  }

  // ========================================================
  // IERC721Receiver Implementation 
  // ========================================================

  /// @notice Handle the receipt of an NFT
  /// @param operator The address which called `safeTransferFrom` function
  /// @param from The address which previously owned the token
  /// @param childTokenId The NFT identifier which is being transferred
  /// @param data Additional data with no specified format
  /// @return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))
  function onERC721Received(address operator, address from, uint256 childTokenId, bytes calldata data) 
    external
    override(IERC721Receiver, IERC998ERC721TopDown)
    virtual
    returns (bytes4) 
  {
    uint256 parentTokenId = abi.decode(data, (uint256));
    _requireOwned(parentTokenId);
    _receiveChild(from, parentTokenId, msg.sender, childTokenId);
    return _ERC721_RECEIVED;
  }

  // ========================================================
  // Helper Functions
  // ========================================================

  /// @dev Extracts address from bytes32 that contains magic value
  /// @param data The bytes32 value to convert
  /// @return The address extracted from the bytes32 value
  function bytes32ToAddress(bytes32 data) public pure returns (address) {
    return address(uint160(uint256(data)));
  }

  /// @dev Converts an address to bytes32 with magic value
  /// @param addr The address to convert
  /// @return The bytes32 value with magic value
  function _addressToBytes32(address addr) internal pure returns (bytes32) {
    return ERC998_MAGIC_VALUE << 224 | bytes32(uint256(uint160(addr)));
  }
}