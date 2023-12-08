// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {KittyToken} from "./KittyToken.sol";
import {KittyConnect} from "./KittyConnect.sol";
import {KittyInsuranceProvider} from "./KittyInsuranceProvider.sol";

/**
 * @title KittyInsurance
 * @author Naman Gautam
 * @notice This contract is responsible for paying the premium amount to the Policy Holder from the Kitty Owner and also allow the Kitty Owner
 * to claim the coverage amount.
 */
contract KittyInsurance {
    // Errors
    error KittyInsurance__NotPolicyHolder();
    error KittyInsurance__PolicyExpired();
    error KittyInsurance__NotPolicyExpired();
    error KittyInsurance__PolicyClaimed();
    error KittyInsurance__NotKittyOwner();
    error KittyInsurance__NotOneYear();
    error KittyInsurance__NotSixMonths();
    error KittyInsurance__PremiumPaid();
    error KittyConnect__NotShopPartner();

    // Storage Variables
    address private immutable i_policyHolder;
    address private immutable i_kittyOwner;
    uint256 private premiumAmount;
    uint256 private coverageAmount;
    uint256 private startTimestamp;
    uint256 private expirationTimestamp;
    bool private isClaimed;
    bool private isOneYear;
    uint256 private tokenId;
    uint256 private totalPremiumPaidByOwner;
    uint256 private netPremiumToBepaid;

    KittyToken private immutable i_kittyToken;
    KittyConnect private immutable i_kittyConnect;
    KittyInsuranceProvider private immutable i_insuranceProvider;

    // Events
    event PolicyPurchased(
        address indexed policyHolder, uint256 premiumAmount, uint256 coverageAmount, uint256 expirationTimestamp
    );
    event ClaimProcessed(address indexed policyHolder, uint256 payoutAmount);
    event PolicyAmountPaid(address indexed policyHolder, uint256 amount);

    // Modifiers
    modifier oneYear() {
        if (!isOneYear) {
            revert KittyInsurance__NotOneYear();
        }
        _;
    }

    modifier sixMonths() {
        if (isOneYear) {
            revert KittyInsurance__NotSixMonths();
        }
        _;
    }

    modifier notExpired() {
        if (block.timestamp > expirationTimestamp) {
            revert KittyInsurance__PolicyExpired();
        }
        _;
    }

    modifier PremiumPaid() {
        if (totalPremiumPaidByOwner == netPremiumToBepaid) {
            revert KittyInsurance__PremiumPaid();
        }
        _;
    }

    modifier onlyShopPartner() {
        if (!i_kittyConnect.getIsKittyPartnerShop(msg.sender)) {
            revert KittyConnect__NotShopPartner();
        }
        _;
    }

    modifier notClaimed() {
        if (isClaimed) {
            revert KittyInsurance__PolicyClaimed();
        }
        _;
    }

    modifier onlyKittyOwner() {
        if (msg.sender != i_kittyOwner) {
            revert KittyInsurance__NotKittyOwner();
        }
        _;
    }

    // Constructor
    constructor(
        address _policyHolder,
        address _kittyOwner,
        uint256 _premiumAmount,
        uint256 _coverageAmount,
        bool _isOneYear,
        address _tokenAddress,
        uint256 _tokenId,
        address _kittyConnect,
        address _insuranceProvider
    ) {
        i_policyHolder = _policyHolder;
        i_kittyOwner = _kittyOwner;
        premiumAmount = _premiumAmount;
        coverageAmount = _coverageAmount;
        startTimestamp = block.timestamp;
        isOneYear = _isOneYear;
        if (_isOneYear) {
            expirationTimestamp = block.timestamp + (1 * 365 days);
            netPremiumToBepaid = _premiumAmount * 12;
        } else {
            expirationTimestamp = block.timestamp + (1 * 183 days);
            netPremiumToBepaid = _premiumAmount * 6;
        }
        isClaimed = false;
        i_kittyToken = KittyToken(_tokenAddress);
        i_kittyConnect = KittyConnect(_kittyConnect);
        i_insuranceProvider = KittyInsuranceProvider(_insuranceProvider);
        tokenId = _tokenId;

        emit PolicyPurchased(_policyHolder, _premiumAmount, _coverageAmount, expirationTimestamp);
    }

    // Functions

    /**
     * @notice This function is responsible for paying the premium amount to the Policy Holder from the Kitty Owner. But, it can only be called in the 1 year policy
     * @notice It also approves the KittyToken contract to transfer the premium amount from the Kitty Owner to the Policy Holder and also update the totalPremiumPaidByOwner
     *
     * @param amount It takes the amount of the premium to be paid by the Kitty Owner
     */
    function payPremiumForOneYearPolicy(uint256 amount) external onlyKittyOwner PremiumPaid oneYear {
        totalPremiumPaidByOwner += amount;
        i_kittyToken.approve(i_policyHolder, amount);

        emit PolicyAmountPaid(i_policyHolder, amount);
    }

    /**
     * @notice This function is responsible for paying the premium amount to the Policy Holder from the Kitty Owner.  But it can only be called in the 6 months policy
     * @notice It also approves the KittyToken contract to transfer the premium amount from the Kitty Owner to the Policy Holder and also update the totalPremiumPaidByOwner
     *
     * @param amount It takes the amount of the premium to be paid by the Kitty Owner
     */
    function payPremiumForSixMonthPolicy(uint256 amount) external onlyKittyOwner PremiumPaid sixMonths {
        totalPremiumPaidByOwner += amount;
        i_kittyToken.approve(i_policyHolder, amount);

        emit PolicyAmountPaid(i_policyHolder, amount);
    }

    /**
     * @notice This function is responsible for paying the coverage amount to the Kitty Owner from the Policy Holder. But it can only be called by the shop partner's
     * @notice It also approves the KittyToken contract to transfer the coverage amount from the Policy Holder to the Kitty Owner
     */

    function claim() external onlyShopPartner notExpired notClaimed {
        uint256 payoutAmount = coverageAmount;

        i_kittyToken.approve(i_kittyOwner, payoutAmount);

        isClaimed = true;
        i_insuranceProvider.setPolicyActive(tokenId, false);

        emit ClaimProcessed(i_policyHolder, payoutAmount);
    }

    function getExpirationTimestamp() external view returns (uint256) {
        return expirationTimestamp;
    }

    function getTotalPremiumPaidByOwner() external view returns (uint256) {
        return totalPremiumPaidByOwner;
    }

    function getNetPremiumToBepaid() external view returns (uint256) {
        return netPremiumToBepaid;
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

    function getKittyOwner() external view returns (address) {
        return i_kittyOwner;
    }

    function getIsOneYear() external view returns (bool) {
        return isOneYear;
    }

    function getPremiumAmount() external view returns (uint256) {
        return premiumAmount;
    }

    function getCoverageAmount() external view returns (uint256) {
        return coverageAmount;
    }

    function getIsClaimed() external view returns (bool) {
        return isClaimed;
    }

    function getTokenId() external view returns (uint256) {
        return tokenId;
    }
}
