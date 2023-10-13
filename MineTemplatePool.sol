// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IMineTemplatePool.sol";
import "./utils/StructSet.sol";
//import "hardhat/console.sol";

contract MineTemplatePool is IMineTemplatePool,Ownable,ReentrancyGuard{

    using StructSet for BaseType.MineralIdReward[];

    modifier isMineFieldPid(uint256 _pid) {
        require(_pid <= mineFieldLength() - 1, "not find this mineField");
        _;
    }

    function mineFieldLength() public view returns (uint256) {
        return mineFields.length;
    }

    function getMineField(uint256 _pid) public view isMineFieldPid(_pid) returns(MineField memory){
        return mineFields[_pid];
    }

    function addMineField(MineField calldata _mineField)  public override onlyOwner nonReentrant returns(uint256){
        MineField storage mineField = mineFields.push();
        uint256 _pid = mineFieldLength()-1;
        _resetMineField(mineField, _mineField);

        emit AddMineField(msg.sender,_pid);
        return _pid;
    }

    function updateMineField(uint256 _pid, MineField calldata _mineField) public override isMineFieldPid(_pid) onlyOwner nonReentrant{
        delete mineFields[_pid];
        MineField storage mineField = mineFields[_pid];
        _resetMineField(mineField, _mineField);

        emit UpdateMineField(msg.sender,_pid);
    }

    function _resetMineField(MineField storage mineField, MineField memory _mineField) internal{
        mineField.mineId = _mineField.mineId;
        mineField.unlock = _mineField.unlock;
        mineField.durabilityRate = _mineField.durabilityRate;

        CoinValue storage unlockCoin = mineField.unlockCoin;
        CoinValue storage costCoin = mineField.costCoin;
        CoinValue storage rewardCoin = mineField.rewardCoin;
        MillConfig storage millConfig = mineField.millConfig;
        MineralReward storage mineralReward = mineField.mineralReward;
        MineralIdReward[] storage mineralIdRewards = mineralReward.mineralIdRewards;

        CoinValue memory _unlockCoin = _mineField.unlockCoin;
        CoinValue memory _costCoin = _mineField.costCoin;
        CoinValue memory _rewardCoin = _mineField.rewardCoin;
        MillConfig memory _millConfig = _mineField.millConfig;
        MineralReward memory _mineralReward = _mineField.mineralReward;
        MineralIdReward[] memory _mineralIdRewards = _mineralReward.mineralIdRewards;

        unlockCoin.coin = _unlockCoin.coin;
        unlockCoin.value = _unlockCoin.value;
        costCoin.coin = _costCoin.coin;
        costCoin.value = _costCoin.value;
        rewardCoin.coin = _rewardCoin.coin;
        rewardCoin.value = _rewardCoin.value;
        millConfig.millAttributeId = _millConfig.millAttributeId;
        millConfig.millQualityId = _millConfig.millQualityId;
        millConfig.millGradeId = _millConfig.millGradeId;
        mineralReward.mineral = _mineralReward.mineral;
        StructSet.pushMineralIdRewards(mineralIdRewards, _mineralIdRewards);
    }
}
