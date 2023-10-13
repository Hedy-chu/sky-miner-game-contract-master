// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IMill is IERC721{
    function getDefaultAttribute() external view returns (uint256 attribute, uint256 quality, uint256 grade, uint256 initDurability);
    function getNftAttribute(uint256 attributeId, uint256 tokenId) external view returns (uint256);

    function mintWithWhiteList(address to) external;
    function burn(uint256 tokenId) external;
    function setNftAttribute(uint256 attributeId, uint256 tokenId, uint256 value) external;
}
