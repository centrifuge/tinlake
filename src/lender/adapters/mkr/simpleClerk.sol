// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

interface ManagerLike {
    function join(uint amountDROP) external;
    function draw(uint amountDAI) external;
    function wipe(uint amountDAI) external;
    function exit(uint amountDROP) external;
}

interface AssessorLike {
    function calcSeniorTokenPrice() external view returns(uint);
}

interface ERC20Like {
    function balanceOf(address) external view returns (uint);
    function transferFrom(address, address, uint) external returns (bool);
    function approve(address usr, uint amount) external;
    function transfer(address, uint) external returns (bool);
}

contract SimpleClerk {

  // --- Auth ---
  mapping (address => uint256) public wards;

  function rely(address usr) external auth {
      wards[usr] = 1;
      emit Rely(usr);
  }
  function deny(address usr) external auth {
      wards[usr] = 0;
      emit Deny(usr);
  }
  modifier auth {
      require(wards[msg.sender] == 1, "SimpleClerk/not-authorized");
      _;
  }

  mapping (address => uint256) public investors;

  function relyInvestor(address usr) external auth {
      investors[usr] = 1;
      emit RelyInvestor(usr);
  }
  function denyInvestor(address usr) external auth {
      investors[usr] = 0;
      emit DenyInvestor(usr);
  }
  modifier onlyInvestor {
      require(investors[msg.sender] == 1, "SimpleClerk/not-an-investor");
      _;
  }

  // Events
  event Rely(address indexed usr);
  event Deny(address indexed usr);
  event RelyInvestor(address indexed usr);
  event DenyInvestor(address indexed usr);

  // --- Contracts ---
  ManagerLike public immutable mgr;
  AssessorLike public immutable assessor;

  ERC20Like public immutable collateral;
  ERC20Like public immutable dai;

  address public immutable vow;

  constructor(address mgr_, address assessor_, address collateral_, address dai_, address vow_) {
    mgr = ManagerLike(mgr_);
    assessor = AssessorLike(assessor_);
    collateral =  ERC20Like(collateral_);
    dai = ERC20Like(dai_);
    vow = vow_;
    wards[msg.sender] = 1;
    emit Rely(msg.sender);
  }

  // --- Math ---
  uint256 constant RAY = 10 ** 27;
  function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
      require((z = x + y) >= x);
  }
  function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
      require((z = x - y) <= x);
  }
  function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
      require(y == 0 || (z = x * y) / y == x);
  }
  function divup(uint256 x, uint256 y) internal pure returns (uint256 z) {
      z = add(x, sub(y, 1)) / y;
  }
  function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
      z = x > y ? y : x;
  }

  // --- Investor Actions ---
  function borrow(uint256 amountDROP) public onlyInvestor {
    collateral.transferFrom(msg.sender, address(this), amountDROP);
    mgr.join(amountDROP);

    uint amountDAI = mul(amountDROP, assessor.calcSeniorTokenPrice());
    mgr.draw(amountDAI);
    dai.approve(address(msg.sender), amountDAI);
    dai.transfer(address(msg.sender), amountDAI);
  }

  function repay(uint256 amountDAI) public onlyInvestor {
    dai.transferFrom(msg.sender, address(this), amountDAI);
    dai.approve(address(mgr), amountDAI);
    mgr.wipe(amountDAI);

    uint amountDROP = divup(mul(amountDAI, RAY), assessor.calcSeniorTokenPrice());
    mgr.exit(amountDROP);
    
    collateral.approve(address(msg.sender), amountDROP);
    collateral.transfer(address(msg.sender), amountDROP);
  }

  // --- Liquidation ---
  // For Maker to redeem:
  // - Set `ilk.toc` to 0
  // - Call `mgr.tell()`
  // - Close and execute the epoch
  // - Call `mgr.unwind(endEpoch)` to disburse DAI
  // - Call `clerk.unwind()` to send DAI to vow
  function unwind() public {
    dai.transfer(vow, dai.balanceOf(address(this)));
  }

}