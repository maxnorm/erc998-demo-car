// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC998} from "./ERC998/ERC998.sol";

contract Car is ERC998 {
  uint256 private _count;

  constructor() ERC998("Car", "CAR") {}

  function mint(address to) external returns (uint256) {
    _count++;
    _mint(to, _count);
    return _count;
  }
}