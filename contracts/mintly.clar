;; Mintly Token Contract - Enhanced Security Version
;; A fungible token implementation with governance and advanced features

;; Define token
(define-fungible-token mintly)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INSUFFICIENT-BALANCE (err u101))
(define-constant ERR-INVALID-AMOUNT (err u102))
(define-constant ERR-INVALID-RECIPIENT (err u103))
(define-constant ERR-INVALID-SPENDER (err u104))
(define-constant ERR-OVERFLOW (err u105))

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

;; Private functions for safety checks
(define-private (is-valid-recipient (recipient principal))
    (and 
        (not (is-eq recipient (as-contract tx-sender)))
        (not (is-eq recipient contract-owner))))

(define-private (check-and-get-balance (account principal))
    (default-to u0 (get voting-power (map-get? governance-tokens { holder: account }))))

(define-private (safe-add (a uint) (b uint))
    (let ((sum (+ a b)))
        (if (>= sum a)
            sum
            u0)))  ;; Return 0 if overflow detected

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
        (asserts! (is-valid-recipient recipient) ERR-INVALID-RECIPIENT)
        
        (let ((current-balance (unwrap! (get-balance recipient) ERR-INVALID-RECIPIENT))
              (new-balance (safe-add current-balance amount)))
            
            (asserts! (> new-balance u0) ERR-OVERFLOW)
            (try! (ft-mint? mintly amount recipient))
            
            (map-set governance-tokens
                { holder: recipient }
                { voting-power: new-balance })
            (ok true))))

(define-public (transfer (amount uint) (recipient principal))
    (begin
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (is-valid-recipient recipient) ERR-INVALID-RECIPIENT)
        
        (let ((sender-balance (unwrap! (get-balance tx-sender) ERR-INSUFFICIENT-BALANCE))
              (recipient-balance (unwrap! (get-balance recipient) ERR-INVALID-RECIPIENT))
              (new-recipient-balance (safe-add recipient-balance amount)))
            
            (asserts! (>= sender-balance amount) ERR-INSUFFICIENT-BALANCE)
            (asserts! (> new-recipient-balance u0) ERR-OVERFLOW)
            
            (try! (ft-transfer? mintly amount tx-sender recipient))
            
            (map-set governance-tokens
                { holder: tx-sender }
                { voting-power: (- sender-balance amount) })
            (map-set governance-tokens
                { holder: recipient }
                { voting-power: new-recipient-balance })
            (ok true))))

(define-public (approve (amount uint) (spender principal))
    (begin
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (not (is-eq spender tx-sender)) ERR-INVALID-SPENDER)
        (map-set allowances
            { owner: tx-sender, spender: spender }
            { amount: amount })
        (ok true)))

(define-public (transfer-from (amount uint) (owner principal) (recipient principal))
    (begin
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (is-valid-recipient recipient) ERR-INVALID-RECIPIENT)
        
        (let ((current-allowance (unwrap! (get-allowance owner tx-sender) ERR-NOT-AUTHORIZED))
              (sender-balance (unwrap! (get-balance owner) ERR-INSUFFICIENT-BALANCE))
              (recipient-balance (unwrap! (get-balance recipient) ERR-INVALID-RECIPIENT))
              (new-recipient-balance (safe-add recipient-balance amount)))
            
            (asserts! (>= current-allowance amount) ERR-INSUFFICIENT-BALANCE)
            (asserts! (>= sender-balance amount) ERR-INSUFFICIENT-BALANCE)
            (asserts! (> new-recipient-balance u0) ERR-OVERFLOW)
            
            (try! (ft-transfer? mintly amount owner recipient))
            
            (map-set allowances
                { owner: owner, spender: tx-sender }
                { amount: (- current-allowance amount) })
            
            (map-set governance-tokens
                { holder: owner }
                { voting-power: (- sender-balance amount) })
            (map-set governance-tokens
                { holder: recipient }
                { voting-power: new-recipient-balance })
            (ok true))))

(define-public (burn (amount uint))
    (begin
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (let ((current-balance (unwrap! (get-balance tx-sender) ERR-INSUFFICIENT-BALANCE)))
            (asserts! (>= current-balance amount) ERR-INSUFFICIENT-BALANCE)
            (try! (ft-burn? mintly amount tx-sender))
            (map-set governance-tokens
                { holder: tx-sender }
                { voting-power: (- current-balance amount) })
            (ok true))))

;; Governance functions
(define-read-only (get-voting-power (holder principal))
    (ok (check-and-get-balance holder)))