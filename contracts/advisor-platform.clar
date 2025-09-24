;; Financial Planning Software Integration Contract
;; Advisor tool platform for client data aggregation, goal tracking, scenario modeling, and compliance

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-data (err u103))
(define-constant err-goal-not-active (err u104))

;; Data Maps
(define-map clients
  { client-id: uint }
  {
    advisor: principal,
    client-principal: principal,
    name: (string-ascii 100),
    risk-tolerance: uint,
    age: uint,
    net-worth: uint,
    annual-income: uint,
    created-at: uint,
    status: (string-ascii 20)
  }
)

(define-map financial-goals
  { client-id: uint, goal-id: uint }
  {
    goal-type: (string-ascii 50),
    target-amount: uint,
    target-date: uint,
    current-progress: uint,
    priority-level: uint,
    status: (string-ascii 20),
    created-at: uint
  }
)

(define-map scenario-models
  { client-id: uint, scenario-id: uint }
  {
    scenario-name: (string-ascii 100),
    investment-return: uint,
    inflation-rate: uint,
    time-horizon: uint,
    projected-value: uint,
    risk-score: uint,
    created-at: uint
  }
)

(define-map compliance-records
  { advisor: principal, record-id: uint }
  {
    client-id: uint,
    compliance-type: (string-ascii 50),
    review-date: uint,
    status: (string-ascii 20),
    notes: (string-ascii 500),
    next-review: uint
  }
)

(define-map advisor-licenses
  { advisor: principal }
  {
    license-type: (string-ascii 50),
    license-number: (string-ascii 50),
    issued-date: uint,
    expiry-date: uint,
    status: (string-ascii 20)
  }
)

;; Data Variables
(define-data-var next-client-id uint u1)
(define-data-var next-goal-id uint u1)
(define-data-var next-scenario-id uint u1)
(define-data-var next-record-id uint u1)
(define-data-var total-clients uint u0)
(define-data-var total-advisors uint u0)

;; Client Management Functions
(define-public (register-client (advisor principal) (client-principal principal) 
                               (name (string-ascii 100)) (risk-tolerance uint) 
                               (age uint) (net-worth uint) (annual-income uint))
  (let ((client-id (var-get next-client-id)))
    (asserts! (or (is-eq tx-sender contract-owner) (is-eq tx-sender advisor)) err-unauthorized)
    (asserts! (> age u18) err-invalid-data)
    (asserts! (<= risk-tolerance u10) err-invalid-data)
    
    (map-set clients
      { client-id: client-id }
      {
        advisor: advisor,
        client-principal: client-principal,
        name: name,
        risk-tolerance: risk-tolerance,
        age: age,
        net-worth: net-worth,
        annual-income: annual-income,
        created-at: stacks-block-height,
        status: "active"
      }
    )
    
    (var-set next-client-id (+ client-id u1))
    (var-set total-clients (+ (var-get total-clients) u1))
    (ok client-id)
  )
)

(define-public (update-client-data (client-id uint) (net-worth uint) (annual-income uint) (risk-tolerance uint))
  (let ((client-data (unwrap! (map-get? clients { client-id: client-id }) err-not-found)))
    (asserts! (or (is-eq tx-sender contract-owner) 
                  (is-eq tx-sender (get advisor client-data)) 
                  (is-eq tx-sender (get client-principal client-data))) err-unauthorized)
    (asserts! (<= risk-tolerance u10) err-invalid-data)
    
    (map-set clients
      { client-id: client-id }
      (merge client-data {
        net-worth: net-worth,
        annual-income: annual-income,
        risk-tolerance: risk-tolerance
      })
    )
    (ok true)
  )
)

;; Goal Tracking Functions
(define-public (create-financial-goal (client-id uint) (goal-type (string-ascii 50)) 
                                     (target-amount uint) (target-date uint) (priority-level uint))
  (let ((client-data (unwrap! (map-get? clients { client-id: client-id }) err-not-found))
        (goal-id (var-get next-goal-id)))
    (asserts! (or (is-eq tx-sender contract-owner) 
                  (is-eq tx-sender (get advisor client-data))) err-unauthorized)
    (asserts! (> target-amount u0) err-invalid-data)
    (asserts! (> target-date stacks-block-height) err-invalid-data)
    (asserts! (<= priority-level u5) err-invalid-data)
    
    (map-set financial-goals
      { client-id: client-id, goal-id: goal-id }
      {
        goal-type: goal-type,
        target-amount: target-amount,
        target-date: target-date,
        current-progress: u0,
        priority-level: priority-level,
        status: "active",
        created-at: stacks-block-height
      }
    )
    
    (var-set next-goal-id (+ goal-id u1))
    (ok goal-id)
  )
)

