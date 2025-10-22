;; Decentralized Policy Prediction Market Smart Contract
;; A smart contract enabling users to create prediction markets for policy outcomes,
;; place wagers on predicted results, resolve markets based on actual outcomes,
;; claim rewards for correct predictions, manage market lifecycles including expiration,
;; participate in liquidity pools for automated market making, and benefit from
;; fee distribution mechanisms.

;; Error Constants - Validation and Operation Failures
(define-constant ERR-INVALID-CLOSING-BLOCK (err u1))
(define-constant ERR-BETTING-PERIOD-ENDED (err u2))
(define-constant ERR-OUTCOME-ALREADY-DETERMINED (err u3))
(define-constant ERR-INVALID-WAGER (err u4))
(define-constant ERR-PREDICTION-MARKET-NOT-FOUND (err u5))
(define-constant ERR-INSUFFICIENT-BALANCE (err u6))
(define-constant ERR-BETTING-STILL-ACTIVE (err u7))
(define-constant ERR-WAGER-NOT-FOUND (err u8))
(define-constant ERR-OUTCOME-NOT-DETERMINED (err u9))
(define-constant ERR-INCORRECT-PREDICTION (err u10))
(define-constant ERR-LIFECYCLE-EXPIRED (err u11))
(define-constant ERR-LIFECYCLE-NOT-EXPIRED (err u12))
(define-constant ERR-UNAUTHORIZED-ACCESS (err u13))
(define-constant ERR-WAGER-BELOW-MINIMUM (err u14))
(define-constant ERR-WAGER-EXCEEDS-MAXIMUM (err u15))
(define-constant ERR-INVALID-PARAMETER-VALUE (err u16))
(define-constant ERR-INSUFFICIENT-LIQUIDITY (err u17))
(define-constant ERR-LIQUIDITY-ALREADY-PROVIDED (err u18))
(define-constant ERR-NO-LIQUIDITY-POSITION (err u19))
(define-constant ERR-LIQUIDITY-LOCKED (err u20))
(define-constant ERR-INVALID-FEE-PERCENTAGE (err u21))
(define-constant ERR-NO-FEES-TO-COLLECT (err u22))
(define-constant ERR-WITHDRAWAL-TOO-SOON (err u23))

;; System Configuration Constants - Blockchain Timing and Limits
(define-constant maximum-closing-block-offset u52560)
(define-constant minimum-closing-block-offset u144)
(define-constant maximum-expiration-offset u105120)
(define-constant minimum-policy-description-length u10)
(define-constant minimum-liquidity-lock-period u1440)
(define-constant maximum-fee-percentage u1000)
(define-constant fee-basis-points u10000)

;; Contract State Variables - Core System Settings
(define-data-var platform-name (string-ascii 50) "Decentralized Policy Prediction Platform")
(define-data-var next-available-market-id uint u1)
(define-data-var platform-administrator principal tx-sender)

;; Configurable Market Parameters - Admin-Controlled Settings
(define-data-var market-expiration-period uint u10000)
(define-data-var minimum-wager-threshold uint u10)
(define-data-var maximum-wager-threshold uint u1000000)
(define-data-var platform-fee-percentage uint u250)
(define-data-var liquidity-provider-fee-percentage uint u150)
(define-data-var total-platform-fees-collected uint u0)
(define-data-var minimum-liquidity-amount uint u1000)

;; Data Structure: Prediction Market Details
;; Stores comprehensive information about each prediction market
(define-map prediction-markets
  { market-identifier: uint }
  {
    policy-description: (string-ascii 256),
    resolved-outcome: (optional bool),
    betting-closes-at-block: uint,
    market-expires-at-block: uint,
    market-creator: principal,
    total-liquidity-pool: uint,
    total-yes-wagers: uint,
    total-no-wagers: uint,
    accumulated-fees: uint
  }
)

;; Data Structure: User Wagers
;; Tracks individual user bets on specific prediction markets
(define-map user-wagers
  { market-identifier: uint, participant: principal }
  { wager-amount: uint, predicted-outcome: bool }
)

