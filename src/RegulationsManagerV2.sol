// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "forge-std/console2.sol";

contract RegulationsManagerV2 {

    bytes32 constant TYPEHASH = keccak256("TermsOfService(bytes32 message,bytes32 hash)");
    bytes32 constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,string version)");
    string public DOMAIN_NAME = "Ether.fi Terms of Service";
    string public DOMAIN_VERSION = "1";

    TermsOfService public currentTerms;

    struct TermsOfService {
        bytes32 message;
        bytes32 hashOfTerms;
    }

    constructor() {
        currentTerms = TermsOfService({
            message: "I agree to Ether.fi ToS",
            hashOfTerms: "hello"
        });
    }

    error InvalidTermsAndConditionsSignature();

    function verifyTermsSignature(bytes memory signature) external {
        /*
        bytes2 prefix = "\x19\x01";
        bytes32 domainSeparator = domainSeparator();
        bytes32 structHash = hashStruct(currentTerms);

        // EIP712
        // encode(domainSeparator : 𝔹²⁵⁶, message : 𝕊) = "\x19\x01" ‖ domainSeparator ‖ hashStruct(message) 
        bytes32 message = keccak256(abi.encodePacked(prefix, domainSeparator, structHash));
        */

        console2.log("recovered", recoverSigner(generateTermsDigest(), signature));
        if (recoverSigner(generateTermsDigest(), signature) != msg.sender) revert InvalidTermsAndConditionsSignature();
    }

    function generateTermsDigest() public returns (bytes32) {
        bytes2 prefix = "\x19\x01";
        bytes32 domainSeparator = domainSeparator();
        bytes32 structHash = hashStruct(currentTerms);

        bytes32 digest = keccak256(abi.encodePacked(prefix, domainSeparator, structHash));
        return digest;
    }

    function hashStruct(TermsOfService memory terms) public pure returns (bytes32 hash) {
        return keccak256(abi.encode(
            TYPEHASH,
            terms.message,
            terms.hashOfTerms
        ));
    }

    function domainSeparator() public view returns (bytes32 hash) {
        return keccak256(abi.encode(
            DOMAIN_TYPEHASH,
            DOMAIN_NAME,
            DOMAIN_VERSION
        ));
    }

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

    // builds a prefixed hash to mimic the behavior of eth_sign.
    function prefixed(bytes32 hash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", hash));
    }



}
