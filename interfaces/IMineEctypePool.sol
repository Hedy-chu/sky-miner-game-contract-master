// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../storage/MineEctypePoolStorage.sol";

abstract contract IMineEctypePool is MineEctypePoolStorage{
    event ResetFeeTo(address oldFeeTo, address newFeeTo);
    event AddMill(address indexed operator, address mill);
    event RemoveMill(address indexed operator, address mill);

    event UnlockUserMineField(address indexed operator, address indexed user,uint256 pid);
    event Mining(address indexed operator, address mill, uint256 tokenId, uint256 pid);
    event NoMining(address indexed operator, address mill, uint256 tokenId, uint256 pid, uint256 expectedBlock);
    event WithdrawRewards(address indexed operator, address mill, uint256 tokenId, uint256 pid, uint256 expectedBlock);
    event WithdrawAsset(address indexed operator, address indexed to, address asset, uint256 amount);
    event PaymentReceived(address indexed from, uint256 amount);

    function addMills(address[] calldata _mills) external virtual;
    function removeMill(address _mill) external virtual;
    function getMillLength() external view virtual returns (uint256);
    function getMill(uint256 _index) external view virtual returns (address);
    function isMill(address _mill) external view virtual returns (bool);

    function getDebts(uint256 _pid, address _user, uint256 _expectedBlock) external view virtual returns (UserMineFieldMing memory _userMineFieldMing, CoinDebt memory _coinDebtCost, CoinDebt memory _coinDebtReward, MineralIdDebt[] memory _mineralIdDebts);
    function getMillDurability(uint256 _pid, address _user, uint256 _expectedBlock) external view virtual returns(uint256, uint256);

    function unlockUserMineField(uint256 _pid, address _user) external virtual payable;
    function mining(uint256 _pid, MillInfo calldata _millInfo) external virtual;
    function noMining(uint256 _pid, uint256 _expectedBlock) external virtual payable;
    function withdrawRewards(uint256 _pid, uint256 _expectedBlock) external virtual payable;
    function withdrawAsset(address _asset, address _to, uint256 _amount) external virtual;
}
