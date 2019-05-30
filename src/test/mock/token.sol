pragma solidity >=0.4.24;


contract TokenMock {
    uint public totalSupply;

    mapping (address => uint) public balance;

    function balanceOf(address addr) public returns (uint) {
        return balance[addr];

    }
    function mint(address addr,uint wad) public {
        balance[addr] += wad;
        totalSupply += wad;
    }
    function transferFrom(address dst ,address src ,uint wad) public {
        balance[dst] -= wad;
        balance[src] += wad;

    }
    function burn(address addr, uint wad) public {
        balance[addr] -= wad;
        totalSupply -= wad;
    }
}
