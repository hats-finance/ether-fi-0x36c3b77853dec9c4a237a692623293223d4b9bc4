// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./WithdrawSafeManager.sol";


contract WithdrawSafe {
    //Allows ether to be sent to this contract
    receive() external payable {
    }

    function withdrawFunds(
        address _treasury,
        uint256 _treasuryAmount,
        address _operator, 
        uint256 _operatorAmount,
        address _tnftHolder,
        uint256 _tnftAmount,
        address _bnftHolder,
        uint256 _bnftAmount
    ) public {
        (bool sent, ) = _treasury.call{value: _treasuryAmount}("");
        require(sent, "Failed to send Ether");
        (sent, ) = payable(_operator).call{value: _operatorAmount}("");
        require(sent, "Failed to send Ether");
        (sent, ) = payable(_tnftHolder).call{value: _tnftAmount}("");
        require(sent, "Failed to send Ether");
        (sent, ) = payable(_bnftHolder).call{value: _bnftAmount}("");
        require(sent, "Failed to send Ether");
    }
}
