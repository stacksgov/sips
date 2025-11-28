;; SIP-XXX Agent Coordination Contract
;; This contract implements the core logic of SIP-XXX: proposing intents, collecting acceptances, and state transitions.
;;
;; Constants (status codes and error codes)
(define-constant NONE u0)
(define-constant PROPOSED u1)
(define-constant READY u2)
(define-constant EXECUTED u3)
(define-constant CANCELLED u4)
(define-constant EXPIRED u5)

(define-constant ERR_UNAUTHORISED u401)          ;; Caller is not authorised to perform this action (e.g., not the initiator)
(define-constant ERR_NOT_FOUND u404)             ;; Specified intent not found
(define-constant ERR_INVALID_STATE u405)         ;; Operation not allowed in current state (e.g., accepting an already executed intent)
(define-constant ERR_INVALID_SIGNATURE u406)     ;; Provided signature did not verify correctly
(define-constant ERR_DUPLICATE_PARTICIPANT u407) ;; Duplicate participant in list (violates uniqueness)
(define-constant ERR_NOT_PARTICIPANT u408)       ;; Caller not in participants list
(define-constant ERR_ALREADY_ACCEPTED u409)      ;; This participant’s acceptance already recorded
(define-constant ERR_EXPIRED u410)               ;; Intent or acceptance has expired, action not allowed
(define-constant ERR_NONCE_NOT_HIGHER u411)      ;; Nonce provided is not higher than the initiator’s previous nonce
(define-constant ERR_INVALID_PARAMS u412)        ;; General invalid parameters (e.g., missing agent in list, unsorted list in strict implementation)

;; Data maps
(define-map intents ((intent-hash (buff 32)))
    (
        (agent principal)               ;; initiator of the intent
        (expiry uint)                   ;; expiration time for the intent
        (nonce uint)                    ;; nonce of the intent (for initiator)
        (coord-type (buff 32))          ;; coordination type identifier
        (coord-value uint)              ;; coordination value field
        (participants (list 100 principal))  ;; list of participants' principals (unique, sorted)
        (status uint)                   ;; current status code of the intent
        (accept-count uint)             ;; how many acceptances have been collected
    )
)

(define-map last-nonce ((agent principal)) ((nonce uint)))  ;; tracks the latest nonce used by each initiator

(define-map acceptances ((intent-hash (buff 32)) (participant principal)) ((accept-expiry uint)))

;; Private helper: convert a principal to a 21-byte buffer (version byte + 20-byte hash)
(define-private (principal->bytes (p principal))
    (let ((res (principal-destruct? p)))
        (match res
            err (unwrap-panic res)   ;; principal-destruct? only errors if principal is invalid; unwrap-panic triggers if so
            ok-data
                (let ((version (tuple-get ok-data "version")) (hash-bytes (tuple-get ok-data "hash-bytes")))
                    ;; concatenate version and hash (both buffers) to produce 21-byte representation
                    (concat version hash-bytes)
                )
        )
    )
)

;; Private helper: check if a list of principals contains a given principal
(define-private (contains? (plist (list 100 principal)) (p principal))
    (if (is-eq plist (list))
        false
        (let ((head (unwrap-panic (get 0 plist))))
            (or (is-eq head p) (contains? (list-drop-n 1 plist) p))
        )
    )
)

;; Private helper: check if a participants list has unique entries (no duplicates).
(define-private (is-unique-list (plist (list 100 principal)))
    (if (is-eq plist (list))
        true
        (let (
                (head (unwrap-panic (get 0 plist)))
                (tail (list-drop-n 1 plist))
             )
            (if (contains? tail head)
                false
                (is-unique-list tail)
            )
        )
    )
)

;; Compute an intent hash from given fields (simplified for reference: includes contract domain and key fields)
(define-private (compute-intent-hash (agent principal) (participants (list 100 principal)) (payload-hash (buff 32)) (expiry uint) (nonce uint) (coord-type (buff 32)) (coord-value uint))
    (keccak256
        (concat
            (principal->bytes (as-contract tx-sender))   ;; domain: using contract's principal (current contract) - Clarity uses (as-contract tx-sender) as current contract principal
            (principal->bytes agent)
            payload-hash
        )
    )
)
;; NOTE: In a full implementation, the hash should include all fields (expiry, nonce, coord-type, coord-value, participants list, etc.) in a deterministic encoded form,
;; along with chain-id and contract name for domain separation. This simplified version only includes critical parts for brevity.

