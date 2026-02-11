;; SIP-037 Agent Coordination Protocol - Stacks Implementation
;;
;; SIP-037 is a Stacks implementation of ERC-8001
;; Canonised version found at https://eips.ethereum.org/EIPS/eip-8001
;;
;; Trustless multi-party coordination for AI agents and humans.
;; Flow: PROPOSE - ACCEPT (signatures) - EXECUTE or CANCEL
;;
;; Clarity 3 (uses block-height for expiry)
;; Block time: ~10 min. 1 hour = 6 blocks, 1 day = 144 blocks

;; =============================================================================
;; CONSTANTS
;; =============================================================================

;; Coordination States
(define-constant STATE_NONE u0)
(define-constant STATE_PROPOSED u1)
(define-constant STATE_READY u2)
(define-constant STATE_EXECUTED u3)
(define-constant STATE_CANCELLED u4)
(define-constant STATE_EXPIRED u5)

;; Error Codes
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_INVALID_STATE (err u102))
(define-constant ERR_INVALID_SIGNATURE (err u103))
(define-constant ERR_NOT_PARTICIPANT (err u104))
(define-constant ERR_ALREADY_ACCEPTED (err u105))
(define-constant ERR_INTENT_EXPIRED (err u106))
(define-constant ERR_NONCE_TOO_LOW (err u107))
(define-constant ERR_INVALID_PARTICIPANTS (err u108))
(define-constant ERR_ACCEPTANCE_EXPIRED (err u109))
(define-constant ERR_PAYLOAD_MISMATCH (err u110))
(define-constant ERR_SERIALIZATION_FAILED (err u111))
(define-constant ERR_DUPLICATE_INTENT (err u112))

;; SIP-018 Structured Data Signing
(define-constant SIP018_PREFIX 0x534950303138)
(define-constant DOMAIN_NAME "SIP-037-Agent-Coordination")
(define-constant DOMAIN_VERSION "1")
(define-constant MSG_TYPE_INTENT "AgentIntent")
(define-constant MSG_TYPE_ACCEPTANCE "AcceptanceAttestation")

;; =============================================================================
;; DATA MAPS
;; =============================================================================

(define-map intents
  { intent-hash: (buff 32) }
  {
    agent: principal,
    payload-hash: (buff 32),
    expiry: uint,
    nonce: uint,
    coordination-type: (buff 32),
    coordination-value: uint,
    participants: (list 20 principal),
    status: uint,
    accept-count: uint
  }
)

(define-map agent-nonces
  { agent: principal }
  uint
)

(define-map acceptances
  { intent-hash: (buff 32), participant: principal }
  {
    expiry: uint,
    conditions: (buff 32)
  }
)

;; =============================================================================
;; SIP-018 HASHING
;; =============================================================================

(define-read-only (get-domain-tuple)
  {
    name: DOMAIN_NAME,
    version: DOMAIN_VERSION,
    chain-id: chain-id
  }
)

(define-read-only (get-domain-hash)
  (sha256 (unwrap-panic (to-consensus-buff? (get-domain-tuple))))
)

(define-private (compute-structured-data-hash (message-buff (buff 8192)))
  (sha256
    (concat SIP018_PREFIX
      (concat (get-domain-hash) (sha256 message-buff))
    )
  )
)

;; =============================================================================
;; INTENT HASH COMPUTATION
;; =============================================================================

(define-private (make-intent-message
    (payload-hash (buff 32))
    (expiry uint)
    (nonce uint)
    (agent principal)
    (coordination-type (buff 32))
    (coordination-value uint)
    (participants (list 20 principal)))
  {
    msg-type: MSG_TYPE_INTENT,
    payload-hash: payload-hash,
    expiry: expiry,
    nonce: nonce,
    agent: agent,
    coordination-type: coordination-type,
    coordination-value: coordination-value,
    participants: participants
  }
)

