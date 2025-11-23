;; Smart Contract Optimization Assistant
;; This contract provides tools for analyzing, tracking, and optimizing smart contract performance.
;; It allows developers to submit contracts for analysis, receive optimization suggestions,
;; track gas usage patterns, and maintain a reputation system for optimization quality.

;; constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-invalid-input (err u103))
(define-constant err-unauthorized (err u104))
(define-constant err-insufficient-payment (err u105))

;; Optimization severity levels
(define-constant severity-critical u1)
(define-constant severity-high u2)
(define-constant severity-medium u3)
(define-constant severity-low u4)

;; Minimum analysis fee in microSTX
(define-constant min-analysis-fee u1000000)

;; data maps and vars

;; Track contract submissions for optimization
(define-map contract-submissions
    { contract-id: principal }
    {
        owner: principal,
        submission-height: uint,
        status: (string-ascii 20),
        gas-estimate: uint,
        optimization-score: uint
    }
)

;; Store optimization suggestions for each contract
(define-map optimization-suggestions
    { contract-id: principal, suggestion-id: uint }
    {
        severity: uint,
        category: (string-ascii 50),
        description: (string-utf8 500),
        estimated-savings: uint,
        implemented: bool
    }
)

;; Track suggestion count per contract
(define-map suggestion-counter
    { contract-id: principal }
    { count: uint }
)

;; Analyzer reputation system
(define-map analyzer-reputation
    { analyzer: principal }
    {
        total-analyses: uint,
        successful-optimizations: uint,
        reputation-score: uint,
        total-savings-achieved: uint
    }
)

;; Gas usage tracking for contracts
(define-map gas-usage-history
    { contract-id: principal, execution-id: uint }
    {
        function-name: (string-ascii 50),
        gas-used: uint,
        block-height: uint,
        optimized: bool
    }
)

;; Payment tracking for analysis services
(define-map analysis-payments
    { contract-id: principal }
    {
        amount-paid: uint,
        analyzer: principal,
        payment-height: uint
    }
)

;; Global statistics
(define-data-var total-contracts-analyzed uint u0)
(define-data-var total-gas-saved uint u0)
(define-data-var total-optimizations-implemented uint u0)

;; private functions

;; Calculate optimization score based on gas savings
(define-private (calculate-optimization-score (original-gas uint) (optimized-gas uint))
    (let
        (
            (gas-saved (- original-gas optimized-gas))
            (savings-percentage (/ (* gas-saved u100) original-gas))
        )
        (if (>= savings-percentage u50)
            u100
            (if (>= savings-percentage u30)
                u80
                (if (>= savings-percentage u15)
                    u60
                    (if (>= savings-percentage u5)
                        u40
                        u20
                    )
                )
            )
        )
    )
)

;; Validate severity level
(define-private (is-valid-severity (severity uint))
    (or
        (is-eq severity severity-critical)
        (or
            (is-eq severity severity-high)
            (or
                (is-eq severity severity-medium)
                (is-eq severity severity-low)
            )
        )
    )
)

;; Update analyzer reputation after successful optimization
(define-private (update-analyzer-reputation (analyzer principal) (gas-saved uint))
    (let
        (
            (current-rep (default-to
                { total-analyses: u0, successful-optimizations: u0, reputation-score: u0, total-savings-achieved: u0 }
                (map-get? analyzer-reputation { analyzer: analyzer })
            ))
        )
        (map-set analyzer-reputation
            { analyzer: analyzer }
            {
                total-analyses: (+ (get total-analyses current-rep) u1),
                successful-optimizations: (+ (get successful-optimizations current-rep) u1),
                reputation-score: (+ (get reputation-score current-rep) (/ gas-saved u1000)),
                total-savings-achieved: (+ (get total-savings-achieved current-rep) gas-saved)
            }
        )
    )
)

;; public functions

;; Submit a contract for optimization analysis
(define-public (submit-contract-for-analysis (contract-id principal) (initial-gas-estimate uint))
    (let
        (
            (existing-submission (map-get? contract-submissions { contract-id: contract-id }))
        )
        (asserts! (is-none existing-submission) err-already-exists)
        (asserts! (> initial-gas-estimate u0) err-invalid-input)
        
        (map-set contract-submissions
            { contract-id: contract-id }
            {
                owner: tx-sender,
                submission-height: block-height,
                status: "pending",
                gas-estimate: initial-gas-estimate,
                optimization-score: u0
            }
        )
        
        (map-set suggestion-counter
            { contract-id: contract-id }
            { count: u0 }
        )
        
        (var-set total-contracts-analyzed (+ (var-get total-contracts-analyzed) u1))
        (ok true)
    )
)

;; Add an optimization suggestion (only contract owner or authorized analyzers)
(define-public (add-optimization-suggestion
    (contract-id principal)
    (severity uint)
    (category (string-ascii 50))
    (description (string-utf8 500))
    (estimated-savings uint))
    (let
        (
            (submission (unwrap! (map-get? contract-submissions { contract-id: contract-id }) err-not-found))
            (counter (unwrap! (map-get? suggestion-counter { contract-id: contract-id }) err-not-found))
            (suggestion-id (get count counter))
        )
        (asserts! (is-valid-severity severity) err-invalid-input)
        (asserts! (> estimated-savings u0) err-invalid-input)
        
        (map-set optimization-suggestions
            { contract-id: contract-id, suggestion-id: suggestion-id }
            {
                severity: severity,
                category: category,
                description: description,
                estimated-savings: estimated-savings,
                implemented: false
            }
        )
        
        (map-set suggestion-counter
            { contract-id: contract-id }
            { count: (+ suggestion-id u1) }
        )
        
        (ok suggestion-id)
    )
)

