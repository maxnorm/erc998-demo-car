// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title IERC998ERC20TopDownEnumerable
/// @author Nick Mudge <nick@perfectabstractions.com>, https://github.com/mattlockyer/composables-998.
/// @notice Interface for the ERC998ERC20TopDownEnumerable contract.
/// @dev This interface is used to enumerate the ERC20 contracts that a token has.
interface IERC998ERC20TopDownEnumerable {
    function totalERC20Contracts(uint256 _tokenId) external view returns (uint256);
    function erc20ContractByIndex(uint256 _tokenId, uint256 _index) external view returns (address);
}