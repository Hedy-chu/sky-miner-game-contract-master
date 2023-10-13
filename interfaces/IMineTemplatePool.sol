// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../storage/MineTemplatePoolStorage.sol";

abstract contract IMineTemplatePool is MineTemplatePoolStorage{

    event AddMineField(address indexed operator, uint256 pid);
    event UpdateMineField(address indexed operator,uint256 pid);

    function addMineField(MineField memory _mineField)  external virtual returns(uint256);
    function updateMineField(uint256 _pid, MineField memory _mineField) external virtual;
}
