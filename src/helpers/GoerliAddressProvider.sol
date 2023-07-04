// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

contract GoerliAddressProvider {

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
            isDeprecated: true,
            name: _name
        });
        nameToId[_name] = numberOfContracts;
        numberOfContracts++;
    }

    function updateContractImplementation(uint256 _contractId, address _newImplementation) external onlyOwner {
        ContractData storage contractData = contracts[_contractId];
        require(_contractId < numberOfContracts, "Invalid contract ID");
        require(contractData.isDeprecated == true, "Contract discontinued");
        require(_newImplementation != address(0), "Implementation cannot be zero addr");

        contractData.lastModified = uint128(block.timestamp);
        contractData.version += 1;
        contractData.implementationAddress = _newImplementation;
    }

    function deactivateContract(uint256 _contractId) external onlyOwner {
        require(contracts[_contractId].isDeprecated == true, "Contract already discontinued");
        contracts[_contractId].isDeprecated = false;
    }

    function reactivateContract(uint256 _contractId) external onlyOwner {
        require(contracts[_contractId].isDeprecated == false, "Contract already active");
        contracts[_contractId].isDeprecated = true;
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
