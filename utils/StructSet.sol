// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../types/BaseType.sol";

library StructSet {

    function pushMineralIdRewards(BaseType.MineralIdReward[] storage mineralIdRewards, BaseType.MineralIdReward[] memory _mineralIdRewards) internal{
        uint256 _len = _mineralIdRewards.length;
        for(uint256 i=0; i< _len; i++){
            BaseType.MineralIdReward memory _mineralIdReward = _mineralIdRewards[i];
            mineralIdRewards.push(BaseType.MineralIdReward({
                id: _mineralIdReward.id,
                convertRate: _mineralIdReward.convertRate
            }));
        }
    }
}