;; Data Structure: Liquidity Positions
;; Tracks liquidity provider positions in specific markets
(define-map liquidity-positions
  { market-identifier: uint, liquidity-provider: principal }
  {
    liquidity-amount: uint,
    deposit-block: uint,
    earned-fees: uint
  }
)

;; Data Structure: Platform Fee Claims
;; Tracks accumulated fees available for withdrawal by administrators
(define-map fee-beneficiaries
  { beneficiary: principal }
  { accumulated-fees: uint }
)

;; Validation Helper: Check Market ID Validity
;; Ensures the provided market identifier exists in the system
(define-private (validate-market-identifier (market-identifier uint))
  (< market-identifier (var-get next-available-market-id))
)

;; Validation Helper: Check Market Expiration Status
;; Determines if a market has passed its expiration block height
(define-private (check-market-expiration (market-identifier uint))
  (let ((market-data (unwrap! (map-get? prediction-markets { market-identifier: market-identifier }) false)))
    (>= block-height (get market-expires-at-block market-data))
  )
)

;; Validation Helper: Verify Description Length
;; Ensures policy descriptions meet minimum and maximum length requirements
(define-private (validate-description-length (description (string-ascii 256)))
  (and 
    (>= (len description) minimum-policy-description-length)
    (<= (len description) u256)
  )
)

;; Validation Helper: Verify Closing Block Timing
;; Ensures the closing block is within acceptable future range
(define-private (validate-closing-block-height (closing-block uint))
  (let 
    (
      (blocks-until-close (- closing-block block-height))
    )
    (and
      (>= blocks-until-close minimum-closing-block-offset)
      (<= blocks-until-close maximum-closing-block-offset)
    )
  )
)

;; Validation Helper: Verify Expiration Block Timing
;; Ensures expiration occurs after closing within acceptable range
(define-private (validate-expiration-block-height (closing-block uint) (expiration-block uint))
  (let
    (
      (blocks-from-close-to-expiry (- expiration-block closing-block))
    )
    (and
      (> expiration-block closing-block)
      (<= blocks-from-close-to-expiry maximum-expiration-offset)
    )
  )
)

;; Validation Helper: Verify Wager Amount
;; Checks if wager amount falls within configured thresholds
(define-private (validate-wager-amount (amount uint))
  (and
    (>= amount (var-get minimum-wager-threshold))
    (<= amount (var-get maximum-wager-threshold))
  )
)

;; Validation Helper: Verify Fee Percentage
;; Ensures fee percentage is within acceptable range
(define-private (validate-fee-percentage (fee-percentage uint))
  (and
    (>= fee-percentage u0)
    (<= fee-percentage maximum-fee-percentage)
  )
)

;; Calculation Helper: Compute Platform Fee
;; Calculates the fee amount based on wager and fee percentage
(define-private (calculate-platform-fee (wager-amount uint))
  (/ (* wager-amount (var-get platform-fee-percentage)) fee-basis-points)
)

;; Calculation Helper: Compute Liquidity Provider Fee
;; Calculates the liquidity provider fee based on wager amount
(define-private (calculate-liquidity-provider-fee (wager-amount uint))
  (/ (* wager-amount (var-get liquidity-provider-fee-percentage)) fee-basis-points)
)

;; Calculation Helper: Compute Net Wager After Fees
;; Returns the wager amount after deducting all fees
(define-private (calculate-net-wager (wager-amount uint))
  (let
    (
      (platform-fee (calculate-platform-fee wager-amount))
      (lp-fee (calculate-liquidity-provider-fee wager-amount))
    )
    (- wager-amount (+ platform-fee lp-fee))
  )
)