;; Public function: propose a new intent
(define-public (propose-intent (agent principal) (participants (list 100 principal)) (expiry uint) (nonce uint) (coord-type (buff 32)) (coord-value uint) (payload-hash (buff 32)))
    (begin
        ;; Only the agent (initiator) can propose their intent
        (if (not (is-eq agent tx-sender))
            (err ERR_UNAUTHORISED)
        )
        ;; Participants list must contain the agent
        (if (not (contains? participants agent))
            (err ERR_INVALID_PARAMS)  ;; initiator not in participants list
        )
        ;; Check participant list uniqueness (and sorting, if we enforce separately)
        (if (not (is-unique-list participants))
            (err ERR_DUPLICATE_PARTICIPANT)
        )
        ;; Nonce must be greater than last used nonce for this agent
        (let ((prev-nonce (unwrap-or (map-get? last-nonce ((agent agent))) {nonce: u0})))
            (if (<= nonce (get nonce prev-nonce))
                (err ERR_NONCE_NOT_HIGHER)
            )
        )
        ;; Expiry must be in the future (greater than current block time)
        (let ((now (stacks-block-time)))
            (if (<= expiry now)
                (err ERR_EXPIRED)
            )
        )
        ;; Compute unique intent hash (ID)
        (let ((intent-hash (compute-intent-hash agent participants payload-hash expiry nonce coord-type coord-value)))
            ;; Ensure not already used (i.e., not conflicting with an existing intent)
            (if (map-get? intents ((intent-hash intent-hash)))
                (err ERR_INVALID_PARAMS)  ;; collision or reuse
            )
            ;; Store the intent
            (map-set intents
                ((intent-hash intent-hash))
                (
                    (agent agent)
                    (expiry expiry)
                    (nonce nonce)
                    (coord-type coord-type)
                    (coord-value coord-value)
                    (participants participants)
                    (status PROPOSED)
                    (accept-count u0)
                )
            )
            ;; Update the initiator's last nonce
            (map-set last-nonce ((agent agent)) ((nonce nonce)))
            ;; Return the intent identifier
            (ok intent-hash)
        )
    )
)

;; Public function: accept an intent (participant provides their signature)
(define-public (accept-intent (intent-hash (buff 32)) (accept-expiry uint) (conditions (buff 32)) (signature (buff 65)))
    (begin
        ;; Ensure the intent exists
        (let ((intent-data (map-get? intents ((intent-hash intent-hash)))))
            (if (is-none intent-data)
                (err ERR_NOT_FOUND)
            )
            (let (
                    (intent (unwrap intent-data ERR_NOT_FOUND))
                    (now (stacks-block-time))
                 )
                ;; Check intent status is Proposed (still collecting signatures)
                (if (not (is-eq (get status intent) PROPOSED))
                    (err ERR_INVALID_STATE)
                )
                ;; Intent must not be expired
                (if (> now (get expiry intent))
                    (begin
                        ;; Mark as expired if past expiry
                        (map-set intents ((intent-hash intent-hash)) (tuple (agent (get agent intent)) (expiry (get expiry intent)) (nonce (get nonce intent)) (coord-type (get coord-type intent)) (coord-value (get coord-value intent)) (participants (get participants intent)) (status EXPIRED) (accept-count (get accept-count intent))))
                        (err ERR_EXPIRED)
                    )
                )
                ;; The caller must be one of the participants
                (if (not (contains? (get participants intent) tx-sender))
                    (err ERR_NOT_PARTICIPANT)
                )
                ;; Check if already accepted by this participant
                (if (map-get? acceptances ((intent-hash intent-hash) (participant tx-sender)))
                    (err ERR_ALREADY_ACCEPTED)
                )
                ;; The acceptance's expiry must not be in the past and not beyond intent expiry
                (if (<= accept-expiry now)
                    (err ERR_EXPIRED)
                )
                (if (> accept-expiry (get expiry intent))
                    (err ERR_INVALID_PARAMS)   ;; participant's acceptance expiry cannot exceed intent expiry
                )
                ;; Verify the signature: recover the public key and derive principal
                (let (
                        ;; Prepare message hash for verification: we hash intent-hash + participant + their constraints + contract domain
                        (msg-hash (keccak256
                                     (concat
                                       (principal->bytes (as-contract tx-sender))
                                       intent-hash
                                       (principal->bytes tx-sender)
                                       conditions
                                       (buff 0)    ;; Note: if we included accept-expiry and nonce in the signed data, we'd need to encode them here.
                                     )
                                   ))
                        (recover-result (secp256k1-recover? msg-hash signature))
                     )
                    (match recover-result
                        err (err ERR_INVALID_SIGNATURE)
                        ok (let ((pubkey recover-result))
                                (let ((derived-principal (principal-of? pubkey)))
                                    (match derived-principal
                                        err (err ERR_INVALID_SIGNATURE)
                                        ok (let ((signer (unwrap derived-principal ERR_INVALID_SIGNATURE)))
                                                ;; Check that the derived principal matches the tx-sender (the claimed participant)
                                                (if (is-eq signer tx-sender)
                                                    (begin
                                                        ;; Record the acceptance
                                                        (map-set acceptances ((intent-hash intent-hash) (participant tx-sender)) ((accept-expiry accept-expiry)))
                                                        ;; Increment acceptance count
                                                        (map-set intents ((intent-hash intent-hash))
                                                            (tuple
                                                                (agent (get agent intent))
                                                                (expiry (get expiry intent))
                                                                (nonce (get nonce intent))
                                                                (coord-type (get coord-type intent))
                                                                (coord-value (get coord-value intent))
                                                                (participants (get participants intent))
                                                                (status (get status intent))
                                                                (accept-count (+ u1 (get accept-count intent)))
                                                            )
                                                        )
                                                        ;; If this was the last required acceptance, update status to Ready
                                                        (let ((new-count (+ u1 (get accept-count intent))) (total (len (get participants intent))))
                                                            (if (>= new-count total)
                                                                (map-set intents ((intent-hash intent-hash)) (tuple
                                                                    (agent (get agent intent))
                                                                    (expiry (get expiry intent))
                                                                    (nonce (get nonce intent))
                                                                    (coord-type (get coord-type intent))
                                                                    (coord-value (get coord-value intent))
                                                                    (participants (get participants intent))
                                                                    (status READY)
                                                                    (accept-count new-count)
                                                                ))
                                                            )
                                                        )
                                                        (ok true)
                                                    )
                                                    (err ERR_INVALID_SIGNATURE)
                                                )
                                            )
                                    )
                                )
                            )
                    )
                )
            )
        )
    )
)

