// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title IERC998ERC20TopDown
/// @author Nick Mudge <nick@perfectabstractions.com>, https://github.com/mattlockyer/composables-998.
/// @notice Interface for the ERC998ERC20TopDown contract.
/// @dev This interface is used to let composable token interact with ERC20 tokens.
interface IERC998ERC20TopDown {
    event ReceivedERC20(address indexed _from, uint256 indexed _tokenId, address indexed _erc20Contract, uint256 _value);
    event TransferERC20(uint256 indexed _tokenId, address indexed _to, address indexed _erc20Contract, uint256 _value);

    // function tokenFallback(address from, uint256 value, bytes calldata data) external;
    function balanceOfERC20(uint256 tokenId, address erc20Contract) external view returns (uint256);
    function transferERC20(uint256 tokenId, address to, address erc20Contract, uint256 value) external;
    function getERC20(address from, uint256 tokenId, address erc20Contract, uint256 value) external;
}