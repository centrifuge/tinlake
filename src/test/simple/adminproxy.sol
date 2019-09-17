// Copyright (C) 2019 Centrifuge

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

contract AdminLike {
    function whitelist (address registry, uint nft, uint principal, uint appraisal, uint fee, address usr) public returns(uint);
}

// AdminProxy is used as a wrapper for the Admin contract for demo purposes of tinlake. So that any address can whitelist nfts.
contract AdminProxy {
    // --- Data ---
    AdminLike admin;

    constructor (address admin_) public {
        admin = AdminLike(admin_);
    }

    // -- Whitelist --
    function whitelist(address registry, uint nft, uint principal, uint appraisal, uint fee, address usr) public returns(uint) {
        uint loan = admin.whitelist(registry, nft, principal, appraisal, fee, usr);
        return loan;
    }

}