;; Public function: execute an intent (mark as executed if ready)
(define-public (execute-intent (intent-hash (buff 32)))
    (begin
        (let ((intent-data (map-get? intents ((intent-hash intent-hash)))))
            (if (is-none intent-data)
                (err ERR_NOT_FOUND)
            )
            (let ((intent (unwrap intent-data ERR_NOT_FOUND)) (now (stacks-block-time)))
                ;; Only allow execution if status is Ready
                (if (not (is-eq (get status intent) READY))
                    (err ERR_INVALID_STATE)
                )
                ;; Check current time against intent expiry
                (if (> now (get expiry intent))
                    (err ERR_EXPIRED)
                )
                ;; Check that all acceptance attestations are still valid (not expired individually)
                (let ((plist (get participants intent)))
                    (if (is-expired-acceptance? intent-hash plist now)
                        (err ERR_EXPIRED)
                    )
                )
                ;; (Business logic for executing the intent's action would go here, if applicable)
                ;; Mark intent as executed
                (map-set intents ((intent-hash intent-hash))
                    (tuple
                        (agent (get agent intent))
                        (expiry (get expiry intent))
                        (nonce (get nonce intent))
                        (coord-type (get coord-type intent))
                        (coord-value (get coord-value intent))
                        (participants (get participants intent))
                        (status EXECUTED)
                        (accept-count (get accept-count intent))
                    )
                )
                (ok true)
            )
        )
    )
)

;; Public function: cancel an intent (initiator only)
(define-public (cancel-intent (intent-hash (buff 32)))
    (begin
        (let ((intent-data (map-get? intents ((intent-hash intent-hash)))))
            (if (is-none intent-data)
                (err ERR_NOT_FOUND)
            )
            (let ((intent (unwrap intent-data ERR_NOT_FOUND)))
                ;; Only initiator can cancel
                (if (not (is-eq (get agent intent) tx-sender))
                    (err ERR_UNAUTHORISED)
                )
                ;; Only allow cancellation if not already executed or cancelled
                (if (or (is-eq (get status intent) EXECUTED) (is-eq (get status intent) CANCELLED))
                    (err ERR_INVALID_STATE)
                )
                ;; Mark as cancelled
                (map-set intents ((intent-hash intent-hash))
                    (tuple
                        (agent (get agent intent))
                        (expiry (get expiry intent))
                        (nonce (get nonce intent))
                        (coord-type (get coord-type intent))
                        (coord-value (get coord-value intent))
                        (participants (get participants intent))
                        (status CANCELLED)
                        (accept-count (get accept-count intent))
                    )
                )
                (ok true)
            )
        )
    )
)

;; Read-only function: get the status code of an intent
(define-read-only (get-coordination-status (intent-hash (buff 32)))
    (let ((intent-data (map-get? intents ((intent-hash intent-hash)))))
        (if (is-none intent-data)
            (err ERR_NOT_FOUND)
            (ok (get status (unwrap intent-data ERR_NOT_FOUND)))
        )
    )
)

;; Private helper: check if any acceptance has expired at a given time
(define-private (is-expired-acceptance? (intent-hash (buff 32)) (plist (list 100 principal)) (current-time uint))
    (if (is-eq plist (list))
        false
        (let ((participant (unwrap-panic (get 0 plist))))
            (let ((acc-data (map-get? acceptances ((intent-hash intent-hash) (participant participant)))))
                (if (is-none acc-data)
                    false   ;; if a participant hasn't accepted, from perspective of execution readiness this function might not be called because status wouldn't be Ready.
                    (let ((acc (unwrap acc-data (err ERR_NOT_FOUND))))
                        (if (> current-time (get accept-expiry acc))
                            true
                            (is-expired-acceptance? intent-hash (list-drop-n 1 plist) current-time)
                        )
                    )
                )
            )
        )
    )
)
