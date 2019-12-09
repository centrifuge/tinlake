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

pragma solidity >=0.4.23;

import { Proxy } from "../proxy/proxy.sol";
import "../../lib/dss-add-ilk-spell/lib/dss-deploy/lib/esm/lib/ds-token/lib/ds-test/src/test.sol";

contract User {
    function approve(address payable proxy_, address actions_, address nft_, address approvee_, uint tokenId) public returns (bytes memory) {
        bytes memory data = abi.encodeWithSignature("approve(address,address,uint256)", nft_, approvee_, tokenId);
        return Proxy(proxy_).execute(actions_, data);
    }
    function borrow(address payable proxy_, address actions_, address desk_, address pile_, address shelf_, uint loan, address deposit_) public returns (bytes memory) {
        bytes memory data = abi.encodeWithSignature("borrow(address,address,address,uint256,address)", desk_, pile_, shelf_, loan, deposit_);
        return Proxy(proxy_).execute(actions_, data);
    }

    function close(address payable proxy_, address actions_, address desk_, address pile_, address shelf_, uint loan, address usr_) public returns (bytes memory){
        bytes memory data = abi.encodeWithSignature("close(address,address,address,uint256,address)", desk_, pile_, shelf_, loan, usr_);
        return Proxy(proxy_).execute(actions_, data);
    }

    function approveERC20(address payable proxy_, address actions_, address tkn_, address pile_, uint wad) public returns (bytes memory) {
        bytes memory data = abi.encodeWithSignature("approveERC20(address,address,uint256)", tkn_, pile_, wad);
        return Proxy(proxy_).execute(actions_, data);
    }
}
