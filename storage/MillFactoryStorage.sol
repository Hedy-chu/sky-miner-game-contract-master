// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../types/MillFactoryType.sol";

contract MillFactoryStorage is MillFactoryType{

    address public feeTo;

    mapping(address =>CompositionConfig) public compositionConfigMapping;
    mapping(address =>RepairConfig) public repairConfigMapping;
    mapping(address =>mapping(uint256 => uint256)) public repairTimesMapping;

    EnumerableSet.AddressSet internal millSet;
}
