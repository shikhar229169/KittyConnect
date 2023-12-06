// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { KittyToken } from "./KittyToken.sol";
 
contract KittyConnect is ERC721 {
    // Errors
    error KittyConnect__AlreadyAPartner();
    error KittyConnect__NotAPartner();
    error KittyConnect__NewOwnerNotApproved();
    error KittyConnect__NotKittyOwner();
    error KittyConnect__CatOwnerCantBeShopPartner();
    error KittyConnect__CatNotFound();
    error KittyConnect__InsufficientAllowance();

    struct CatInfo {
        string catName;
        string breed;
        string image;
        uint256 dob;
        uint256[] prevOwner;
        address shopPartner;
        string latestRemarks;
    }

    // Storage Variables
    uint256 kittyTokenCounter;
    mapping(address => bool) private s_isKittyShop;
    address[] private s_kittyShops;
    mapping(address user => uint256[]) private s_ownerToCatsTokenId;
    mapping(uint256 tokenId => CatInfo) private s_catInfo;
    KittyToken private immutable i_kittyToken;

    // Events
    event ShopPartnerAdded(address partner);
    event CatMinted(uint256 tokenId, string catIpfsHash);
    event KittyConnect__TokensRedeemedForVetVisit(uint256 tokenId, uint256 amount, string remarks);

    // Modifiers
    modifier onlyShopPartner() {
        if (!s_isKittyShop[msg.sender]) {
            revert KittyConnect__NotAPartner();
        }
        _;
    }

    // Constructor
    constructor(address[] memory initShops,address ethUsdcPriceFeeds) ERC721("KittyConnect", "KC") {
        for (uint256 i = 0; i < initShops.length; i++) {
            s_kittyShops.push(initShops[i]);
            s_isKittyShop[initShops[i]] = true;
        }

        i_kittyToken = new KittyToken(address(this), ethUsdcPriceFeeds);
    }


    // Functions

    function addShop(address shopAddress) external {
        if (s_isKittyShop[shopAddress]) {
            revert KittyConnect__AlreadyAPartner();
        }

        s_kittyShops.push(shopAddress);
        s_isKittyShop[shopAddress] = true;
        emit ShopPartnerAdded(shopAddress);
    }

    function mintCatToNewOwner(
        address catOwner,
        string memory catIpfsHash,
        string memory catName,
        string memory breed,
        uint256 dob
    ) external onlyShopPartner {
        if (s_isKittyShop[catOwner]) {
            revert KittyConnect__CatOwnerCantBeShopPartner();
        }

        uint256 tokenId = kittyTokenCounter;
        kittyTokenCounter++;

        s_ownerToCatsTokenId[catOwner].push(tokenId);

        s_catInfo[tokenId] = CatInfo({
            catName: catName,
            breed: breed,
            image: catIpfsHash,
            dob: dob,
            prevOwner: new uint256[](0),
            shopPartner: msg.sender,
            latestRemarks: ""
        });

        _safeMint(catOwner, tokenId);
        emit CatMinted(tokenId, catIpfsHash);
    }

    function redeemTokensForVetVisit(address catOwner, uint256 tokenId, uint256 amount, string memory remarks) external onlyShopPartner {
        if (_ownerOf(tokenId) != catOwner) {
            revert KittyConnect__NotKittyOwner();
        }

        if (i_kittyToken.allowance(catOwner, msg.sender) < amount) {
            revert KittyConnect__InsufficientAllowance();
        }

        i_kittyToken.burnFrom(catOwner, amount);
        s_catInfo[tokenId].latestRemarks = remarks;

        emit KittyConnect__TokensRedeemedForVetVisit(tokenId, amount, remarks);
    }

    function transferFrom(address currCatOwner, address newOwner, uint256 tokenId) public override onlyShopPartner {
        if (_ownerOf(tokenId) != currCatOwner) {
            revert KittyConnect__NotKittyOwner();
        }

        if (getApproved(tokenId) != newOwner) {
            revert KittyConnect__NewOwnerNotApproved();
        }

        _transfer(currCatOwner, newOwner, tokenId);
    }

    function safeTransferFrom(address currCatOwner, address newOwner, uint256 tokenId, bytes memory data) public override onlyShopPartner {
        if (_ownerOf(tokenId) != currCatOwner) {
            revert KittyConnect__NotKittyOwner();
        }

        if (getApproved(tokenId) != newOwner) {
            revert KittyConnect__NewOwnerNotApproved();
        }
        _safeTransfer(currCatOwner, newOwner, tokenId, data);
    }

    function getCatAge(uint256 tokenId) external view returns (uint256) {
        if (!_exists(tokenId)) {
            revert KittyConnect__CatNotFound();
        }
        return block.timestamp - s_catInfo[tokenId].dob;
    }

    function _baseURI() internal pure override returns (string memory) {
        return "data:application/json;base64,";
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        CatInfo memory catInfo = s_catInfo[tokenId];

        string memory catTokenUri = Base64.encode(
            abi.encodePacked(
                '{"name": "', catInfo.catName,
                '","breed": "', catInfo.breed,
                '", "image": "', catInfo.image,
                '", "dob": ', catInfo.dob,
                ', "shopPartner": "', catInfo.shopPartner,
                '"}'
            )
        );
        return string.concat(_baseURI(), catTokenUri);
    }
    
}
