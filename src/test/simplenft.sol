pragma solidity >=0.4.24;

import { ERC721  } from "../openzeppelin-solidity/token/ERC721/ERC721.sol";
import "ds-test/test.sol";

// This contract allows anyone to mint an NFT. Used for testing Tinlake
contract SimpleNFT is ERC721 {
    constructor () ERC721() public {
    }

    function mint(address to, uint tokenId) public {
        _mint(to, tokenId); 
    }
}

contract NFTUser {
    SimpleNFT nft;
    constructor (SimpleNFT nft_) public {
        nft = nft_;
    }
    function mint(uint id) public {
        nft.mint(address(this), id);
    }
}

contract SimpleNFTTest is DSTest {
    SimpleNFT nft;
    NFTUser usr;
    function setUp() public {
        nft = new SimpleNFT();
        usr = new NFTUser(nft);
    }
    function testMintNFT() public {
        usr.mint(1);

        assertEq(nft.ownerOf(1), address(usr));
    }
}
