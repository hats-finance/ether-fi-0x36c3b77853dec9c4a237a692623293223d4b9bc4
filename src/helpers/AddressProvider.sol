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

    mapping(uint256 => ContractData) public contracts;
    mapping(string => uint256) public nameToId;
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
        contracts[numberOfContracts] = ContractData({
            version: 1,
            lastModified: uint128(block.timestamp),
            proxyAddress: _proxy,
            implementationAddress: _implementation,
            isDeprecated: false,
            name: _name
        });
        nameToId[_name] = numberOfContracts;
        numberOfContracts++;
    }

    function updateContractImplementation(string memory _name, address _newImplementation) external onlyOwner {
        uint256 contractId = nameToId[_name];
        ContractData storage contractData = contracts[contractId];
    
        require(contractId < numberOfContracts, "Invalid contract ID");
        require(contractData.isDeprecated == false, "Contract deprecated");
        require(_newImplementation != address(0), "Implementation cannot be zero addr");

        contractData.lastModified = uint128(block.timestamp);
        contractData.version += 1;
        contractData.implementationAddress = _newImplementation;
    }

    function deactivateContract(string memory _name) external onlyOwner {
        uint256 contractId = nameToId[_name];
        require(contracts[contractId].isDeprecated == false, "Contract already deprecated");
        contracts[contractId].isDeprecated = true;
    }

    function reactivateContract(string memory _name) external onlyOwner {
        uint256 contractId = nameToId[_name];
        require(contracts[contractId].isDeprecated == true, "Contract already active");
        contracts[contractId].isDeprecated = false;
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
        uint256 contractId = nameToId[_name];
        return contracts[contractId].proxyAddress;
    }

    function getImplementationAddress(string memory _name) external returns (address) {
        uint256 contractId = nameToId[_name];
        return contracts[contractId].implementationAddress;
    }

    //--------------------------------------------------------------------------------------
    //-----------------------------------  MODIFIERS  --------------------------------------
    //--------------------------------------------------------------------------------------

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner function");
        _;
    }
}
