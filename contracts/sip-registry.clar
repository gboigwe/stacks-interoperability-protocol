;; title: sip-registry
;; version: 1.0
;; summary: Central registry for the Stacks Interoperability Protocol
;; description: This contract manages the registry of supported chains, adapters, and resources

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ALREADY-REGISTERED (err u101))
(define-constant ERR-NOT-REGISTERED (err u102))
(define-constant ERR-INVALID-CHAIN (err u103))

;; Contract owner
(define-constant CONTRACT-OWNER tx-sender)

;; Data structures
;; Chain Registry - stores information about supported chains
(define-map chain-registry
  { registry-chain-id: uint }
  {
    chain-name: (string-ascii 32),
    chain-status: (string-ascii 16),  ;; "active", "paused", "deprecated"
    chain-adapter: principal
  }
)

;; Adapter Registry - stores information about chain adapters
(define-map adapter-registry
  { adapter-principal: principal }
  {
    adapter-chain-id: uint,
    adapter-type: (string-ascii 16),  ;; "light-client", "oracle", "hybrid"
    adapter-status: (string-ascii 16)  ;; "active", "paused", "deprecated"
  }
)

;; Bridge Registry - stores information about bridge contracts
(define-map bridge-registry
  { bridge-source-chain: uint, bridge-target-chain: uint }
  {
    bridge-contract: principal,
    bridge-status: (string-ascii 16)  ;; "active", "paused", "deprecated"
  }
)

;; Access control - check if sender is contract owner
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

;; Register a new chain
(define-public (register-chain 
  (registry-chain-id uint) 
  (chain-name (string-ascii 32))
  (chain-adapter principal)
)
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (is-none (map-get? chain-registry { registry-chain-id: registry-chain-id })) ERR-ALREADY-REGISTERED)
    
    (map-set chain-registry
      { registry-chain-id: registry-chain-id }
      {
        chain-name: chain-name,
        chain-status: "active",
        chain-adapter: chain-adapter
      }
    )
    (ok registry-chain-id)
  )
)

;; Update chain status
(define-public (update-chain-status (registry-chain-id uint) (new-status (string-ascii 16)))
  (let (
    (chain-info (unwrap! (map-get? chain-registry { registry-chain-id: registry-chain-id }) ERR-NOT-REGISTERED))
  )
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    
    (map-set chain-registry
      { registry-chain-id: registry-chain-id }
      (merge chain-info { chain-status: new-status })
    )
    (ok registry-chain-id)
  )
)

;; Adapter management functions
;; Register a new adapter
(define-public (register-adapter 
  (adapter-id principal) 
  (registry-chain-id uint) 
  (adapter-type (string-ascii 16))
)
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (is-none (map-get? adapter-registry { adapter-principal: adapter-id })) ERR-ALREADY-REGISTERED)
    (asserts! (is-some (map-get? chain-registry { registry-chain-id: registry-chain-id })) ERR-INVALID-CHAIN)
    
    (map-set adapter-registry
      { adapter-principal: adapter-id }
      {
        adapter-chain-id: registry-chain-id,
        adapter-type: adapter-type,
        adapter-status: "active"
      }
    )
    (ok adapter-id)
  )
)

;; Update adapter status
(define-public (update-adapter-status (adapter-id principal) (new-status (string-ascii 16)))
  (let (
    (adapter-info (unwrap! (map-get? adapter-registry { adapter-principal: adapter-id }) ERR-NOT-REGISTERED))
  )
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    
    (map-set adapter-registry
      { adapter-principal: adapter-id }
      (merge adapter-info { adapter-status: new-status })
    )
    (ok adapter-id)
  )
)

;; Bridge management functions
;; Register a new bridge between chains
(define-public (register-bridge 
  (source-registry-chain-id uint) 
  (target-registry-chain-id uint) 
  (bridge-contract principal)
)
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (map-get? chain-registry { registry-chain-id: source-registry-chain-id })) ERR-INVALID-CHAIN)
    (asserts! (is-some (map-get? chain-registry { registry-chain-id: target-registry-chain-id })) ERR-INVALID-CHAIN)
    (asserts! (is-none (map-get? bridge-registry { bridge-source-chain: source-registry-chain-id, bridge-target-chain: target-registry-chain-id })) ERR-ALREADY-REGISTERED)
    
    (map-set bridge-registry
      { bridge-source-chain: source-registry-chain-id, bridge-target-chain: target-registry-chain-id }
      {
        bridge-contract: bridge-contract,
        bridge-status: "active"
      }
    )
    (ok bridge-contract)
  )
)

;; Update bridge status
(define-public (update-bridge-status 
  (source-registry-chain-id uint) 
  (target-registry-chain-id uint) 
  (new-status (string-ascii 16))
)
  (let (
    (bridge-info (unwrap! (map-get? bridge-registry { bridge-source-chain: source-registry-chain-id, bridge-target-chain: target-registry-chain-id }) ERR-NOT-REGISTERED))
  )
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    
    (map-set bridge-registry
      { bridge-source-chain: source-registry-chain-id, bridge-target-chain: target-registry-chain-id }
      (merge bridge-info { bridge-status: new-status })
    )
    (ok true)
  )
)

;; Read-only functions
;; Get chain information
(define-read-only (get-chain-info (registry-chain-id uint))
  (map-get? chain-registry { registry-chain-id: registry-chain-id })
)

;; Get adapter information
(define-read-only (get-adapter-info (adapter-id principal))
  (map-get? adapter-registry { adapter-principal: adapter-id })
)

;; Get bridge information
(define-read-only (get-bridge-info (source-registry-chain-id uint) (target-registry-chain-id uint))
  (map-get? bridge-registry { bridge-source-chain: source-registry-chain-id, bridge-target-chain: target-registry-chain-id })
)

;; Check if a chain is active
(define-read-only (is-chain-active (registry-chain-id uint))
  (match (map-get? chain-registry { registry-chain-id: registry-chain-id })
    chain-info (is-eq (get chain-status chain-info) "active")
    false
  )
)

;; Check if a bridge is active
(define-read-only (is-bridge-active (source-registry-chain-id uint) (target-registry-chain-id uint))
  (match (map-get? bridge-registry { bridge-source-chain: source-registry-chain-id, bridge-target-chain: target-registry-chain-id })
    bridge-info (is-eq (get bridge-status bridge-info) "active")
    false
  )
)
