pragma solidity >=0.4.23;

import "ds-test/test.sol";

import "../desk.sol";
import "./mock/pile.sol";
import "./mock/lender.sol";
import "./mock/token.sol";

contract DeskTest is DSTest {

    Desk desk;
    // --- Data ---

    PileMock pile;
    LenderMock lender;
  //  ValveMock valve;
    TokenMock collateral;
  //  LightswitchMock lightswitch;


    function setUp() public {

    }

    function testSetupPrecondition() public {

    }
}
