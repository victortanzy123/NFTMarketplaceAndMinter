// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { ERC721Core } from "../ERC721/ERC721Core.sol";
import { PMath } from "../Libraries/Math/PMath.sol";

contract SyntheticERC721 is ERC721Core {
    using PMath for uint256;

    uint256 internal _tokenCount = 0;

    mapping(uint256 => string) private _uri;

    constructor() {
        _name = "Synthetic ERC721";
        _symbol = "S-ERC721";
    }

    function mint(string memory uri) public {
        _tokenCount += 1;
        uint256 tokenId = _tokenCount;
        uint96 tokenData = PMath.Uint96(tokenId);

        _safeMint(msg.sender, tokenId, tokenData);
        _uri[tokenId] = uri;

    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        require(tokenId <= _tokenCount, "Invalid tokenId");
        return _uri[tokenId];
    }
}