(define-public (update-goal-progress (client-id uint) (goal-id uint) (progress-amount uint))
  (let ((goal-data (unwrap! (map-get? financial-goals { client-id: client-id, goal-id: goal-id }) err-not-found))
        (client-data (unwrap! (map-get? clients { client-id: client-id }) err-not-found)))
    (asserts! (or (is-eq tx-sender contract-owner) 
                  (is-eq tx-sender (get advisor client-data))) err-unauthorized)
    (asserts! (is-eq (get status goal-data) "active") err-goal-not-active)
    
    (let ((new-progress (+ (get current-progress goal-data) progress-amount))
          (target (get target-amount goal-data)))
      (map-set financial-goals
        { client-id: client-id, goal-id: goal-id }
        (merge goal-data {
          current-progress: new-progress,
          status: (if (>= new-progress target) "completed" "active")
        })
      )
      (ok new-progress)
    )
  )
)

;; Scenario Modeling Functions
(define-public (create-scenario (client-id uint) (scenario-name (string-ascii 100)) 
                               (investment-return uint) (inflation-rate uint) (time-horizon uint))
  (let ((client-data (unwrap! (map-get? clients { client-id: client-id }) err-not-found))
        (scenario-id (var-get next-scenario-id)))
    (asserts! (or (is-eq tx-sender contract-owner) 
                  (is-eq tx-sender (get advisor client-data))) err-unauthorized)
    (asserts! (<= investment-return u2000) err-invalid-data)
    (asserts! (<= inflation-rate u1000) err-invalid-data)
    (asserts! (> time-horizon u0) err-invalid-data)
    
    (let ((projected-value (calculate-projection (get net-worth client-data) investment-return inflation-rate time-horizon))
          (risk-score (+ (/ investment-return u100) (get risk-tolerance client-data))))
      
      (map-set scenario-models
        { client-id: client-id, scenario-id: scenario-id }
        {
          scenario-name: scenario-name,
          investment-return: investment-return,
          inflation-rate: inflation-rate,
          time-horizon: time-horizon,
          projected-value: projected-value,
          risk-score: risk-score,
          created-at: stacks-block-height
        }
      )
      
      (var-set next-scenario-id (+ scenario-id u1))
      (ok scenario-id)
    )
  )
)

;; Compliance Management Functions
(define-public (add-compliance-record (client-id uint) (compliance-type (string-ascii 50)) 
                                     (review-date uint) (notes (string-ascii 500)) (next-review uint))
  (let ((client-data (unwrap! (map-get? clients { client-id: client-id }) err-not-found))
        (record-id (var-get next-record-id)))
    (asserts! (or (is-eq tx-sender contract-owner) 
                  (is-eq tx-sender (get advisor client-data))) err-unauthorized)
    (asserts! (> next-review stacks-block-height) err-invalid-data)
    
    (map-set compliance-records
      { advisor: (get advisor client-data), record-id: record-id }
      {
        client-id: client-id,
        compliance-type: compliance-type,
        review-date: review-date,
        status: "current",
        notes: notes,
        next-review: next-review
      }
    )
    
    (var-set next-record-id (+ record-id u1))
    (ok record-id)
  )
)

(define-public (register-advisor-license (advisor principal) (license-type (string-ascii 50)) 
                                        (license-number (string-ascii 50)) (expiry-date uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> expiry-date stacks-block-height) err-invalid-data)
    
    (map-set advisor-licenses
      { advisor: advisor }
      {
        license-type: license-type,
        license-number: license-number,
        issued-date: stacks-block-height,
        expiry-date: expiry-date,
        status: "active"
      }
    )
    
    (var-set total-advisors (+ (var-get total-advisors) u1))
    (ok true)
  )
)

;; Helper Functions
(define-private (calculate-projection (initial-value uint) (return-rate uint) (inflation uint) (years uint))
  (let ((real-return (- return-rate inflation))
        (growth-factor (+ u10000 real-return)))
    (* initial-value (pow growth-factor years))
  )
)

;; Read-only Functions
(define-read-only (get-client (client-id uint))
  (map-get? clients { client-id: client-id })
)

(define-read-only (get-financial-goal (client-id uint) (goal-id uint))
  (map-get? financial-goals { client-id: client-id, goal-id: goal-id })
)

(define-read-only (get-scenario (client-id uint) (scenario-id uint))
  (map-get? scenario-models { client-id: client-id, scenario-id: scenario-id })
)

(define-read-only (get-compliance-record (advisor principal) (record-id uint))
  (map-get? compliance-records { advisor: advisor, record-id: record-id })
)

(define-read-only (get-advisor-license (advisor principal))
  (map-get? advisor-licenses { advisor: advisor })
)

(define-read-only (get-platform-stats)
  {
    total-clients: (var-get total-clients),
    total-advisors: (var-get total-advisors),
    next-client-id: (var-get next-client-id)
  }
)

(define-read-only (calculate-goal-progress-percentage (client-id uint) (goal-id uint))
  (let ((goal-data (unwrap! (map-get? financial-goals { client-id: client-id, goal-id: goal-id }) err-not-found)))
    (ok (/ (* (get current-progress goal-data) u100) (get target-amount goal-data)))
  )
)


;; title: advisor-platform
;; version:
;; summary:
;; description:

;; traits
;;

;; token definitions
;;

;; constants
;;

;; data vars
;;

;; data maps
;;

;; public functions
;;

;; read only functions
;;

;; private functions
;;