(define-read-only (compute-intent-hash
    (payload-hash (buff 32))
    (expiry uint)
    (nonce uint)
    (agent principal)
    (coordination-type (buff 32))
    (coordination-value uint)
    (participants (list 20 principal)))
  (let (
    (intent-msg (make-intent-message
      payload-hash expiry nonce agent
      coordination-type coordination-value participants))
  )
    (match (to-consensus-buff? intent-msg)
      serialized (ok (compute-structured-data-hash serialized))
      ERR_SERIALIZATION_FAILED
    )
  )
)

;; =============================================================================
;; ACCEPTANCE HASH COMPUTATION
;; =============================================================================

(define-private (make-acceptance-message
    (intent-hash (buff 32))
    (participant principal)
    (accept-nonce uint)
    (expiry uint)
    (conditions (buff 32)))
  {
    msg-type: MSG_TYPE_ACCEPTANCE,
    intent-hash: intent-hash,
    participant: participant,
    nonce: accept-nonce,
    expiry: expiry,
    conditions: conditions
  }
)

(define-read-only (compute-acceptance-digest
    (intent-hash (buff 32))
    (participant principal)
    (accept-nonce uint)
    (expiry uint)
    (conditions (buff 32)))
  (let (
    (acceptance-msg (make-acceptance-message
      intent-hash participant accept-nonce expiry conditions))
  )
    (match (to-consensus-buff? acceptance-msg)
      serialized (ok (compute-structured-data-hash serialized))
      ERR_SERIALIZATION_FAILED
    )
  )
)

;; =============================================================================
;; PARTICIPANT VALIDATION
;; =============================================================================

(define-private (principal-in-list? (p principal) (plist (list 20 principal)))
  (is-some (index-of? plist p))
)

;; Compare principals by comparing bytes of consensus buffer
;; Uses element-at? which returns (buff 1) avoiding type issues
(define-private (principal-lt? (a principal) (b principal))
  (let (
    (a-buff (unwrap-panic (to-consensus-buff? a)))
    (b-buff (unwrap-panic (to-consensus-buff? b)))
  )
    ;; Compare first 8 bytes (sufficient for ordering)
    (let (
      (a0 (buff-to-uint-be (default-to 0x00 (element-at? a-buff u0))))
      (b0 (buff-to-uint-be (default-to 0x00 (element-at? b-buff u0))))
      (a1 (buff-to-uint-be (default-to 0x00 (element-at? a-buff u1))))
      (b1 (buff-to-uint-be (default-to 0x00 (element-at? b-buff u1))))
      (a2 (buff-to-uint-be (default-to 0x00 (element-at? a-buff u2))))
      (b2 (buff-to-uint-be (default-to 0x00 (element-at? b-buff u2))))
      (a3 (buff-to-uint-be (default-to 0x00 (element-at? a-buff u3))))
      (b3 (buff-to-uint-be (default-to 0x00 (element-at? b-buff u3))))
      (a4 (buff-to-uint-be (default-to 0x00 (element-at? a-buff u4))))
      (b4 (buff-to-uint-be (default-to 0x00 (element-at? b-buff u4))))
      (a5 (buff-to-uint-be (default-to 0x00 (element-at? a-buff u5))))
      (b5 (buff-to-uint-be (default-to 0x00 (element-at? b-buff u5))))
      (a6 (buff-to-uint-be (default-to 0x00 (element-at? a-buff u6))))
      (b6 (buff-to-uint-be (default-to 0x00 (element-at? b-buff u6))))
      (a7 (buff-to-uint-be (default-to 0x00 (element-at? a-buff u7))))
      (b7 (buff-to-uint-be (default-to 0x00 (element-at? b-buff u7))))
    )
      ;; Lexicographic comparison
      (if (< a0 b0) true
      (if (> a0 b0) false
      (if (< a1 b1) true
      (if (> a1 b1) false
      (if (< a2 b2) true
      (if (> a2 b2) false
      (if (< a3 b3) true
      (if (> a3 b3) false
      (if (< a4 b4) true
      (if (> a4 b4) false
      (if (< a5 b5) true
      (if (> a5 b5) false
      (if (< a6 b6) true
      (if (> a6 b6) false
      (< a7 b7)))))))))))))))
    )
  )
)

