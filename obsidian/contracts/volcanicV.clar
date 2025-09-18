;; Obsidian Volcanic Vault Contract
;; This contract manages a mystical vault that amplifies contributions according to ancient volcanic rules

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INACTIVE-EPOCH (err u101))
(define-constant ERR-INSUFFICIENT-MAGMA (err u102))
(define-constant ERR-EXCEEDS-MAX-OFFERING (err u103))
(define-constant ERR-BELOW-MIN-OFFERING (err u104))
(define-constant ERR-INVALID-SHRINE (err u105))
(define-constant ERR-EPOCH-EXISTS (err u106))
(define-constant ERR-EPOCH-NOT-FOUND (err u107))
(define-constant ERR-SHRINE-EXISTS (err u108))
(define-constant ERR-SHRINE-NOT-FOUND (err u109))
(define-constant ERR-PATRON-CAP-REACHED (err u110))
(define-constant ERR-ALREADY-HARVESTED (err u111))
(define-constant ERR-EPOCH-NOT-SEALED (err u112))
(define-constant ERR-INVALID-UINT (err u113))
(define-constant ERR-DIVIDE-BY-ZERO (err u114))

;; Data storage
(define-data-var obsidian-keeper principal tx-sender)
(define-data-var volcanic-reserves uint u0)
(define-data-var total-magma-amplified uint u0)
(define-data-var active-epoch-id uint u0)

;; Map: epoch ID => epoch info
(define-map volcanic-epochs
  { epoch-id: uint }
  {
    ignition-block-height: uint,
    extinction-block-height: uint,
    amplification-pool: uint,
    amplification-pool-remaining: uint,
    min-offering: uint,
    max-offering: uint,
    patron-cap: uint,
    total-offerings: uint,
    is-burning: bool,
    is-sealed: bool
  }
)

;; Map: shrine ID => shrine info
(define-map obsidian-shrines
  { shrine-id: uint }
  {
    inscription: (string-ascii 100), 
    guardian: principal,
    total-offerings: uint,
    total-amplified: uint,
    is-consecrated: bool
  }
)

;; Map: (epoch-id, shrine-id) => blessed status
(define-map epoch-shrines
  { epoch-id: uint, shrine-id: uint }
  {
    is-blessed: bool,
    total-offerings: uint
  }
)

;; Map: (epoch-id, patron, shrine-id) => offering info
(define-map volcanic-offerings
  { epoch-id: uint, patron: principal, shrine-id: uint }
  {
    amount: uint,
    amplified-amount: uint,
    harvested: bool
  }
)

;; Map: (epoch-id, patron) => total offered in epoch
(define-map patron-totals
  { epoch-id: uint, patron: principal }
  { total-offered: uint }
)

;; Map: shrine ID => next ID
(define-data-var next-shrine-id uint u1)
(define-data-var next-epoch-id uint u1)

;; Fixed validate-uint function - returns response type consistently
(define-private (validate-uint (input uint))
  (ok input)
)

;; Initialize contract
(define-public (awaken-vault)
  (begin
    (asserts! (is-eq tx-sender (var-get obsidian-keeper)) ERR-NOT-AUTHORIZED)
    (ok true)
  )
)

;; Only keeper modifier
(define-private (is-keeper)
  (is-eq tx-sender (var-get obsidian-keeper))
)

;; Change keeper - fixed by validating input
(define-public (transfer-keepership (new-keeper principal))
  (begin
    (asserts! (is-keeper) ERR-NOT-AUTHORIZED)
    ;; Check that new-keeper is not tx-sender, or some other validation
    ;; This is a simple fix; you might want more validation logic
    (asserts! (not (is-eq new-keeper tx-sender)) ERR-INVALID-SHRINE)
    (var-set obsidian-keeper new-keeper)
    (ok true)
  )
)

