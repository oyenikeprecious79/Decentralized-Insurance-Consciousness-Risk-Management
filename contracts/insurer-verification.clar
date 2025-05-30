;; Insurer Verification Contract
;; Validates consciousness risk providers and manages insurer credentials

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_VERIFIED (err u101))
(define-constant ERR_NOT_VERIFIED (err u102))
(define-constant ERR_INVALID_CREDENTIALS (err u103))

;; Data structures
(define-map verified-insurers
  { insurer: principal }
  {
    verified: bool,
    verification-date: uint,
    credentials-hash: (buff 32),
    risk-rating: uint
  }
)

(define-map insurer-metadata
  { insurer: principal }
  {
    name: (string-ascii 50),
    license-number: (string-ascii 20),
    jurisdiction: (string-ascii 30)
  }
)

(define-data-var total-verified-insurers uint u0)

;; Public functions
(define-public (verify-insurer
  (insurer principal)
  (credentials-hash (buff 32))
  (risk-rating uint)
  (name (string-ascii 50))
  (license-number (string-ascii 20))
  (jurisdiction (string-ascii 30)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? verified-insurers { insurer: insurer })) ERR_ALREADY_VERIFIED)
    (asserts! (<= risk-rating u100) ERR_INVALID_CREDENTIALS)

    (map-set verified-insurers
      { insurer: insurer }
      {
        verified: true,
        verification-date: block-height,
        credentials-hash: credentials-hash,
        risk-rating: risk-rating
      }
    )

    (map-set insurer-metadata
      { insurer: insurer }
      {
        name: name,
        license-number: license-number,
        jurisdiction: jurisdiction
      }
    )

    (var-set total-verified-insurers (+ (var-get total-verified-insurers) u1))
    (ok true)
  )
)

(define-public (revoke-verification (insurer principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? verified-insurers { insurer: insurer })) ERR_NOT_VERIFIED)

    (map-delete verified-insurers { insurer: insurer })
    (map-delete insurer-metadata { insurer: insurer })
    (var-set total-verified-insurers (- (var-get total-verified-insurers) u1))
    (ok true)
  )
)

;; Read-only functions
(define-read-only (is-verified-insurer (insurer principal))
  (match (map-get? verified-insurers { insurer: insurer })
    verification (get verified verification)
    false
  )
)

(define-read-only (get-insurer-details (insurer principal))
  (map-get? verified-insurers { insurer: insurer })
)

(define-read-only (get-insurer-metadata (insurer principal))
  (map-get? insurer-metadata { insurer: insurer })
)

(define-read-only (get-total-verified-insurers)
  (var-get total-verified-insurers)
)