;; Public Function: Create New Prediction Market
;; Allows any user to establish a new market for a policy outcome prediction
;; Parameters:
;;   - policy-description: Detailed description of the policy being predicted
;;   - betting-closes-at-block: Block height when betting period ends
;; Returns: Market identifier on success
(define-public (create-prediction-market (policy-description (string-ascii 256)) (betting-closes-at-block uint))
  (let
    (
      (market-identifier (var-get next-available-market-id))
      (market-expires-at-block (+ betting-closes-at-block (var-get market-expiration-period)))
    )
    (asserts! (validate-description-length policy-description) ERR-INVALID-PARAMETER-VALUE)
    (asserts! (validate-closing-block-height betting-closes-at-block) ERR-INVALID-CLOSING-BLOCK)
    (asserts! (validate-expiration-block-height betting-closes-at-block market-expires-at-block) ERR-INVALID-PARAMETER-VALUE)
    
    (map-set prediction-markets
      { market-identifier: market-identifier }
      {
        policy-description: policy-description,
        resolved-outcome: none,
        betting-closes-at-block: betting-closes-at-block,
        market-expires-at-block: market-expires-at-block,
        market-creator: tx-sender,
        total-liquidity-pool: u0,
        total-yes-wagers: u0,
        total-no-wagers: u0,
        accumulated-fees: u0
      }
    )
    (var-set next-available-market-id (+ market-identifier u1))
    (ok market-identifier)
  )
)

;; Public Function: Place Wager on Market
;; Allows users to bet on their predicted outcome for a specific market
;; Automatically deducts platform and liquidity provider fees
;; Parameters:
;;   - market-identifier: ID of the target prediction market
;;   - predicted-outcome: Boolean representing the predicted result
;;   - wager-amount: Amount of STX tokens to wager
;; Returns: Success confirmation with transaction details
(define-public (submit-wager (market-identifier uint) (predicted-outcome bool) (wager-amount uint))
  (let
    (
      (existing-wager (default-to { wager-amount: u0, predicted-outcome: false } 
                      (map-get? user-wagers { market-identifier: market-identifier, participant: tx-sender })))
    )
    (asserts! (validate-market-identifier market-identifier) ERR-PREDICTION-MARKET-NOT-FOUND)
    (asserts! (validate-wager-amount wager-amount) ERR-INVALID-WAGER)
    (let
      (
        (market-data (unwrap! (map-get? prediction-markets { market-identifier: market-identifier }) ERR-PREDICTION-MARKET-NOT-FOUND))
        (total-wager-amount (+ wager-amount (get wager-amount existing-wager)))
        (platform-fee (calculate-platform-fee wager-amount))
        (lp-fee (calculate-liquidity-provider-fee wager-amount))
        (net-wager (calculate-net-wager wager-amount))
      )
      (asserts! (<= total-wager-amount (var-get maximum-wager-threshold)) ERR-WAGER-EXCEEDS-MAXIMUM)
      (asserts! (< block-height (get betting-closes-at-block market-data)) ERR-BETTING-PERIOD-ENDED)
      (asserts! (is-none (get resolved-outcome market-data)) ERR-OUTCOME-ALREADY-DETERMINED)
      (asserts! (>= (stx-get-balance tx-sender) wager-amount) ERR-INSUFFICIENT-BALANCE)
      
      (map-set user-wagers
        { market-identifier: market-identifier, participant: tx-sender }
        { wager-amount: total-wager-amount, predicted-outcome: predicted-outcome }
      )
      
      (map-set prediction-markets
        { market-identifier: market-identifier }
        (merge market-data {
          total-yes-wagers: (if predicted-outcome 
            (+ (get total-yes-wagers market-data) net-wager)
            (get total-yes-wagers market-data)),
          total-no-wagers: (if predicted-outcome
            (get total-no-wagers market-data)
            (+ (get total-no-wagers market-data) net-wager)),
          accumulated-fees: (+ (get accumulated-fees market-data) lp-fee)
        })
      )
      
      (var-set total-platform-fees-collected 
        (+ (var-get total-platform-fees-collected) platform-fee))
      
      (try! (stx-transfer? wager-amount tx-sender (as-contract tx-sender)))
      (ok { net-wager: net-wager, platform-fee: platform-fee, lp-fee: lp-fee })
    )
  )
)

