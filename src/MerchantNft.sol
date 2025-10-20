// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MerchantNft is ERC721 {
    error MerchantNft__MerchantIdAlreadyMinted();
    

    constructor() ERC721("MerchantNft", "MNFT") {
        
    }

    function mintNft(uint256 merchantId) public {
        if (_ownerOf(merchantId) != address(0)) {
            revert MerchantNft__MerchantIdAlreadyMinted();
        }
        _safeMint(msg.sender, merchantId);
        
    }

    function isMerchant(address wallet, uint256 merchantId) external view returns (bool) {
        if (_ownerOf(merchantId) == wallet) {
            return true;
        } else {
            return false;
        }
    }
}