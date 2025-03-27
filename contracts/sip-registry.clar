;; title: sip-registry
;; version: 1.0
;; summary: Central registry for the Stacks Interoperability Protocol
;; description: This contract manages the registry of supported chains, adapters, and resources

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-MESSAGE (err u101))
(define-constant ERR-ALREADY-PROCESSED (err u102))
(define-constant ERR-INVALID-CHAIN (err u103))
(define-constant ERR-VERIFICATION-FAILED (err u104))
(define-constant ERR-MESSAGE-EXPIRED (err u105))

;; Contract owner
(define-constant CONTRACT-OWNER tx-sender)

;; Registry contract
(define-constant REGISTRY-CONTRACT 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.sip-registry)

;; Message status constants
(define-constant STATUS-PENDING "pending")
(define-constant STATUS-EXECUTED "executed")
(define-constant STATUS-FAILED "failed")

;; Data structures

;; Message structure
;; A cross-chain message with all necessary metadata
(define-map message-registry
  { message-id: (buff 32) }
  {
    message-source-chain: uint,
    message-dest-chain: uint,
    message-nonce: uint,
    message-sender: principal,
    message-recipient: (buff 32),
    message-payload: (buff 1024),
    message-timestamp: uint,
    message-expiration: uint,
    message-status: (string-ascii 16)
  }
)

;; Message nonce tracking to prevent replay attacks
(define-map nonce-registry
  { nonce-chain-id: uint }
  { next-nonce: uint }
)

;; Processed messages to prevent duplicates
(define-map processed-registry
  { processed-source-chain: uint, processed-nonce: uint }
  { processed: bool }
)

;; Variables
(define-data-var message-fee uint u1000) ;; Fee in microSTX for sending messages

;; Functions

;; Access control - check if sender is contract owner
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

;; Send a cross-chain message
(define-public (send-message 
  (dest-registry-chain-id uint) 
  (recipient (buff 32)) 
  (payload (buff 1024))
  (expiration uint)
)
  (let (
    (source-registry-chain-id u1)  ;; Stacks chain ID is 1 in this example
    (nonce-data (default-to { next-nonce: u0 } (map-get? nonce-registry { nonce-chain-id: source-registry-chain-id })))
    (next-nonce (get next-nonce nonce-data))
    (curr-time block-height)
    
    ;; Create a simple message ID from recipient and payload
    (message-id (sha256 (concat recipient payload)))
  )
    ;; Verify chain is supported
    (asserts! (contract-call? REGISTRY-CONTRACT is-chain-active dest-registry-chain-id) ERR-INVALID-CHAIN)
    
    ;; Collect message fee
    (try! (stx-transfer? (var-get message-fee) tx-sender CONTRACT-OWNER))
    
    ;; Store message
    (map-set message-registry
      { message-id: message-id }
      {
        message-source-chain: source-registry-chain-id,
        message-dest-chain: dest-registry-chain-id,
        message-nonce: next-nonce,
        message-sender: tx-sender,
        message-recipient: recipient,
        message-payload: payload,
        message-timestamp: curr-time,
        message-expiration: expiration,
        message-status: STATUS-PENDING
      }
    )
    
    ;; Update nonce
    (map-set nonce-registry
      { nonce-chain-id: source-registry-chain-id }
      { next-nonce: (+ next-nonce u1) }
    )
    
    ;; Emit event for relayers
    (print {
      event: "message-sent",
      message-id: message-id,
      source-chain: source-registry-chain-id,
      dest-chain: dest-registry-chain-id,
      nonce: next-nonce,
      sender: tx-sender,
      recipient: recipient
    })
    
    (ok message-id)
  )
)

;; Receive and process a message from another chain
(define-public (receive-message
  (source-registry-chain-id uint)
  (nonce uint)
  (sender principal)
  (recipient (buff 32))
  (payload (buff 1024))
  (timestamp uint)
  (expiration uint)
  (message-id (buff 32))
)
  (let (
    (dest-registry-chain-id u1)  ;; Stacks chain ID is 1
    (curr-time block-height)
  )
    ;; Check if message already processed
    (asserts! (is-none (map-get? processed-registry 
      { processed-source-chain: source-registry-chain-id, processed-nonce: nonce })) 
      ERR-ALREADY-PROCESSED)
    
    ;; Verify chain is supported
    (asserts! (contract-call? REGISTRY-CONTRACT is-chain-active source-registry-chain-id) ERR-INVALID-CHAIN)
    
    ;; Check message hasn't expired
    (asserts! (< curr-time expiration) ERR-MESSAGE-EXPIRED)
    
    ;; Mark message as processed
    (map-set processed-registry
      { processed-source-chain: source-registry-chain-id, processed-nonce: nonce }
      { processed: true }
    )
    
    ;; Store message
    (map-set message-registry
      { message-id: message-id }
      {
        message-source-chain: source-registry-chain-id,
        message-dest-chain: dest-registry-chain-id,
        message-nonce: nonce,
        message-sender: sender,
        message-recipient: recipient,
        message-payload: payload,
        message-timestamp: timestamp,
        message-expiration: expiration,
        message-status: STATUS-EXECUTED
      }
    )
    
    ;; Forward message to recipient contract
    ;; In a real implementation, this would use a more sophisticated mechanism
    ;; for handling different message types
    (print {
      event: "message-received",
      message-id: message-id,
      source-chain: source-registry-chain-id,
      dest-chain: dest-registry-chain-id,
      nonce: nonce,
      sender: sender,
      recipient: tx-sender
    })
    
    (ok message-id)
  )
)

;; Admin functions

;; Update message fee
(define-public (set-message-fee (new-fee uint))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (var-set message-fee new-fee)
    (ok new-fee)
  )
)

;; Read-only functions

;; Get message information
(define-read-only (get-message (message-id (buff 32)))
  (map-get? message-registry { message-id: message-id })
)

;; Check if a message has been processed
(define-read-only (is-message-processed (source-registry-chain-id uint) (nonce uint))
  (match (map-get? processed-registry 
    { processed-source-chain: source-registry-chain-id, processed-nonce: nonce })
    processed-info true
    false
  )
)

;; Get current message fee
(define-read-only (get-message-fee)
  (var-get message-fee)
)