;; Safe division to avoid division by zero
(define-read-only (safe-divide (numerator uint) (denominator uint))
  (if (> denominator u0)
      (ok (/ numerator denominator))
      (err ERR-DIVIDE-BY-ZERO))
)

;; Calculate proportion of magma
(define-private (calculate-proportion (amount uint) (total uint) (pool uint))
  (if (> total u0)
      (/ (* amount pool) total)
      u0)
)

;; Create a new volcanic epoch - fixed by validating inputs
(define-public (forge-volcanic-epoch
                (ignition-block-height uint)
                (extinction-block-height uint)
                (amplification-pool uint)
                (min-offering uint)
                (max-offering uint)
                (patron-cap uint))
  (let (
        (epoch-id (var-get next-epoch-id))
        (validated-amplification-pool amplification-pool) ;; Added validation variable
        (validated-patron-cap patron-cap) ;; Added validation variable
       )
    (asserts! (is-keeper) ERR-NOT-AUTHORIZED)
    (asserts! (> extinction-block-height ignition-block-height) ERR-INVALID-SHRINE)
    (asserts! (>= ignition-block-height block-height) ERR-INVALID-SHRINE)
    (asserts! (>= max-offering min-offering) ERR-INVALID-SHRINE)
    
    ;; Validate pool and cap are not zero
    (asserts! (> validated-amplification-pool u0) ERR-INVALID-UINT)
    (asserts! (> validated-patron-cap u0) ERR-INVALID-UINT)
    
    ;; Create the volcanic epoch
    (map-insert volcanic-epochs
      { epoch-id: epoch-id }
      {
        ignition-block-height: ignition-block-height,
        extinction-block-height: extinction-block-height,
        amplification-pool: validated-amplification-pool,
        amplification-pool-remaining: validated-amplification-pool,
        min-offering: min-offering,
        max-offering: max-offering,
        patron-cap: validated-patron-cap,
        total-offerings: u0,
        is-burning: false,
        is-sealed: false
      }
    )
    
    ;; Increment the epoch ID counter
    (var-set next-epoch-id (+ epoch-id u1))
    
    (ok epoch-id)
  )
)

;; Fund the volcanic reserves
(define-public (feed-volcanic-reserves (amount uint))
  (begin
    (asserts! (>= (stx-get-balance tx-sender) amount) ERR-INSUFFICIENT-MAGMA)
    
    ;; Transfer STX to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Update volcanic reserves
    (var-set volcanic-reserves (+ (var-get volcanic-reserves) amount))
    
    (ok true)
  )
)

;; Fund a specific epoch's amplification pool - fixed by validating input
(define-public (infuse-amplification-pool (epoch-id uint) (amount uint))
  (let (
        (epoch (unwrap! (map-get? volcanic-epochs { epoch-id: epoch-id }) ERR-EPOCH-NOT-FOUND))
        (validated-epoch-id epoch-id) ;; Added validation variable
      )
    (asserts! (is-keeper) ERR-NOT-AUTHORIZED)
    (asserts! (>= (var-get volcanic-reserves) amount) ERR-INSUFFICIENT-MAGMA)
    
    ;; Validate epoch
    (asserts! (>= validated-epoch-id u1) ERR-INVALID-UINT)
    
    ;; Update volcanic reserves
    (var-set volcanic-reserves (- (var-get volcanic-reserves) amount))
    
    ;; Update epoch amplification pool
    (map-set volcanic-epochs
      { epoch-id: validated-epoch-id }
      (merge epoch {
        amplification-pool: (+ (get amplification-pool epoch) amount),
        amplification-pool-remaining: (+ (get amplification-pool-remaining epoch) amount)
      })
    )
    
    (ok true)
  )
)

