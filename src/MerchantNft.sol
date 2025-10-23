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
    error MerchantNft__AlreadyApplied();
    error MerchantNft__AlreadyHasNFT();
    error MerchantNft__NoPendingApplication();
    error MerchantNft__NotTokenOwner();
    error MerchantNft__ZeroAddress();

    enum AppStatus { None, Pending, Processed, Rejected }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    address private immutable i_owner;
    uint256 private _nextId = 1;
    mapping(address => AppStatus) public applicationStatus;



    event MerchantApplied(address indexed applicant);
    event MerchantApproved(address indexed applicant, uint256 indexed tokenId);
    event MerchantRejected(address indexed applicant);

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
     function applyAsMerchant() external {
        if (applicationStatus[msg.sender] != AppStatus.None) revert MerchantNft__AlreadyApplied();
        

        applicationStatus[msg.sender] = AppStatus.Pending;
        emit MerchantApplied(msg.sender);
    }

     function approveApplicant(address applicant) external onlyOwner {
        if (applicant == address(0)) revert MerchantNft__ZeroAddress();
        if (applicationStatus[applicant] != AppStatus.Pending) revert MerchantNft__NoPendingApplication();
        

        uint256 tokenId = _nextId++;
        _safeMint(applicant, tokenId);

        applicationStatus[applicant] = AppStatus.Processed;

        emit MerchantApproved(applicant, tokenId);
    }

    function rejectApplicant(address applicant) external onlyOwner {
        if (applicationStatus[applicant] != AppStatus.Pending) revert MerchantNft__NoPendingApplication();
        applicationStatus[applicant] = AppStatus.Rejected;
        emit MerchantRejected(applicant);
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

    function ownerBurn(uint256 tokenId) external onlyOwner {
        if (_ownerOf(tokenId) == address(0)) {
            revert MerchantNft__TokenDoesNotExist();
        }
        _burn(tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                            GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function getOwner() external view returns (address) {
        return i_owner;
    }

    function getNextId() external view returns (uint256) {
        return _nextId;
    }

    function getApplicationStatus(address applicant) external view returns (AppStatus) {
        return applicationStatus[applicant];
    }


}