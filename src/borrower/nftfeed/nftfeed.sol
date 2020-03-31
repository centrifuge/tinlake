// principal.sol
// Copyright (C) 2020 Centrifuge

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

pragma solidity >=0.5.3;

import "ds-note/note.sol";
import "tinlake-auth/auth.sol";
import "tinlake-math/math.sol";

contract ShelfLike {
    function shelf(uint loan) public view returns (address registry, uint tokenId);
}

contract PileLike {
    function setRate(uint loan, uint rate) public;
    function debt(uint loan) public returns (uint);
}

contract NFTFeed is DSNote, Auth, Math {
    // nftID => nftValues
    mapping (bytes32 => uint) public nftValues;

    // nftID => risk
    mapping (bytes32 => uint) public risk;

    // risk => thresholdRatio
    mapping (uint => uint) public thresholdRatio;
    // risk => ceilingRatio
    mapping (uint => uint) public ceilingRatio;
    // risk => rate
    mapping (uint => uint) public rate;

    PileLike pile;
    ShelfLike shelf;

    /// defines default values for risk group 0
    /// all values are denominated in RAY (10^27)
    constructor (uint defaultThresholdRatio, uint defaultCeilingRatio, uint defaultRate) public {
        thresholdRatio[0] = defaultThresholdRatio;
        ceilingRatio[0] = defaultCeilingRatio;
        rate[0] = defaultRate;
    }


    /// sets the dependency to another contract
    function depend(bytes32 contractName, address addr) external auth {
        if (contractName == "pile") {pile = PileLike(addr);}
        else if (contractName == "shelf") { shelf = ShelfLike(addr); }
        else revert();
    }

    function nftID(address registry, uint tokenId) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(registry, tokenId));
    }

    function nftID(uint loan) public view returns (bytes32) {
        (address registry, uint tokenId) = shelf.shelf(loan);
        return nftID(registry, tokenId);
    }

    /// Admin -- Updates
    function setRiskGroup(uint risk_, uint thresholdRatio_, uint ceilingRatio_, uint rate_) public auth {
        thresholdRatio[risk_] = thresholdRatio_;
        ceilingRatio[risk_] = ceilingRatio_;
        rate[risk_]= rate_;
    }

    function file(bytes32 what, uint risk_, uint value_) public auth {
        if (what == "threshold") { thresholdRatio[risk_]  = value_; }
        else if (what == "ceiling") { ceilingRatio[risk_] = value_; }
        else if (what == "rate") { rate[risk_]= value_;}
        else revert("unknown parameter");
    }

    ///  -- Oracle Updates --

    /// update the nft value
    function update(bytes32 nftID_,  uint value) public auth {
        nftValues[nftID_] = value;
    }

    /// update the nft value and change the risk group
    function update(bytes32 nftID_, uint value, uint risk_) public auth {
        require(thresholdRatio[risk_] != 0, "threshold for risk group not defined");
        require(ceilingRatio[risk_] != 0, "ceiling for risk group not defined");
        require(rate[risk_] != 0, "rate for risk group not defined");

        risk[nftID_] = risk_;
        nftValues[nftID_] = value;
    }

    // sets the loan rate in pile
    // not possible for ongoing loans
    function setPileRate(uint loan) external auth {
        pile.setRate(loan, loanRate(loan));
    }

    ///  -- Getter methods --
    function ceiling(uint loan) public view returns (uint) {
        bytes32 nftID_ = nftID(loan);
        return rmul(nftValues[nftID_], ceilingRatio[risk[nftID_]]);
    }

    function threshold(uint loan) public view returns (uint) {
        bytes32 nftID_ = nftID(loan);
        return rmul(nftValues[nftID_], thresholdRatio[risk[nftID_]]);
    }

    function loanRate(uint loan) public view returns (uint) {
        return rate[risk[nftID(loan)]];
    }
}