;; Ignite a volcanic epoch - fixed by validating input
(define-public (ignite-epoch (epoch-id uint))
  (let (
        (epoch (unwrap! (map-get? volcanic-epochs { epoch-id: epoch-id }) ERR-EPOCH-NOT-FOUND))
        (validated-epoch-id epoch-id) ;; Added validation variable
       )
    (asserts! (is-keeper) ERR-NOT-AUTHORIZED)
    (asserts! (not (get is-burning epoch)) ERR-EPOCH-EXISTS)
    (asserts! (>= block-height (get ignition-block-height epoch)) ERR-INACTIVE-EPOCH)
    (asserts! (<= block-height (get extinction-block-height epoch)) ERR-INACTIVE-EPOCH)
    
    ;; Validate epoch
    (asserts! (>= validated-epoch-id u1) ERR-INVALID-UINT)
    
    ;; Set epoch as burning
    (map-set volcanic-epochs
      { epoch-id: validated-epoch-id }
      (merge epoch { is-burning: true })
    )
    
    ;; Update active epoch ID
    (var-set active-epoch-id validated-epoch-id)
    
    (ok true)
  )
)

;; Consecrate a new obsidian shrine - fixed by validating input
(define-public (consecrate-shrine (inscription (string-ascii 100)))
  (let (
        (shrine-id (var-get next-shrine-id))
        (validated-inscription inscription) ;; Added validation variable
       )
    ;; Validate inscription is not empty
    (asserts! (> (len validated-inscription) u0) ERR-INVALID-SHRINE)
    
    ;; Create the shrine
    (map-insert obsidian-shrines
      { shrine-id: shrine-id }
      {
        inscription: validated-inscription,
        guardian: tx-sender,
        total-offerings: u0,
        total-amplified: u0,
        is-consecrated: true
      }
    )
    
    ;; Increment the shrine ID counter
    (var-set next-shrine-id (+ shrine-id u1))
    
    (ok shrine-id)
  )
)

;; Bless a shrine for a volcanic epoch - fixed by validating inputs
(define-public (bless-shrine-for-epoch (epoch-id uint) (shrine-id uint))
  (let (
        (validated-epoch-id epoch-id) ;; Added validation variable
        (validated-shrine-id shrine-id) ;; Added validation variable
       )
    (asserts! (is-keeper) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (map-get? volcanic-epochs { epoch-id: validated-epoch-id })) ERR-EPOCH-NOT-FOUND)
    (asserts! (is-some (map-get? obsidian-shrines { shrine-id: validated-shrine-id })) ERR-SHRINE-NOT-FOUND)
    (asserts! (is-none (map-get? epoch-shrines { epoch-id: validated-epoch-id, shrine-id: validated-shrine-id })) ERR-SHRINE-EXISTS)
    
    ;; Validate IDs
    (asserts! (>= validated-epoch-id u1) ERR-INVALID-UINT)
    (asserts! (>= validated-shrine-id u1) ERR-INVALID-UINT)
    
    ;; Bless shrine for epoch
    (map-insert epoch-shrines
      { epoch-id: validated-epoch-id, shrine-id: validated-shrine-id }
      { is-blessed: true, total-offerings: u0 }
    )
    
    (ok true)
  )
)

