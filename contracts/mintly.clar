;; Mintly Token Contract
;; A fungible token implementation with governance and advanced features

;; Define token
(define-fungible-token mintly)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INSUFFICIENT-BALANCE (err u101))
(define-constant ERR-INVALID-AMOUNT (err u102))

;; Data maps
(define-map allowances 
    { owner: principal, spender: principal }
    { amount: uint })

(define-map frozen-tokens
    { address: principal }
    { amount: uint })

;; Governance data
(define-map governance-tokens
    { holder: principal }
    { voting-power: uint })

;; Read-only functions
(define-read-only (get-name)
    (ok "Mintly Token"))

(define-read-only (get-symbol)
    (ok "MNTLY"))

(define-read-only (get-decimals)
    (ok u6))

(define-read-only (get-balance (account principal))
    (ok (ft-get-balance mintly account)))

(define-read-only (get-allowance (owner principal) (spender principal))
    (match (map-get? allowances { owner: owner, spender: spender })
        allowance (ok (get amount allowance))
        (ok u0)))

;; Public functions
(define-public (mint (amount uint) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (try! (ft-mint? mintly amount recipient))
        ;; Update voting power for governance
        (map-set governance-tokens
            { holder: recipient }
            { voting-power: (+ (unwrap-panic (get-balance recipient)) amount) })
        (ok true)))

(define-public (transfer (amount uint) (recipient principal))
    (begin
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (try! (ft-transfer? mintly amount tx-sender recipient))
        ;; Update voting power for both parties
        (map-set governance-tokens
            { holder: tx-sender }
            { voting-power: (- (unwrap-panic (get-balance tx-sender)) amount) })
        (map-set governance-tokens
            { holder: recipient }
            { voting-power: (+ (unwrap-panic (get-balance recipient)) amount) })
        (ok true)))

(define-public (approve (amount uint) (spender principal))
    (begin
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (map-set allowances
            { owner: tx-sender, spender: spender }
            { amount: amount })
        (ok true)))

(define-public (transfer-from (amount uint) (owner principal) (recipient principal))
    (let ((current-allowance (unwrap! (get-allowance owner tx-sender) ERR-NOT-AUTHORIZED)))
        (begin
            (asserts! (>= current-allowance amount) ERR-INSUFFICIENT-BALANCE)
            (try! (ft-transfer? mintly amount owner recipient))
            ;; Update allowance
            (map-set allowances
                { owner: owner, spender: tx-sender }
                { amount: (- current-allowance amount) })
            ;; Update voting power
            (map-set governance-tokens
                { holder: owner }
                { voting-power: (- (unwrap-panic (get-balance owner)) amount) })
            (map-set governance-tokens
                { holder: recipient }
                { voting-power: (+ (unwrap-panic (get-balance recipient)) amount) })
            (ok true))))

(define-public (burn (amount uint))
    (begin
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (try! (ft-burn? mintly amount tx-sender))
        ;; Update voting power
        (map-set governance-tokens
            { holder: tx-sender }
            { voting-power: (- (unwrap-panic (get-balance tx-sender)) amount) })
        (ok true)))

;; Governance functions
(define-public (get-voting-power (holder principal))
    (match (map-get? governance-tokens { holder: holder })
        power (ok (get voting-power power))
        (ok u0)))

;; Token freezing functions
(define-public (freeze-tokens (amount uint))
    (begin
        (asserts! (>= (unwrap-panic (get-balance tx-sender)) amount) ERR-INSUFFICIENT-BALANCE)
        (try! (ft-burn? mintly amount tx-sender))
        (map-set frozen-tokens
            { address: tx-sender }
            { amount: (+ (default-to u0 (get amount (map-get? frozen-tokens { address: tx-sender }))) amount) })
        (ok true)))

(define-public (unfreeze-tokens (amount uint))
    (let ((frozen-amount (default-to u0 (get amount (map-get? frozen-tokens { address: tx-sender })))))
        (begin
            (asserts! (>= frozen-amount amount) ERR-INSUFFICIENT-BALANCE)
            (try! (ft-mint? mintly amount tx-sender))
            (map-set frozen-tokens
                { address: tx-sender }
                { amount: (- frozen-amount amount) })
            (ok true))))