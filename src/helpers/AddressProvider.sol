// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

contract AddressProvider {

    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------

    struct ContractData {
        uint128 version;
        uint128 lastModified;
        address proxyAddress;
        address implementationAddress;
        bool isDeprecated;
        string name;
    }

    mapping(string => ContractData) public contracts;
    uint256 public numberOfContracts;

    address public owner;

    constructor() {
        owner = msg.sender;
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    function addContract(address _proxy, address _implementation, string memory _name) external onlyOwner {
        require(_implementation != address(0), "Implementation cannot be zero addr");
        require(contracts[_name].lastModified == 0, "Contract already exists");
        contracts[_name] = ContractData({
            version: 1,
            lastModified: uint128(block.timestamp),
            proxyAddress: _proxy,
            implementationAddress: _implementation,
            isDeprecated: false,
            name: _name
        });
        numberOfContracts++;
    }

    function updateContractImplementation(string memory _name, address _newImplementation) external onlyOwner {
        ContractData storage contractData = contracts[_name];
        require(contractData.lastModified != 0, "Contract doesn't exists");
        require(contractData.isDeprecated == false, "Contract deprecated");
        require(_newImplementation != address(0), "Implementation cannot be zero addr");

        contractData.lastModified = uint128(block.timestamp);
        contractData.version += 1;
        contractData.implementationAddress = _newImplementation;
    }

    function deactivateContract(string memory _name) external onlyOwner {
        require(contracts[_name].isDeprecated == false, "Contract already deprecated");
        contracts[_name].isDeprecated = true;
    }

    function reactivateContract(string memory _name) external onlyOwner {
        require(contracts[_name].isDeprecated == true, "Contract already active");
        contracts[_name].isDeprecated = false;
    }

    //--------------------------------------------------------------------------------------
    //--------------------------------------  SETTER  --------------------------------------
    //--------------------------------------------------------------------------------------

    function setOwner(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Cannot be zero addr");
        owner = _newOwner;
    }

    //--------------------------------------------------------------------------------------
    //--------------------------------------  GETTER  --------------------------------------
    //--------------------------------------------------------------------------------------

    function getProxyAddress(string memory _name) external returns (address) {
        return contracts[_name].proxyAddress;
    }

    function getImplementationAddress(string memory _name) external returns (address) {
        return contracts[_name].implementationAddress;
    }

    //--------------------------------------------------------------------------------------
    //-----------------------------------  MODIFIERS  --------------------------------------
    //--------------------------------------------------------------------------------------

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner function");
        _;
    }
}
