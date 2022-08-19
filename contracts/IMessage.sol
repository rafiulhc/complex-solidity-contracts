// SPDX-License-Identifier: None
pragma solidity ^0.8.7;

interface Message {

    function setName(string memory _name) external;
}

contract A is Message {
    string public name;
    uint public x;
    constructor(uint _x){
            x = _x;
    }
    function setName(string memory _name) public override{
        name = _name;
    }
}