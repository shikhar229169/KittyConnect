<p align="center">
<img src="https://th.bing.com/th/id/OIG.dD0gTqhpCpl6Qpf7zabf?w=270&h=270&c=6&r=0&o=5&dpr=1.3&pid=ImgGn" width="500" alt="SantasList">
<img src="https://th.bing.com/th/id/OIG.G1yBCOUl02a2PGh8_ZZf?w=270&h=270&c=6&r=0&o=5&dpr=1.3&pid=ImgGn" width="500" alt="SantasList">
<br/>

# About the Project

This project allows users to buy a cute cat from our branches and mint NFT for buying a cat. The NFT will be used to track the cat info and all related data for a particular cat corresponding to their token ids. Cat owners can also visit any partner shop for vet checkup and makes payment in KittyToken. Cat Owner can also take insurance policy for their cat and all the payment will be done in KittyToken. The KittyToken is ERC20 token pegged with the USDC and all data of price feed are come from [`the Chainlink Data Feeds`](https://docs.chain.link/data-feeds/price-feeds/addresses?network=ethereum&page=1). Kitty Owner can also Bridge their NFT from one chain to another chain via [`Chainlink CCIP`](https://docs.chain.link/ccip).

The codebase is broken up into 6 contracts:

- `KittyConnect.sol`
- `KittyInsurance.sol`
- `KittyToken.sol`
- `KittyBridge.sol`
- `KittyInsuranceProvider.sol`
- `Ownable.sol`

## KittyConnect

This contract allows users to buy a cute cat from our branches and mint NFT for buying a cat. The NFT will be used to track the cat info and all related data for a particular cat corresponding to their token ids. Cat owners can also visit any partner shop for vet checkup and makes payment in KittyToken (the price of the token is same as USDC).

## KittyInsurance

This contract allows users to pay his premium in KittyToken to the policy provider and also claim the insurance by any shop partner in KittyToken. The insurance will be valid for either 1 year or 6 month as per the user choice.

## KittyToken

This contract allows users to buy KittyToken which pegged with the USDC and all the data feeds of prices are come from the [`the Chainlink Data Feeds`](https://docs.chain.link/data-feeds/price-feeds/addresses?network=ethereum&page=1).

## KittyBridge

This contract allows users to bridge their Kitty NFT from one chain to another chain via [`Chainlink CCIP`](https://docs.chain.link/ccip).

## KittyInsuranceProvider

This contract allows policy provider to deploy the insurance policy for the users. The policy parameter will be decided between the policy provider and the cat Owner (for example: coverage amount, premium amount, Time(1 year or 6 month), etc.). By the contract, policy provider can also mark the insurance complete when the insurance time completed with all the premium amount paid by the user.

## Ownable

This contract allows the owner to transfer the ownership of the contract to another address.

## Roles in the Project:

1. Cat Owner
   - User who buy the cat from our branches and mint NFT for buying a cat.
2. Shop Partner
   - Shop partner provide services to the cat owner to buy can and make payment in KittyToken.
3. Insurance Policy Provider
   - Policy provider provides insurance policy to the cat owner and all the payment will be done in KittyToken.
4. KittyConnect Owner
   - Owner of the contract who can transfer the ownership of the contract to another address.

# Getting Started

## Requirements

- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
  - You'll know you did it right if you can run `git --version` and you see a response like `git version x.x.x`
- [foundry](https://getfoundry.sh/)
  - You'll know you did it right if you can run `forge --version` and you see a response like `forge 0.2.0 (816e00b 2023-03-16T00:05:26.396218Z)`

## Quickstart

```bash
git clone https://github.com/shikhar229169/KittyConnect.git
cd KittyConnect
```

### Install Dependencies

```bash
forge build
```

OR

```bash
forge install
```

# Usage

## Testing

```bash
forge test
```

### Test Coverage

```bash
forge coverage
```

### Compiling

```bash
forge compile
```

### Help

```bash
$ forge --help
$ anvil --help
$ cast --help
```

### Deploying and verifying contracts In testnet

```bash
forge script script/DeployKittyConnect.s.sol:DeployKittyConnect --fork-url $RPC_URL --private-key $PRIVATE_KEY --verify --broadcast
```

### Interacting with deployed contracts

#### Buying a Cat

```bash
forge script script/Interactions.s.sol:BuyCat --fork-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

#### BridgeNFT to another chain

```bash
forge script script/Interactions.s.sol:BridgeNFT --fork-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

# How this Project Works

## Buying a Cat

- first User will buy the Cat from our branches and mint NFT for buying a cat. By calling the function by Shop patners, this NFT will track all the data related to the cat :

```solidity
function mintCatToNewOwner(
        address catOwner,
        string memory catIpfsHash,
        string memory catName,
        string memory breed,
        uint256 dob
    ) external onlyShopPartner;
```

## Buying a KittyToken

- User can buy the KittyToken from the KittyToken contract by calling the function :

```solidity
function mintKittyTokenForEth() external payable;
```

## Bridge Kitty NFT from one chain to another chain

- User can bridge Kitty NFT from one chain to another chain by calling this function from KittyConnect contract:

```solidity
function bridgeNftToAnotherChain(uint64 destChainSelector, address destChainBridge, uint256 tokenId) external;
```

## Taking Insurance Policy

- User can take insurance policy for their cat by this function from KittyInsuranceProvider contract call by the policy provider:

```solidity
function provideInsurance(
        address _kittyOwner,
        uint256 _premiumAmount,
        uint256 _coverageAmount,
        bool _isOneYear,
        address _tokenAddress,
        uint256 _tokenId
    ) external onlyPolicyHolder;
```

- User can pay the premium amount in KittyToken by calling this function from KittyInsurance contract:

```solidity
// if user policy is for one year
function payPremiumForOneYearPolicy(uint256 amount) external onlyKittyOwner PremiumPaid oneYear;

// OR

// if user policy is for six month
function payPremiumForSixMonthPolicy(uint256 amount) external onlyKittyOwner PremiumPaid sixMonths
```

- User can claim the insurance by this function from KittyInsurance contract call by the shop partner:

```solidity
function claim() external onlyShopPartner notExpired notClaimed;
```

## User can sell their cat to other user

- User can sell their cat to other user by calling this function from KittyConnect contract:

```solidity
function transferFrom(address currCatOwner, address newOwner, uint256 tokenId) public override onlyShopPartner;

// Same as transferFrom but with additional data field

function safeTransferFrom(address currCatOwner, address newOwner, uint256 tokenId, bytes memory data) public override onlyShopPartner;
```

## User can visit any partner shop for vet checkup and makes payment in KittyToken

- User can visit any partner shop for vet checkup and makes payment in KittyToken by this function from KittyConnect contract call by the shop partner:

```solidity
function redeemTokensForVetVisit(address catOwner, uint256 tokenId, uint256 amount, string memory remarks) external onlyShopPartner;
```

# Getter Functions of KittyConnect Contract:

- These are the getter functions of KittyConnect contract:

```solidity
function tokenURI(uint256 tokenId) public view override returns (string memory);
function getCatAge(uint256 tokenId) external view returns (uint256);
function getTokenCounter() external view returns (uint256);
function getKittyConnectOwner() external view returns (address);
function getKittyConnectOwner() external view returns (address);
function getAllKittyShops() external view returns (address[] memory);
function getKittyShopAtIdx(uint256 idx) external view returns (address);
function getIsKittyPartnerShop(address partnerShop) external view returns (bool);
function getKittyToken() external view returns (address);
function getCatInfo(uint256 tokenId) external view returns (CatInfo memory);
function getCatsTokenIdOwnedBy(address user) external view returns (uint256[] memory);
```

# Getter Functions of KittyToken Contract:

- These are the getter functions of KittyToken contract:

```solidity
function getEthUsdPriceFeed() external view returns (address);
function getKittyConnectAddr() external view returns (address);
```

# Getter Functions of KittyBridge Contract:

- These are the getter functions of KittyBridge contract:

```solidity
function getKittyConnectAddr() external view returns (address);
function getGaslimit() external view returns (uint256);
function getLinkToken() external view returns (address);
```

# Getter Functions of KittyInsurance Contract:

- These are the getter functions of KittyInsurance contract:

```solidity
function getExpirationTimestamp() external view returns (uint256);
function getTotalPremiumPaidByOwner() external view returns (uint256);
function getNetPremiumToBepaid() external view returns (uint256);
function getPolicyHolder() external view returns (address);
function getKittyConnect() external view returns (address);
function getKittyToken() external view returns (address);
function getKittyOwner() external view returns (address);
function getIsOneYear() external view returns (bool);
function getPremiumAmount() external view returns (uint256);
function getCoverageAmount() external view returns (uint256);
function getIsClaimed() external view returns (bool);
function getTokenId() external view returns (uint256);
```

# Getter Functions of KittyInsuranceProvider Contract:

- These are the getter functions of KittyInsuranceProvider contract:

```solidity
function getTokenIdToInsuranceContract(uint256 tokenId) external view returns (address);
function getPolicyHolder() external view returns (address);
function getKittyConnect() external view returns (address);
function getKittyToken() external view returns (address);
```