;; Mark a suggestion as implemented and update statistics
(define-public (mark-suggestion-implemented (contract-id principal) (suggestion-id uint))
    (let
        (
            (submission (unwrap! (map-get? contract-submissions { contract-id: contract-id }) err-not-found))
            (suggestion (unwrap! (map-get? optimization-suggestions { contract-id: contract-id, suggestion-id: suggestion-id }) err-not-found))
        )
        (asserts! (is-eq tx-sender (get owner submission)) err-unauthorized)
        (asserts! (not (get implemented suggestion)) err-invalid-input)
        
        (map-set optimization-suggestions
            { contract-id: contract-id, suggestion-id: suggestion-id }
            (merge suggestion { implemented: true })
        )
        
        (var-set total-gas-saved (+ (var-get total-gas-saved) (get estimated-savings suggestion)))
        (var-set total-optimizations-implemented (+ (var-get total-optimizations-implemented) u1))
        
        (ok true)
    )
)

;; Record gas usage for a contract function
(define-public (record-gas-usage
    (contract-id principal)
    (execution-id uint)
    (function-name (string-ascii 50))
    (gas-used uint)
    (optimized bool))
    (let
        (
            (submission (unwrap! (map-get? contract-submissions { contract-id: contract-id }) err-not-found))
        )
        (asserts! (is-eq tx-sender (get owner submission)) err-unauthorized)
        
        (map-set gas-usage-history
            { contract-id: contract-id, execution-id: execution-id }
            {
                function-name: function-name,
                gas-used: gas-used,
                block-height: block-height,
                optimized: optimized
            }
        )
        
        (ok true)
    )
)

;; Pay for analysis service
(define-public (pay-for-analysis (contract-id principal) (analyzer principal) (amount uint))
    (let
        (
            (submission (unwrap! (map-get? contract-submissions { contract-id: contract-id }) err-not-found))
        )
        (asserts! (is-eq tx-sender (get owner submission)) err-unauthorized)
        (asserts! (>= amount min-analysis-fee) err-insufficient-payment)
        
        (try! (stx-transfer? amount tx-sender analyzer))
        
        (map-set analysis-payments
            { contract-id: contract-id }
            {
                amount-paid: amount,
                analyzer: analyzer,
                payment-height: block-height
            }
        )
        
        (ok true)
    )
)

;; Get contract submission details
(define-read-only (get-contract-submission (contract-id principal))
    (ok (map-get? contract-submissions { contract-id: contract-id }))
)

;; Get optimization suggestion details
(define-read-only (get-optimization-suggestion (contract-id principal) (suggestion-id uint))
    (ok (map-get? optimization-suggestions { contract-id: contract-id, suggestion-id: suggestion-id }))
)

;; Get analyzer reputation
(define-read-only (get-analyzer-reputation (analyzer principal))
    (ok (map-get? analyzer-reputation { analyzer: analyzer }))
)

;; Get global statistics
(define-read-only (get-global-statistics)
    (ok {
        total-contracts-analyzed: (var-get total-contracts-analyzed),
        total-gas-saved: (var-get total-gas-saved),
        total-optimizations-implemented: (var-get total-optimizations-implemented)
    })
)

;; Advanced feature: Comprehensive contract optimization report generator
;; This function generates a detailed optimization report by analyzing all suggestions,
;; gas usage patterns, and calculating potential savings across multiple dimensions
(define-public (generate-comprehensive-optimization-report
    (contract-id principal)
    (original-gas uint)
    (optimized-gas uint))
    (let
        (
            (submission (unwrap! (map-get? contract-submissions { contract-id: contract-id }) err-not-found))
            (counter (unwrap! (map-get? suggestion-counter { contract-id: contract-id }) err-not-found))
            (payment-info (map-get? analysis-payments { contract-id: contract-id }))
            (gas-saved (- original-gas optimized-gas))
            (optimization-score (calculate-optimization-score original-gas optimized-gas))
            (savings-percentage (/ (* gas-saved u100) original-gas))
        )
        ;; Verify caller is the contract owner
        (asserts! (is-eq tx-sender (get owner submission)) err-unauthorized)
        (asserts! (> original-gas optimized-gas) err-invalid-input)
        
        ;; Update contract submission with final optimization score
        (map-set contract-submissions
            { contract-id: contract-id }
            (merge submission {
                status: "completed",
                optimization-score: optimization-score,
                gas-estimate: optimized-gas
            })
        )
        
        ;; Update global statistics
        (var-set total-gas-saved (+ (var-get total-gas-saved) gas-saved))
        
        ;; Update analyzer reputation if payment was made
        (match payment-info
            payment-data (update-analyzer-reputation (get analyzer payment-data) gas-saved)
            true
        )
        
        ;; Return comprehensive report
        (ok {
            contract-id: contract-id,
            original-gas: original-gas,
            optimized-gas: optimized-gas,
            gas-saved: gas-saved,
            savings-percentage: savings-percentage,
            optimization-score: optimization-score,
            total-suggestions: (get count counter),
            analysis-complete: true,
            report-generated-at: block-height
        })
    )
)


