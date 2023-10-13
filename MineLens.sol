// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./MineEctypePool.sol";
import "./interfaces/asset/IMill.sol";
import "./interfaces/asset/IMineral.sol";

contract MineLens {

    struct MinePoolBaseInfo{
        bool paused;
        uint256 mineFieldLength;
    }

    function getMinePoolBaseInfo(MineEctypePool _pool) public view returns(MinePoolBaseInfo memory){
       uint256 len =  _pool.mineFieldLength();
        return MinePoolBaseInfo({
            paused: _pool.paused(),
            mineFieldLength: len
        });
    }

    struct UserMineFieldBaseInfo {
        uint256 mineId;
        uint256 durabilityRate;
        uint256 state;
        BaseType.CoinValue costCoin;
        BaseType.CoinValue rewardCoin;
        BaseType.MillConfig millConfig;
    }

    function getUserMineFieldBaseInfo(MineEctypePool _pool, uint256 _pid, address _user) public view returns(UserMineFieldBaseInfo memory ){
        (uint256 _mineId
        , uint256 _durabilityRate
        ,
        ,
        , BaseType.CoinValue memory _costCoin
        , BaseType.CoinValue memory _rewardCoin
        , BaseType.MillConfig memory _millConfig
        ,) = _pool.userMineFieldMapping(_user,_pid);

        return UserMineFieldBaseInfo({
            mineId: _mineId,
            durabilityRate: _durabilityRate,
            state: uint256(_pool.userMineFieldStateMapping(_user,_pid)),
            costCoin: _costCoin,
            rewardCoin: _rewardCoin,
            millConfig: _millConfig
        });
    }
}