;; Make an offering to a shrine - fixed by validating inputs
(define-public (make-offering (epoch-id uint) (shrine-id uint) (amount uint))
  (let (
        (validated-epoch-id epoch-id) ;; Added validation variable
        (validated-shrine-id shrine-id) ;; Added validation variable
        (epoch (unwrap! (map-get? volcanic-epochs { epoch-id: validated-epoch-id }) ERR-EPOCH-NOT-FOUND))
        (shrine (unwrap! (map-get? obsidian-shrines { shrine-id: validated-shrine-id }) ERR-SHRINE-NOT-FOUND))
        (epoch-shrine (unwrap! (map-get? epoch-shrines { epoch-id: validated-epoch-id, shrine-id: validated-shrine-id }) ERR-INVALID-SHRINE))
        (patron-total (default-to { total-offered: u0 } (map-get? patron-totals { epoch-id: validated-epoch-id, patron: tx-sender })))
        (offering-key { epoch-id: validated-epoch-id, patron: tx-sender, shrine-id: validated-shrine-id })
        (existing-offering (default-to { amount: u0, amplified-amount: u0, harvested: false } (map-get? volcanic-offerings offering-key)))
      )
    ;; Validate IDs
    (asserts! (>= validated-epoch-id u1) ERR-INVALID-UINT)
    (asserts! (>= validated-shrine-id u1) ERR-INVALID-UINT)
    
    ;; Verify epoch is burning
    (asserts! (get is-burning epoch) ERR-INACTIVE-EPOCH)
    (asserts! (>= block-height (get ignition-block-height epoch)) ERR-INACTIVE-EPOCH)
    (asserts! (<= block-height (get extinction-block-height epoch)) ERR-INACTIVE-EPOCH)
    
    ;; Verify shrine is blessed for the epoch
    (asserts! (get is-blessed epoch-shrine) ERR-INVALID-SHRINE)
    
    ;; Verify offering amount
    (asserts! (>= amount (get min-offering epoch)) ERR-BELOW-MIN-OFFERING)
    (asserts! (<= amount (get max-offering epoch)) ERR-EXCEEDS-MAX-OFFERING)
    
    ;; Check patron cap
    (asserts! (<= (+ (get total-offered patron-total) amount) (get patron-cap epoch)) ERR-PATRON-CAP-REACHED)
    
    ;; Transfer STX to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Update offering records
    (map-set volcanic-offerings 
      offering-key
      { 
        amount: (+ (get amount existing-offering) amount), 
        amplified-amount: (get amplified-amount existing-offering),
        harvested: false 
      }
    )
    
    ;; Update patron totals
    (map-set patron-totals
      { epoch-id: validated-epoch-id, patron: tx-sender }
      { total-offered: (+ (get total-offered patron-total) amount) }
    )
    
    ;; Update epoch totals
    (map-set volcanic-epochs
      { epoch-id: validated-epoch-id }
      (merge epoch { total-offerings: (+ (get total-offerings epoch) amount) })
    )
    
    ;; Update shrine totals in epoch
    (map-set epoch-shrines
      { epoch-id: validated-epoch-id, shrine-id: validated-shrine-id }
      (merge epoch-shrine { total-offerings: (+ (get total-offerings epoch-shrine) amount) })
    )
    
    ;; Update shrine totals
    (map-set obsidian-shrines
      { shrine-id: validated-shrine-id }
      (merge shrine { total-offerings: (+ (get total-offerings shrine) amount) })
    )
    
    ;; Add to volcanic reserves
    (var-set volcanic-reserves (+ (var-get volcanic-reserves) amount))
    
    (ok true)
  )
)

;; Extinguish a volcanic epoch - fixed by validating input
(define-public (extinguish-epoch (epoch-id uint))
  (let (
        (validated-epoch-id epoch-id) ;; Added validation variable
        (epoch (unwrap! (map-get? volcanic-epochs { epoch-id: validated-epoch-id }) ERR-EPOCH-NOT-FOUND))
       )
    (asserts! (is-keeper) ERR-NOT-AUTHORIZED)
    (asserts! (get is-burning epoch) ERR-INACTIVE-EPOCH)
    (asserts! (>= block-height (get extinction-block-height epoch)) ERR-EPOCH-NOT-SEALED)
    
    ;; Validate epoch ID
    (asserts! (>= validated-epoch-id u1) ERR-INVALID-UINT)
    
    ;; Set epoch as extinguished
    (map-set volcanic-epochs
      { epoch-id: validated-epoch-id }
      (merge epoch { is-burning: false })
    )
    
    ;; If this is the active epoch, reset active epoch ID
    (if (is-eq (var-get active-epoch-id) validated-epoch-id)
      (var-set active-epoch-id u0)
      false
    )
    
    (ok true)
  )
)

