// SPDX-License-Identifier: MIT

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.18;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MerchantNft is ERC721 {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error MerchantNft__MerchantIdAlreadyMinted();
    error MerchantNft__TokenDoesNotExist();
    error MerchantNft__OnlyOwnerCanCall();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    address private immutable i_owner;

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier onlyOwner() {
        if (msg.sender != i_owner) {
            revert MerchantNft__OnlyOwnerCanCall();
        }
        _;
    }
    
    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    constructor(address owner) ERC721("MerchantNft", "MNFT") {
        i_owner = owner;
    }

    /*//////////////////////////////////////////////////////////////
                     EXTERNAL AND PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function mintNft(uint256 merchantId, address to) external onlyOwner {
        if (_ownerOf(merchantId) != address(0)) {
            revert MerchantNft__MerchantIdAlreadyMinted();
        }
        _safeMint(to, merchantId);
        
    }

    function isMerchant(address wallet, uint256 merchantId) external view returns (bool) {
        if (_ownerOf(merchantId) == wallet) {
            return true;
        } else {
            return false;
        }
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (_ownerOf(tokenId) == address(0)) {
            revert MerchantNft__TokenDoesNotExist();
        }

        return "ipfs://bafkreidn7tkkov6iykgq5kb7zbfb77tg7lza5exutuufoozebeg7gwz22u";
    }

    /*//////////////////////////////////////////////////////////////
                            GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function getOwner() external view returns (address) {
        return i_owner;
    }
}