;; Public Function: Resolve Market Outcome
;; Allows market creator to set the final outcome after betting closes
;; Parameters:
;;   - market-identifier: ID of the market to resolve
;;   - actual-outcome: The actual policy outcome (true/false)
;; Returns: Success confirmation
(define-public (determine-market-outcome (market-identifier uint) (actual-outcome bool))
  (let
    (
      (market-data (unwrap! (map-get? prediction-markets { market-identifier: market-identifier }) ERR-PREDICTION-MARKET-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get market-creator market-data)) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (>= block-height (get betting-closes-at-block market-data)) ERR-BETTING-STILL-ACTIVE)
    (asserts! (is-none (get resolved-outcome market-data)) ERR-OUTCOME-ALREADY-DETERMINED)
    (asserts! (not (check-market-expiration market-identifier)) ERR-LIFECYCLE-EXPIRED)
    
    (map-set prediction-markets
      { market-identifier: market-identifier }
      (merge market-data { resolved-outcome: (some actual-outcome) })
    )
    (ok true)
  )
)

;; Public Function: Claim Winning Rewards
;; Allows users with correct predictions to claim their winnings
;; Parameters:
;;   - market-identifier: ID of the resolved market
;; Returns: Amount of STX transferred to winner
(define-public (withdraw-winnings (market-identifier uint))
  (let
    (
      (market-data (unwrap! (map-get? prediction-markets { market-identifier: market-identifier }) ERR-PREDICTION-MARKET-NOT-FOUND))
      (user-wager (unwrap! (map-get? user-wagers { market-identifier: market-identifier, participant: tx-sender }) ERR-WAGER-NOT-FOUND))
      (final-outcome (unwrap! (get resolved-outcome market-data) ERR-OUTCOME-NOT-DETERMINED))
    )
    (asserts! (is-eq (get predicted-outcome user-wager) final-outcome) ERR-INCORRECT-PREDICTION)
    
    (map-delete user-wagers { market-identifier: market-identifier, participant: tx-sender })
    (as-contract (stx-transfer? (get wager-amount user-wager) tx-sender tx-sender))
  )
)

;; Public Function: Refund Expired Market Wager
;; Allows users to reclaim wagers from unresolved expired markets
;; Parameters:
;;   - market-identifier: ID of the expired market
;; Returns: Amount of STX refunded to user
(define-public (reclaim-expired-wager (market-identifier uint))
  (let
    (
      (market-data (unwrap! (map-get? prediction-markets { market-identifier: market-identifier }) ERR-PREDICTION-MARKET-NOT-FOUND))
      (user-wager (unwrap! (map-get? user-wagers { market-identifier: market-identifier, participant: tx-sender }) ERR-WAGER-NOT-FOUND))
    )
    (asserts! (check-market-expiration market-identifier) ERR-LIFECYCLE-NOT-EXPIRED)
    (asserts! (is-none (get resolved-outcome market-data)) ERR-OUTCOME-ALREADY-DETERMINED)
    
    (map-delete user-wagers { market-identifier: market-identifier, participant: tx-sender })
    (as-contract (stx-transfer? (get wager-amount user-wager) tx-sender tx-sender))
  )
)

;; Public Function: Remove Expired Market
;; Allows market creator to clean up expired unresolved markets
;; Parameters:
;;   - market-identifier: ID of the expired market to remove
;; Returns: Success confirmation
(define-public (remove-expired-market (market-identifier uint))
  (let
    (
      (market-data (unwrap! (map-get? prediction-markets { market-identifier: market-identifier }) ERR-PREDICTION-MARKET-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get market-creator market-data)) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (check-market-expiration market-identifier) ERR-LIFECYCLE-NOT-EXPIRED)
    (asserts! (is-none (get resolved-outcome market-data)) ERR-OUTCOME-ALREADY-DETERMINED)
    
    (map-delete prediction-markets { market-identifier: market-identifier })
    (ok true)
  )
)

