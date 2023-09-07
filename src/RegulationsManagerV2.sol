// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "forge-std/console2.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RegulationsManagerV2 is Ownable {

    bytes32 constant TYPEHASH = keccak256("TermsOfService(bytes32 message,bytes32 hash)");
    bytes32 constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,string version)");
    string public DOMAIN_NAME = "Ether.fi Terms of Service";
    string public DOMAIN_VERSION = "1";

    struct TermsOfService {
        bytes32 message;
        bytes32 hashOfTerms;
    }
    TermsOfService public currentTerms;

    error InvalidTermsAndConditionsSignature();

    function verifyTermsSignature(bytes memory signature) external {

        console2.log("sender", msg.sender);
        console2.log("recovered", recoverSigner(generateTermsDigest(), signature));
        if (recoverSigner(generateTermsDigest(), signature) != msg.sender) revert InvalidTermsAndConditionsSignature();
    }

    function generateTermsDigest() public returns (bytes32) {

        TermsOfService memory terms = currentTerms;

        bytes2 prefix = "\x19\x01";
        bytes32 domainSeparator = keccak256(abi.encode(DOMAIN_TYPEHASH, DOMAIN_NAME, DOMAIN_VERSION));
        bytes32 structHash = keccak256(abi.encode(TYPEHASH, terms.message, terms.hashOfTerms));

        console2.logBytes32(structHash);

        bytes32 digest = keccak256(abi.encodePacked(prefix, domainSeparator, structHash));
        return digest;
    }

    //--------------------------------------------------------------------------------------
    //----------------------------------  Admin   ------------------------------------------
    //--------------------------------------------------------------------------------------

    function updateTermsOfService(bytes32 _message, bytes32 _hashOfTerms, string calldata _domainVersion) external onlyOwner {
        currentTerms = TermsOfService({ message: _message, hashOfTerms: _hashOfTerms });
        DOMAIN_VERSION = _domainVersion;
    }

    //--------------------------------------------------------------------------------------
    //---------------------------  Signature Recovery   ------------------------------------
    //--------------------------------------------------------------------------------------

    function splitSignature(bytes memory sig)
        internal
        pure
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        require(sig.length == 65);

        assembly {
            // first 32 bytes, after the length prefix.
            r := mload(add(sig, 32))
            // second 32 bytes.
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes).
            v := byte(0, mload(add(sig, 96)))
        }

        return (v, r, s);
    }

    function recoverSigner(bytes32 message, bytes memory sig)
        internal
        pure
        returns (address)
    {
        (uint8 v, bytes32 r, bytes32 s) = splitSignature(sig);

        return ecrecover(message, v, r, s);
    }

}
