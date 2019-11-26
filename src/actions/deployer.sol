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

import { Title } from "../title.sol";
import { Proxy, ProxyFactory } from "./proxy.sol";
import { ProxyRegistry } from "./registry.sol";

contract FactoryFab {
    function newProxyFactory(address title) public returns (ProxyFactory factory) {
        factory = new ProxyFactory(title);
    }
}

contract RegistryFab {
    function newProxyRegistry(address factory) public returns (ProxyRegistry registry) {
        registry = new ProxyRegistry(factory);
    }
}

contract TitleFab {
    function newTitle(string memory name, string memory symbol) public returns (Title title) {
        title = new Title(name, symbol);
        title.rely(msg.sender);
        title.deny(address(this));
    }
}

contract Deployer {
    TitleFab titlefab;
    FactoryFab factoryfab;
    RegistryFab registryfab;

    address     public god;

    Title           public title;
    ProxyFactory    public factory;
    ProxyRegistry   public registry;

    constructor (address god_, TitleFab titlefab_, FactoryFab factoryfab_, RegistryFab registryfab_) public {
        address self = msg.sender;
        god = god_;

        titlefab = titlefab_;
        factoryfab = factoryfab_;
        registryfab = registryfab_;
    }

    function deployTitle(string memory name, string memory symbol) public {
        title = titlefab.newTitle(name, symbol);
        title.rely(god);
    }

    function deployProxyStation(Title title_) public {
        factory = factoryfab.newProxyFactory(address(title_));
        title_.rely(address(factory));
        registry = registryfab.newProxyRegistry(address(factory));
    }

    function deployProxy(ProxyRegistry registry_) public returns (address payable proxy) {
       return registry.build();
    }
}