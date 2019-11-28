// Copyright (C) 2019 Centrifuge

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity >=0.4.24;

import './proxy.sol';

contract ProxyRegistry {
    mapping(uint => Proxy) public proxies;
    ProxyFactory factory;

    constructor(address factory_) public {
        factory = ProxyFactory(factory_);
    }

    // deploys a new proxy instance
    function build() public returns (address payable proxy) {
        proxy = build(msg.sender);
    }

    // deploys a new proxy instance
    // sets custom owner of proxy by creating an accessToken NFT
    function build(address owner) public returns (address payable proxy) {
        proxy = factory.build(owner);
        uint accessToken = Proxy(proxy).accessToken();
        proxies[accessToken] = Proxy(proxy);
    }
}