// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { KittyToken } from "./KittyToken.sol";
import { KittyBridge } from "./KittyBridge.sol";

/**
 * @title KittyConnect
 * @author Shikhar Agarwal
 * @notice This contract allows users to buy a cute cat from our branches and mint NFT for buying a cat
 * The NFT will be used to track the cat info and all related data for a particular cat corresponding to their token ids
 * @notice Cat owners can also visit any partner shop for vet checkup and makes payment in KittyToken (the price of the token is same as USDC)
 */
contract KittyConnect is ERC721 {
    // Errors
    error KittyConnect__NotKittyConnectOwner();
    error KittyConnect__AlreadyAPartner();
    error KittyConnect__NotAPartner();
    error KittyConnect__NewOwnerNotApproved();
    error KittyConnect__NotKittyOwner();
    error KittyConnect__CatOwnerCantBeShopPartner();
    error KittyConnect__CatNotFound();
    error KittyConnect__InsufficientAllowance();
    error KittyConnect__NotKittyBridge();

    struct CatInfo {
        string catName;
        string breed;
        string image;
        uint256 dob;
        address[] prevOwner;
        address shopPartner;
        string latestRemarks;
        uint256 idx;
    }

    // Storage Variables
    uint256 private kittyTokenCounter;
    address private immutable i_kittyConnectOwner;
    mapping(address => bool) private s_isKittyShop;
    address[] private s_kittyShops;
    mapping(address user => uint256[]) private s_ownerToCatsTokenId;
    mapping(uint256 tokenId => CatInfo) private s_catInfo;
    KittyToken private immutable i_kittyToken;
    KittyBridge private immutable i_kittyBridge;

    // Events
    event ShopPartnerAdded(address partner);
    event CatMinted(uint256 tokenId, string catIpfsHash);
    event TokensRedeemedForVetVisit(uint256 tokenId, uint256 amount, string remarks);
    event CatTransferredToNewOwner(address prevOwner, address newOwner, uint256 tokenId);
    event NFTBridgeRequestSent(uint256 sourceChainId, uint64 destChainSelector, address destBridge, uint256 tokenId);
    event NFTBridged(uint256 chainId, uint256 tokenId);

    // Modifiers
    modifier onlyKittyConnectOwner() {
        if (msg.sender != i_kittyConnectOwner) {
            revert KittyConnect__NotKittyConnectOwner();
        }
        _;
    }

    modifier onlyShopPartner() {
        if (!s_isKittyShop[msg.sender]) {
            revert KittyConnect__NotAPartner();
        }
        _;
    }

    modifier onlyKittyBridge() {
        if (msg.sender != address(i_kittyBridge)) {
            revert KittyConnect__NotKittyBridge();
        }
        _;
    }

    // Constructor
    constructor(address[] memory initShops,address ethUsdcPriceFeeds, address router, address link) ERC721("KittyConnect", "KC") {
        for (uint256 i = 0; i < initShops.length; i++) {
            s_kittyShops.push(initShops[i]);
            s_isKittyShop[initShops[i]] = true;
        }

        i_kittyConnectOwner = msg.sender;
        i_kittyToken = new KittyToken(address(this), ethUsdcPriceFeeds);
        i_kittyBridge = new KittyBridge(router, link, msg.sender);
    }

    // Functions

    /**
     * @notice Allows the owner of the protocol to add a new shop partner
     * @param shopAddress The address of new shop partner
     */
    function addShop(address shopAddress) external onlyKittyConnectOwner {
        if (s_isKittyShop[shopAddress]) {
            revert KittyConnect__AlreadyAPartner();
        }

        s_kittyShops.push(shopAddress);
        s_isKittyShop[shopAddress] = true;
        emit ShopPartnerAdded(shopAddress);
    }

    /**
     * @notice Allows the shop partners to mint a cat nft to owner when a purchase is made by user (cat owner)
     * @param catOwner The owner of new cat
     * @param catIpfsHash The image Ipfs Hash for the cat bought by catOwner
     * @param catName Name of cat
     * @param breed Breed of cat
     * @param dob timestamp of date of birth of cat (in seconds)
     * @dev Payments for the cat purchase takes off-chain and a corresponding NFT is minted to the owner which stores the info of cat
     */
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

        s_catInfo[tokenId] = CatInfo({
            catName: catName,
            breed: breed,
            image: catIpfsHash,
            dob: dob,
            prevOwner: new address[](0),
            shopPartner: msg.sender,
            latestRemarks: "",
            idx: s_ownerToCatsTokenId[catOwner].length
        });

        s_ownerToCatsTokenId[catOwner].push(tokenId);

        _safeMint(catOwner, tokenId);
        emit CatMinted(tokenId, catIpfsHash);
    }

    /**
     * @notice The shop partner will call this function to receive payments for the cat checkup by vet
     * @param catOwner The owner of cat that came for vet visit at a pertner shop
     * @param tokenId the token id of the cat the user brings for visit
     * @param amount The cost in KittyTokens for vet fees
     * @param remarks The remarks given by vet
     */
    function redeemTokensForVetVisit(address catOwner, uint256 tokenId, uint256 amount, string memory remarks) external onlyShopPartner {
        if (_ownerOf(tokenId) != catOwner) {
            revert KittyConnect__NotKittyOwner();
        }

        if (i_kittyToken.allowance(catOwner, msg.sender) < amount) {
            revert KittyConnect__InsufficientAllowance();
        }

        i_kittyToken.burnFrom(catOwner, amount);
        s_catInfo[tokenId].latestRemarks = remarks;

        emit TokensRedeemedForVetVisit(tokenId, amount, remarks);
    }

    /**
     * @notice Allows the shop partner to tranfer the ownership of cat to a new owner
     * @notice First the current owner is required to approve the cat's token id to the newOwner
     * @param currCatOwner The current cat owner corresponding to the cat's token id
     * @param newOwner The new owner of cat
     * @param tokenId The token id of cat
     */
    function transferFrom(address currCatOwner, address newOwner, uint256 tokenId) public override onlyShopPartner {
        if (_ownerOf(tokenId) != currCatOwner) {
            revert KittyConnect__NotKittyOwner();
        }

        if (getApproved(tokenId) != newOwner) {
            revert KittyConnect__NewOwnerNotApproved();
        }

        _updateOwnershipInfo(currCatOwner, newOwner, tokenId);

        emit CatTransferredToNewOwner(currCatOwner, newOwner, tokenId);
        _transfer(currCatOwner, newOwner, tokenId);
    }

    /**
     * @notice Same as transferFrom but with additional data field
     */
    function safeTransferFrom(address currCatOwner, address newOwner, uint256 tokenId, bytes memory data) public override onlyShopPartner {
        if (_ownerOf(tokenId) != currCatOwner) {
            revert KittyConnect__NotKittyOwner();
        }

        if (getApproved(tokenId) != newOwner) {
            revert KittyConnect__NewOwnerNotApproved();
        }

        _updateOwnershipInfo(currCatOwner, newOwner, tokenId);

        emit CatTransferredToNewOwner(currCatOwner, newOwner, tokenId);
        _safeTransfer(currCatOwner, newOwner, tokenId, data);
    }

    function bridgeNftToAnotherChain(uint64 destChainSelector, address destChainBridge, uint256 tokenId) external {
        address catOwner = _ownerOf(tokenId);

        if (msg.sender != catOwner) {
            revert KittyConnect__NotKittyOwner();
        }

        CatInfo memory catInfo = s_catInfo[tokenId];
        uint256 idx = catInfo.idx;
        bytes memory data = abi.encode(catOwner, catInfo.catName, catInfo.breed, catInfo.image, catInfo.dob, catInfo.shopPartner);

        _burn(tokenId);
        delete s_catInfo[tokenId];

        uint256[] memory userTokenIds = s_ownerToCatsTokenId[msg.sender];
        uint256 lastItem = userTokenIds[userTokenIds.length - 1];

        s_ownerToCatsTokenId[msg.sender].pop();

        if (idx < (userTokenIds.length - 1)) {
            s_ownerToCatsTokenId[msg.sender][idx] = lastItem;
        }

        emit NFTBridgeRequestSent(block.chainid, destChainSelector, destChainBridge, tokenId);
        i_kittyBridge.bridgeNftWithData(destChainSelector, destChainBridge, data);
    }

    function mintBridgedNFT(bytes memory data) external onlyKittyBridge {
        (
            address catOwner, 
            string memory catName, 
            string memory breed, 
            string memory imageIpfsHash, 
            uint256 dob, 
            address shopPartner
        ) = abi.decode(data, (address, string, string, string, uint256, address));

        uint256 tokenId = kittyTokenCounter;
        kittyTokenCounter++;

        s_catInfo[tokenId] = CatInfo({
            catName: catName,
            breed: breed,
            image: imageIpfsHash,
            dob: dob,
            prevOwner: new address[](0),
            shopPartner: shopPartner,
            latestRemarks: "",
            idx: s_ownerToCatsTokenId[catOwner].length
        });

        s_ownerToCatsTokenId[catOwner].push(tokenId);

        emit NFTBridged(block.chainid, tokenId);
        _safeMint(catOwner, tokenId);
    }

    function _updateOwnershipInfo(address currCatOwner, address newOwner, uint256 tokenId) internal {
        uint256 oldIdx = s_catInfo[tokenId].idx;
        
        s_catInfo[tokenId].prevOwner.push(currCatOwner);
        s_catInfo[tokenId].idx = s_ownerToCatsTokenId[newOwner].length;
        s_ownerToCatsTokenId[newOwner].push(tokenId);

        uint256[] storage currOwnerTokens = s_ownerToCatsTokenId[currCatOwner];
        uint256 lastItem = currOwnerTokens[currOwnerTokens.length - 1];
        currOwnerTokens.pop();

        if (currOwnerTokens.length > oldIdx) {
            currOwnerTokens[oldIdx] = lastItem;
        }
    }


    function _baseURI() internal pure override returns (string memory) {
        return "data:application/json;base64,";
    }

    /**
     * @notice returns the token uri of the corresponding cat nft
     * @param tokenId The token id of cat
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        CatInfo memory catInfo = s_catInfo[tokenId];

        string memory catTokenUri = Base64.encode(
            abi.encodePacked(
                '{"name": "', catInfo.catName,
                '", "breed": "', catInfo.breed,
                '", "image": "', catInfo.image,
                '", "dob": ', Strings.toString(catInfo.dob),
                ', "owner": "', Strings.toHexString(_ownerOf(tokenId)),
                '", "shopPartner": "', Strings.toHexString(catInfo.shopPartner),
                '"}'
            )
        );
        return string.concat(_baseURI(), catTokenUri);
    }

    /**
     * @notice Returns the age of cat in seconds
     * @param tokenId The token id of cat
     */
    function getCatAge(uint256 tokenId) external view returns (uint256) {
        if (!_exists(tokenId)) {
            revert KittyConnect__CatNotFound();
        }
        return block.timestamp - s_catInfo[tokenId].dob;
    }
    
    function getTokenCounter() external view returns (uint256) {
        return kittyTokenCounter;
    }

    function getKittyConnectOwner() external view returns (address) {
        return i_kittyConnectOwner;
    }

    function getAllKittyShops() external view returns (address[] memory) {
        return s_kittyShops;
    }

    function getKittyShopAtIdx(uint256 idx) external view returns (address) {
        return s_kittyShops[idx];
    }

    function getIsKittyPartnerShop(address partnerShop) external view returns (bool) {
        return s_isKittyShop[partnerShop];
    } 

    function getKittyToken() external view returns (address) {
        return address(i_kittyToken);
    }

    function getCatInfo(uint256 tokenId) external view returns (CatInfo memory) {
        if (!_exists(tokenId)) {
            revert KittyConnect__CatNotFound();
        }

        return s_catInfo[tokenId];
    }

    function getCatsTokenIdOwnedBy(address user) external view returns (uint256[] memory) {
        return s_ownerToCatsTokenId[user];
    }

    function getKittyBridge() external view returns (address) {
        return address(i_kittyBridge);
    }
}
