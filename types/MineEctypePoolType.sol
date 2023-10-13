// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./BaseType.sol";
import "./MineTemplatePoolType.sol";

contract MineEctypePoolType is MineTemplatePoolType{

    struct MillInfo{
        address mill;
        uint256 tokenId;
    }

    struct UserMineFieldMing {
        uint256 startAt;
        uint256 endAt;
        MillInfo millInfo;
    }

    enum State {
        UNCULTIVATED,
        CULTIVATED,
        MING
    }
}
