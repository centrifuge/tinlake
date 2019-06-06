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
pragma experimental ABIEncoderV2;

import "ds-note/note.sol";

contract TokenLike {
    uint public totalSupply;
    function balanceOf(address) public view returns (uint);
    function transferFrom(address,address,uint) public;
}

contract VatLike {
    struct Urn {
        uint256 ink;
        uint256 art;
    }
    function urns(bytes32,address) public returns (Urn memory);
}

contract ProxyLike {
    function open(address, bytes32) public returns (uint);
    function wipeAndFreeGem(address, address, address, uint, uint, uint) public;
    function lockGemAndDraw(address, address, address, uint, uint, uint) public;
    function freeGem(address, address, uint, uint) public;
}

contract LightSwitchLike {
    function set(uint) public;
}

contract MCDDeployLike {
    function daiJoin() public returns (address);
    function vat() public returns (address);
}

contract MakerLenderFab {
    MCDDeployLike mcddeploy;
    MakerAdapter public maker;
    address proxy;
    address manager;
        
    constructor (address deploy_, address proxy_, address manager_) public {
        mcddeploy = MCDDeployLike(deploy_);
        proxy = proxy_;
        manager = manager_;
    }

    function lender() public returns (address) {
        return address(maker);
    }

    function deploy(address tkn_, address collateral_, address light_) public returns (address) {
        maker = new MakerAdapter(tkn_, collateral_, proxy, manager, mcddeploy.daiJoin(), mcddeploy.vat(), light_);
        maker.rely(msg.sender);
        return address(maker);
    }

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
    LightSwitchLike     public lightswitch;

    ProxyLike           public proxy;
    VatLike             public vat;
    address             public manager;
    address             public daiJoin;
    address             public gemJoin;

    uint                public cdp;
    bytes32             public ilk;
    address             public pile;
    uint                public gem;

    constructor(address tkn_, address collateral_, address proxy_, address manager_, address daiJoin_, address vat_, address lightswitch_) public {
        wards[msg.sender] = 1;
        tkn = TokenLike(tkn_); 
        collateral = TokenLike(collateral_);
        lightswitch = LightSwitchLike(lightswitch_);
        // Maker specific stuff
        proxy = ProxyLike(proxy_);
        vat = VatLike(vat_);
        manager = manager_;
        daiJoin = daiJoin_;
    } 

    function file(bytes32 what, address data) public note auth {
         if (what == "gemJoin") { gemJoin = data; }
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

    // --- Maker CDP Interaction ---
    // poke shuts off any lending if the CDP has been bitten. 
    function poke() public note {
        require(vat.urns(ilk, address(this)).ink >= gem, "cdp-not-bitten"); 
        lightswitch.set(0); 
    }


    // Below methods are a bit repetitive with the above but split out to make sure we can later on abstract the Maker interaction away.
    function open() public auth {
        require(cdp == 0, "already-open"); 
        cdp = proxy.open(manager, ilk); 
    }

    function lock(address usrC, address usrT, uint wadC, uint wadT) public auth { collateral.transferFrom(usrC, address(this), wadC);
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
