;; Mintly Token Contract - Robust Version
;; Enhanced fungible token implementation with advanced features and security

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INSUFFICIENT-BALANCE (err u101))
(define-constant ERR-INVALID-AMOUNT (err u102))
(define-constant ERR-INVALID-RECIPIENT (err u103))
(define-constant ERR-INVALID-SPENDER (err u104))
(define-constant ERR-OVERFLOW (err u105))
(define-constant ERR-PAUSED (err u106))
(define-constant ERR-ALREADY-INITIALIZED (err u107))
(define-constant ERR-NOT-INITIALIZED (err u108))
(define-constant ERR-BLACKLISTED (err u109))
(define-constant ERR-MAX-SUPPLY-REACHED (err u110))
(define-constant ERR-ZERO-ADDRESS (err u111))
(define-constant ERR-SELF-TRANSFER (err u112))
(define-constant ERR-EXPIRED-ALLOWANCE (err u113))

;; Constants
(define-constant MAX-SUPPLY u1000000000000000) ;; 1 trillion tokens
(define-constant PRECISION u1000000) ;; 6 decimal places

;; Define token
(define-fungible-token mintly)

;; Data Variables
(define-data-var contract-owner principal tx-sender)
(define-data-var token-name (string-ascii 32) "Mintly Token")
(define-data-var token-symbol (string-ascii 10) "MNTLY")
(define-data-var token-decimals uint u6)
(define-data-var total-supply uint u0)
(define-data-var paused bool false)
(define-data-var initialized bool false)

;; Data Maps
(define-map allowances 
    { owner: principal, spender: principal }
    { amount: uint, expiry: uint })

(define-map frozen-tokens
    { address: principal }
    { amount: uint, unlock-height: uint })

(define-map governance-tokens
    { holder: principal }
    { voting-power: uint, last-vote-height: uint })

(define-map blacklisted-addresses 
    { address: principal } 
    { blocked-height: uint })

(define-map minter-roles 
    { address: principal } 
    { can-mint: bool, mint-allowance: uint })

;; Private Functions
(define-private (is-contract-owner)
    (is-eq tx-sender (var-get contract-owner)))

(define-private (is-valid-recipient (recipient principal))
    (and 
        (not (is-eq recipient tx-sender))
        (not (is-eq recipient (as-contract tx-sender)))
        (not (is-blacklisted recipient))
        (not (is-eq recipient (var-get contract-owner)))))

(define-private (is-blacklisted (address principal))
    (match (map-get? blacklisted-addresses { address: address })
        blacklist-data true
        false))

(define-private (check-initialized)
    (if (var-get initialized)
        (ok true)
        ERR-NOT-INITIALIZED))

(define-private (check-not-paused)
    (if (not (var-get paused))
        (ok true)
        ERR-PAUSED))

(define-private (safe-add (a uint) (b uint))
    (let ((sum (+ a b)))
        (if (>= sum a)
            (ok sum)
            ERR-OVERFLOW)))

;; Read-Only Functions
(define-read-only (get-name)
    (ok (var-get token-name)))

(define-read-only (get-symbol)
    (ok (var-get token-symbol)))

(define-read-only (get-decimals)
    (ok (var-get token-decimals)))

(define-read-only (get-total-supply)
    (ok (var-get total-supply)))

(define-read-only (get-balance (account principal))
    (ok (ft-get-balance mintly account)))

(define-read-only (get-allowance (owner principal) (spender principal))
    (match (map-get? allowances { owner: owner, spender: spender })
        allowance-data (let ((current-height block-height))
            (if (>= current-height (get expiry allowance-data))
                (ok u0)
                (ok (get amount allowance-data))))
        (ok u0)))

(define-read-only (is-frozen (address principal))
    (match (map-get? frozen-tokens { address: address })
        freeze-data (> (get unlock-height freeze-data) block-height)
        false))

