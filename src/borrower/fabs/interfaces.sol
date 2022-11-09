// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

interface NAVFeedFabLike {
    function newFeed() external returns (address);
}

interface TitleFabLike {
    function newTitle(string calldata, string calldata) external returns (address);
}

interface PileFabLike {
    function newPile() external returns (address);
}

interface ShelfFabLike {
    function newShelf(address, address, address, address) external returns (address);
}
