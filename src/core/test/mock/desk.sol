pragma solidity >=0.4.24;

contract DeskMock {

    uint public assetReturn; function setAssetReturn(uint assetAmount_) public {assetReturn=assetAmount_;}
    
    // calls
    uint public callsBalance;
    uint public callsReduce;

    uint public wad;
    address public tranche;

    function balance() public {
        callsBalance++;
    }

    function reduce(uint wad_) public  {
        wad = wad_;
        callsReduce++;
    }

    function getTrancheAssets(address tranche_) public returns (uint) {
        tranche = tranche_;
        return assetReturn;
    }
}
