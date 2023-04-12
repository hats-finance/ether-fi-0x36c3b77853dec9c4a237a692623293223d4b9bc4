pragma solidity ^0.8.0;


// FIFO Queue supporting O(1) deletion at a random position
// using a doubly linked list and a map.
contract Queue {
    struct Node {
        uint24 prev;
        uint24 next;
        bytes26 data;
    }

    mapping(uint24 => Node) public nodes;
    uint24 public head;
    uint24 public tail;
    uint24 public nodeIdCounter = 1;
    uint24 public size;

    //--------------------------------------------------------------------------------------
    //------------------------------------  GETTERS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    function top() external view returns (uint24) {
        require(!isEmpty(), "Queue is empty");
        return head;
    }

    function get(uint24 _id) external view validId(_id) returns (bytes26) {
        require(contains(_id), "Such element does not exist");
        return nodes[_id].data;
    }

    function isEmpty() public view returns (bool) {
        return (head == 0 && tail == 0);
    }

    function contains(uint24 id) public view returns (bool) {
        return (nodes[id].prev > 0 && nodes[id].next > 0);
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    // enqueue after the tail
    function enqueue(bytes26 data) public returns (uint24 id) {
        id = nodeIdCounter;

        nodes[id] = Node({data: data, prev: 0, next: id});
        if (isEmpty()) {
            head = id;
            tail = id;
            nodes[id].prev = id;
            nodes[id].next = id;
        } else {
            nodes[tail].next = id;
            nodes[id].prev = tail;
            tail = id;
        }

        size++;
        nodeIdCounter++;
    }

    // dequeue from the head
    function dequeue() public returns (uint24, bytes26) {
        require(!isEmpty(), "Queue is empty");        
        uint24 id = head;
        bytes26 data = nodes[id].data;

        if (_isTail(id)) {
            head = 0;
            tail = 0;
        } else {
            head = nodes[id].next;
            nodes[head].prev = head;
        }

        size--;
        return (id, data);
    }

    function deleteAt(uint24 _id) public validId(_id) {
        require(contains(_id), "Such element does not exist");

        uint24 prev = nodes[_id].prev;
        uint24 next = nodes[_id].next;

        if (_isHead(_id)) {
            head = next;
            nodes[head].prev = head;            
        } else if (_isTail(_id)) {
            tail = prev;
            nodes[tail].next = tail;
        } else {
            nodes[prev].next = next;
            nodes[next].prev = prev;
        }

        delete nodes[_id];
        size--;
    }

    //--------------------------------------------------------------------------------------
    //-------------------------------  INTERNAL FUNCTIONS   --------------------------------
    //--------------------------------------------------------------------------------------

    function _isHead(uint24 _id) internal view validId(_id) returns (bool) {
        return head == _id;
    }

    function _isTail(uint24 _id) internal view validId(_id) returns (bool) {
        return tail == _id;
    }

    //--------------------------------------------------------------------------------------
    //-----------------------------------  MODIFIERS  --------------------------------------
    //--------------------------------------------------------------------------------------

    modifier validId(uint24 _id) {
        require(_id > 0, "Invalid Id");
        _;
    }
}