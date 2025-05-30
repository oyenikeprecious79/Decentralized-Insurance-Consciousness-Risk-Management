;; Claim Processing Contract
;; Manages consciousness insurance claims

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_CLAIM_NOT_FOUND (err u401))
(define-constant ERR_INVALID_POLICY (err u402))
(define-constant ERR_CLAIM_ALREADY_PROCESSED (err u403))
(define-constant ERR_INSUFFICIENT_EVIDENCE (err u404))

;; Claim status constants
(define-constant CLAIM_PENDING u1)
(define-constant CLAIM_APPROVED u2)
(define-constant CLAIM_REJECTED u3)
(define-constant CLAIM_PAID u4)

;; Claim types for consciousness insurance
(define-constant CONSCIOUSNESS_LOSS u1)
(define-constant IDENTITY_THEFT u2)
(define-constant AI_DAMAGE u3)
(define-constant COGNITIVE_IMPAIRMENT u4)
(define-constant NEURAL_BREACH u5)

;; Data structures
(define-map claims
  { claim-id: uint }
  {
    claimant: principal,
    policy-id: uint,
    claim-type: uint,
    claim-amount: uint,
    incident-date: uint,
    filing-date: uint,
    status: uint,
    evidence-hash: (buff 32),
    assessor: (optional principal)
  }
)

(define-map claim-decisions
  { claim-id: uint }
  {
    decision-date: uint,
    approved-amount: uint,
    rejection-reason: (optional (string-ascii 200)),
    decision-maker: principal
  }
)

(define-data-var next-claim-id uint u1)
(define-data-var total-claims-filed uint u0)
(define-data-var total-claims-paid uint u0)

;; Public functions
(define-public (file-claim
  (policy-id uint)
  (claim-type uint)
  (claim-amount uint)
  (incident-date uint)
  (evidence-hash (buff 32)))
  (let ((claim-id (var-get next-claim-id)))
    (asserts! (<= claim-type u5) ERR_INVALID_POLICY)
    (asserts! (> claim-amount u0) ERR_INVALID_POLICY)
    (asserts! (<= incident-date block-height) ERR_INVALID_POLICY)

    ;; Would verify policy exists and is active via policy-management contract

    (map-set claims
      { claim-id: claim-id }
      {
        claimant: tx-sender,
        policy-id: policy-id,
        claim-type: claim-type,
        claim-amount: claim-amount,
        incident-date: incident-date,
        filing-date: block-height,
        status: CLAIM_PENDING,
        evidence-hash: evidence-hash,
        assessor: none
      }
    )

    (var-set next-claim-id (+ claim-id u1))
    (var-set total-claims-filed (+ (var-get total-claims-filed) u1))
    (ok claim-id)
  )
)

(define-public (assign-assessor (claim-id uint) (assessor principal))
  (match (map-get? claims { claim-id: claim-id })
    claim
      (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status claim) CLAIM_PENDING) ERR_CLAIM_ALREADY_PROCESSED)

        (map-set claims
          { claim-id: claim-id }
          (merge claim { assessor: (some assessor) })
        )
        (ok true)
      )
    ERR_CLAIM_NOT_FOUND
  )
)

(define-public (process-claim
  (claim-id uint)
  (approved bool)
  (approved-amount uint)
  (rejection-reason (optional (string-ascii 200))))
  (match (map-get? claims { claim-id: claim-id })
    claim
      (begin
        (asserts! (is-some (get assessor claim)) ERR_UNAUTHORIZED)
        (asserts! (is-eq tx-sender (unwrap-panic (get assessor claim))) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status claim) CLAIM_PENDING) ERR_CLAIM_ALREADY_PROCESSED)

        (let ((new-status (if approved CLAIM_APPROVED CLAIM_REJECTED)))
          (map-set claims
            { claim-id: claim-id }
            (merge claim { status: new-status })
          )

          (map-set claim-decisions
            { claim-id: claim-id }
            {
              decision-date: block-height,
              approved-amount: (if approved approved-amount u0),
              rejection-reason: (if approved none rejection-reason),
              decision-maker: tx-sender
            }
          )

          (if approved
            (var-set total-claims-paid (+ (var-get total-claims-paid) u1))
            true
          )
          (ok true)
        )
      )
    ERR_CLAIM_NOT_FOUND
  )
)

(define-public (pay-claim (claim-id uint))
  (match (map-get? claims { claim-id: claim-id })
    claim
      (begin
        (asserts! (is-eq (get status claim) CLAIM_APPROVED) ERR_CLAIM_ALREADY_PROCESSED)

        ;; Would transfer funds to claimant here

        (map-set claims
          { claim-id: claim-id }
          (merge claim { status: CLAIM_PAID })
        )
        (ok true)
      )
    ERR_CLAIM_NOT_FOUND
  )
)

;; Read-only functions
(define-read-only (get-claim (claim-id uint))
  (map-get? claims { claim-id: claim-id })
)

(define-read-only (get-claim-decision (claim-id uint))
  (map-get? claim-decisions { claim-id: claim-id })
)

(define-read-only (get-claims-statistics)
  {
    total-filed: (var-get total-claims-filed),
    total-paid: (var-get total-claims-paid),
    success-rate: (if (> (var-get total-claims-filed) u0)
      (/ (* (var-get total-claims-paid) u100) (var-get total-claims-filed))
      u0)
  }
)
