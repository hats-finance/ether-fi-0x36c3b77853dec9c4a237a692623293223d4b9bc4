// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./IStakingManager.sol";

interface ILiquidityPool {
    function numValidators() external view returns (uint256);
    function getTotalEtherClaimOf(address _user) external view returns (uint256);
    function getTotalPooledEther() external view returns (uint256);
    function sharesForAmount(uint256 _amount) external view returns (uint256);
    function amountForShare(uint256 _share) external view returns (uint256);
    function eEthliquidStakingOpened() external view returns (bool);

    function deposit(address _user, bytes32[] calldata _merkleProof) external payable;
    function deposit(address _user, address _recipient, bytes32[] calldata _merkleProof) external payable;
    function withdraw(address _recipient, uint256 _amount) external;

    function batchDepositWithBidIds(uint256 _numDeposits, uint256[] calldata _candidateBidIds, bytes32[] calldata _merkleProof) external payable returns (uint256[] memory);
    function batchRegisterValidators(bytes32 _depositRoot, uint256[] calldata _validatorIds, IStakingManager.DepositData[] calldata _depositData) external;
    function processNodeExit(uint256[] calldata _validatorIds, uint256[] calldata _slashingPenalties) external;
    function sendExitRequests(uint256[] calldata _validatorIds) external;

    function openEEthLiquidStaking() external;
    function closeEEthLiquidStaking() external;

    function setTokenAddress(address _eETH) external;
    function setStakingManager(address _address) external;
    function setEtherFiNodesManager(address _nodeManager) external;
    function setMeEth(address _address) external;
}