// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

interface IMineral is IERC1155{
    function mintTokenIdWithWitelist(address to, uint256[] memory ids, uint256[] memory amounts) external;
    function brun(address account, uint256 id, uint256 value) external;
    function brunBatch(address account, uint256[] memory ids, uint256[] memory amounts) external;
}
