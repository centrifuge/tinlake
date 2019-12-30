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

import { Title } from "tinlake-title/title.sol";
import { Proxy, ProxyFactory } from "./proxy.sol";
import { ProxyRegistry } from "./registry.sol";

contract FactoryFab {
    function newProxyFactory(address title_) public returns (ProxyFactory factory) {
        factory = new ProxyFactory(title_);
    }
}

contract RegistryFab {
    function newProxyRegistry(address factory_) public returns (ProxyRegistry registry) {
        registry = new ProxyRegistry(factory_);
    }
}

contract AccessRegistryFab {
    function newAccessNFTRegistry(string memory name, string memory symbol) public returns (Title accessRegistry) {
        accessRegistry = new Title(name, symbol);
        accessRegistry.rely(msg.sender);
        accessRegistry.deny(address(this));
    }
}

contract ProxyDeployer {
    FactoryFab factoryfab;
    RegistryFab registryfab;

    address     public god;

    Title           public title;
    ProxyFactory    public factory;
    ProxyRegistry   public registry;

    constructor (address god_, FactoryFab factoryfab_, RegistryFab registryfab_) public {
        address self = msg.sender;
        god = god_;

        factoryfab = factoryfab_;
        registryfab = registryfab_;
    }

    function deployProxyRegistry(address title_) public returns (address registry){
        require(Title(title_).wards(address(this)) == 1);
        factory = factoryfab.newProxyFactory(title_);
        Title(title_).rely(address(factory));
        return address(registryfab.newProxyRegistry(address(factory)));
    }

    function deployProxy(address registry_, address user_) public returns (address payable proxy) {
       return ProxyRegistry(registry_).build(user_);
    }
}
