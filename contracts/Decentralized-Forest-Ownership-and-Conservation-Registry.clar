(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-token-not-found (err u102))
(define-constant err-not-listed (err u103))
(define-constant err-insufficient-funds (err u104))
(define-constant err-milestone-not-met (err u105))
(define-constant err-already-verified (err u106))
(define-constant err-invalid-milestone (err u107))
(define-constant err-not-collaborator (err u108))
(define-constant err-insufficient-shares (err u109))
(define-constant err-already-collaborator (err u110))
(define-constant err-lease-not-found (err u111))
(define-constant err-lease-active (err u112))
(define-constant err-invalid-duration (err u113))
(define-constant err-not-lessee (err u114))

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

(define-map collaborators
  {token-id: uint, collaborator: principal}
  {
    shares: uint,
    active: bool,
    joined-at: uint
  }
)

(define-map plot-leases
  uint
  {
    lessor: principal,
    lessee: (optional principal),
    duration-blocks: uint,
    rental-fee: uint,
    start-time: (optional uint)
  }
)

(define-map collaboration-approvals
  {token-id: uint, milestone-id: uint, collaborator: principal}
  bool
)

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

(define-read-only (get-collaborator (token-id uint) (collaborator principal))
  (map-get? collaborators {token-id: token-id, collaborator: collaborator})
)

(define-read-only (get-collaboration-approval (token-id uint) (milestone-id uint) (collaborator principal))
  (default-to false (map-get? collaboration-approvals {token-id: token-id, milestone-id: milestone-id, collaborator: collaborator}))
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

(define-read-only (get-lease (token-id uint))
  (map-get? plot-leases token-id)
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

(define-public (invite-collaborator (token-id uint) (collaborator principal) (shares uint))
  (let
    (
      (plot (unwrap! (map-get? forest-plots token-id) (err err-token-not-found)))
    )
    (asserts! (is-eq (get owner plot) tx-sender) (err err-not-token-owner))
    (asserts! (> shares u0) (err err-insufficient-shares))
    (asserts! (is-none (map-get? collaborators {token-id: token-id, collaborator: collaborator})) (err err-already-collaborator))
    (map-set collaborators
      {token-id: token-id, collaborator: collaborator}
      {
        shares: shares,
        active: true,
        joined-at: stacks-block-height
      }
    )
    (ok true)
  )
)

(define-public (remove-collaborator (token-id uint) (collaborator principal))
  (let
    (
      (plot (unwrap! (map-get? forest-plots token-id) (err err-token-not-found)))
      (collaboration (unwrap! (map-get? collaborators {token-id: token-id, collaborator: collaborator}) (err err-not-collaborator)))
    )
    (asserts! (is-eq (get owner plot) tx-sender) (err err-not-token-owner))
    (map-set collaborators
      {token-id: token-id, collaborator: collaborator}
      (merge collaboration {active: false})
    )
    (ok true)
  )
)

(define-public (approve-milestone-collaborative (token-id uint) (milestone-id uint))
  (let
    (
      (plot (unwrap! (map-get? forest-plots token-id) (err err-token-not-found)))
      (collaboration (unwrap! (map-get? collaborators {token-id: token-id, collaborator: tx-sender}) (err err-not-collaborator)))
    )
    (asserts! (get active collaboration) (err err-not-collaborator))
    (map-set collaboration-approvals
      {token-id: token-id, milestone-id: milestone-id, collaborator: tx-sender}
      true
    )
    (ok true)
  )
)

(define-public (distribute-rewards (token-id uint) (total-reward uint))
  (let
    (
      (plot (unwrap! (map-get? forest-plots token-id) (err err-token-not-found)))
    )
    (asserts! (is-eq (get owner plot) tx-sender) (err err-not-token-owner))
    (ok total-reward)
  )
)

(define-public (transfer-collaboration-shares (token-id uint) (to principal) (shares uint))
  (let
    (
      (collaboration (unwrap! (map-get? collaborators {token-id: token-id, collaborator: tx-sender}) (err err-not-collaborator)))
      (current-shares (get shares collaboration))
    )
    (asserts! (get active collaboration) (err err-not-collaborator))
    (asserts! (>= current-shares shares) (err err-insufficient-shares))
    (asserts! (> shares u0) (err err-insufficient-shares))
    (if (is-eq current-shares shares)
      (begin
        (map-set collaborators
          {token-id: token-id, collaborator: to}
          collaboration
        )
        (map-delete collaborators {token-id: token-id, collaborator: tx-sender})
      )
      (begin
        (map-set collaborators
          {token-id: token-id, collaborator: tx-sender}
          (merge collaboration {shares: (- current-shares shares)})
        )
        (map-set collaborators
          {token-id: token-id, collaborator: to}
          {
            shares: shares,
            active: true,
            joined-at: stacks-block-height
          }
        )
      )
    )
    (ok true)
  )
)

(define-public (offer-lease (token-id uint) (duration-blocks uint) (rental-fee uint))
  (let
    (
      (plot (unwrap! (map-get? forest-plots token-id) (err err-token-not-found)))
    )
    (asserts! (is-eq (get owner plot) tx-sender) (err err-not-token-owner))
    (asserts! (> duration-blocks u0) (err err-invalid-duration))
    (asserts! (is-none (map-get? plot-leases token-id)) (err err-lease-active))
    (map-set plot-leases
      token-id
      {
        lessor: tx-sender,
        lessee: none,
        duration-blocks: duration-blocks,
        rental-fee: rental-fee,
        start-time: none
      }
    )
    (ok true)
  )
)

(define-public (rent-plot (token-id uint))
  (let
    (
      (lease (unwrap! (map-get? plot-leases token-id) (err err-lease-not-found)))
      (plot (unwrap! (map-get? forest-plots token-id) (err err-token-not-found)))
      (fee (get rental-fee lease))
      (owner (get lessor lease))
      (current-time stacks-block-height)
    )
    (asserts! (is-none (get lessee lease)) (err err-lease-active))
    (asserts! (>= (stx-get-balance tx-sender) fee) (err err-insufficient-funds))
    (unwrap! (stx-transfer? fee tx-sender owner) (err err-insufficient-funds))
    (map-set plot-leases
      token-id
      (merge lease {
        lessee: (some tx-sender),
        start-time: (some current-time)
      })
    )
    (ok true)
  )
)

(define-public (end-lease (token-id uint))
  (let
    (
      (lease (unwrap! (map-get? plot-leases token-id) (err err-lease-not-found)))
      (lessee (unwrap! (get lessee lease) (err err-lease-not-found)))
      (start-time (unwrap! (get start-time lease) (err err-lease-not-found)))
      (duration (get duration-blocks lease))
      (current-time stacks-block-height)
    )
    (asserts! (or (is-eq tx-sender (get lessor lease)) (>= current-time (+ start-time duration))) (err err-not-lessee))
    (map-set plot-leases
      token-id
      (merge lease {
        lessee: none,
        start-time: none
      })
    )
    (ok true)
  )
)
