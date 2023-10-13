// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./BaseType.sol";

contract MineTemplatePoolType is BaseType{

    struct MineField{
        uint256 mineId;
        uint256 durabilityRate;
        bool unlock;

        CoinValue unlockCoin;
        CoinValue costCoin;
        CoinValue rewardCoin;
        MillConfig millConfig;
        MineralReward mineralReward;
    }
}