;; LIQUIDITY POOL SYSTEM

;; Public Function: Provide Liquidity to Market
;; Allows users to become liquidity providers for a specific market
;; Liquidity providers earn fees from all wagers placed on the market
;; Parameters:
;;   - market-identifier: ID of the market to provide liquidity for
;;   - liquidity-amount: Amount of STX to provide as liquidity
;; Returns: Success confirmation with liquidity position details
(define-public (provide-market-liquidity (market-identifier uint) (liquidity-amount uint))
  (let
    (
      (market-data (unwrap! (map-get? prediction-markets { market-identifier: market-identifier }) ERR-PREDICTION-MARKET-NOT-FOUND))
      (existing-position (map-get? liquidity-positions { market-identifier: market-identifier, liquidity-provider: tx-sender }))
    )
    (asserts! (is-none existing-position) ERR-LIQUIDITY-ALREADY-PROVIDED)
    (asserts! (>= liquidity-amount (var-get minimum-liquidity-amount)) ERR-INVALID-PARAMETER-VALUE)
    (asserts! (< block-height (get betting-closes-at-block market-data)) ERR-BETTING-PERIOD-ENDED)
    (asserts! (>= (stx-get-balance tx-sender) liquidity-amount) ERR-INSUFFICIENT-BALANCE)
    
    (map-set liquidity-positions
      { market-identifier: market-identifier, liquidity-provider: tx-sender }
      {
        liquidity-amount: liquidity-amount,
        deposit-block: block-height,
        earned-fees: u0
      }
    )
    
    (map-set prediction-markets
      { market-identifier: market-identifier }
      (merge market-data {
        total-liquidity-pool: (+ (get total-liquidity-pool market-data) liquidity-amount)
      })
    )
    
    (try! (stx-transfer? liquidity-amount tx-sender (as-contract tx-sender)))
    (ok { liquidity-amount: liquidity-amount, deposit-block: block-height })
  )
)

;; Public Function: Withdraw Liquidity from Market
;; Allows liquidity providers to withdraw their position plus earned fees
;; Can only withdraw after market is resolved or expired, and after lock period
;; Parameters:
;;   - market-identifier: ID of the market to withdraw liquidity from
;; Returns: Amount withdrawn including principal and earned fees
(define-public (withdraw-market-liquidity (market-identifier uint))
  (let
    (
      (market-data (unwrap! (map-get? prediction-markets { market-identifier: market-identifier }) ERR-PREDICTION-MARKET-NOT-FOUND))
      (liquidity-position (unwrap! (map-get? liquidity-positions { market-identifier: market-identifier, liquidity-provider: tx-sender }) ERR-NO-LIQUIDITY-POSITION))
      (lock-expired (>= block-height (+ (get deposit-block liquidity-position) minimum-liquidity-lock-period)))
    )
    (asserts! lock-expired ERR-LIQUIDITY-LOCKED)
    (asserts! (or 
      (is-some (get resolved-outcome market-data))
      (check-market-expiration market-identifier)
    ) ERR-BETTING-STILL-ACTIVE)
    
    (let
      (
        (provider-share (if (> (get total-liquidity-pool market-data) u0)
          (/ (* (get accumulated-fees market-data) (get liquidity-amount liquidity-position)) 
             (get total-liquidity-pool market-data))
          u0))
        (total-withdrawal (+ (get liquidity-amount liquidity-position) provider-share))
      )
      (map-delete liquidity-positions { market-identifier: market-identifier, liquidity-provider: tx-sender })
      
      (map-set prediction-markets
        { market-identifier: market-identifier }
        (merge market-data {
          total-liquidity-pool: (- (get total-liquidity-pool market-data) (get liquidity-amount liquidity-position)),
          accumulated-fees: (- (get accumulated-fees market-data) provider-share)
        })
      )
      
      (as-contract (stx-transfer? total-withdrawal tx-sender tx-sender))
    )
  )
)

