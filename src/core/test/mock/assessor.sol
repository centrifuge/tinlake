pragma solidity >=0.4.24;

contract AssessorMock {

    uint public assetReturn; function setAssetReturn(uint assetAmount_) public {assetReturn=assetAmount_;}
    
    uint public wad;
    address public tranche;

    function getAssetValueFor(address tranche_) public returns (uint) {
        tranche = tranche_;
        return assetReturn;
    }
}