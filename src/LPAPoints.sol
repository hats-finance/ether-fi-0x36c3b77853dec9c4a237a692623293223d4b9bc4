// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

contract LPAPoints is Ownable {

    event PointsPurchased(address indexed buyer, uint256 amountWei);

    function purchasePoints() external payable {
        emit PointsPurchased(msg.sender, msg.value);
    }

    receive() external payable {
        emit PointsPurchased(msg.sender, msg.value);
    }

    //-----------------------------------------------------------------------------
    //-------------------------------  Admin  -------------------------------------
    //-----------------------------------------------------------------------------

    function withdrawFunds(address payable _to) external onlyOwner {
        _to.transfer(address(this).balance);
    }
}
