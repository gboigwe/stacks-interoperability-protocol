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
    chain-adapter: principal,
    chain-last-block: uint,
    chain-confirmations-required: uint
  }
)

;; Adapter Registry - stores information about chain adapters
(define-map adapter-registry
  { adapter-principal: principal }
  {
    adapter-chain-id: uint,
    adapter-type: (string-ascii 16),  ;; "light-client", "oracle", "hybrid"
    adapter-status: (string-ascii 16),  ;; "active", "paused", "deprecated"
    adapter-version: (string-ascii 16)
  }
)

;; Bridge Registry - stores information about bridge contracts
(define-map bridge-registry
  { bridge-source-chain: uint, bridge-target-chain: uint }
  {
    bridge-source-adapter: principal,
    bridge-target-adapter: principal,
    bridge-contract: principal,
    bridge-status: (string-ascii 16)  ;; "active", "paused", "deprecated"
  }
)

;; Resource Registry - stores information about bridged resources (tokens, etc.)
(define-map resource-registry
  { resource-chain-id: uint, resource-hash: (buff 32) }
  {
    resource-type: (string-ascii 16),  ;; "ft", "nft", "data"
    resource-contract: principal,
    resource-name: (string-ascii 64),
    resource-status: (string-ascii 16)  ;; "active", "paused", "deprecated"
  }
)

;; Access control - check if sender is contract owner
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

;; Chain management functions

;; Register a new chain
(define-public (register-chain 
  (registry-chain-id uint) 
  (chain-name (string-ascii 32)) 
  (chain-adapter principal) 
  (chain-confirmations uint)
)
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (is-none (map-get? chain-registry { registry-chain-id: registry-chain-id })) ERR-ALREADY-REGISTERED)
    
    (map-set chain-registry
      { registry-chain-id: registry-chain-id }
      {
        chain-name: chain-name,
        chain-status: "active",
        chain-adapter: chain-adapter,
        chain-last-block: u0,
        chain-confirmations-required: chain-confirmations
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

;; Update last processed block for a chain
(define-public (update-last-block (registry-chain-id uint) (new-block-height uint))
  (let (
    (chain-info (unwrap! (map-get? chain-registry { registry-chain-id: registry-chain-id }) ERR-NOT-REGISTERED))
    (adapter (get chain-adapter chain-info))
  )
    ;; Only the registered adapter for this chain can update the last block
    (asserts! (is-eq tx-sender adapter) ERR-NOT-AUTHORIZED)
    
    (map-set chain-registry
      { registry-chain-id: registry-chain-id }
      (merge chain-info { chain-last-block: new-block-height })
    )
    (ok new-block-height)
  )
)

;; Adapter management functions

;; Register a new adapter
(define-public (register-adapter 
  (adapter-id principal) 
  (registry-chain-id uint) 
  (adapter-type (string-ascii 16)) 
  (adapter-version (string-ascii 16))
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
        adapter-status: "active",
        adapter-version: adapter-version
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
  (source-adapter principal) 
  (target-adapter principal) 
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
        bridge-source-adapter: source-adapter,
        bridge-target-adapter: target-adapter,
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

;; Resource management functions

;; Register a new resource (token, NFT, etc.)
(define-public (register-resource 
  (resource-chain-id uint) 
  (resource-id (buff 32)) 
  (resource-type (string-ascii 16))
  (contract-address principal)
  (resource-name (string-ascii 64))
)
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (map-get? chain-registry { registry-chain-id: resource-chain-id })) ERR-INVALID-CHAIN)
    (asserts! (is-none (map-get? resource-registry { resource-chain-id: resource-chain-id, resource-hash: resource-id })) ERR-ALREADY-REGISTERED)
    
    (map-set resource-registry
      { resource-chain-id: resource-chain-id, resource-hash: resource-id }
      {
        resource-type: resource-type,
        resource-contract: contract-address,
        resource-name: resource-name,
        resource-status: "active"
      }
    )
    (ok resource-id)
  )
)

;; Update resource status
(define-public (update-resource-status 
  (resource-chain-id uint) 
  (resource-id (buff 32)) 
  (new-status (string-ascii 16))
)
  (let (
    (resource-info (unwrap! (map-get? resource-registry { resource-chain-id: resource-chain-id, resource-hash: resource-id }) ERR-NOT-REGISTERED))
  )
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    
    (map-set resource-registry
      { resource-chain-id: resource-chain-id, resource-hash: resource-id }
      (merge resource-info { resource-status: new-status })
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

;; Get resource information
(define-read-only (get-resource-info (resource-chain-id uint) (resource-id (buff 32)))
  (map-get? resource-registry { resource-chain-id: resource-chain-id, resource-hash: resource-id })
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
