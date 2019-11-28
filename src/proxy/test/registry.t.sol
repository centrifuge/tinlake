pragma solidity >=0.4.24;

import "ds-test/test.sol";
import "../proxy.sol";
import "../registry.sol";

contract RegistryTest is DSTest {
    ProxyRegistry registry;

    Title title;
    ProxyFactory factory;

    function setUp() public {
        title = new Title("Tinlake", "TLO");
        factory = new ProxyFactory(address(title));
        title.rely(address(factory));

        registry = new ProxyRegistry(address(factory));
    }

    function testBuildProxy() public {
        address payable proxyAddr = registry.build();
        Proxy proxy = Proxy(proxyAddr);
        uint accessToken = proxy.accessToken();

        assertEq(address(registry.proxies(accessToken)), proxyAddr);

        // second proxy same msg.sender
        address payable proxyAddr2 = registry.build();
        assertTrue(proxyAddr != proxyAddr2);

        uint accessToken2 = Proxy(proxyAddr2).accessToken();
        assertTrue(accessToken != accessToken2);
    }
}
