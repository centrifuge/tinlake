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

    function testProvideCollateral() public {
        int wantTkn = 80;
        int wantCollatoral = 100;
        pile.setWantReturn(wantTkn);
        valve.setWantReturn(wantCollatoral);

        desk.balance();

        assertEq(valve.mintMaxCalls(),1);
        assertEq(valve.usr(),address(desk));

        assertEq(lender.provideCalls(), 1);
        assertEq(lender.usrC(),address(desk));
        assertEq(lender.usrT(),address(pile));
        assertEq(lender.wadT(),uint(wantTkn));
        assertEq(lender.wadC(),uint(wantCollatoral));
    }

    function testReleaseCollateral() public {
        int wantTkn = -80;
        int wantCollatoral = -100;
        pile.setWantReturn(wantTkn);
        valve.setWantReturn(wantCollatoral);

        desk.balance();

        assertEq(valve.burnMaxCalls(),1);
        assertEq(valve.usr(),address(desk));

        assertEq(valve.tkn().approveCalls(), 1);
        assertEq(valve.tkn().usr(), address(valve));
        assertEq(valve.tkn().wad(), uint(-1));

        assertEq(lender.releaseCalls(), 1);
        assertEq(lender.usrC(),address(desk));
        assertEq(lender.usrT(),address(pile));
        assertEq(lender.wadT(),uint(wantTkn*-1));
        assertEq(lender.wadC(),uint(wantCollatoral*-1));
    }
}
