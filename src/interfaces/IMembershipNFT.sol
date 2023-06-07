// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IMembershipNFT {
    function initialize(string calldata _metadataURI) external;
    function mint(address _to, uint256 _amount) external returns (uint256);
    function burn(address _from, uint256 _tokenId, uint256 _amount) external;
    function setMembershipManager(address _address) external;
    function valueOf(uint256 _tokenId) external view returns (uint256);
    function loyaltyPointsOf(uint256 _tokenId) external view returns (uint40);
    function tierPointsOf(uint256 _tokenId) external view returns (uint40);
    function tierOf(uint256 _tokenId) external view returns (uint8);
    function claimableTier(uint256 _tokenId) external view returns (uint8);
    function accruedLoyaltyPointsOf(uint256 _tokenId) external view returns (uint40);
    function accruedTierPointsOf(uint256 _tokenId) external view returns (uint40);
    function canTopUp(uint256 _tokenId, uint256 _totalAmount, uint128 _amount, uint128 _amountForPoints) external view returns (bool);
    function isWithdrawable(uint256 _tokenId, uint256 _withdrawalAmount) external view returns (bool);
    function allTimeHighDepositOf(uint256 _tokenId) external view returns (uint256);
    function contractURI() external view returns (string memory);
    function setContractMetadataURI(string calldata _newURI) external;
    function setMetadataURI(string calldata _newURI) external;
    function alertMetadataUpdate(uint256 id) external;
    function alertBatchMetadataUpdate(uint256 startID, uint256 endID) external;
}