;; Public Function: Calculate Liquidity Provider Earnings
;; Read-only helper to calculate potential earnings for a liquidity provider
;; Parameters:
;;   - market-identifier: ID of the market
;;   - liquidity-provider: Principal of the liquidity provider
;; Returns: Calculated earnings based on current accumulated fees
(define-read-only (calculate-liquidity-earnings (market-identifier uint) (liquidity-provider principal))
  (let
    (
      (market-data (unwrap! (map-get? prediction-markets { market-identifier: market-identifier }) ERR-PREDICTION-MARKET-NOT-FOUND))
      (liquidity-position (unwrap! (map-get? liquidity-positions { market-identifier: market-identifier, liquidity-provider: liquidity-provider }) ERR-NO-LIQUIDITY-POSITION))
    )
    (ok (if (> (get total-liquidity-pool market-data) u0)
      (/ (* (get accumulated-fees market-data) (get liquidity-amount liquidity-position)) 
         (get total-liquidity-pool market-data))
      u0))
  )
)

;; FEE COLLECTION AND DISTRIBUTION SYSTEM

;; Public Function: Withdraw Platform Fees
;; Allows platform administrator to withdraw accumulated platform fees
;; Parameters:
;;   - withdrawal-amount: Amount of fees to withdraw
;; Returns: Success confirmation with withdrawal amount
(define-public (withdraw-platform-fees (withdrawal-amount uint))
  (let
    (
      (available-fees (var-get total-platform-fees-collected))
    )
    (asserts! (is-eq tx-sender (var-get platform-administrator)) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (> withdrawal-amount u0) ERR-INVALID-PARAMETER-VALUE)
    (asserts! (<= withdrawal-amount available-fees) ERR-NO-FEES-TO-COLLECT)
    
    (var-set total-platform-fees-collected (- available-fees withdrawal-amount))
    (as-contract (stx-transfer? withdrawal-amount tx-sender (var-get platform-administrator)))
  )
)

;; Public Function: Allocate Fees to Beneficiary
;; Allows platform administrator to allocate fees to specific beneficiaries
;; Useful for distributing fees to stakeholders, treasury, or development fund
;; Parameters:
;;   - beneficiary: Principal to receive fee allocation
;;   - allocation-amount: Amount of fees to allocate
;; Returns: Success confirmation
(define-public (allocate-fees-to-beneficiary (beneficiary principal) (allocation-amount uint))
  (let
    (
      (available-fees (var-get total-platform-fees-collected))
      (existing-beneficiary (default-to { accumulated-fees: u0 } 
        (map-get? fee-beneficiaries { beneficiary: beneficiary })))
    )
    (asserts! (is-eq tx-sender (var-get platform-administrator)) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (> allocation-amount u0) ERR-INVALID-PARAMETER-VALUE)
    (asserts! (<= allocation-amount available-fees) ERR-NO-FEES-TO-COLLECT)
    
    (var-set total-platform-fees-collected (- available-fees allocation-amount))
    
    (map-set fee-beneficiaries
      { beneficiary: beneficiary }
      { accumulated-fees: (+ (get accumulated-fees existing-beneficiary) allocation-amount) }
    )
    (ok allocation-amount)
  )
)

;; Public Function: Claim Allocated Fees
;; Allows beneficiaries to claim their allocated fees
;; Parameters: None (uses tx-sender as beneficiary)
;; Returns: Amount claimed
(define-public (claim-allocated-fees)
  (let
    (
      (beneficiary-data (unwrap! (map-get? fee-beneficiaries { beneficiary: tx-sender }) ERR-NO-FEES-TO-COLLECT))
      (claimable-amount (get accumulated-fees beneficiary-data))
    )
    (asserts! (> claimable-amount u0) ERR-NO-FEES-TO-COLLECT)
    
    (map-set fee-beneficiaries
      { beneficiary: tx-sender }
      { accumulated-fees: u0 }
    )
    
    (as-contract (stx-transfer? claimable-amount tx-sender tx-sender))
  )
)

