# Decentralized Policy Prediction Market

A comprehensive smart contract platform built on Stacks blockchain that enables users to create and participate in prediction markets for policy outcomes. The contract supports wagering, liquidity provision, automated market making, and fee distribution mechanisms.

## Overview

This smart contract provides a complete infrastructure for decentralized prediction markets focused on policy outcomes. Users can create markets, place wagers on binary outcomes, provide liquidity, and earn rewards based on correct predictions.

## Key Features

### Core Functionality
- Create prediction markets for policy outcomes with customizable parameters
- Place wagers on binary outcomes (yes/no predictions)
- Resolve markets based on actual policy outcomes
- Claim rewards for correct predictions
- Automated market lifecycle management with expiration handling

### Advanced Features
- Liquidity pool system for automated market making
- Multi-tier fee structure supporting platform and liquidity providers
- Time-locked liquidity positions with minimum lock periods
- Fee accumulation and distribution mechanisms
- Comprehensive validation and security checks

### Administrative Controls
- Configurable platform parameters (fees, wager limits, expiration periods)
- Platform ownership transfer capabilities
- Dynamic fee adjustment mechanisms
- Market parameter controls

## Technical Specifications

### System Constants

**Blockchain Timing Limits:**
- Maximum closing block offset: 52,560 blocks (approximately 1 year)
- Minimum closing block offset: 144 blocks (approximately 1 day)
- Maximum expiration offset: 105,120 blocks (approximately 2 years)
- Minimum liquidity lock period: 1,440 blocks (approximately 10 days)

**Validation Parameters:**
- Minimum policy description length: 10 characters
- Maximum fee percentage: 1,000 basis points (10%)
- Fee basis points denominator: 10,000 (for percentage calculations)

### Default Configuration

**Market Parameters:**
- Default market expiration period: 10,000 blocks
- Minimum wager threshold: 10 STX
- Maximum wager threshold: 1,000,000 STX
- Minimum liquidity amount: 1,000 STX

**Fee Structure:**
- Platform fee percentage: 250 basis points (2.5%)
- Liquidity provider fee percentage: 150 basis points (1.5%)
- Total fee per wager: 400 basis points (4%)

## Data Structures

### Prediction Markets
Each market stores:
- Policy description (up to 256 ASCII characters)
- Resolved outcome (optional boolean)
- Betting closes at block height
- Market expires at block height
- Market creator principal
- Total liquidity pool amount
- Total yes and no wagers
- Accumulated fees

### User Wagers
Tracks individual positions:
- Market identifier
- Participant principal
- Wager amount
- Predicted outcome (boolean)

### Liquidity Positions
Tracks liquidity provider positions:
- Market identifier
- Liquidity provider principal
- Liquidity amount
- Deposit block height
- Earned fees

### Fee Beneficiaries
Tracks accumulated platform fees:
- Beneficiary principal
- Accumulated fees amount

## Public Functions

### Market Creation

**create-prediction-market**
```clarity
(create-prediction-market (policy-description (string-ascii 256)) (betting-closes-at-block uint))
```
Creates a new prediction market with specified policy description and closing block.

### Wagering

**place-wager**
```clarity
(place-wager (market-identifier uint) (wager-amount uint) (predicted-outcome bool))
```
Places a wager on a specific market outcome. Requires market to be active.

### Market Resolution

**resolve-market-outcome**
```clarity
(resolve-market-outcome (market-identifier uint) (actual-outcome bool))
```
Resolves a market with the actual policy outcome. Only callable by market creator after betting period ends.

### Rewards

**claim-prediction-reward**
```clarity
(claim-prediction-reward (market-identifier uint))
```
Claims reward for a correct prediction. Market must be resolved.

### Liquidity Provision

**provide-liquidity**
```clarity
(provide-liquidity (market-identifier uint) (liquidity-amount uint))
```
Adds liquidity to a market pool. Subject to minimum liquidity requirements.

**withdraw-liquidity**
```clarity
(withdraw-liquidity (market-identifier uint))
```
Withdraws liquidity position after lock period expires.

### Fee Management

**collect-accumulated-fees**
```clarity
(collect-accumulated-fees)
```
Claims accumulated platform fees. Available to fee beneficiaries.

## Administrative Functions

### Fee Management
- `update-platform-fee-percentage`: Adjust platform fee rate
- `update-liquidity-provider-fee-percentage`: Adjust LP fee rate

### Parameter Configuration
- `update-minimum-liquidity-amount`: Set minimum liquidity requirement
- `update-expiration-period`: Modify default market expiration period
- `update-minimum-wager`: Set minimum wager threshold
- `update-maximum-wager`: Set maximum wager threshold

### Ownership
- `transfer-platform-ownership`: Transfer platform control to new administrator

## Read-Only Functions

### Information Retrieval
- `get-platform-administrator`: Returns current admin principal
- `get-market-information`: Retrieves complete market details
- `get-wager-information`: Gets user wager details for specific market
- `get-platform-configuration`: Returns current platform settings
- `get-liquidity-position`: Retrieves LP position details
- `get-beneficiary-fees`: Gets accumulated fees for beneficiary
- `get-market-statistics`: Provides comprehensive market statistics

