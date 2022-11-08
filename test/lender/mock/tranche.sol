// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "../../../test/mock/mock.sol";
import "tinlake-auth/auth.sol";

contract TrancheMock is Mock, Auth {
    uint256 epochTotalSupply;
    uint256 epochTotalRedeem;

    SimpleTokenLike public token;

    constructor() {
        wards[msg.sender] = 1;
    }

    function depend(bytes32 contractName, address addr) public auth {
        if (contractName == "token") token = SimpleTokenLike(addr);
        else revert();
    }

    function setEpochReturn(uint256 totalSupply_, uint256 totalRedeem_) public {
        epochTotalSupply = totalSupply_;
        epochTotalRedeem = totalRedeem_;
    }

    function closeEpoch() public view returns (uint256, uint256) {
        return (epochTotalSupply, epochTotalRedeem);
    }

    function epochUpdate(
        uint256 epochID,
        uint256 supplyFulfillment_,
        uint256 redeemFulfillment_,
        uint256 tokenPrice_,
        uint256 epochSupplyCurrency,
        uint256 epochRedeemCurrency
    ) external {
        values_uint["epochUpdate_epochID"] = epochID;
        values_uint["epochUpdate_supplyFulfillment"] = supplyFulfillment_;
        values_uint["epochUpdate_redeemFulfillment"] = redeemFulfillment_;
        values_uint["epochUpdate_tokenPrice"] = tokenPrice_;
        values_uint["epochUpdate_epochSupply"] = epochSupplyCurrency;
        values_uint["epochUpdate_epochRedeem"] = epochRedeemCurrency;
    }

    function supplyOrder(address usr, uint256 newSupplyAmount) public auth {
        calls["supplyOrder"]++;
        values_address["supply_usr"] = usr;
        values_uint["supplyAmount"] = newSupplyAmount;
    }

    function redeemOrder(address usr, uint256 newRedeemAmount) public auth {
        calls["redeemOrder"]++;
        values_address["redeem_usr"] = usr;
        values_uint["redeemAmount"] = newRedeemAmount;
    }

    function disburse(address usr) public auth returns (uint256, uint256, uint256, uint256) {
        call("disburse");
        values_address["disburse_usr"] = usr;
        return (0, 0, 0, 0);
    }

    function disburse(address usr, uint256 endEpoch) public auth returns (uint256, uint256, uint256, uint256) {
        call("disburse");
        values_address["disburse_usr"] = usr;
        values_uint["disburse_endEpoch"] = endEpoch;
        return (0, 0, 0, 0);
    }

    function tokenSupply() external view returns (uint256) {
        return values_return["tokenSupply"];
    }

    function mint(address usr, uint256 amount) public auth {
        token.mint(usr, amount);
    }

    function payoutRequestedCurrency() public view returns (uint256) {
        return values_return["payoutRequestedCurrency"];
    }
}
