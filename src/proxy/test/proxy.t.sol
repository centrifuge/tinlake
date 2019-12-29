pragma solidity >=0.4.24;

import "ds-test/test.sol";

import "../proxy.sol";
import "tinlake-title/title.sol";


contract SimpleCore {
    address public caller;

    function add(uint256 a, uint256 b) public returns (uint256) {
        caller = msg.sender;
        return a+b;
    }
}

contract SimpleAction {
    SimpleCore core;
    constructor(address core_) public {
        core = SimpleCore(core_);
    }

    function inlineAdd(uint256 a, uint256 b) public returns (uint256) {
        return a+b;
    }

    function doAdd(address core_, uint256 a, uint256 b) public returns (uint256) {
        return SimpleCore(core_).add(a,b);
    }

    function doAdd(uint256 a, uint256 b) public returns (uint256) {
        return core.add(a,b);
    }

    function coreAddr() public returns(address) {
        return address(core);
    }
}

contract ProxyTest is DSTest {
    Title title;
    ProxyFactory factory;
    SimpleCore core;
    SimpleAction action;

    bytes testCode = hex"608060405234801561001057600080fd5b506103da806100206000396000f30060806040526004361061006d576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680631f903037146100725780635f7a3d16146100a55780638583cc0b14610127578063a9cc471814610161578063aa4025cc14610178575b600080fd5b34801561007e57600080fd5b50610087610208565b60405180826000191660001916815260200191505060405180910390f35b3480156100b157600080fd5b506100d060048036038101908080359060200190929190505050610230565b6040518080602001828103825283818151815260200191508051906020019060200280838360005b838110156101135780820151818401526020810190506100f8565b505050509050019250505060405180910390f35b34801561013357600080fd5b5061013c6102b0565b6040518083600019166000191681526020018281526020019250505060405180910390f35b34801561016d57600080fd5b506101766102e1565b005b34801561018457600080fd5b5061018d610359565b6040518080602001828103825283818151815260200191508051906020019080838360005b838110156101cd5780820151818401526020810190506101b2565b50505050905090810190601f1680156101fa5780820380516001836020036101000a031916815260200191505b509250505060405180910390f35b60007f48656c6c6f000000000000000000000000000000000000000000000000000000905090565b60606000826040519080825280602002602001820160405280156102635781602001602082028038833980820191505090505b509150600090505b828110156102aa5780600102828281518110151561028557fe5b906020019060200201906000191690816000191681525050808060010191505061026b565b50919050565b6000807f42796500000000000000000000000000000000000000000000000000000000006096809050915091509091565b60001515610357576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040180806020018281038252600e8152602001807f4661696c2074657374206361736500000000000000000000000000000000000081525060200191505060405180910390fd5b565b606060405190507f414141414141414141414141414141414141414141414141414141414141414181527f41414141414141414141414141414141000000000000000000000000000000006020820152603081f300a165627a7a72305820e929b77ffa3b36f7f7ea1d39bee3c7fa4a921b5bf4d14e9db75e23b8d209fb8c0029";

    function setUp() public {
        title = new Title("Tinlake", "TLO");
        factory = new ProxyFactory(address(title));
        title.rely(address(factory));

        core = new SimpleCore();

        // setup proxy lib
        action = new SimpleAction(address(core));
    }

    function testBuildProxy() public {
        address payable first = factory.build();
        Proxy proxy = Proxy(first);
        assertEq(proxy.accessToken(), 0);

        address payable second = factory.build();
        assertTrue(first != second);
        proxy = Proxy(second);
        assertEq(proxy.accessToken(), 1);
    }

    function testExecute() public {
        address payable proxyAddr = factory.build();
        Proxy proxy = Proxy(proxyAddr);

        bytes memory data = abi.encodeWithSignature("inlineAdd(uint256,uint256)", 5,7);

        // action not calling other method
        bytes memory response = proxy.execute(address(action), data);

        // using core
        data = abi.encodeWithSignature("doAdd(address,uint256,uint256)", address(core), 5,7);
        response = proxy.execute(address(action), data);

        // msg.sender should be proxy address
        assertEq(core.caller(), proxyAddr);

    }

    function testFailExecuteAccessActionStorage() public {
        address payable proxyAddr = factory.build();
        Proxy proxy = Proxy(proxyAddr);

        // using action contract storage should fail
        bytes memory data = abi.encodeWithSignature("doAdd(uint256,uint256)", address(core), 5,7);
        bytes memory response = proxy.execute(address(action), data);
    }

    function testFailExecuteNotNFTOwner() public {
        address payable proxyAddr = factory.build();
        Proxy proxy = Proxy(proxyAddr);

        uint accessToken = proxy.accessToken();
        title.transferFrom(msg.sender,address(123), accessToken);

        // using core
        bytes memory data = abi.encodeWithSignature("doAdd(address,uint256,uint256)", address(core), 5,7);

        // should fail because doesn't own accessToken anymore
        bytes memory  response = proxy.execute(address(action), data);
    }

    function testExecuteCode() public {
        address payable proxyAddr = factory.build();
        Proxy proxy = Proxy(proxyAddr);

        bytes memory data = abi.encodeWithSignature("getBytes32AndUint()");

        //deploy and call the contracts code
        (, bytes memory response) = proxy.execute(testCode, data);

        bytes32 response32;
        uint responseUint;

        assembly {
            response32 := mload(add(response, 0x20))
            responseUint := mload(add(response, 0x40))
        }

        //verify we got correct response
        assertEq32(response32, bytes32("Bye"));
        assertEq(responseUint, uint(150));
    }
}
