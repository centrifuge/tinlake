// Copyright (C) 2019 lucasvo

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity >=0.4.24;

import "ds-note/note.sol";

contract TokenLike {
    uint public totalSupply;
    function balanceOf(address) public view returns (uint);
    function transferFrom(address,address,uint) public;
}

contract ProxyLike {
    function open(address, bytes32) public returns (uint);
    function wipeAndFreeGem(address, address, address, uint, uint, uint) public;
    function lockGemAndDraw(address, address, address, uint, uint, uint) public;
    function freeGem(address, address, uint, uint) public;
}

// MakerAdapter
// Operates a CDP and pushes collateral value tokens into it and draws dai or vice versa. It tries to borrow
// enough Dai to make the Dai balance of the pile reflect pile.totalBalance (which is the total Dai people 
// could want to draw)
// It makes use of https://github.com/makerdao/dss-proxy-actions/blob/master/src/DssProxyActions.sol and
// https://github.com/makerdao/dss-cdp-manager/blob/master/src/DssCdpManager.sol to interact with the CDP.
contract MakerAdapter is DSNote {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) public auth note { wards[usr] = 1; }
    function deny(address usr) public auth note { wards[usr] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    // --- Data ---
    TokenLike           public tkn;
    TokenLike           public collateral;
    
    ProxyLike           public proxy;
    address             public manager;
    address             public daiJoin;
    address             public gemJoin;

    uint                public cdp;
    bytes32             public ilk;
   
    uint                public gem;

    constructor(address tkn_, address collateral_, address proxy_, address manager_, address gemJoin_, address daiJoin_) public {
        wards[msg.sender] = 1;
        tkn = TokenLike(tkn_); 
        collateral = TokenLike(collateral_);
        
        // Maker specific stuff
        proxy = ProxyLike(proxy_); 
        manager = manager_;
        gemJoin = gemJoin_;
        daiJoin = daiJoin_;
    } 

    // --- Math ---
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x);
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x);
    }

    // --- Lender Methods ---
    function provide(address usrC, address usrT, uint wadC, uint wadT) public auth { 
        lock(usrC, usrT, wadC, wadT);
    }

    function release(address usrC, address usrT, uint wadC, uint wadT) public auth {
        wipe(usrC, usrT, wadC, wadT);
    }

    function free(address usr, uint wad) public auth { 
        freeGem(usr, wad);
    }

    function poke() public note {
        // sub(gem, vat) 
    }
    

    // --- Maker CDP Interaction ---
    // Below methods are a bit repetitive with the above but split out to make sure we can later on abstract the Maker interaction away.
    function open() public auth {
        require(cdp == 0, "already-open"); 
        cdp = proxy.open(manager, ilk); 
    }

    function lock(address usrC, address usrT, uint wadC, uint wadT) public auth {
        collateral.transferFrom(usrC, address(this), wadC);
        proxy.lockGemAndDraw(manager, gemJoin, daiJoin, cdp, wadC, wadT);
        gem = add(gem, wadC);
        tkn.transferFrom(address(this), usrT, wadT);
    }

    function wipe(address usrC, address usrT, uint wadC, uint wadT) public auth {
        tkn.transferFrom(usrC, address(this), wadT);
        proxy.wipeAndFreeGem(manager, gemJoin, daiJoin, cdp, wadT, wadC);
        gem = sub(gem, wadC);
        collateral.transferFrom(address(this), usrT, wadC);
    }

    function freeGem(address usr, uint wad) public auth {
        proxy.freeGem(manager, gemJoin, cdp, wad);
        gem = sub(gem, wad);
        tkn.transferFrom(address(this), usr, wad);
    }
}