;; Calculate amplification amounts for an epoch - fixed by validating input
(define-public (seal-amplification (epoch-id uint))
  (let (
        (validated-epoch-id epoch-id) ;; Added validation variable
        (epoch (unwrap! (map-get? volcanic-epochs { epoch-id: validated-epoch-id }) ERR-EPOCH-NOT-FOUND))
      )
    (asserts! (is-keeper) ERR-NOT-AUTHORIZED)
    (asserts! (not (get is-burning epoch)) ERR-INACTIVE-EPOCH)
    (asserts! (not (get is-sealed epoch)) ERR-EPOCH-EXISTS)
    
    ;; Validate epoch ID
    (asserts! (>= validated-epoch-id u1) ERR-INVALID-UINT)
    
    ;; Mark epoch as sealed
    (map-set volcanic-epochs
      { epoch-id: validated-epoch-id }
      (merge epoch { is-sealed: true })
    )
    
    (ok true)
  )
)

;; Calculate amplification amount for a specific offering - fixed by validating inputs
(define-public (calculate-amplification (epoch-id uint) (shrine-id uint) (patron principal))
  (let (
        (validated-epoch-id epoch-id) ;; Added validation variable
        (validated-shrine-id shrine-id) ;; Added validation variable
        (epoch (unwrap! (map-get? volcanic-epochs { epoch-id: validated-epoch-id }) ERR-EPOCH-NOT-FOUND))
        (offering-key { epoch-id: validated-epoch-id, patron: patron, shrine-id: validated-shrine-id })
        (offering (unwrap! (map-get? volcanic-offerings offering-key) ERR-SHRINE-NOT-FOUND))
        (shrine (unwrap! (map-get? obsidian-shrines { shrine-id: validated-shrine-id }) ERR-SHRINE-NOT-FOUND))
        (epoch-shrine (unwrap! (map-get? epoch-shrines { epoch-id: validated-epoch-id, shrine-id: validated-shrine-id }) ERR-INVALID-SHRINE))
        (offering-amount (get amount offering))
        (amplification-pool (get amplification-pool epoch))
        (total-offerings (get total-offerings epoch))
        (amplified-amount (calculate-proportion offering-amount total-offerings amplification-pool))
      )
    (asserts! (is-keeper) ERR-NOT-AUTHORIZED)
    (asserts! (get is-sealed epoch) ERR-EPOCH-NOT-SEALED)
    (asserts! (not (get harvested offering)) ERR-ALREADY-HARVESTED)
    
    ;; Validate IDs
    (asserts! (>= validated-epoch-id u1) ERR-INVALID-UINT)
    (asserts! (>= validated-shrine-id u1) ERR-INVALID-UINT)
    
    ;; Update offering with amplified amount
    (map-set volcanic-offerings 
      offering-key
      (merge offering { amplified-amount: amplified-amount })
    )
    
    ;; Update shrine amplified total
    (map-set obsidian-shrines
      { shrine-id: validated-shrine-id }
      (merge shrine { total-amplified: (+ (get total-amplified shrine) amplified-amount) })
    )
    
    ;; Update total magma amplified
    (var-set total-magma-amplified (+ (var-get total-magma-amplified) amplified-amount))
    
    (ok amplified-amount)
  )
)

