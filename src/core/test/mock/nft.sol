pragma solidity >=0.4.24;

contract NFTMock {

    //calls
    uint public transferFromCalls;
    uint public mintCalls;

    uint public tokenId;
    address public from;
    address public to;
    address public owner;
    
    function reset() public {
        transferFromCalls = 0;
        mintCalls = 0;
        tokenId = 0;
        from = address(0);
        to = address(0);
        owner = address(0);
    }

    //returns
    address public ownerOfReturn; function setOwnerOfReturn(address ownerOfReturn_) public {ownerOfReturn=ownerOfReturn_;}

    function ownerOf(uint256 tokenId_) public view returns (address) {

        return ownerOfReturn;

    }
    function transferFrom(address from_, address to_, uint256 tokenId_) public {
        from = from_;
        to = to_;
        tokenId = tokenId_;

        ownerOfReturn = to_; //mock nft transfer behaviour

        transferFromCalls++;

    }
    function mint(address owner_, uint256 tokenId_) public {
        owner = owner_;
        tokenId = tokenId_;
        mintCalls++;
    }
}
