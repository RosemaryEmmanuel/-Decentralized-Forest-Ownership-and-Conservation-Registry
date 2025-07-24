(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-token-not-found (err u102))
(define-constant err-not-listed (err u103))
(define-constant err-insufficient-funds (err u104))
(define-constant err-milestone-not-met (err u105))
(define-constant err-already-verified (err u106))
(define-constant err-invalid-milestone (err u107))

(define-data-var token-id-nonce uint u1)
(define-data-var total-supply uint u0)

(define-map forest-plots
  uint
  {
    owner: principal,
    location: (string-ascii 100),
    size-acres: uint,
    conservation-type: (string-ascii 50),
    creation-time: uint,
    milestone-count: uint,
    verified-milestones: uint,
    reward-tokens: uint
  }
)

(define-map conservation-milestones
  {token-id: uint, milestone-id: uint}
  {
    description: (string-ascii 200),
    target-date: uint,
    verification-method: (string-ascii 100),
    reward-amount: uint,
    completed: bool,
    verified-by: (optional principal)
  }
)

(define-map marketplace-listings
  uint
  {
    seller: principal,
    price: uint,
    listed-at: uint
  }
)

(define-map token-balances principal uint)

(define-read-only (get-owner (token-id uint))
  (match (map-get? forest-plots token-id)
    plot (ok (get owner plot))
    (err err-token-not-found)
  )
)

(define-read-only (get-token-uri (token-id uint))
  (match (map-get? forest-plots token-id)
    plot (ok (some "https://forest-registry.com/metadata/"))
    (err err-token-not-found)
  )
)

(define-read-only (get-last-token-id)
  (ok (- (var-get token-id-nonce) u1))
)

(define-read-only (get-token-balance (owner principal))
  (default-to u0 (map-get? token-balances owner))
)

(define-read-only (get-forest-plot (token-id uint))
  (map-get? forest-plots token-id)
)

(define-read-only (get-milestone (token-id uint) (milestone-id uint))
  (map-get? conservation-milestones {token-id: token-id, milestone-id: milestone-id})
)

(define-read-only (get-listing (token-id uint))
  (map-get? marketplace-listings token-id)
)

(define-read-only (get-total-supply)
  (ok (var-get total-supply))
)

(define-private (mint-nft (to principal) (location (string-ascii 100)) (size-acres uint) (conservation-type (string-ascii 50)))
  (let
    (
      (token-id (var-get token-id-nonce))
    )
    (map-set forest-plots
      token-id
      {
        owner: to,
        location: location,
        size-acres: size-acres,
        conservation-type: conservation-type,
        creation-time: stacks-block-height,
        milestone-count: u0,
        verified-milestones: u0,
        reward-tokens: u0
      }
    )
    (map-set token-balances to (+ (get-token-balance to) u1))
    (var-set token-id-nonce (+ token-id u1))
    (var-set total-supply (+ (var-get total-supply) u1))
    (ok token-id)
  )
)

(define-public (register-forest-plot (location (string-ascii 100)) (size-acres uint) (conservation-type (string-ascii 50)))
  (mint-nft tx-sender location size-acres conservation-type)
)

(define-public (add-conservation-milestone 
  (token-id uint) 
  (description (string-ascii 200)) 
  (target-date uint) 
  (verification-method (string-ascii 100)) 
  (reward-amount uint))
  (let
    (
      (plot (unwrap! (map-get? forest-plots token-id) (err err-token-not-found)))
      (milestone-id (get milestone-count plot))
    )
    (asserts! (is-eq (get owner plot) tx-sender) (err err-not-token-owner))
    (map-set conservation-milestones
      {token-id: token-id, milestone-id: milestone-id}
      {
        description: description,
        target-date: target-date,
        verification-method: verification-method,
        reward-amount: reward-amount,
        completed: false,
        verified-by: none
      }
    )
    (map-set forest-plots
      token-id
      (merge plot {milestone-count: (+ milestone-id u1)})
    )
    (ok milestone-id)
  )
)

