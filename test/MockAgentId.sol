// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Test double for the SPACE ID Agent ID NFT: only balanceOf/ownerOf,
///         mirroring the real contract (no enumerable functions).
contract MockAgentId {
    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;

    function mint(address to, uint256 tokenId) external {
        require(_owners[tokenId] == address(0), "already minted");
        _owners[tokenId] = to;
        _balances[to] += 1;
    }

    function balanceOf(address owner) external view returns (uint256) {
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721NonexistentToken");
        return owner;
    }
}
