// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {KittyToken} from "./KittyToken.sol";
import {KittyInsurance} from "./KittyInsurance.sol";
import {KittyConnect} from "./KittyConnect.sol";

contract KittyInsuranceProvider {
    // Errors
    error KittyInsurance__NotPolicyHolder();
    error KittyInsurance__OfferTimeExpired();
    error KittyInsurance__NotInsuranceContract();
    error KittyInsurance__OfferTimeNotExpired();
    error KittyInsurance__AlreadyIssued();

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
            revert KittyInsurance__NotPolicyHolder();
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
    function provideInsurance(
        address _kittyOwner,
        uint256 _premiumAmount,
        uint256 _coverageAmount,
        bool _isOneYear,
        address _tokenAddress,
        uint256 _tokenId
    ) external onlyPolicyHolder {
        if (i_kittyConnect.getCatAge(_tokenId) > 15 * ONE_DAY) {
            revert KittyInsurance__OfferTimeExpired();
        }

        if (isPolicyActive[_tokenId]) {
            revert KittyInsurance__AlreadyIssued();
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

    function setPolicyActive(uint256 tokenId, bool isActive) external {
        if (msg.sender != tokenIdToInsuranceContract[tokenId]) {
            revert KittyInsurance__NotInsuranceContract();
        }
        isPolicyActive[tokenId] = isActive;
        emit InsuranceCompleted(tokenId);
    }

    function setPolicyActiveAfterExpiration(address policyAddress, uint256 tokenId) external onlyPolicyHolder {
        KittyInsurance insuranceContract = KittyInsurance(policyAddress);
        if (
            insuranceContract.getExpirationTimestamp() < block.timestamp
                && insuranceContract.getTotalPremiumPaidByOwner() != insuranceContract.getNetPremiumToBepaid()
        ) {
            revert KittyInsurance__OfferTimeNotExpired();
        }
        isPolicyActive[tokenId] = false;
        emit InsuranceCompleted(tokenId);
    }
}
