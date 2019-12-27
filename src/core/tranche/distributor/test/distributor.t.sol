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

//import "ds-test/test.sol";

import "../../../test/mock/operator.sol";
import "../distributor.sol";
import "../line.sol";
import "../fixed.sol";
import "../flow.sol";
import "../../../test/mock/pile.sol";
import "../../../test/mock/desk.sol";
import "../../../../../lib/dss-add-ilk-spell/lib/dss-deploy/lib/esm/lib/ds-token/lib/ds-test/src/test.sol";

contract DistributorTest is DSTest{

    OperatorMock o1;
    OperatorMock o2;
    PileMock pile;
    DeskMock manager;
    Flowable flowable;
    Flow flow;
    Distributor distributor;
    LOC l;
    FixedCredit f;

    function setUp() public {
        o1 = new OperatorMock();
        o2 = new OperatorMock();
        pile = new PileMock();
        manager = new DeskMock();
        distributor = new Distributor(address(manager));
        flow = new Flow();
        flowable = new Flowable(address(flow));
        l = new LOC(address(distributor), address(flowable));
        f = new FixedCredit(address(distributor), address(flowable));

        addTranches();
    }

    function addTranches() public {
        manager.addTranche(30, address(o1));
        manager.addTranche(70, address(o2));
    }

    function testFixedBalance() public {
        flow.file("distribution", 1);
        manager.setPoolClosing(false);
//        f.balance();
    }

    function testFailFixedBalance() public {

    }

    function testLOCBalance() public {

    }

    function testFailLOCBalance() public {

    }

    function testRepayTranches() public {

    }

    function testFailRepayTranches() public {

    }

}