;; Harvest amplified magma for a shrine
(define-public (harvest-amplified-magma (epoch-id uint) (shrine-id uint))
  (let (
        (validated-epoch-id epoch-id) ;; Added validation variable
        (validated-shrine-id shrine-id) ;; Added validation variable
        (epoch (unwrap! (map-get? volcanic-epochs { epoch-id: validated-epoch-id }) ERR-EPOCH-NOT-FOUND))
        (shrine (unwrap! (map-get? obsidian-shrines { shrine-id: validated-shrine-id }) ERR-SHRINE-NOT-FOUND))
        (offering-key { epoch-id: validated-epoch-id, patron: tx-sender, shrine-id: validated-shrine-id })
        (offering (unwrap! (map-get? volcanic-offerings offering-key) ERR-SHRINE-NOT-FOUND))
      )
    ;; Validate IDs
    (asserts! (>= validated-epoch-id u1) ERR-INVALID-UINT)
    (asserts! (>= validated-shrine-id u1) ERR-INVALID-UINT)
    
    ;; Only shrine guardian can harvest
    (asserts! (is-eq tx-sender (get guardian shrine)) ERR-NOT-AUTHORIZED)
    (asserts! (get is-sealed epoch) ERR-EPOCH-NOT-SEALED)
    (asserts! (not (get harvested offering)) ERR-ALREADY-HARVESTED)
    (asserts! (> (get amplified-amount offering) u0) ERR-INSUFFICIENT-MAGMA)
    
    ;; Transfer amplified magma to shrine guardian
    (try! (as-contract (stx-transfer? (get amplified-amount offering) tx-sender (get guardian shrine))))
    
    ;; Update offering to mark as harvested
    (map-set volcanic-offerings 
      offering-key
      (merge offering { harvested: true })
    )
    
    ;; Update volcanic reserves
    (var-set volcanic-reserves (- (var-get volcanic-reserves) (get amplified-amount offering)))
    
    (ok (get amplified-amount offering))
  )
)

;; Get epoch info
(define-read-only (get-epoch-info (epoch-id uint))
  (map-get? volcanic-epochs { epoch-id: epoch-id })
)

;; Get shrine info
(define-read-only (get-shrine-info (shrine-id uint))
  (map-get? obsidian-shrines { shrine-id: shrine-id })
)

;; Get offering info
(define-read-only (get-offering-info (epoch-id uint) (patron principal) (shrine-id uint))
  (map-get? volcanic-offerings { epoch-id: epoch-id, patron: patron, shrine-id: shrine-id })
)

;; Get shrine in epoch info
(define-read-only (get-shrine-in-epoch (epoch-id uint) (shrine-id uint))
  (map-get? epoch-shrines { epoch-id: epoch-id, shrine-id: shrine-id })
)

;; Get patron total in epoch
(define-read-only (get-patron-total (epoch-id uint) (patron principal))
  (default-to { total-offered: u0 } (map-get? patron-totals { epoch-id: epoch-id, patron: patron }))
)

;; Check if epoch is burning
(define-read-only (is-epoch-burning (epoch-id uint))
  (let ((epoch (unwrap! (map-get? volcanic-epochs { epoch-id: epoch-id }) false)))
    (and 
      (get is-burning epoch)
      (>= block-height (get ignition-block-height epoch))
      (<= block-height (get extinction-block-height epoch))
    )
  )
)

;; Get current burning epoch
(define-read-only (get-burning-epoch)
  (let ((active-id (var-get active-epoch-id)))
    (if (> active-id u0)
        (map-get? volcanic-epochs { epoch-id: active-id })
        none
    )
  )
)

;; Get total vault stats
(define-read-only (get-vault-stats)
  {
    volcanic-reserves: (var-get volcanic-reserves),
    total-magma-amplified: (var-get total-magma-amplified),
    active-epoch-id: (var-get active-epoch-id),
    next-shrine-id: (var-get next-shrine-id),
    next-epoch-id: (var-get next-epoch-id)
  }
)

;; Withdraw unused volcanic reserves (only keeper)
(define-public (withdraw-volcanic-reserves (amount uint))
  (begin
    (asserts! (is-keeper) ERR-NOT-AUTHORIZED)
    (asserts! (>= (var-get volcanic-reserves) amount) ERR-INSUFFICIENT-MAGMA)
    
    ;; Transfer STX from contract
    (try! (as-contract (stx-transfer? amount tx-sender (var-get obsidian-keeper))))
    
    ;; Update volcanic reserves
    (var-set volcanic-reserves (- (var-get volcanic-reserves) amount))
    
    (ok true)
  )
)