(define-private (check-sorted-step
    (current principal)
    (state { valid: bool, prev: (optional principal) }))
  (let ((prev-opt (get prev state)))
    (if (not (get valid state))
      { valid: false, prev: (some current) }
      (match prev-opt
        prev-val
          { valid: (principal-lt? prev-val current), prev: (some current) }
        { valid: true, prev: (some current) }
      )
    )
  )
)

(define-private (is-sorted-unique? (plist (list 20 principal)))
  (let ((n (len plist)))
    (if (<= n u1)
      true
      (get valid (fold check-sorted-step plist { valid: true, prev: none }))
    )
  )
)

(define-private (validate-participants
    (participants (list 20 principal))
    (agent principal))
  (and
    (> (len participants) u0)
    (is-sorted-unique? participants)
    (principal-in-list? agent participants)
  )
)

;; =============================================================================
;; SIGNATURE VERIFICATION
;; =============================================================================

(define-private (verify-signature
    (message-hash (buff 32))
    (signature (buff 65))
    (expected-signer principal))
  (match (secp256k1-recover? message-hash signature)
    recovered-pubkey
      (match (principal-of? recovered-pubkey)
        recovered-principal (is-eq recovered-principal expected-signer)
        err-principal false
      )
    err-recover false
  )
)

;; =============================================================================
;; STATUS HELPERS
;; =============================================================================

(define-private (get-effective-status (stored-status uint) (expiry uint))
  (if (or (is-eq stored-status STATE_EXECUTED)
          (is-eq stored-status STATE_CANCELLED))
    stored-status
    (if (> stacks-block-height expiry)
      STATE_EXPIRED
      stored-status
    )
  )
)

(define-private (check-acceptance-fresh
    (participant principal)
    (state { fresh: bool, intent-hash: (buff 32) }))
  (if (not (get fresh state))
    state
    (match (map-get? acceptances
              { intent-hash: (get intent-hash state), participant: participant })
      acceptance
        {
          fresh: (<= stacks-block-height (get expiry acceptance)),
          intent-hash: (get intent-hash state)
        }
      { fresh: false, intent-hash: (get intent-hash state) }
    )
  )
)

(define-private (all-acceptances-fresh?
    (intent-hash (buff 32))
    (participants (list 20 principal)))
  (get fresh
    (fold check-acceptance-fresh
      participants
      { fresh: true, intent-hash: intent-hash }))
)

;; =============================================================================
;; PUBLIC: PROPOSE
;; =============================================================================

(define-public (propose-coordination
    (payload-hash (buff 32))
    (expiry uint)
    (nonce uint)
    (coordination-type (buff 32))
    (coordination-value uint)
    (participants (list 20 principal)))
  (let (
    (agent tx-sender)
    (now stacks-block-height)
    (prev-nonce (default-to u0 (map-get? agent-nonces { agent: agent })))
  )
    (asserts! (> expiry now) ERR_INTENT_EXPIRED)
    (asserts! (> nonce prev-nonce) ERR_NONCE_TOO_LOW)
    (asserts! (validate-participants participants agent) ERR_INVALID_PARTICIPANTS)

    (let (
      (intent-hash-result (compute-intent-hash
        payload-hash expiry nonce agent
        coordination-type coordination-value participants))
    )
      (match intent-hash-result
        intent-hash
          (begin
            (asserts! (is-none (map-get? intents { intent-hash: intent-hash }))
                      ERR_DUPLICATE_INTENT)

            (map-set intents { intent-hash: intent-hash }
              {
                agent: agent,
                payload-hash: payload-hash,
                expiry: expiry,
                nonce: nonce,
                coordination-type: coordination-type,
                coordination-value: coordination-value,
                participants: participants,
                status: STATE_PROPOSED,
                accept-count: u0
              }
            )

            (map-set agent-nonces { agent: agent } nonce)

            (print {
              event: "coordination-proposed",
              intent-hash: intent-hash,
              agent: agent,
              coordination-type: coordination-type,
              coordination-value: coordination-value,
              participant-count: (len participants),
              expiry: expiry
            })

            (ok intent-hash)
          )
        err-val (err err-val)
      )
    )
  )
)

