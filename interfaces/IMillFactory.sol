// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../storage/MillFactoryStorage.sol";
import "../utils/SignatureLens.sol";

abstract contract IMillFactory is SignatureLens,MillFactoryStorage{

    event ResetFeeTo(address oldFeeTo, address newFeeTo);
    event AddMill(address indexed operator, address mill);
    event RemoveMill(address indexed operator, address mill);

    event PaymentReceived(address indexed from, uint256 amount);
    event Composition(address indexed from , address compositionMill, address consumeMill, bool success);
    event Repair(address indexed from, address mill, uint256 tokenId, bool success);

    function addMills(address[] calldata _mills) external virtual;
    function removeMill(address _mill) external virtual;
    function getMillLength() external view virtual returns (uint256);
    function getMill(uint256 _index) external view virtual returns (address);
    function isMill(address _mill) external view virtual returns (bool);

    function restCompositionConfig(address _compositionMill, CompositionConfig calldata _compositionConfig) external virtual;
    function restRepairConfig(address _mill, RepairConfig calldata _repairConfig) external virtual;

    function composition(address _compositionMill, MillInfos calldata _consumeMillInfos, Signature calldata _signature) external virtual payable;
    function repair(MillInfo calldata _millInfo, Signature calldata _signature) external virtual payable;
    function getCompositionDebts(address _mill) external view virtual returns(MineralIdDebt[] memory);
    function getRepairDebts(address _mill,uint256 _tokenId) external view virtual returns(MineralIdDebt[] memory);

}
