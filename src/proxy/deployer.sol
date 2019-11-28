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

import { Title } from "../core/title.sol";
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

    function deployProxyStation(address title_) public {
        factory = factoryfab.newProxyFactory(title_);
        Title title = Title(title_);
        title.rely(address(factory));
        registry = registryfab.newProxyRegistry(address(factory));
    }

    function deployProxy(address registry_) public {
       ProxyRegistry registry = ProxyRegistry(registry_);
       registry.build();
    }
}