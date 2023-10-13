// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../interfaces/asset/IMineral.sol";
import "../interfaces/asset/IMill.sol";

contract BaseType {

    struct MillConfig{
        uint256 millAttributeId;
        uint256 millQualityId;
        uint256 millGradeId;
    }

    struct CoinValue{
        address coin;
        uint256 value;
    }

    struct MineralReward {
        IMineral mineral;
        MineralIdReward[] mineralIdRewards;
    }

    struct MineralIdReward {
        uint256 id;
        uint256 convertRate;
    }

    struct CoinDebt {
        address coin;
        uint256 convertRate;
        uint256 debt;
    }

    struct MineralDebt {
        IMineral mineral;
        MineralIdDebt[] mineralIdDebts;
    }

    struct MineralIdDebt {
        uint256 id;
        uint256 convertRate;
        uint256 debt;
    }

    enum Attribute {
        ATTRIBUTE,
        QUALITY,
        GRADE,
        DURABILITY,
        INIT_DURABILITY
    }
}
