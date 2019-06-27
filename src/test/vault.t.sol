pragma solidity >=0.4.23;

import "ds-test/test.sol";

import "../vault.sol";
import "./mock/pile.sol";
import "./mock/token.sol";

import "./mock/lightswitch.sol";

contract VaultTest is DSTest {
    Vault vault;

    PileMock pile;
    TokenMock tkn;
    LightSwitchMock lightswitch;

    address self;

    function setUp() public {
        self = address(this);

        pile = new PileMock();
        tkn = new TokenMock();
        lightswitch = new LightSwitchMock();

        vault = new Vault(address(pile), address(tkn), address(lightswitch));
    }

    function testWantCurrency() public {
        int wad = 80;
        pile.setWantReturn(wad);
        tkn.setBalanceOfReturn(100);
        vault.balance();
        assertEq(tkn.transferFromCalls(), 1);
        assertEq(tkn.dst(), address(vault));
        assertEq(tkn.src(), address(pile));
        assertEq(tkn.wad(), uint(wad));
    }

    function testFailWantCurrency() public {
        int wad = 800;
        pile.setWantReturn(wad);
        // not enough currency in fault
        tkn.setBalanceOfReturn(80);
        vault.balance();
    }

    function testTakeCurrency() public {
        int wad = -80;
        pile.setWantReturn(wad);
        tkn.setBalanceOfReturn(80);
        vault.balance();
        assertEq(tkn.transferFromCalls(), 1);
        assertEq(tkn.dst(), address(pile));
        assertEq(tkn.src(), address(vault));
        assertEq(tkn.wad(), uint(wad*-1));
    }


    function testFailTakeCurrency() public {
        int wad = -800;
        pile.setWantReturn(wad);
        // not enough currency in pile
        tkn.setBalanceOfReturn(80);
        vault.balance();
    }


    function testWithdraw() public {
        uint wad = 100;
        tkn.setBalanceOfReturn(wad);
        vault.withdraw(self, 80);
        assertEq(tkn.transferFromCalls(), 1);
        assertEq(tkn.dst(), address(vault));
        assertEq(tkn.src(), address(self));
        assertEq(tkn.wad(), 80);
    }

    function testFailWithdraw() public {
        uint wad = 100;
        tkn.setBalanceOfReturn(wad);
        vault.withdraw(self, 800);
    }
}