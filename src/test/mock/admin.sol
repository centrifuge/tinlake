pragma solidity >=0.4.24;
pragma experimental ABIEncoderV2;

contract AdminMock {

    //calls
    uint public callsWhitelist;

    //Auth
    mapping (address => uint) public wards;
    function rely(address usr) public auth { wards[usr] = 1; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    // returns
    uint public whitelistReturn; function setWhitelistReturn(uint whitelistReturn_) public {whitelistReturn = whitelistReturn_;}

    address public registry;
    uint public nft;
    uint public principal;
    uint public appraisal;
    uint public fee;
    address public usr;

     constructor () public {
        wards[msg.sender] = 1;
    }

    function whitelist(address registry_, uint nft_, uint principal_, uint appraisal_, uint fee_, address usr_) public auth returns(uint){
        callsWhitelist++;
        registry = registry_;
        nft = nft_;
        principal = principal_;
        appraisal = appraisal_;
        fee = fee_;
        usr = usr_;
        return whitelistReturn;
    }

}