;; =============================================================================
;; PUBLIC: ACCEPT
;; =============================================================================

(define-public (accept-coordination
    (intent-hash (buff 32))
    (accept-expiry uint)
    (conditions (buff 32))
    (signature (buff 65)))
  (let (
    (caller tx-sender)
    (now stacks-block-height)
    (accept-nonce u0)
  )
    (match (map-get? intents { intent-hash: intent-hash })
      intent
        (begin
          (asserts! (<= now (get expiry intent)) ERR_INTENT_EXPIRED)
          (asserts! (is-eq (get status intent) STATE_PROPOSED) ERR_INVALID_STATE)
          (asserts! (principal-in-list? caller (get participants intent))
                    ERR_NOT_PARTICIPANT)
          (asserts! (is-none (map-get? acceptances
                      { intent-hash: intent-hash, participant: caller }))
                    ERR_ALREADY_ACCEPTED)
          (asserts! (> accept-expiry now) ERR_ACCEPTANCE_EXPIRED)

          (let (
            (digest-result (compute-acceptance-digest
              intent-hash caller accept-nonce accept-expiry conditions))
          )
            (match digest-result
              digest
                (begin
                  (asserts! (verify-signature digest signature caller)
                            ERR_INVALID_SIGNATURE)

                  (map-set acceptances
                    { intent-hash: intent-hash, participant: caller }
                    { expiry: accept-expiry, conditions: conditions }
                  )

                  (let (
                    (new-count (+ (get accept-count intent) u1))
                    (total-required (len (get participants intent)))
                    (new-status (if (>= new-count total-required)
                                  STATE_READY
                                  STATE_PROPOSED))
                  )
                    (map-set intents { intent-hash: intent-hash }
                      (merge intent {
                        accept-count: new-count,
                        status: new-status
                      })
                    )

                    (print {
                      event: "coordination-accepted",
                      intent-hash: intent-hash,
                      participant: caller,
                      accepted-count: new-count,
                      required-count: total-required,
                      is-ready: (>= new-count total-required)
                    })

                    (ok (>= new-count total-required))
                  )
                )
              err-val (err err-val)
            )
          )
        )
      ERR_NOT_FOUND
    )
  )
)

;; =============================================================================
;; PUBLIC: EXECUTE
;; =============================================================================

(define-public (execute-coordination
    (intent-hash (buff 32))
    (payload (buff 1024))
    (execution-data (buff 1024)))
  (let ((now stacks-block-height))
    (match (map-get? intents { intent-hash: intent-hash })
      intent
        (begin
          (asserts! (is-eq (get status intent) STATE_READY) ERR_INVALID_STATE)
          (asserts! (<= now (get expiry intent)) ERR_INTENT_EXPIRED)
          (asserts! (all-acceptances-fresh? intent-hash (get participants intent))
                    ERR_ACCEPTANCE_EXPIRED)
          (asserts! (is-eq (sha256 payload) (get payload-hash intent))
                    ERR_PAYLOAD_MISMATCH)

          (map-set intents { intent-hash: intent-hash }
            (merge intent { status: STATE_EXECUTED })
          )

          (print {
            event: "coordination-executed",
            intent-hash: intent-hash,
            executor: tx-sender,
            payload-hash: (get payload-hash intent),
            coordination-type: (get coordination-type intent),
            coordination-value: (get coordination-value intent)
          })

          (ok true)
        )
      ERR_NOT_FOUND
    )
  )
)