;; Admin Function: Update Platform Fee Percentage
;; Allows platform administrator to adjust the platform fee rate
;; Parameters:
;;   - new-fee-percentage: New fee percentage in basis points (100 = 1%)
;; Returns: Success confirmation
(define-public (update-platform-fee-percentage (new-fee-percentage uint))
  (begin
    (asserts! (is-eq tx-sender (var-get platform-administrator)) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (validate-fee-percentage new-fee-percentage) ERR-INVALID-FEE-PERCENTAGE)
    (ok (var-set platform-fee-percentage new-fee-percentage))
  )
)

;; Admin Function: Update Liquidity Provider Fee Percentage
;; Allows platform administrator to adjust the LP fee rate
;; Parameters:
;;   - new-fee-percentage: New fee percentage in basis points (100 = 1%)
;; Returns: Success confirmation
(define-public (update-liquidity-provider-fee-percentage (new-fee-percentage uint))
  (begin
    (asserts! (is-eq tx-sender (var-get platform-administrator)) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (validate-fee-percentage new-fee-percentage) ERR-INVALID-FEE-PERCENTAGE)
    (ok (var-set liquidity-provider-fee-percentage new-fee-percentage))
  )
)

;; Admin Function: Update Minimum Liquidity Amount
;; Allows platform administrator to set minimum liquidity requirement
;; Parameters:
;;   - new-minimum: New minimum liquidity amount
;; Returns: Success confirmation
(define-public (update-minimum-liquidity-amount (new-minimum uint))
  (begin
    (asserts! (is-eq tx-sender (var-get platform-administrator)) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (>= new-minimum u100) ERR-INVALID-PARAMETER-VALUE)
    (ok (var-set minimum-liquidity-amount new-minimum))
  )
)

;; Admin Function: Update Expiration Period
;; Allows platform administrator to modify the default market expiration period
;; Parameters:
;;   - new-period: New expiration period in blocks
;; Returns: Success confirmation
(define-public (update-expiration-period (new-period uint))
  (begin
    (asserts! (is-eq tx-sender (var-get platform-administrator)) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (and 
      (>= new-period u1000)
      (<= new-period u52560)
    ) ERR-INVALID-PARAMETER-VALUE)
    (ok (var-set market-expiration-period new-period))
  )
)

;; Admin Function: Update Minimum Wager Amount
;; Allows platform administrator to set the minimum allowable wager
;; Parameters:
;;   - new-minimum: New minimum wager amount
;; Returns: Success confirmation
(define-public (update-minimum-wager (new-minimum uint))
  (begin
    (asserts! (is-eq tx-sender (var-get platform-administrator)) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (and 
      (>= new-minimum u1)
      (< new-minimum (var-get maximum-wager-threshold))
      (<= new-minimum u1000000)
    ) ERR-INVALID-PARAMETER-VALUE)
    (ok (var-set minimum-wager-threshold new-minimum))
  )
)

;; Admin Function: Update Maximum Wager Amount
;; Allows platform administrator to set the maximum allowable wager
;; Parameters:
;;   - new-maximum: New maximum wager amount
;; Returns: Success confirmation
(define-public (update-maximum-wager (new-maximum uint))
  (begin
    (asserts! (is-eq tx-sender (var-get platform-administrator)) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (and 
      (> new-maximum (var-get minimum-wager-threshold))
      (<= new-maximum u1000000000000)
      (>= new-maximum u1000)
    ) ERR-INVALID-PARAMETER-VALUE)
    (ok (var-set maximum-wager-threshold new-maximum))
  )
)

;; Read-Only Function: Get Platform Administrator
;; Returns the current platform administrator principal
;; Returns: Administrator principal address
(define-read-only (get-platform-administrator)
  (ok (var-get platform-administrator))
)

