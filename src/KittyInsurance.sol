// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {KittyToken} from "./KittyToken.sol";
import {KittyConnect} from "./KittyConnect.sol";
import {KittyInsuranceProvider} from "./KittyInsuranceProvider.sol";

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
        if (!i_kittyConnect.getIsKittyShop(msg.sender)) {
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

    function payPremiumForOneYearPolicy(uint256 amount) external onlyKittyOwner PremiumPaid oneYear {
        totalPremiumPaidByOwner += amount;
        i_kittyToken.approve(i_policyHolder, amount);

        emit PolicyAmountPaid(i_policyHolder, amount);
    }

    function payPremiumForSixMonthPolicy(uint256 amount) external onlyKittyOwner PremiumPaid sixMonths {
        totalPremiumPaidByOwner += amount;
        i_kittyToken.approve(i_policyHolder, amount);

        emit PolicyAmountPaid(i_policyHolder, amount);
    }

    function claim() external onlyShopPartner notExpired notClaimed {
        uint256 payoutAmount = coverageAmount;

        i_kittyToken.transferFrom(i_policyHolder, i_kittyOwner, payoutAmount);

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
}