(define-public (verify-milestone (token-id uint) (milestone-id uint))
  (let
    (
      (plot (unwrap! (map-get? forest-plots token-id) (err err-token-not-found)))
      (milestone (unwrap! (map-get? conservation-milestones {token-id: token-id, milestone-id: milestone-id}) (err err-invalid-milestone)))
    )
    (asserts! (is-eq tx-sender contract-owner) (err err-owner-only))
    (asserts! (not (get completed milestone)) (err err-already-verified))
    (map-set conservation-milestones
      {token-id: token-id, milestone-id: milestone-id}
      (merge milestone {completed: true, verified-by: (some tx-sender)})
    )
    (let
      (
        (reward-amount (get reward-amount milestone))
        (owner (get owner plot))
        (new-verified-count (+ (get verified-milestones plot) u1))
        (new-reward-total (+ (get reward-tokens plot) reward-amount))
      )
      (map-set forest-plots
        token-id
        (merge plot {
          verified-milestones: new-verified-count,
          reward-tokens: new-reward-total
        })
      )
      (map-set token-balances owner (+ (get-token-balance owner) reward-amount))
      (ok reward-amount)
    )
  )
)

(define-public (list-for-sale (token-id uint) (price uint))
  (let
    (
      (plot (unwrap! (map-get? forest-plots token-id) (err err-token-not-found)))
    )
    (asserts! (is-eq (get owner plot) tx-sender) (err err-not-token-owner))
    (map-set marketplace-listings
      token-id
      {
        seller: tx-sender,
        price: price,
        listed-at: stacks-block-height
      }
    )
    (ok true)
  )
)

(define-public (buy-forest-nft (token-id uint))
  (let
    (
      (listing (unwrap! (map-get? marketplace-listings token-id) (err err-not-listed)))
      (plot (unwrap! (map-get? forest-plots token-id) (err err-token-not-found)))
      (seller (get seller listing))
      (price (get price listing))
    )
    (asserts! (>= (stx-get-balance tx-sender) price) (err err-insufficient-funds))
    (unwrap! (stx-transfer? price tx-sender seller) (err err-insufficient-funds))
    (map-delete marketplace-listings token-id)
    (map-set forest-plots
      token-id
      (merge plot {owner: tx-sender})
    )
    (map-set token-balances seller (- (get-token-balance seller) u1))
    (map-set token-balances tx-sender (+ (get-token-balance tx-sender) u1))
    (ok true)
  )
)

(define-public (remove-listing (token-id uint))
  (let
    (
      (listing (unwrap! (map-get? marketplace-listings token-id) (err err-not-listed)))
      (plot (unwrap! (map-get? forest-plots token-id) (err err-token-not-found)))
    )
    (asserts! (is-eq (get seller listing) tx-sender) (err err-not-token-owner))
    (map-delete marketplace-listings token-id)
    (ok true)
  )
)

(define-public (transfer (token-id uint) (from principal) (to principal))
  (let
    (
      (plot (unwrap! (map-get? forest-plots token-id) (err err-token-not-found)))
    )
    (asserts! (is-eq (get owner plot) from) (err err-not-token-owner))
    (asserts! (is-eq tx-sender from) (err err-not-token-owner))
    (map-set forest-plots
      token-id
      (merge plot {owner: to})
    )
    (map-set token-balances from (- (get-token-balance from) u1))
    (map-set token-balances to (+ (get-token-balance to) u1))
    (ok true)
  )
)

(define-public (claim-reward-tokens (amount uint))
  (let
    (
      (balance (get-token-balance tx-sender))
    )
    (asserts! (>= balance amount) (err err-insufficient-funds))
    (map-set token-balances tx-sender (- balance amount))
    (ok amount)
  )
)

(define-read-only (get-conservation-progress (token-id uint))
  (match (map-get? forest-plots token-id)
    plot (ok {
      total-milestones: (get milestone-count plot),
      verified-milestones: (get verified-milestones plot),
      reward-tokens-earned: (get reward-tokens plot),
      completion-rate: (if (> (get milestone-count plot) u0)
        (/ (* (get verified-milestones plot) u100) (get milestone-count plot))
        u0
      )
    })
    (err err-token-not-found)
  )
)

(define-read-only (get-marketplace-stats)
  (ok {
    total-plots: (var-get total-supply),
    active-listings: u0
  })
)
