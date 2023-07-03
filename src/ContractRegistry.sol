// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

contract ContractRegistry {

    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------

    //Network 0 = GOERLI, 1 = MAINNET
    struct ContractData {
        uint256 network;
        uint256 version;
        uint256 lastModified;
        address proxyAddress;
        address implementationAddress;
        bool isActive;
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

    function addContract(address _proxy, address _implementation, string memory _name, uint256 _network) external onlyOwner {
        require(_implementation != address(0), "Implementation cannot be zero addr");
        contracts[numberOfContracts] = ContractData({
            network: _network,
            version: 1,
            lastModified: block.timestamp,
            proxyAddress: _proxy,
            implementationAddress: _implementation,
            isActive: true,
            name: _name
        });
        nameToId[_name] = numberOfContracts;
        numberOfContracts++;
    }

    function updateContractImplementation(uint256 _contractId, address _newImplementation) external onlyOwner {
        ContractData storage contractData = contracts[_contractId];
        require(_contractId < numberOfContracts, "Invalid contract ID");
        require(contractData.isActive == true, "Contract discontinued");
        require(_newImplementation != address(0), "Implementation cannot be zero addr");

        contractData.lastModified = block.timestamp;
        contractData.version += 1;
        contractData.implementationAddress = _newImplementation;
    }

    function discontinueContract(uint256 _contractId) external onlyOwner {
        require(contracts[_contractId].isActive == true, "Contract already discontinued");
        contracts[_contractId].isActive = false;
    }

    function reviveContract(uint256 _contractId) external onlyOwner {
        require(contracts[_contractId].isActive == false, "Contract already active");
        contracts[_contractId].isActive = true;
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

    //--------------------------------------------------------------------------------------
    //-----------------------------------  MODIFIERS  --------------------------------------
    //--------------------------------------------------------------------------------------

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner function");
        _;
    }
}
