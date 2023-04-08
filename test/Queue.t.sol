// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console.sol";
import "forge-std/Test.sol";
import "../src/Queue.sol";

contract QueueTest is Test {

    struct Data {
        address owner;
        uint32 winningTimestamp;
        uint8 numTickets;
        uint8 numDeposits;
    }

    Queue public queue;

    function setUp() public {
        queue = new Queue();
        require(queue.isEmpty());
    }

    function decodePacked(bytes memory data) pure internal returns (Data memory) {
        address owner;
        uint32 winningTimestamp;
        uint8 numTickets;
        uint8 numDeposits;
        assembly {
            owner := mload(add(data, 20)) // 20
            winningTimestamp := mload(add(data, 24)) // 20 + 4
            numTickets := mload(add(data, 25)) // 20 + 4 + 1
            numDeposits := mload(add(data, 26)) // 20 + 4 + 1 + 1
        }
        return Data({owner: owner, winningTimestamp: winningTimestamp, numTickets: numTickets, numDeposits: numDeposits});
    }

    function test_EncodeAndDecode() public {
        Data memory data = Data({owner: address(vm.addr(1)), winningTimestamp: uint32(block.timestamp), numTickets: type(uint8).max, numDeposits: 2});
        bytes memory encodedData = abi.encodePacked(data.owner, data.winningTimestamp, data.numTickets, data.numDeposits);
        Data memory decodedData = decodePacked(encodedData);

        assertEq(data.owner, decodedData.owner);
        assertEq(data.winningTimestamp, decodedData.winningTimestamp);
        assertEq(data.numTickets, decodedData.numTickets);
        assertEq(data.numDeposits, decodedData.numDeposits);
    }

    function test_EnqueueDequeue() public {
        uint24[] memory ids = new uint24[](16);

        for (uint8 i = 0; i < ids.length; i++) {
            Data memory data = Data({owner: address(vm.addr(i+1)), winningTimestamp: uint32(block.timestamp), numTickets: i, numDeposits: 0});
            bytes memory encodedData = abi.encodePacked(data.owner, data.winningTimestamp, data.numTickets, data.numDeposits);
            ids[i] = queue.enqueue(bytes26(encodedData));

            assertEq(ids[i], i+1);
            assertTrue(!queue.isEmpty());
            assertTrue(queue.contains(ids[i]));
            assertEq(queue.head(), ids[0]);
            assertEq(queue.tail(), ids[i]);
            assertEq(queue.size(), i+1);
        }

        for (uint i = 0; i < ids.length; i++) {
            if (i % 2 == 0) {
                bytes26 encodedData26 = queue.get(ids[i]);
                bytes memory encodedData = bytes.concat(encodedData26);
                Data memory data = decodePacked(encodedData);

                assertEq(ids[i], i+1);
                assertTrue(!queue.isEmpty());
                assertTrue(queue.contains(ids[i]));

                queue.deleteAt(ids[i]);

                assertEq(data.owner, address(vm.addr(i+1)));
                assertEq(data.winningTimestamp, uint32(block.timestamp));
                assertEq(data.numTickets, i);
                assertEq(data.numDeposits, 0);
                assertTrue(!queue.contains(ids[i]));

                vm.expectRevert("Such element does not exist");
                queue.get(ids[i]);
            } else {
                assertTrue(queue.contains(ids[i]));
            }
        }

        for (uint i = 0; i < ids.length; i++) {
            if (i % 2 != 0) {
                (uint24 id, bytes26 encodedData26) = queue.dequeue();
                bytes memory encodedData = bytes.concat(encodedData26);
                Data memory data = decodePacked(encodedData);

                assertEq(data.owner, address(vm.addr(i+1)));
                assertEq(data.winningTimestamp, uint32(block.timestamp));
                assertEq(data.numTickets, i);
                assertEq(data.numDeposits, 0);
                assertEq(id, i+1);
            }
        }

        assertTrue(queue.isEmpty());

        vm.expectRevert("Queue is empty");
        queue.top();
    }

}