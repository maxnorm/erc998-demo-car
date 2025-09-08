// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Fuel is ERC20 {
  constructor() ERC20("Fuel", "FUEL") {}

  function mint(address to, uint256 amount) external returns (uint256) {
    _mint(to, amount);
    return amount;
  }

  function mintTo(address to) external returns (uint256) {
    uint256 amount = 1000 * 10**decimals(); // 1000 tokens
    _mint(to, amount);
    return amount;
  }
}