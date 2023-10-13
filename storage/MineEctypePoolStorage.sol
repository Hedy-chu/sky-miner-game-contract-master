// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../types/MineEctypePoolType.sol";
import "../MineTemplatePool.sol";

contract MineEctypePoolStorage is MineEctypePoolType{

    MineTemplatePool public mineTemplatePool;
    address public feeTo;
    uint256 public expectedBlockDelta;

    mapping(address => mapping(uint256 => MineField)) public userMineFieldMapping;
    mapping(address => mapping(uint256 => State)) public userMineFieldStateMapping;
    mapping(address => mapping(uint256 => UserMineFieldMing)) public userMineFieldMingMapping;

    EnumerableSet.AddressSet internal millSet;
}