;; ------------------------------------------------------------
;; LivePass.clar
;; LivePass Protocol: Decentralized Event Ticketing System
;; Version: 2.0.0
;; Author: your-handle
;; ------------------------------------------------------------

;; -----------------------------
;; Errors
;; -----------------------------
(define-constant ERR-UNAUTHORIZED        u100)
(define-constant ERR-NOT-INITIALIZED     u101)
(define-constant ERR-ALREADY-INITIALIZED u102)
(define-constant ERR-NOT-HOLDER          u103)
(define-constant ERR-NOT-LISTED          u104)
(define-constant ERR-ALREADY-LISTED      u105)
(define-constant ERR-ZERO-PRICE          u106)
(define-constant ERR-INVALID_BPS         u107)
(define-constant ERR-SELF_PURCHASE       u108)
(define-constant ERR-NOT-FOUND           u109)
(define-constant ERR-BAD-INPUT           u110)
(define-constant ERR-INVALID-ID          u111)
(define-constant ERR-INVALID-PRINCIPAL   u112)

;; -----------------------------
;; NFT Core
;; -----------------------------
(define-non-fungible-token livepass uint)

;; -----------------------------
;; State
;; -----------------------------
(define-data-var initialized bool false)
(define-data-var protocol-owner principal tx-sender)
(define-data-var creator principal tx-sender)
(define-data-var royalty-fee uint u1000) ;; 10%
(define-data-var total-minted uint u0)

;; metadata
(define-map pass-data
  { id: uint }
  {
    title: (string-ascii 48),
    event-date: uint,
    location: (string-ascii 48),
    uri: (optional (string-utf8 256))
  }
)

;; marketplace
(define-map marketplace
  { id: uint }
  { price: uint })

;; -----------------------------
;; Validation
;; -----------------------------
(define-private (valid-id (id uint))
  (and (> id u0) (<= id u1000000))
)

