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

        desk = new Desk(address(pile), address(valve), address(collateral), address(lightswitch));
        desk.depend("lender", address(lender));
    }


    function provideCollateral(int wadT, int wadC) public {
        pile.setWantReturn(wadT);
        valve.setWantReturn(wadC);

        desk.balance();

        assertEq(valve.mintMaxCalls(),1);
        assertEq(valve.usr(),address(desk));

        assertEq(lender.provideCalls(), 1);
        assertEq(lender.usrC(),address(desk));
        assertEq(lender.usrT(),address(pile));
        assertEq(lender.wadT(),uint(wadT));
        assertEq(lender.wadC(),uint(wadC));

    }
    
    function releaseCollateral(int wadT, int wadC) public {
        pile.setWantReturn(wadT);
        valve.setWantReturn(wadC);

        desk.balance();

        assertEq(valve.burnMaxCalls(),1);
        assertEq(valve.usr(),address(desk));

        assertEq(valve.tkn().approveCalls(), 1);
        assertEq(valve.tkn().usr(), address(valve));
        assertEq(valve.tkn().wad(), uint(-1));

        assertEq(lender.releaseCalls(), 1);
        assertEq(lender.usrC(),address(desk));
        assertEq(lender.usrT(),address(pile));
        assertEq(lender.wadT(),uint(wadT*-1));
        assertEq(lender.wadC(),uint(wadC*-1));
    }
    
    // tests
    function testProvideCollateral() public {
        int wadT = 80;
        int wadC = 100;

        provideCollateral(wadT, wadC);
    }

    function testReleaseCollateral() public {
        int wadT = -80;
        int wadC = -100;

        releaseCollateral(wadT, wadC);
    }

    function testReleaseZero() public {
        releaseCollateral(0, 0);
    }

    function testFailNegativeCollateral() public {
        int wadT = 80;
        int wadC = -100;
        pile.setWantReturn(wadT);
        valve.setWantReturn(wadC);

        desk.balance();
    }

    function testFailNegativeTkn() public {
        int wadT = -80;
        int wadC = 100;
        pile.setWantReturn(wadT);
        valve.setWantReturn(wadC);

        desk.balance();
    }
}