;; Admin Function: Transfer Platform Ownership
;; Allows current administrator to transfer control to a new principal
;; Parameters:
;;   - new-administrator: Principal address of the new administrator
;; Returns: Success confirmation
(define-public (transfer-platform-ownership (new-administrator principal))
  (begin
    (asserts! (is-eq tx-sender (var-get platform-administrator)) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (not (is-eq new-administrator (var-get platform-administrator))) ERR-INVALID-PARAMETER-VALUE)
    (ok (var-set platform-administrator new-administrator))
  )
)

;; Read-Only Function: Get Market Details
;; Retrieves complete information about a specific prediction market
;; Parameters:
;;   - market-identifier: ID of the market to query
;; Returns: Market details or error if not found
(define-read-only (get-market-information (market-identifier uint))
  (ok (unwrap! (map-get? prediction-markets { market-identifier: market-identifier }) ERR-PREDICTION-MARKET-NOT-FOUND))
)

;; Read-Only Function: Get User Wager Details
;; Retrieves wager information for a specific user on a specific market
;; Parameters:
;;   - market-identifier: ID of the market
;;   - participant: Principal address of the user
;; Returns: Wager details or error if not found
(define-read-only (get-wager-information (market-identifier uint) (participant principal))
  (ok (unwrap! (map-get? user-wagers { market-identifier: market-identifier, participant: participant }) ERR-WAGER-NOT-FOUND))
)

;; Read-Only Function: Get Platform Configuration
;; Returns current platform settings and thresholds
;; Returns: Configuration details including expiration period and wager limits
(define-read-only (get-platform-configuration)
  (ok {
    expiration-period: (var-get market-expiration-period),
    minimum-wager: (var-get minimum-wager-threshold),
    maximum-wager: (var-get maximum-wager-threshold),
    next-market-id: (var-get next-available-market-id),
    platform-fee-percentage: (var-get platform-fee-percentage),
    liquidity-provider-fee-percentage: (var-get liquidity-provider-fee-percentage),
    total-platform-fees: (var-get total-platform-fees-collected),
    minimum-liquidity: (var-get minimum-liquidity-amount)
  })
)

;; Read-Only Function: Get Liquidity Position Details
;; Retrieves liquidity provider position information
;; Parameters:
;;   - market-identifier: ID of the market
;;   - liquidity-provider: Principal of the liquidity provider
;; Returns: Liquidity position details or error if not found
(define-read-only (get-liquidity-position (market-identifier uint) (liquidity-provider principal))
  (ok (unwrap! (map-get? liquidity-positions { market-identifier: market-identifier, liquidity-provider: liquidity-provider }) ERR-NO-LIQUIDITY-POSITION))
)

;; Read-Only Function: Get Fee Beneficiary Details
;; Retrieves accumulated fees for a specific beneficiary
;; Parameters:
;;   - beneficiary: Principal of the fee beneficiary
;; Returns: Beneficiary details or error if not found
(define-read-only (get-beneficiary-fees (beneficiary principal))
  (ok (unwrap! (map-get? fee-beneficiaries { beneficiary: beneficiary }) ERR-NO-FEES-TO-COLLECT))
)

;; Read-Only Function: Get Market Statistics
;; Provides comprehensive statistics about a market including liquidity and volume
;; Parameters:
;;   - market-identifier: ID of the market
;; Returns: Market statistics including wager totals and liquidity
(define-read-only (get-market-statistics (market-identifier uint))
  (let
    (
      (market-data (unwrap! (map-get? prediction-markets { market-identifier: market-identifier }) ERR-PREDICTION-MARKET-NOT-FOUND))
    )
    (ok {
      total-liquidity: (get total-liquidity-pool market-data),
      total-yes-wagers: (get total-yes-wagers market-data),
      total-no-wagers: (get total-no-wagers market-data),
      total-volume: (+ (get total-yes-wagers market-data) (get total-no-wagers market-data)),
      accumulated-fees: (get accumulated-fees market-data),
      is-resolved: (is-some (get resolved-outcome market-data)),
      is-expired: (check-market-expiration market-identifier)
    })
  )
)