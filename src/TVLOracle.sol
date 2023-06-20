// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

contract TVLOracle is Ownable {

  address public tvlAggregator;
  uint256 private _currentTvl;

  event TVLUpdated(uint256 _currentTvl);

  constructor(address _tvlAggregator) {
    require(_tvlAggregator != address(0), "No zero addresses");
    tvlAggregator = _tvlAggregator;
  }

  function setTvl(uint256 _newTvl) public {
    require(msg.sender == tvlAggregator, "Only TVL Aggregator can call this message");
    require(_newTvl > 0, "TVL shouldn't be 0");

    _currentTvl = _newTvl;
    emit TVLUpdated(_newTvl);
  }

  function getTvl() public view returns (uint256) {
    return _currentTvl;
  }

  function setTVLAggregator(address _tvlAggregator) public onlyOwner {
    require(_tvlAggregator != address(0), "No zero addresses");
    tvlAggregator = _tvlAggregator;
  }
}