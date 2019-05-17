// Copyright (C) 2019 lucasvo
pragma solidity >=0.4.24;

contract TokenLike {
    uint public totalSupply;
    function mint(address,uint) public;
    function transferFrom(address,address,uint) public;
}


