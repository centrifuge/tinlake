pragma solidity >=0.5.15 <0.6.0;

import "../../../test/mock/mock.sol";

contract NFTMock is Mock {

    uint threshold_;

    function ownerOf(uint) public view returns (address) {
        return values_address_return["ownerOf"];
    }
    function transferFrom(address from, address to, uint tokenId) public {
        calls["transferFrom"]++;
        values_address["transferFrom_from"] = from;
        values_address["transferFrom_to"] = to;

        //mock nft transfer behaviour
        values_address_return["ownerOf"] = to;

        values_uint["transferFrom_tokenId"] = tokenId;
    }
    function mint(address owner, uint256 tokenId) public {
        calls["mint"]++;
        values_address["mint_owner"] = owner;
        values_uint["mint_tokenId"] = tokenId;
    }

    function setThreshold(uint , uint amount) public {
        threshold_ = amount;
    }

    function threshold(uint) public view returns (uint) {
        return threshold_;
    }
}
