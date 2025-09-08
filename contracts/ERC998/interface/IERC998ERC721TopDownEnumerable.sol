// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title IERC998ERC721TopDownEnumerable
/// @author Nick Mudge <nick@perfectabstractions.com>, https://github.com/mattlockyer/composables-998.
/// @notice Interface for the ERC998ERC721TopDownEnumerable contract.
/// @dev This interface is used to enumerate the ERC721 contracts that a token has.
interface IERC998ERC721TopDownEnumerable {
    function totalChildContracts(uint256 _tokenId) external view returns (uint256);
    function childContractByIndex(uint256 _tokenId, uint256 _index) external view returns (address childContract);
    function totalChildTokens(uint256 _tokenId, address _childContract) external view returns (uint256);
    function childTokenByIndex(uint256 _tokenId, address _childContract, uint256 _index) external view returns (uint256 childTokenId);
}