;; Administrative Functions
(define-public (initialize (name (string-ascii 32)) (symbol (string-ascii 10)) (decimals uint))
    (begin
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        (asserts! (not (var-get initialized)) ERR-ALREADY-INITIALIZED)
        
        ;; Validate name
        (asserts! (>= (len name) u1) ERR-INVALID-AMOUNT)  ;; Ensure name is not empty
        (asserts! (<= (len name) u32) ERR-INVALID-AMOUNT)  ;; Extra safety check for length
        
        ;; Validate symbol
        (asserts! (>= (len symbol) u1) ERR-INVALID-AMOUNT)  ;; Ensure symbol is not empty
        (asserts! (<= (len symbol) u10) ERR-INVALID-AMOUNT)  ;; Extra safety check for length
        
        ;; Validate decimals (common values are 6, 8, or 18)
        (asserts! (<= decimals u18) ERR-INVALID-AMOUNT)  ;; Ensure decimals is reasonable
        (asserts! (>= decimals u0) ERR-INVALID-AMOUNT)   ;; Ensure decimals is non-negative
        
        ;; After validation, set the values
        (var-set token-name name)
        (var-set token-symbol symbol)
        (var-set token-decimals decimals)
        (var-set initialized true)
        (ok true)))


(define-public (set-contract-owner (new-owner principal))
    (begin
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        (asserts! (not (is-eq new-owner (var-get contract-owner))) ERR-INVALID-RECIPIENT)
        (var-set contract-owner new-owner)
        (ok true)))

(define-public (pause)
    (begin
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        (var-set paused true)
        (ok true)))

(define-public (unpause)
    (begin
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        (var-set paused false)
        (ok true)))

;; Token Operations
(define-public (mint (amount uint) (recipient principal))
    (begin
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (is-valid-recipient recipient) ERR-INVALID-RECIPIENT)
        (try! (check-initialized))
        (try! (check-not-paused))
        
        (let ((new-supply (try! (safe-add (var-get total-supply) amount))))
            (asserts! (<= new-supply MAX-SUPPLY) ERR-MAX-SUPPLY-REACHED)
            
            (try! (ft-mint? mintly amount recipient))
            (var-set total-supply new-supply)
            
            (map-set governance-tokens
                { holder: recipient }
                { 
                    voting-power: (unwrap! (safe-add 
                        (default-to u0 (get voting-power (map-get? governance-tokens { holder: recipient }))) 
                        amount) ERR-OVERFLOW),
                    last-vote-height: block-height 
                })
            (ok true))))

(define-public (transfer (amount uint) (recipient principal))
    (begin
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (is-valid-recipient recipient) ERR-INVALID-RECIPIENT)
        (try! (check-initialized))
        (try! (check-not-paused))
        (asserts! (not (is-frozen tx-sender)) ERR-NOT-AUTHORIZED)
        
        (let ((sender-balance (unwrap! (get-balance tx-sender) ERR-INSUFFICIENT-BALANCE)))
            (asserts! (>= sender-balance amount) ERR-INSUFFICIENT-BALANCE)
            
            (try! (ft-transfer? mintly amount tx-sender recipient))
            
            (map-set governance-tokens
                { holder: tx-sender }
                { 
                    voting-power: (- sender-balance amount),
                    last-vote-height: block-height 
                })
                
            (map-set governance-tokens
                { holder: recipient }
                { 
                    voting-power: (unwrap! (safe-add 
                        (default-to u0 (get voting-power (map-get? governance-tokens { holder: recipient }))) 
                        amount) ERR-OVERFLOW),
                    last-vote-height: block-height 
                })
            (ok true))))

(define-public (approve (amount uint) (spender principal) (expiry uint))
    (begin
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (not (is-eq spender tx-sender)) ERR-INVALID-SPENDER)
        (asserts! (>= expiry block-height) ERR-EXPIRED-ALLOWANCE)
        (try! (check-initialized))
        (try! (check-not-paused))
        
        (map-set allowances
            { owner: tx-sender, spender: spender }
            { amount: amount, expiry: expiry })
        (ok true)))

;; Events
(define-data-var last-event-nonce uint u0)

(define-private (emit-transfer-event (from principal) (to principal) (amount uint))
    (begin
        (var-set last-event-nonce (+ (var-get last-event-nonce) u1))
        (print { type: "transfer", nonce: (var-get last-event-nonce), from: from, to: to, amount: amount })))

(define-private (emit-mint-event (to principal) (amount uint))
    (begin
        (var-set last-event-nonce (+ (var-get last-event-nonce) u1))
        (print { type: "mint", nonce: (var-get last-event-nonce), to: to, amount: amount })))

(define-private (emit-burn-event (from principal) (amount uint))
    (begin
        (var-set last-event-nonce (+ (var-get last-event-nonce) u1))
        (print { type: "burn", nonce: (var-get last-event-nonce), from: from, amount: amount })))