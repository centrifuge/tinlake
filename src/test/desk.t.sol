pragma solidity >=0.4.23;

import "ds-test/test.sol";

import "../desk.sol";
import "./mock/pile.sol";
import "./mock/lender.sol";
import "./mock/token.sol";
import "./mock/valve.sol";
import "./mock/lightswitch.sol";

contract DeskTest is DSTest {
    Desk desk;

    PileMock pile;
    LenderMock lender;
    ValveMock valve;
    TokenMock collateral;
    LightSwitchMock lightswitch;

    address self;

    function setUp() public {

        self = address(this);

        pile = new PileMock();
        lender = new LenderMock();
        valve = new ValveMock();
        collateral = new TokenMock();
        lightswitch = new LightSwitchMock();

        desk = new Desk(address(pile), address(lender), address(valve), address(collateral), address(lightswitch));

    }

    function testSetupPrecondition() public {

    }
}
