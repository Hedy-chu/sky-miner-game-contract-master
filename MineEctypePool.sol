// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "./interfaces/IMineEctypePool.sol";
import "./utils/AssetTransfer.sol";
import "./utils/StructSet.sol";
import "./MineTemplatePool.sol";
//import "hardhat/console.sol";

contract MineEctypePool is IMineEctypePool,ERC721Holder,ERC1155Holder,Ownable,Pausable,ReentrancyGuard{
    using Math for uint256;
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    using AssetTransfer for address;
    using StructSet for BaseType.MineralIdReward[];

    constructor (address _mineTemplatePool, address _feeTo, uint256 _expectedBlockDelta) {
        require(_mineTemplatePool != address(0),"Constructor: _mineTemplatePool the zero address");
        require(_feeTo != address(0),"Constructor: _feeTo the zero address");
        mineTemplatePool = MineTemplatePool(_mineTemplatePool);
        feeTo = _feeTo;
        expectedBlockDelta = _expectedBlockDelta;
    }

    modifier verifyPid(uint256 _pid) {
        require(_pid <= mineFieldLength() - 1, "Not find this mineField");
        _;
    }

    function mineFieldLength() public view returns (uint256) {
        return mineTemplatePool.mineFieldLength();
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

    function unlockUserMineField(uint256 _pid, address _user) public override payable verifyPid(_pid) nonReentrant whenNotPaused{
        MineField memory mineField = mineTemplatePool.getMineField(_pid);
        CoinValue memory unlockCoin = mineField.unlockCoin;
        require(userMineFieldStateMapping[_user][_pid] == State.UNCULTIVATED, "CULTIVATED");

        if(!mineField.unlock && unlockCoin.value != 0){
            AssetTransfer.coinCost(feeTo, unlockCoin.coin, unlockCoin.value);
        }

        userMineFieldStateMapping[_user][_pid] = State.CULTIVATED;

        emit UnlockUserMineField(msg.sender, _user, _pid);
    }

    function mining(uint256 _pid, MillInfo calldata _millInfo) public override verifyPid(_pid) nonReentrant whenNotPaused{
        address mill = _millInfo.mill;
        uint256 tokenId = _millInfo.tokenId;

        require(EnumerableSet.contains(millSet, mill),"Illegal _millInfo");
        uint256 durability = IMill(mill).getNftAttribute(uint(Attribute.DURABILITY),tokenId);
        require(durability >0, "Lack of durability");

        MineField memory mineField = mineTemplatePool.getMineField(_pid);
        CoinValue memory unlockCoin = mineField.unlockCoin;
        State state = userMineFieldStateMapping[msg.sender][_pid];
        require(mineField.unlock
            || unlockCoin.value == 0
            || state == State.CULTIVATED,"You need to be unlocked!");
        require(state != State.MING, "It is currently being mined!");

        IMill(mill).safeTransferFrom(msg.sender, address(this), tokenId);//质押矿机
        _mining(_pid, _millInfo);

        emit Mining(msg.sender, mill, tokenId, _pid);
    }

    function getDebts(uint256 _pid, address _user, uint256 _expectedBlock) external view override verifyPid(_pid) returns (UserMineFieldMing memory _userMineFieldMing, CoinDebt memory _coinDebtCost, CoinDebt memory _coinDebtReward, MineralIdDebt[] memory _mineralIdDebts) {
        MineField storage userMineField = userMineFieldMapping[_user][_pid];
        CoinValue storage costCoin = userMineField.costCoin;
        CoinValue storage rewardCoin = userMineField.rewardCoin;
        MineralReward storage mineralReward = userMineField.mineralReward;
        MineralIdReward[] storage mineralIdRewards = mineralReward.mineralIdRewards;

        _userMineFieldMing = userMineFieldMingMapping[_user][_pid];
        _coinDebtCost = CoinDebt(costCoin.coin, costCoin.value, 0);
        _coinDebtReward = CoinDebt(rewardCoin.coin, rewardCoin.value, 0);
        _mineralIdDebts = new MineralIdDebt[](mineralIdRewards.length);

        if(userMineFieldStateMapping[_user][_pid] != State.MING){ //未挖矿状态
            return (_userMineFieldMing, _coinDebtCost, _coinDebtReward, _mineralIdDebts); //TODO 修改结构
        }

        uint256 startBlock = _userMineFieldMing.startAt;
        uint256 expectedValidBlock = getValidBlock(_pid, _user, _expectedBlock);
        uint256 entBlock = startBlock.add(expectedValidBlock);

        _coinDebtReward.debt = expectedValidBlock.mul(_coinDebtReward.convertRate);
        _coinDebtCost.debt = expectedValidBlock.mul(_coinDebtCost.convertRate);
        _userMineFieldMing.endAt = entBlock;

        for(uint256 i = 0; i< mineralIdRewards.length; i++){
            MineralIdReward storage mineralIdReward = mineralIdRewards[i];
            MineralIdDebt memory _mineralIdDebt = MineralIdDebt(mineralIdReward.id
            , mineralIdReward.convertRate
            , expectedValidBlock.div(mineralIdReward.convertRate));
            _mineralIdDebts[i] = _mineralIdDebt;
        }

        return (_userMineFieldMing, _coinDebtCost, _coinDebtReward, _mineralIdDebts);
    }

    function getMillDurability(uint256 _pid, address _user, uint256 _expectedBlock) public view override returns(uint256, uint256){
        MineField storage userMineField = userMineFieldMapping[_user][_pid];
        UserMineFieldMing storage userMineFieldMing = userMineFieldMingMapping[_user][_pid];
        MillInfo storage millInfo = userMineFieldMing.millInfo;
        address mill = millInfo.mill;
        uint256 tokenId = millInfo.tokenId;

        uint256 durability = IMill(mill).getNftAttribute(uint(Attribute.DURABILITY),tokenId);
        if(userMineFieldStateMapping[_user][_pid] != State.MING){//未挖矿状态
            return (0, durability);
        }

        uint256 startBlock = userMineFieldMing.startAt;
        if(_expectedBlock !=0 && _expectedBlock <= startBlock){
            return (0, durability);
        }

        uint256 durabilityBlock = durability.mul(userMineField.durabilityRate);
        uint256 durabilityEndBlock = startBlock.add(durabilityBlock);

        if(_expectedBlock >= durabilityEndBlock){
            return (durability, 0);
        }

        if(_expectedBlock == 0){
            _expectedBlock = block.number;
        }
        uint256 deltaBlock = _expectedBlock.sub(startBlock);
        uint256 usedDurability = deltaBlock.ceilDiv(userMineField.durabilityRate);//向上取整

        if(durability >= usedDurability){
            return (usedDurability, durability.sub(usedDurability));
        }else{
            return (durability, 0);
        }
    }

    function noMining(uint256 _pid, uint256 _expectedBlock) public override payable verifyPid(_pid) nonReentrant{
        UserMineFieldMing storage userMineFieldMing = userMineFieldMingMapping[msg.sender][_pid];
        address mill = userMineFieldMing.millInfo.mill;
        uint256 tokenId = userMineFieldMing.millInfo.tokenId;

        _verifyAndWithdrawAndReset(_pid, _expectedBlock);

        IMill(mill).safeTransferFrom(address(this), msg.sender, tokenId);

        emit NoMining(msg.sender, mill, tokenId, _pid, _expectedBlock);
    }

    function withdrawRewards(uint256 _pid, uint256 _expectedBlock) public override payable verifyPid(_pid) nonReentrant{
        UserMineFieldMing storage userMineFieldMing = userMineFieldMingMapping[msg.sender][_pid];
        address mill = userMineFieldMing.millInfo.mill;
        uint256 tokenId = userMineFieldMing.millInfo.tokenId;

        _verifyAndWithdrawAndReset(_pid, _expectedBlock);

        MillInfo memory _millInfo = MillInfo(mill, tokenId);
        _mining(_pid, _millInfo);

        emit WithdrawRewards(msg.sender, mill, tokenId, _pid, _expectedBlock);
    }

    function _verifyAndWithdrawAndReset(uint256 _pid, uint256 _expectedBlock) internal{
        require(userMineFieldStateMapping[msg.sender][_pid] == State.MING, "Not Ming");

        UserMineFieldMing storage userMineFieldMing = userMineFieldMingMapping[msg.sender][_pid];
        uint256 startAt = userMineFieldMing.startAt;

        if(_expectedBlock != 0){
            require(_expectedBlock > startAt && _expectedBlock <= block.number, "Illegal _expectedBlock");
        }
        _withdrawRewardsAndRest(_pid, _expectedBlock);
    }

    function _mining(uint256 _pid, MillInfo memory _millInfo) internal {
        address mill = _millInfo.mill;
        uint256 tokenId = _millInfo.tokenId;
        _createEctype(_pid, msg.sender);
        MineField storage userMineField = userMineFieldMapping[msg.sender][_pid];
        MillConfig storage millConfig = userMineField.millConfig;

        require(IMill(mill).getNftAttribute(uint(Attribute.GRADE),tokenId) == millConfig.millGradeId
            && IMill(mill).getNftAttribute(uint(Attribute.ATTRIBUTE),tokenId) == millConfig.millAttributeId,"The mill do not match");

        userMineFieldStateMapping[msg.sender][_pid] = State.MING;
        UserMineFieldMing storage userMineFieldMing =  userMineFieldMingMapping[msg.sender][_pid];
        userMineFieldMing.startAt = block.number;
        userMineFieldMing.millInfo = _millInfo;
    }

    function _withdrawRewardsAndRest(uint256 _pid, uint256 _expectedBlock) internal{
        UserMineFieldMing storage userMineFieldMing = userMineFieldMingMapping[msg.sender][_pid];
        MillInfo storage millInfo = userMineFieldMing.millInfo;
        address mill = millInfo.mill;
        uint256 tokenId = millInfo.tokenId;

        _withdrawRewards(_pid, _expectedBlock);

        (, uint256 surplusDurability) = getMillDurability(_pid, msg.sender, _expectedBlock);
        IMill(mill).setNftAttribute(uint256(Attribute.DURABILITY), tokenId, surplusDurability);

        delete userMineFieldMapping[msg.sender][_pid];
        delete userMineFieldMingMapping[msg.sender][_pid];
        userMineFieldStateMapping[msg.sender][_pid] = State.CULTIVATED;
    }

    function _withdrawRewards(uint256 _pid, uint256 _expectedBlock) internal{
        require(userMineFieldStateMapping[msg.sender][_pid] == State.MING, "Not Ming");

        (UserMineFieldMing memory _userMineFieldMing
        , CoinDebt memory coinDebtCost
        , CoinDebt memory coinDebtReward
        , MineralIdDebt[] memory mineralIdDebts) = this.getDebts(_pid, msg.sender, _expectedBlock);

        uint256 expectedEndAt = _userMineFieldMing.endAt;
        UserMineFieldMing storage userMineFieldMing = userMineFieldMingMapping[msg.sender][_pid];
        uint256 realtimeValidBlock = getValidBlock(_pid, msg.sender, 0);
        uint256 realtimeEndAt = userMineFieldMing.startAt.add(realtimeValidBlock);
        require(realtimeEndAt >= expectedEndAt && realtimeEndAt.sub(expectedEndAt) <= expectedBlockDelta,"Exceed _expectedBlock");

        AssetTransfer.coinCost(feeTo, coinDebtCost.coin, coinDebtCost.debt);
        AssetTransfer.coinReward(msg.sender, coinDebtReward.coin, coinDebtReward.debt);
        MineField storage userMineField = userMineFieldMapping[msg.sender][_pid];
        MineralReward storage mineralReward = userMineField.mineralReward;
        AssetTransfer.mineralReward(msg.sender, address(mineralReward.mineral), mineralIdDebts);
    }

    function withdrawAsset(address _asset, address _to, uint256 _amount) public override onlyOwner{
        require(_to != address(0),"WithdrawAsset: _to the zero address");
        uint256 amount = _asset == address(0) ? address(this).balance : IERC20(_asset).balanceOf(address(this));
        require(_amount >0 && _amount <= amount);
        AssetTransfer.coinReward(_to, _asset, _amount);

        emit WithdrawAsset(msg.sender, _to, _asset, _amount);
    }

    function _createEctype(uint256 _pid, address _user) internal {
        delete userMineFieldMapping[_user][_pid];

        MineField storage userMineField = userMineFieldMapping[_user][_pid];
        CoinValue storage costCoin = userMineField.costCoin;
        CoinValue storage rewardCoin = userMineField.rewardCoin;
        MillConfig storage millConfig = userMineField.millConfig;
        MineralReward storage mineralReward = userMineField.mineralReward;
        MineralIdReward[] storage mineralIdRewards = mineralReward.mineralIdRewards;

        MineField memory _mineField = mineTemplatePool.getMineField(_pid);
        MillConfig memory _millConfig = _mineField.millConfig;
        CoinValue memory _costCoin = _mineField.costCoin;
        CoinValue memory _rewardCoin = _mineField.rewardCoin;

        userMineField.mineId = _mineField.mineId;
        userMineField.durabilityRate = _mineField.durabilityRate;

        costCoin.coin = _costCoin.coin;
        costCoin.value = _costCoin.value;
        rewardCoin.coin = _rewardCoin.coin;
        rewardCoin.value = _rewardCoin.value;
        millConfig.millAttributeId = _millConfig.millAttributeId;
        millConfig.millQualityId = _millConfig.millQualityId;
        millConfig.millGradeId = _millConfig.millGradeId;

        MineralReward memory _mineralReward = _mineField.mineralReward;
        MineralIdReward[] memory _mineralIdRewards = _mineralReward.mineralIdRewards;
        mineralReward.mineral = _mineralReward.mineral;
        StructSet.pushMineralIdRewards(mineralIdRewards,_mineralIdRewards);
    }

    function getValidBlock(uint256 _pid, address _user,uint256 _expectedBlock) public view returns(uint256){
        State state = userMineFieldStateMapping[_user][_pid];
        if(State.MING != state){
            return 0;
        }

        UserMineFieldMing storage userMineFieldMing = userMineFieldMingMapping[_user][_pid];
        uint256 startBlock = userMineFieldMing.startAt;
        if(_expectedBlock !=0 && _expectedBlock <= startBlock){
            return 0;
        }

        (uint256 usedDurability, ) = getMillDurability(_pid, _user, _expectedBlock);
        MineField storage userMineField = userMineFieldMapping[_user][_pid];
        uint256 durabilityBlock = userMineField.durabilityRate.mul(usedDurability);

        if(_expectedBlock == 0){
            _expectedBlock = block.number;
        }
        uint256 deltaBlock = _expectedBlock.sub(startBlock);
        return durabilityBlock >= deltaBlock ? deltaBlock : durabilityBlock;
    }

    receive() external payable virtual {
        emit PaymentReceived(_msgSender(), msg.value);
    }
}
