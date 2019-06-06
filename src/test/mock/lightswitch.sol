pragma solidity >=0.4.24;

contract LightSwitchMock {
    uint public setCounter;
    uint public on;

    // --- LightSwitch ---
    function set(uint on_) public  {
        on = on_;
        setCounter++;
    }

}
