// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

abstract contract SignatureLens is Ownable {

    struct Signature {
        uint256 nonce;
        uint256 deadline;
        bytes s;
    }

    event ResetSigner(address oldSigner, address newSigner);

    address public signer;
    mapping(address =>uint256) public signerNonceMapping;

    constructor (address _singer) {
        require(_singer != address(0),"Constructor: _singer the zero address");
        signer = _singer;
    }

    function resetSigner(address _signer) external onlyOwner{
        require(_signer != address(0), "ResetSigner: _signer the zero address");
        address oldSigner = signer;
        signer = _signer;

        emit ResetSigner(oldSigner, _signer);
    }

    function verifySignature(Signature calldata _signature) public virtual returns(bool) {
        uint256 _nonce = _signature.nonce;
        uint256 _deadline = _signature.deadline;

        uint256 nonce = signerNonceMapping[msg.sender];
        require(_nonce == nonce, "Illegal nonce");
        require(block.timestamp <= _deadline, "Out of time");

        address _signer = resolveSignature(msg.sender, _signature);
        signerNonceMapping[msg.sender] = nonce +1;

        return _signer != address(0) && _signer == signer;
    }

    function resolveSignature(address _user, Signature calldata _signature) public pure returns(address) {
        uint256 _nonce = _signature.nonce;
        uint256 _deadline = _signature.deadline;
        bytes calldata _s = _signature.s;

        bytes32 hash = keccak256(abi.encodePacked(_user, _nonce, _deadline));
        bytes32 message = ECDSA.toEthSignedMessageHash(hash);
        return ECDSA.recover(message, _s);
    }
}
