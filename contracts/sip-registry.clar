;; title: sip-registry
;; version: 1.0
;; summary: Central registry for the Stacks Interoperability Protocol
;; description: This contract manages the registry of supported chains, adapters, and resources

;; Message Relay - Initial Version
;; Core contract for basic cross-chain message passing

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-MESSAGE (err u101))
(define-constant ERR-ALREADY-PROCESSED (err u102))
(define-constant ERR-INVALID-CHAIN (err u103))

;; Contract owner
(define-constant CONTRACT-OWNER tx-sender)

;; Registry contract
(define-constant REGISTRY-CONTRACT 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.sip-registry)

;; Message status constants
(define-constant STATUS-PENDING "pending")
(define-constant STATUS-EXECUTED "executed")

;; Data structures

;; Message structure
;; A cross-chain message with all necessary metadata
(define-map message-registry
  { message-id: (buff 32) }
  {
    message-source-chain: uint,
    message-dest-chain: uint,
    message-sender: principal,
    message-recipient: (buff 32),
    message-payload: (buff 1024),
    message-timestamp: uint,
    message-status: (string-ascii 16)
  }
)

;; Access control - check if sender is contract owner
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

;; Send a cross-chain message
(define-public (send-message 
  (dest-registry-chain-id uint) 
  (recipient (buff 32)) 
  (payload (buff 1024))
)
  (let (
    (source-registry-chain-id u1)  ;; Stacks chain ID is 1 in this example
    (curr-time block-height)
    
    ;; Create a simple message ID from recipient and payload
    (message-id (sha256 (concat recipient payload)))
  )
    ;; Verify chain is supported
    (asserts! (contract-call? REGISTRY-CONTRACT is-chain-active dest-registry-chain-id) ERR-INVALID-CHAIN)
    
    ;; Store message
    (map-set message-registry
      { message-id: message-id }
      {
        message-source-chain: source-registry-chain-id,
        message-dest-chain: dest-registry-chain-id,
        message-sender: tx-sender,
        message-recipient: recipient,
        message-payload: payload,
        message-timestamp: curr-time,
        message-status: STATUS-PENDING
      }
    )
    
    ;; Emit event for relayers
    (print {
      event: "message-sent",
      message-id: message-id,
      source-chain: source-registry-chain-id,
      dest-chain: dest-registry-chain-id,
      sender: tx-sender,
      recipient: recipient
    })
    
    (ok message-id)
  )
)

;; Read-only functions

;; Get message information
(define-read-only (get-message (message-id (buff 32)))
  (map-get? message-registry { message-id: message-id })
)
