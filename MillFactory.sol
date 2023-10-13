// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "./interfaces/IMillFactory.sol";
import "./utils/AssetTransfer.sol";

contract MillFactory is IMillFactory,ERC721Holder,ERC1155Holder,Pausable,ReentrancyGuard{

    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    using AssetTransfer for address;

    constructor (address _feeTo, address _singer) SignatureLens(_singer){
        require(_feeTo != address(0),"Constructor: _feeTo the zero address");
        feeTo = _feeTo;
    }

    modifier verifyMill(address _mill) {
        require(millSet.contains(_mill),"Illegal mill");
        _;
    }

    function resetFeeTo(address payable _feeTo) external onlyOwner{
        require(_feeTo != address(0), "ResetFeeTo: _feeTo the zero address");
        address oldFeeTo = feeTo;
        feeTo = _feeTo;

        emit ResetFeeTo(oldFeeTo, _feeTo);
    }

    function addMills(address[] calldata _mills) public override onlyOwner{
        for(uint256 i=0; i<_mills.length; i++){
            addMill(_mills[i]);
        }
    }

    function addMill(address _mill) internal{
        require(_mill != address(0),"AddMill: _mill the zero address");
        EnumerableSet.add(millSet,_mill);

        emit AddMill(msg.sender, _mill);
    }

    function removeMill(address _mill) public override onlyOwner{
        EnumerableSet.remove(millSet,_mill);
        emit RemoveMill(msg.sender, _mill);
    }

    function getMillLength() public view override returns (uint256){
        return EnumerableSet.length(millSet);
    }

    function getMill(uint256 _index) public view override returns (address){
        require(_index <= getMillLength() - 1, "millSet: index out of bounds");
        return EnumerableSet.at(millSet, _index);
    }

    function isMill(address _mill) public view override returns (bool) {
        return EnumerableSet.contains(millSet, _mill);
    }

    function restCompositionConfig(address _compositionMill, CompositionConfig calldata _compositionConfig) external override verifyMill(_compositionMill) verifyMill(_compositionConfig.consumeMill) onlyOwner{
        delete compositionConfigMapping[_compositionMill];

        _initCompositionConfig(_compositionMill, _compositionConfig);
    }

    function restRepairConfig(address _mill, RepairConfig calldata _repairConfig) external override verifyMill(_mill) onlyOwner{
        require(EnumerableSet.contains(millSet,_mill),"Illegal _mill");
        delete repairConfigMapping[_mill];

        _initRepairConfig(_mill,_repairConfig);
    }

    function composition(address _compositionMill, MillInfos calldata _consumeMillInfos, Signature calldata _signature) public override payable verifyMill(_compositionMill) verifyMill(_consumeMillInfos.mill) nonReentrant whenNotPaused{
        bool _success = verifySignature(_signature);

        address _consumeMill = _consumeMillInfos.mill;
        uint256[] memory _tokenIds = _consumeMillInfos.tokenIds;

        CompositionConfig storage compositionConfig = compositionConfigMapping[_compositionMill];
        CoinValue storage compositionCoin = compositionConfig.compositionCoin;

        uint256 consumeMillCount = compositionConfig.consumeMillCount;
        address consumeMill = compositionConfig.consumeMill;
        address mineral = compositionConfig.mineralCost.mineral;

        require(_consumeMill == consumeMill, "Illegal mill");
        require(_tokenIds.length == consumeMillCount, "Lack of mill");

        AssetTransfer.coinCost(feeTo, compositionCoin.coin, compositionCoin.value);
        MineralIdDebt[] memory _mineralIdDebt = getCompositionDebts(_compositionMill);
        AssetTransfer.mineralBurn(msg.sender, mineral, _mineralIdDebt);

        for(uint256 i=0; i<_tokenIds.length; i++){
            uint256 _tokenId = _tokenIds[i];
            uint256 durability = IMill(_consumeMill).getNftAttribute(uint(Attribute.DURABILITY),_tokenId);
            (,,,uint256 initDurability) = IMill(_consumeMill).getDefaultAttribute();
            require(durability == initDurability, "Lack of durability");
            IMill(_consumeMill).burn(_tokenId);
        }

        if(_success){
            IMill(_compositionMill).mintWithWhiteList(msg.sender);
        }

        emit Composition(msg.sender, _compositionMill, _consumeMill, _success);
    }

    function repair(MillInfo calldata _millInfo, Signature calldata _signature) public override payable verifyMill(_millInfo.mill) nonReentrant whenNotPaused{
        bool _success = verifySignature(_signature);

        address _mill = _millInfo.mill;
        uint256 _tokenId = _millInfo.tokenId;

        RepairConfig storage repairConfig = repairConfigMapping[_mill];
        CoinValue storage repairCoin = repairConfig.repairCoin;
        address mineral = repairConfig.mineralCost.mineral;
        uint256 times = repairTimesMapping[_mill][_tokenId];

        require(times < repairConfig.maxRepairTimes, "The number of repairs has exceeded");
        uint256 durability = IMill(_mill).getNftAttribute(uint(Attribute.DURABILITY),_tokenId);
        (,,,uint256 initDurability) = IMill(_mill).getDefaultAttribute();
        require(durability < initDurability, "Enough durability");

        AssetTransfer.coinCost(feeTo, repairCoin.coin, repairCoin.value);
        MineralIdDebt[] memory _mineralIdDebt = getRepairDebts(_mill, _tokenId);
        AssetTransfer.mineralBurn(msg.sender, mineral, _mineralIdDebt);

        repairTimesMapping[_mill][_tokenId] = times.add(1);
        if(_success){
            IMill(_mill).setNftAttribute(uint256(Attribute.DURABILITY), _tokenId, initDurability);
        }

        emit Repair(msg.sender, _mill, _tokenId, _success);
    }

    function _initCompositionConfig(address _compositionMill, CompositionConfig memory _compositionConfig) internal{
        CompositionConfig storage compositionConfig = compositionConfigMapping[_compositionMill];
        CoinValue storage compositionCoin = compositionConfig.compositionCoin;
        MineralCost storage mineralCost = compositionConfig.mineralCost;
        MineralIdCost[] storage mineralIdCosts = mineralCost.mineralIdCost;

        CoinValue memory _compositionCoin = _compositionConfig.compositionCoin;
        MineralCost memory _mineralCost = _compositionConfig.mineralCost;
        MineralIdCost[] memory _mineralIdCosts = _mineralCost.mineralIdCost;

        compositionConfig.consumeMillCount = _compositionConfig.consumeMillCount;
        compositionConfig.consumeMill = _compositionConfig.consumeMill;
        compositionCoin.coin = _compositionCoin.coin;
        compositionCoin.value = _compositionCoin.value;
        mineralCost.mineral = _mineralCost.mineral;

        _pushMineralIdCosts(mineralIdCosts, _mineralIdCosts);
    }

    function _initRepairConfig(address _mill, RepairConfig memory _repairConfig) internal{
        RepairConfig storage repairConfig = repairConfigMapping[_mill];
        CoinValue storage repairCoin = repairConfig.repairCoin;
        MineralCost storage mineralCost = repairConfig.mineralCost;
        MineralIdCost[] storage mineralIdCosts = mineralCost.mineralIdCost;

        CoinValue memory _repairCoin = _repairConfig.repairCoin;
        MineralCost memory _mineralCost = _repairConfig.mineralCost;
        MineralIdCost[] memory _mineralIdCosts = _mineralCost.mineralIdCost;

        repairConfig.maxRepairTimes = _repairConfig.maxRepairTimes;
        repairCoin.coin = _repairCoin.coin;
        repairCoin.value = _repairCoin.value;
        mineralCost.mineral = _mineralCost.mineral;

        _pushMineralIdCosts(mineralIdCosts, _mineralIdCosts);
    }

    function getCompositionDebts(address _mill) public view override returns(MineralIdDebt[] memory){
        CompositionConfig storage compositionConfig = compositionConfigMapping[_mill];
        MineralCost storage mineralCost = compositionConfig.mineralCost;
        MineralIdCost[] storage mineralIdCosts = mineralCost.mineralIdCost;
        uint256 _len = mineralIdCosts.length;

        MineralIdDebt[] memory mineralIdDebts = new MineralIdDebt[](_len);
        for(uint256 i= 0; i< _len; i++){
            MineralIdCost memory mineralIdCost = mineralIdCosts[i];
            MineralIdDebt memory _mineralIdDebt = MineralIdDebt(mineralIdCost.id, 0, mineralIdCost.firstCost);
            mineralIdDebts[i] = _mineralIdDebt;
        }

        return mineralIdDebts;
    }

    function getRepairDebts(address _mill,uint256 _tokenId) public view override returns(MineralIdDebt[] memory){
        RepairConfig storage repairConfig = repairConfigMapping[_mill];
        MineralCost storage mineralCost = repairConfig.mineralCost;
        MineralIdCost[] storage mineralIdCosts = mineralCost.mineralIdCost;
        uint256 _len = mineralIdCosts.length;

        MineralIdDebt[] memory mineralIdDebts = new MineralIdDebt[](_len);
        uint256 times = repairTimesMapping[_mill][_tokenId];
        if(times >= repairConfig.maxRepairTimes){
            return mineralIdDebts;
        }

        for(uint256 i= 0; i< _len; i++){
            MineralIdCost memory mineralIdCost = mineralIdCosts[i];

            uint256 stepTotalCost = times.mul(mineralIdCost.stepCost);
            uint256 totalCost =  mineralIdCost.firstCost.add(stepTotalCost);

            MineralIdDebt memory _mineralIdDebt = MineralIdDebt(mineralIdCost.id, 0, totalCost);
            mineralIdDebts[i] = _mineralIdDebt;
        }

        return mineralIdDebts;
    }

    function _pushMineralIdCosts(MineralIdCost[] storage mineralIdCosts, MineralIdCost[] memory _mineralIdCosts) internal{
        uint256 _len = _mineralIdCosts.length;
        for(uint256 i=0; i< _len; i++){
            MineralIdCost memory _mineralIdCost = _mineralIdCosts[i];
            mineralIdCosts.push(_mineralIdCost);
        }
    }

    receive() external payable virtual {
        emit PaymentReceived(_msgSender(), msg.value);
    }
}
