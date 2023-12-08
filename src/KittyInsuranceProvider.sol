// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {KittyToken} from "./KittyToken.sol";
import {KittyInsurance} from "./KittyInsurance.sol";
import {KittyConnect} from "./KittyConnect.sol";

/**
 * @title KittyInsuranceProvider
 * @author Naman Gautam
 * @notice This contract is responsible for providing insurance to the Kitty Owners from Policy Holder.
 * This contract deploy by the shop partner's within 15 day's (included) of the buying of the cat.
 */
contract KittyInsuranceProvider {
    // Errors
    error KittyInsuranceProvider__NotPolicyHolder();
    error KittyInsuranceProvider__OfferTimeExpired();
    error KittyInsuranceProvider__NotInsuranceContract();
    error KittyInsuranceProvider__OfferTimeNotExpired();
    error KittyInsuranceProvider__AlreadyIssued();

    // Storage Variables
    address private immutable i_policyHolder;
    KittyToken private immutable i_kittyToken;
    KittyConnect private immutable i_kittyConnect;
    mapping(uint256 => bool) public isPolicyActive;
    mapping(uint256 => address) public tokenIdToInsuranceContract;
    uint256 public constant ONE_DAY = 1 days;

    // Events
    event InsuranceProvided(address indexed policyHolder, address indexed insuranceContract);
    event InsuranceCompleted(uint256 indexed tokenId);

    // Modifiers
    modifier onlyPolicyHolder() {
        if (msg.sender != i_policyHolder) {
            revert KittyInsuranceProvider__NotPolicyHolder();
        }
        _;
    }

    // Constructor
    constructor(address _tokenAddress, address _kittyConnectAddress) {
        i_policyHolder = msg.sender;
        i_kittyToken = KittyToken(_tokenAddress);
        i_kittyConnect = KittyConnect(_kittyConnectAddress);
    }

    // Functions

    /**
     * @notice This function deploy KittyInsurance to initiate the insurance protocol and also mark true in the isPolicyActive mapping
     * corresponding to the tokenId and also map the KittyInsurance address to the tokenId in tokenIdToInsuranceContract mapping
     *
     * @param _kittyOwner Cat Owner After the buying of cat
     * @param _premiumAmount Premium Amount of the Insurance
     * @param _coverageAmount Coverage Amount of the Insurance
     * @param _isOneYear It take bool
     * @param _tokenAddress It takes address of the KittyToken Contract
     * @param _tokenId It takes tokenId to the corresponding to the cat.
     */
    function provideInsurance(
        address _kittyOwner,
        uint256 _premiumAmount,
        uint256 _coverageAmount,
        bool _isOneYear,
        address _tokenAddress,
        uint256 _tokenId
    ) external onlyPolicyHolder {
        if (i_kittyConnect.getCatAge(_tokenId) > 15 * ONE_DAY) {
            revert KittyInsuranceProvider__OfferTimeExpired();
        }

        if (isPolicyActive[_tokenId]) {
            revert KittyInsuranceProvider__AlreadyIssued();
        }

        KittyInsurance insuranceContract = new KittyInsurance(
            msg.sender,
            _kittyOwner,
            _premiumAmount,
            _coverageAmount,
            _isOneYear,
            _tokenAddress,
            _tokenId,
            address(i_kittyConnect),
            address(this)
        );

        // Mark the policy as active
        isPolicyActive[_tokenId] = true;
        tokenIdToInsuranceContract[_tokenId] = address(insuranceContract);

        emit InsuranceProvided(msg.sender, address(insuranceContract));
    }

    /**
     * @notice This function allows KittyInsurance to change the active status to the false in order to end the insurance after calling claim in KittyInsurance
     *
     * @param tokenId Token Id corresponding to the Cat NFT
     * @param isActive always come with false from the KittyInsurance claim function
     */
    function setPolicyActive(uint256 tokenId, bool isActive) external {
        if (msg.sender != tokenIdToInsuranceContract[tokenId]) {
            revert KittyInsuranceProvider__NotInsuranceContract();
        }
        isPolicyActive[tokenId] = isActive;
        emit InsuranceCompleted(tokenId);
    }

    /**
     * @notice This function allows Policy Holder to change the active status to the false in order to end the insurance after the expiration of the insurance
     *
     * @param policyAddress It takes the address of the KittyInsurance Contract
     * @param tokenId It takes the tokenId corresponding to the Cat NFT
     */

    function setPolicyActiveAfterExpiration(address policyAddress, uint256 tokenId) external onlyPolicyHolder {
        KittyInsurance insuranceContract = KittyInsurance(policyAddress);
        if (
            insuranceContract.getExpirationTimestamp() < block.timestamp
                && insuranceContract.getTotalPremiumPaidByOwner() != insuranceContract.getNetPremiumToBepaid()
        ) {
            revert KittyInsuranceProvider__OfferTimeNotExpired();
        }
        isPolicyActive[tokenId] = false;
        emit InsuranceCompleted(tokenId);
    }

    function getTokenIdToInsuranceContract(uint256 tokenId) external view returns (address) {
        return tokenIdToInsuranceContract[tokenId];
    }

    function getPolicyHolder() external view returns (address) {
        return i_policyHolder;
    }

    function getKittyConnect() external view returns (address) {
        return address(i_kittyConnect);
    }

    function getKittyToken() external view returns (address) {
        return address(i_kittyToken);
    }
}
