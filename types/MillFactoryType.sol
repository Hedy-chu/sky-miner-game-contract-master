// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./BaseType.sol";

contract MillFactoryType is BaseType{

    struct MillInfo{
        address mill;
        uint256 tokenId;
    }

    struct MillInfos{
        address mill;
        uint256[] tokenIds;
    }

    struct RepairConfig{
        uint256 maxRepairTimes;
        CoinValue repairCoin;
        MineralCost mineralCost;
    }

    struct CompositionConfig{
        uint256 consumeMillCount;
        address consumeMill;
        CoinValue compositionCoin;
        MineralCost mineralCost;
    }

    struct MineralCost {
        address mineral;
        MineralIdCost[] mineralIdCost;
    }

    struct MineralIdCost {
        uint256 id;
        uint256 firstCost;
        uint256 stepCost;
    }
}
