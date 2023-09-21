// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./IEtherFiOracle.sol";

interface IEtherFiAdmin {
    function initialize(
        address _etherFiOracle,
        address _stakingManager,
        address _auctionManager,
        address _etherFiNodesManager,
        address _liquidityPool,
        address _membershipManager,
        address _withdrawRequestNft
    ) external;
    function executeTasks(
        IEtherFiOracle.OracleReport calldata _report, 
        bytes[] calldata _pubKey, 
        bytes[] calldata _signature
    ) external;
    function slotForNextReportToProcess() external view returns (uint32);
    function blockForNextReportToProcess() external view returns (uint32);
    function updateAdmin(address _address, bool _isAdmin) external;
    function getImplementation() external view returns (address);

    function numValidatorsToSpinUp() external view returns (uint32);
}