## Error Codes

The contract defines 23 error constants for comprehensive error handling:

| Code | Constant | Description |
|------|----------|-------------|
| u1 | ERR-INVALID-CLOSING-BLOCK | Invalid closing block parameter |
| u2 | ERR-BETTING-PERIOD-ENDED | Betting period has ended |
| u3 | ERR-OUTCOME-ALREADY-DETERMINED | Market outcome already resolved |
| u4 | ERR-INVALID-WAGER | Invalid wager parameters |
| u5 | ERR-PREDICTION-MARKET-NOT-FOUND | Market does not exist |
| u6 | ERR-INSUFFICIENT-BALANCE | Insufficient balance for operation |
| u7 | ERR-BETTING-STILL-ACTIVE | Betting period still active |
| u8 | ERR-WAGER-NOT-FOUND | No wager found for user |
| u9 | ERR-OUTCOME-NOT-DETERMINED | Market outcome not yet resolved |
| u10 | ERR-INCORRECT-PREDICTION | User predicted incorrectly |
| u11 | ERR-LIFECYCLE-EXPIRED | Market has expired |
| u12 | ERR-LIFECYCLE-NOT-EXPIRED | Market has not expired yet |
| u13 | ERR-UNAUTHORIZED-ACCESS | Unauthorized access attempt |
| u14 | ERR-WAGER-BELOW-MINIMUM | Wager below minimum threshold |
| u15 | ERR-WAGER-EXCEEDS-MAXIMUM | Wager exceeds maximum threshold |
| u16 | ERR-INVALID-PARAMETER-VALUE | Invalid parameter value |
| u17 | ERR-INSUFFICIENT-LIQUIDITY | Insufficient liquidity in pool |
| u18 | ERR-LIQUIDITY-ALREADY-PROVIDED | Liquidity already provided |
| u19 | ERR-NO-LIQUIDITY-POSITION | No liquidity position found |
| u20 | ERR-LIQUIDITY-LOCKED | Liquidity is still locked |
| u21 | ERR-INVALID-FEE-PERCENTAGE | Invalid fee percentage |
| u22 | ERR-NO-FEES-TO-COLLECT | No fees available to collect |
| u23 | ERR-WITHDRAWAL-TOO-SOON | Withdrawal attempted too soon |

## Usage Examples

### Creating a Market
```clarity
(contract-call? .prediction-market create-prediction-market 
  "Will policy X be implemented by end of 2025?" 
  u100000)
```

### Placing a Wager
```clarity
(contract-call? .prediction-market place-wager 
  u1 
  u1000 
  true)
```

### Providing Liquidity
```clarity
(contract-call? .prediction-market provide-liquidity 
  u1 
  u5000)
```

### Resolving a Market
```clarity
(contract-call? .prediction-market resolve-market-outcome 
  u1 
  true)
```

### Claiming Rewards
```clarity
(contract-call? .prediction-market claim-prediction-reward 
  u1)
```

## Security Considerations

### Validation Mechanisms
- Comprehensive input validation on all public functions
- Block height validation for timing parameters
- Amount validation for wagers and liquidity
- Principal verification for authorization

### Access Controls
- Market creator-only resolution
- Administrator-only configuration changes
- User-specific wager and liquidity operations

### Economic Security
- Minimum and maximum wager limits prevent manipulation
- Time-locked liquidity prevents rapid withdrawal attacks
- Fee mechanisms ensure platform sustainability

## Market Lifecycle

1. **Creation Phase**: Market is created with policy description and closing block
2. **Active Betting Phase**: Users can place wagers until closing block
3. **Pending Resolution Phase**: No new wagers; awaiting outcome determination
4. **Resolved Phase**: Outcome determined; winners can claim rewards
5. **Expiration Phase**: Market expires after expiration block; cleanup possible

## Fee Distribution Model

### Platform Fees (2.5% default)
- Collected on every wager
- Accumulated in platform treasury
- Claimable by designated fee beneficiaries

### Liquidity Provider Fees (1.5% default)
- Distributed to liquidity providers proportionally
- Earned continuously during market activity
- Claimable upon liquidity withdrawal

### Total Fee Impact
- Users pay 4% total fees on wagers
- 96% of wager enters the market pool
- Fees incentivize liquidity provision and platform maintenance

## Deployment Considerations

### Initial Setup
1. Deploy contract to Stacks blockchain
2. Configure initial platform parameters
3. Set administrator principal
4. Establish fee beneficiary structure

### Ongoing Maintenance
- Monitor market activity and liquidity levels
- Adjust fee structures based on platform economics
- Update wager limits as STX value changes
- Manage expired markets and cleanup operations

## Integration Guidelines

### Frontend Integration
- Use read-only functions to display market information
- Implement wallet connection for user transactions
- Display real-time odds calculation based on wager totals
- Show liquidity depth and fee structures

### Analytics Integration
- Track market creation rate and outcomes
- Monitor liquidity provision patterns
- Analyze prediction accuracy rates
- Calculate platform revenue from fees