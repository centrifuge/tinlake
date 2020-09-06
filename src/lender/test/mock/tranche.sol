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

pragma solidity >=0.5.15 <0.6.0;

import "ds-test/test.sol";
import "../../../test/mock/mock.sol";
import "tinlake-auth/auth.sol";

contract TrancheMock is Mock, Auth, DSTest {
    uint epochTotalSupply;
    uint epochTotalRedeem;

    constructor() public {
        wards[msg.sender] = 1;
    }

    function setEpochReturn(uint totalSupply_, uint totalRedeem_) public {
        epochTotalSupply = totalSupply_;
        epochTotalRedeem = totalRedeem_;
    }

    function closeEpoch() public view returns(uint, uint) {
        return (epochTotalSupply, epochTotalRedeem);
    }

    function epochUpdate(uint epochID, uint supplyFulfillment_,
        uint redeemFulfillment_, uint tokenPrice_, uint epochSupplyCurrency, uint epochRedeemCurrency) external {
        values_uint["epochUpdate_epochID"] = supplyFulfillment_;
        values_uint["epochUpdate_supplyFulfillment"] = supplyFulfillment_;
        values_uint["epochUpdate_redeemFulfillment"] = redeemFulfillment_;
        values_uint["epochUpdate_epochSupply"] = epochSupplyCurrency;
        values_uint["epochUpdate_epochRedeem"] = epochRedeemCurrency;
    }

    function supplyOrder(address usr, uint newSupplyAmount) public auth {
        calls["supplyOrder"]++;
        values_address["supply_usr"] = usr;
        values_uint["supplyAmount"] = newSupplyAmount;
    }

    function redeemOrder(address usr, uint newRedeemAmount) public auth {
        calls["redeemOrder"]++;
        values_address["redeem_usr"] = usr;
        values_uint["redeemAmount"] = newRedeemAmount;
    }

    function disburse(address usr) public auth returns(uint,uint,uint,uint) {
        call("disburse");
        values_address["disburse_usr"] = usr;
        return(0,0,0,0);
    }

    function disburse(address usr, uint endEpoch) public auth returns(uint, uint, uint, uint) {
        call("disburse");
        values_address["disburse_usr"] = usr;
        values_uint["disburse_endEpoch"] = endEpoch;
        return (0,0,0,0);
    }

    function tokenSupply() external returns(uint) {
        return call("tokenSupply");
    }
}