;; =============================================================================
;; PUBLIC: CANCEL
;; =============================================================================

(define-public (cancel-coordination
    (intent-hash (buff 32))
    (reason (string-ascii 64)))
  (let ((now stacks-block-height))
    (match (map-get? intents { intent-hash: intent-hash })
      intent
        (let (
          (agent (get agent intent))
          (status (get status intent))
          (expiry (get expiry intent))
        )
          (asserts! (not (is-eq status STATE_EXECUTED)) ERR_INVALID_STATE)
          (asserts! (not (is-eq status STATE_CANCELLED)) ERR_INVALID_STATE)
          (asserts! (or (is-eq tx-sender agent) (> now expiry))
                    ERR_UNAUTHORIZED)

          (map-set intents { intent-hash: intent-hash }
            (merge intent { status: STATE_CANCELLED })
          )

          (print {
            event: "coordination-cancelled",
            intent-hash: intent-hash,
            canceller: tx-sender,
            reason: reason,
            was-expired: (> now expiry)
          })

          (ok true)
        )
      ERR_NOT_FOUND
    )
  )
)

;; =============================================================================
;; READ-ONLY: QUERIES
;; =============================================================================

(define-read-only (get-coordination-status (intent-hash (buff 32)))
  (match (map-get? intents { intent-hash: intent-hash })
    intent
      (let (
        (effective-status (get-effective-status
          (get status intent)
          (get expiry intent)))
        (accepted-list (get-accepted-participants intent-hash (get participants intent)))
      )
        (ok {
          status: effective-status,
          agent: (get agent intent),
          participants: (get participants intent),
          accepted-by: accepted-list,
          accept-count: (get accept-count intent),
          expiry: (get expiry intent),
          coordination-type: (get coordination-type intent),
          coordination-value: (get coordination-value intent),
          payload-hash: (get payload-hash intent)
        })
      )
    ERR_NOT_FOUND
  )
)

(define-private (collect-accepted
    (p principal)
    (state { accepted: (list 20 principal), intent-hash: (buff 32) }))
  (if (is-some (map-get? acceptances
        { intent-hash: (get intent-hash state), participant: p }))
    {
      accepted: (unwrap-panic (as-max-len?
        (append (get accepted state) p) u20)),
      intent-hash: (get intent-hash state)
    }
    state
  )
)

(define-read-only (get-accepted-participants
    (intent-hash (buff 32))
    (participants (list 20 principal)))
  (get accepted
    (fold collect-accepted participants
      { accepted: (list), intent-hash: intent-hash }))
)

(define-read-only (get-required-acceptances (intent-hash (buff 32)))
  (match (map-get? intents { intent-hash: intent-hash })
    intent (ok (len (get participants intent)))
    ERR_NOT_FOUND
  )
)

(define-read-only (get-agent-nonce (agent principal))
  (default-to u0 (map-get? agent-nonces { agent: agent }))
)

(define-read-only (get-acceptance
    (intent-hash (buff 32))
    (participant principal))
  (map-get? acceptances { intent-hash: intent-hash, participant: participant })
)

;; =============================================================================
;; READ-ONLY: SIGNING HELPERS
;; =============================================================================

(define-read-only (get-signing-domain)
  {
    name: DOMAIN_NAME,
    version: DOMAIN_VERSION,
    chain-id: chain-id,
    domain-hash: (get-domain-hash)
  }
)

(define-read-only (get-acceptance-message-to-sign
    (intent-hash (buff 32))
    (participant principal)
    (expiry uint)
    (conditions (buff 32)))
  {
    domain: (get-domain-tuple),
    message: (make-acceptance-message
      intent-hash participant u0 expiry conditions)
  }
)