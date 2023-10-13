// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../types/BaseType.sol";

library AssetTransfer {

    function coinCost(address to, address coin, uint256 amount) internal{
        if(amount == 0 ){
            return;
        }
        if(coin == address(0)){//平台币
            require(msg.value >= amount, "The ether value sent is not correct");
            payable(to).transfer(msg.value);
        }else{
            IERC20(coin).transferFrom(msg.sender, to, amount);
        }
    }

    function coinReward(address to,address coin, uint256 amount) internal{
        if(amount == 0 ){
            return;
        }
        if(coin == address(0)){//平台币
            payable(to).transfer(amount);
        }else{
            IERC20(coin).transfer(to, amount);
        }
    }

    function mineralBurn(address account, address mineral, BaseType.MineralIdDebt[] memory mineralIdDebts) internal{
        (uint256[] memory ids, uint256[] memory amounts) = parseMineralIdDebts(mineralIdDebts);
        if(ids.length == 0){
            return;
        }
        IMineral(mineral).brunBatch(account ,ids, amounts);
    }

    function mineralCost(address to, address mineral, BaseType.MineralIdDebt[] memory mineralIdDebts) internal{
        (uint256[] memory ids, uint256[] memory amounts) = parseMineralIdDebts(mineralIdDebts);
        if(ids.length == 0){
            return;
        }
        IMineral(mineral).safeBatchTransferFrom(msg.sender,to ,ids,amounts,"");
    }

    function mineralReward(address to, address mineral, BaseType.MineralIdDebt[] memory mineralIdDebts) internal{
        (uint256[] memory ids, uint256[] memory amounts) = parseMineralIdDebts(mineralIdDebts);
        if(ids.length == 0){
            return;
        }
        IMineral(mineral).mintTokenIdWithWitelist(to, ids, amounts); //铸造矿产
    }

    function parseMineralIdDebts(BaseType.MineralIdDebt[] memory mineralIdDebts) private pure returns(uint256[] memory,uint256[] memory){
        uint256 len = mineralIdDebts.length;
        uint256[] memory ids = new uint256[](len);
        uint256[] memory amounts = new uint256[](len);
        for(uint256 i= 0; i < len; i++){
            BaseType.MineralIdDebt memory mineralIdDebt = mineralIdDebts[i];
            uint256 id = mineralIdDebt.id;
            uint256 amount = mineralIdDebt.debt;
            if(amount == 0){
                continue;
            }
            ids[i] = id;
            amounts[i] = amount;
        }

        return (ids, amounts);
    }
}