(define-private (valid-user (who principal))
  (not (is-eq who 'SP000000000000000000002Q6VF78))
)

(define-private (valid-str (s (string-ascii 48)))
  (and (> (len s) u0) (<= (len s) u48))
)

(define-private (valid-date (d uint))
  (and (>= d u20200101) (<= d u30001231))
)

;; -----------------------------
;; Internal
;; -----------------------------
(define-read-only (is-owner)
  (ok (is-eq tx-sender (var-get protocol-owner)))
)

(define-read-only (is-ready)
  (ok (var-get initialized))
)

(define-private (calc-fee (price uint))
  (ok (/ (* price (var-get royalty-fee)) u10000))
)

;; -----------------------------
;; Initialize
;; -----------------------------
(define-public (initialize)
  (begin
    (asserts! (not (var-get initialized)) (err ERR-ALREADY-INITIALIZED))
    (var-set protocol-owner tx-sender)
    (var-set creator tx-sender)
    (var-set initialized true)
    (ok true)
  )
)

;; -----------------------------
;; Admin
;; -----------------------------
(define-public (set-creator (who principal))
  (begin
    (asserts! (unwrap-panic (is-owner)) (err ERR-UNAUTHORIZED))
    (asserts! (unwrap-panic (is-ready)) (err ERR-NOT-INITIALIZED))
    (asserts! (valid-user who) (err ERR-INVALID-PRINCIPAL))
    (var-set creator who)
    (ok who)
  )
)

(define-public (set-royalty (bps uint))
  (begin
    (asserts! (unwrap-panic (is-owner)) (err ERR-UNAUTHORIZED))
    (asserts! (<= bps u2000) (err ERR-INVALID_BPS))
    (var-set royalty-fee bps)
    (ok bps)
  )
)

;; -----------------------------
;; Mint Pass
;; -----------------------------
(define-public (mint-pass
  (id uint)
  (recipient principal)
  (title (string-ascii 48))
  (event-date uint)
  (location (string-ascii 48))
  (uri (optional (string-utf8 256))))
  (begin
    (asserts! (unwrap-panic (is-owner)) (err ERR-UNAUTHORIZED))
    (asserts! (unwrap-panic (is-ready)) (err ERR-NOT-INITIALIZED))

    (asserts! (valid-id id) (err ERR-INVALID-ID))
    (asserts! (valid-user recipient) (err ERR-INVALID-PRINCIPAL))
    (asserts! (valid-str title) (err ERR-BAD-INPUT))
    (asserts! (valid-date event-date) (err ERR-BAD-INPUT))
    (asserts! (valid-str location) (err ERR-BAD-INPUT))

    (try! (nft-mint? livepass id recipient))

    (map-set pass-data { id: id }
      { title: title, event-date: event-date, location: location, uri: uri })

    (var-set total-minted (+ (var-get total-minted) u1))
    (ok id)
  )
)

;; -----------------------------
;; Marketplace
;; -----------------------------
(define-public (list-pass (id uint) (price uint))
  (let ((owner (unwrap! (nft-get-owner? livepass id) (err ERR-NOT-FOUND))))
    (begin
      (asserts! (is-eq owner tx-sender) (err ERR-NOT-HOLDER))
      (asserts! (valid-id id) (err ERR-INVALID-ID))
      (asserts! (> price u0) (err ERR-ZERO-PRICE))

      (match (map-get? marketplace { id: id })
        existing (err ERR-ALREADY-LISTED)
        (begin
          (map-set marketplace { id: id } { price: price })
          (ok true)
        )
      )
    )
  )
)

(define-public (update-pass (id uint) (price uint))
  (let ((owner (unwrap! (nft-get-owner? livepass id) (err ERR-NOT-FOUND))))
    (begin
      (asserts! (is-eq owner tx-sender) (err ERR-NOT-HOLDER))
      (asserts! (> price u0) (err ERR-ZERO-PRICE))
      (asserts! (is-some (map-get? marketplace { id: id })) (err ERR-NOT-LISTED))

      (map-set marketplace { id: id } { price: price })
      (ok true)
    )
  )
)

(define-public (delist-pass (id uint))
  (let ((owner (unwrap! (nft-get-owner? livepass id) (err ERR-NOT-FOUND))))
    (begin
      (asserts! (is-eq owner tx-sender) (err ERR-NOT-HOLDER))
      (asserts! (is-some (map-get? marketplace { id: id })) (err ERR-NOT-LISTED))

      (map-delete marketplace { id: id })
      (ok true)
    )
  )
)

;; -----------------------------
;; Purchase
;; -----------------------------
(define-public (buy-pass (id uint))
  (let ((listing (map-get? marketplace { id: id })))
    (begin
      (asserts! (valid-id id) (err ERR-INVALID-ID))
      (asserts! (is-some listing) (err ERR-NOT-LISTED))

      (let (
        (price (get price (default-to { price: u0 } listing)))
        (seller (unwrap! (nft-get-owner? livepass id) (err ERR-NOT-FOUND)))
      )
        (begin
          (asserts! (> price u0) (err ERR-ZERO-PRICE))
          (asserts! (not (is-eq seller tx-sender)) (err ERR-SELF_PURCHASE))

          (let (
            (fee (unwrap-panic (calc-fee price)))
            (creator-addr (var-get creator))
          )
            (begin
              (try! (stx-transfer? (- price fee) tx-sender seller))
              (try! (stx-transfer? fee tx-sender creator-addr))

              (try! (nft-transfer? livepass id seller tx-sender))

              (map-delete marketplace { id: id })
              (ok true)
            )
          )
        )
      )
    )
  )
)

;; -----------------------------
;; Standard Interface
;; -----------------------------
(define-read-only (get-holder (id uint))
  (ok (nft-get-owner? livepass id))
)

(define-read-only (get-uri (id uint))
  (match (map-get? pass-data { id: id })
    data (ok (get uri data))
    (ok none)
  )
)

(define-public (transfer (id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq sender tx-sender) (err ERR-UNAUTHORIZED))
    (asserts! (valid-user recipient) (err ERR-INVALID-PRINCIPAL))
    (try! (nft-transfer? livepass id sender recipient))
    (ok true)
  )
)

;; -----------------------------
;; Views
;; -----------------------------
(define-read-only (get-total) (ok (var-get total-minted)))
(define-read-only (get-creator) (ok (var-get creator)))
(define-read-only (get-royalty) (ok (var-get royalty-fee)))

(define-read-only (get-market (id uint))
  (ok (map-get? marketplace { id: id }))
)

(define-read-only (get-pass (id uint))
  (ok (map-get? pass-data { id: id }))
)