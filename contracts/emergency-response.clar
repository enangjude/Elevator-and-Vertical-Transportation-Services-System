;; Emergency Response Contract
;; Manages emergency incidents, response coordination, and passenger safety protocols

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-INCIDENT-EXISTS (err u401))
(define-constant ERR-INCIDENT-NOT-FOUND (err u402))
(define-constant ERR-INVALID-INPUT (err u403))
(define-constant ERR-ELEVATOR-NOT-FOUND (err u404))
(define-constant ERR-INVALID-SEVERITY (err u405))
(define-constant ERR-RESPONDER-NOT-FOUND (err u406))
(define-constant ERR-PROTOCOL-NOT-FOUND (err u407))
(define-constant ERR-INVALID-STATUS (err u408))

;; Emergency response time targets (in blocks)
(define-constant CRITICAL-RESPONSE-TIME u72)    ;; ~30 minutes
(define-constant HIGH-RESPONSE-TIME u144)       ;; ~1 hour
(define-constant MEDIUM-RESPONSE-TIME u288)     ;; ~2 hours
(define-constant LOW-RESPONSE-TIME u576)        ;; ~4 hours

;; Data Variables
(define-data-var next-incident-id uint u1)
(define-data-var next-protocol-id uint u1)
(define-data-var next-response-id uint u1)

;; Data Maps
(define-map emergency-incidents
  { incident-id: uint }
  {
    elevator-id: uint,
    reporter: principal,
    incident-type: (string-ascii 50),
    severity: (string-ascii 20),
    title: (string-ascii 100),
    description: (string-ascii 500),
    location-details: (string-ascii 200),
    passengers-involved: uint,
    passengers-trapped: uint,
    injuries-reported: bool,
    injury-details: (string-ascii 300),
    reported-time: uint,
    response-time: (optional uint),
    resolution-time: (optional uint),
    status: (string-ascii 20),
    assigned-responders: (list 10 principal),
    response-actions: (list 20 (string-ascii 300)),
    equipment-used: (list 10 (string-ascii 100)),
    root-cause: (string-ascii 300),
    preventive-measures: (string-ascii 300),
    regulatory-reported: bool,
    insurance-claimed: bool,
    created-at: uint,
    updated-at: uint
  }
)

(define-map emergency-protocols
  { protocol-id: uint }
  {
    protocol-name: (string-ascii 100),
    incident-types: (list 10 (string-ascii 50)),
    severity-levels: (list 5 (string-ascii 20)),
    response-steps: (list 30 (string-ascii 200)),
    required-responders: (list 10 (string-ascii 50)),
    equipment-needed: (list 15 (string-ascii 100)),
    max-response-time: uint,
    escalation-triggers: (list 10 (string-ascii 100)),
    communication-plan: (string-ascii 500),
    active: bool,
    created-at: uint,
    updated-at: uint
  }
)

(define-map emergency-responders
  { responder: principal }
  {
    name: (string-ascii 100),
    role: (string-ascii 50),
    specializations: (list 10 (string-ascii 50)),
    certification-level: (string-ascii 30),
    contact-info: (string-ascii 200),
    availability-status: (string-ascii 20),
    response-rating: uint,
    incidents-handled: uint,
    average-response-time: uint,
    active: bool,
    created-at: uint,
    updated-at: uint
  }
)

(define-map incident-responses
  { response-id: uint }
  {
    incident-id: uint,
    responder: principal,
    response-type: (string-ascii 30),
    arrival-time: uint,
    action-taken: (string-ascii 300),
    equipment-used: (list 5 (string-ascii 100)),
    outcome: (string-ascii 200),
    follow-up-required: bool,
    notes: (string-ascii 300),
    created-at: uint
  }
)

(define-map elevator-incidents
  { elevator-id: uint }
  { incident-ids: (list 100 uint) }
)

(define-map responder-incidents
  { responder: principal }
  { incident-ids: (list 50 uint) }
)

(define-map active-incidents
  { severity: (string-ascii 20) }
  { incident-ids: (list 50 uint) }
)

;; Authorization Functions
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

(define-private (is-authorized-responder (responder principal))
  (match (map-get? emergency-responders { responder: responder })
    responder-data (get active responder-data)
    false
  )
)

(define-private (can-handle-incident-type (responder principal) (incident-type (string-ascii 50)))
  (match (map-get? emergency-responders { responder: responder })
    responder-data
      (and
        (get active responder-data)
        (is-some (index-of (get specializations responder-data) incident-type))
      )
    false
  )
)

;; Validation Functions
(define-private (validate-incident-type (incident-type (string-ascii 50)))
  (or
    (is-eq incident-type "entrapment")
    (is-eq incident-type "mechanical-failure")
    (is-eq incident-type "power-outage")
    (is-eq incident-type "fire")
    (is-eq incident-type "medical-emergency")
    (is-eq incident-type "vandalism")
    (is-eq incident-type "safety-system-failure")
    (is-eq incident-type "door-malfunction")
    (is-eq incident-type "cable-issue")
    (is-eq incident-type "controller-failure")
  )
)

(define-private (validate-severity (severity (string-ascii 20)))
  (or
    (is-eq severity "critical")
    (is-eq severity "high")
    (is-eq severity "medium")
    (is-eq severity "low")
  )
)

(define-private (validate-response-rating (rating uint))
  (and (>= rating u1) (<= rating u10))
)

;; Helper Functions
(define-private (add-incident-to-elevator (elevator-id uint) (incident-id uint))
  (let ((current-incidents (default-to (list) (get incident-ids (map-get? elevator-incidents { elevator-id: elevator-id })))))
    (ok (map-set elevator-incidents
      { elevator-id: elevator-id }
      { incident-ids: (unwrap! (as-max-len? (append current-incidents incident-id) u100) ERR-INVALID-INPUT) }
    ))
  )
)

(define-private (add-incident-to-responder (responder principal) (incident-id uint))
  (let ((current-incidents (default-to (list) (get incident-ids (map-get? responder-incidents { responder: responder })))))
    (ok (map-set responder-incidents
      { responder: responder }
      { incident-ids: (unwrap! (as-max-len? (append current-incidents incident-id) u50) ERR-INVALID-INPUT) }
    ))
  )
)

(define-private (add-to-active-incidents (severity (string-ascii 20)) (incident-id uint))
  (let ((current-incidents (default-to (list) (get incident-ids (map-get? active-incidents { severity: severity })))))
    (ok (map-set active-incidents
      { severity: severity }
      { incident-ids: (unwrap! (as-max-len? (append current-incidents incident-id) u50) ERR-INVALID-INPUT) }
    ))
  )
)

(define-private (get-response-time-target (severity (string-ascii 20)))
  ;; replaced cond with nested if statements - cond doesn't exist in Clarity
  (if (is-eq severity "critical")
    CRITICAL-RESPONSE-TIME
    (if (is-eq severity "high")
      HIGH-RESPONSE-TIME
      (if (is-eq severity "medium")
        MEDIUM-RESPONSE-TIME
        LOW-RESPONSE-TIME
      )
    )
  )
)

;; Public Functions

;; Register emergency responder
(define-public (register-responder
  (responder principal)
  (name (string-ascii 100))
  (role (string-ascii 50))
  (specializations (list 10 (string-ascii 50)))
  (certification-level (string-ascii 30))
  (contact-info (string-ascii 200))
)
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (asserts! (> (len role) u0) ERR-INVALID-INPUT)
    (asserts! (> (len contact-info) u0) ERR-INVALID-INPUT)

    (map-set emergency-responders
      { responder: responder }
      {
        name: name,
        role: role,
        specializations: specializations,
        certification-level: certification-level,
        contact-info: contact-info,
        availability-status: "available",
        response-rating: u5,
        incidents-handled: u0,
        average-response-time: u0,
        active: true,
        created-at: block-height,
        updated-at: block-height
      }
    )

    (ok true)
  )
)

;; Report emergency incident
(define-public (report-incident
  (elevator-id uint)
  (incident-type (string-ascii 50))
  (severity (string-ascii 20))
  (title (string-ascii 100))
  (description (string-ascii 500))
  (location-details (string-ascii 200))
  (passengers-involved uint)
  (passengers-trapped uint)
  (injuries-reported bool)
  (injury-details (string-ascii 300))
)
  (let ((incident-id (var-get next-incident-id)))
    (asserts! (validate-incident-type incident-type) ERR-INVALID-INPUT)
    (asserts! (validate-severity severity) ERR-INVALID-SEVERITY)
    (asserts! (> (len title) u0) ERR-INVALID-INPUT)
    (asserts! (> (len description) u0) ERR-INVALID-INPUT)
    (asserts! (>= passengers-involved passengers-trapped) ERR-INVALID-INPUT)

    (map-set emergency-incidents
      { incident-id: incident-id }
      {
        elevator-id: elevator-id,
        reporter: tx-sender,
        incident-type: incident-type,
        severity: severity,
        title: title,
        description: description,
        location-details: location-details,
        passengers-involved: passengers-involved,
        passengers-trapped: passengers-trapped,
        injuries-reported: injuries-reported,
        injury-details: injury-details,
        reported-time: block-height,
        response-time: none,
        resolution-time: none,
        status: "reported",
        assigned-responders: (list),
        response-actions: (list),
        equipment-used: (list),
        root-cause: "",
        preventive-measures: "",
        regulatory-reported: false,
        insurance-claimed: false,
        created-at: block-height,
        updated-at: block-height
      }
    )

    (unwrap! (add-incident-to-elevator elevator-id incident-id) ERR-INVALID-INPUT)
    (unwrap! (add-to-active-incidents severity incident-id) ERR-INVALID-INPUT)
    (var-set next-incident-id (+ incident-id u1))

    (ok incident-id)
  )
)

;; Assign responder to incident
(define-public (assign-responder (incident-id uint) (responder principal))
  (let ((incident-data (unwrap! (map-get? emergency-incidents { incident-id: incident-id }) ERR-INCIDENT-NOT-FOUND)))
    (asserts! (or (is-contract-owner) (is-authorized-responder tx-sender)) ERR-NOT-AUTHORIZED)
    (asserts! (can-handle-incident-type responder (get incident-type incident-data)) ERR-INVALID-INPUT)
    (asserts! (not (is-eq (get status incident-data) "resolved")) ERR-INVALID-STATUS)

    (let ((updated-responders
           (unwrap! (as-max-len? (append (get assigned-responders incident-data) responder) u10) ERR-INVALID-INPUT)))

      (map-set emergency-incidents
        { incident-id: incident-id }
        (merge incident-data {
          assigned-responders: updated-responders,
          status: "assigned",
          updated-at: block-height
        })
      )

      (unwrap! (add-incident-to-responder responder incident-id) ERR-INVALID-INPUT)

      (ok true)
    )
  )
)

;; Record response action
(define-public (record-response
  (incident-id uint)
  (response-type (string-ascii 30))
  (action-taken (string-ascii 300))
  (equipment-used (list 5 (string-ascii 100)))
  (outcome (string-ascii 200))
  (follow-up-required bool)
  (notes (string-ascii 300))
)
  (let ((incident-data (unwrap! (map-get? emergency-incidents { incident-id: incident-id }) ERR-INCIDENT-NOT-FOUND))
        (response-id (var-get next-response-id)))

    (asserts! (is-authorized-responder tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (index-of (get assigned-responders incident-data) tx-sender)) ERR-NOT-AUTHORIZED)
    (asserts! (> (len action-taken) u0) ERR-INVALID-INPUT)

    ;; Record individual response
    (map-set incident-responses
      { response-id: response-id }
      {
        incident-id: incident-id,
        responder: tx-sender,
        response-type: response-type,
        arrival-time: block-height,
        action-taken: action-taken,
        equipment-used: equipment-used,
        outcome: outcome,
        follow-up-required: follow-up-required,
        notes: notes,
        created-at: block-height
      }
    )

    ;; Update incident with response time if first response
    (let ((updated-incident
           (if (is-none (get response-time incident-data))
               (merge incident-data {
                 response-time: (some (- block-height (get reported-time incident-data))),
                 status: "responding",
                 response-actions: (unwrap! (as-max-len? (append (get response-actions incident-data) action-taken) u20) ERR-INVALID-INPUT),
                 updated-at: block-height
               })
               (merge incident-data {
                 response-actions: (unwrap! (as-max-len? (append (get response-actions incident-data) action-taken) u20) ERR-INVALID-INPUT),
                 updated-at: block-height
               }))))

      (map-set emergency-incidents
        { incident-id: incident-id }
        updated-incident
      )
    )

    (var-set next-response-id (+ response-id u1))

    (ok response-id)
  )
)

;; Resolve incident
(define-public (resolve-incident
  (incident-id uint)
  (root-cause (string-ascii 300))
  (preventive-measures (string-ascii 300))
  (regulatory-reported bool)
)
  (let ((incident-data (unwrap! (map-get? emergency-incidents { incident-id: incident-id }) ERR-INCIDENT-NOT-FOUND)))
    (asserts! (is-authorized-responder tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (index-of (get assigned-responders incident-data) tx-sender)) ERR-NOT-AUTHORIZED)
    (asserts! (not (is-eq (get status incident-data) "resolved")) ERR-INVALID-STATUS)
    (asserts! (> (len root-cause) u0) ERR-INVALID-INPUT)

    (map-set emergency-incidents
      { incident-id: incident-id }
      (merge incident-data {
        resolution-time: (some (- block-height (get reported-time incident-data))),
        status: "resolved",
        root-cause: root-cause,
        preventive-measures: preventive-measures,
        regulatory-reported: regulatory-reported,
        updated-at: block-height
      })
    )

    ;; Update responder statistics
    (match (map-get? emergency-responders { responder: tx-sender })
      responder-data
        (map-set emergency-responders
          { responder: tx-sender }
          (merge responder-data {
            incidents-handled: (+ (get incidents-handled responder-data) u1),
            updated-at: block-height
          })
        )
      true
    )

    (ok true)
  )
)

;; Create emergency protocol
(define-public (create-protocol
  (protocol-name (string-ascii 100))
  (incident-types (list 10 (string-ascii 50)))
  (severity-levels (list 5 (string-ascii 20)))
  (response-steps (list 30 (string-ascii 200)))
  (required-responders (list 10 (string-ascii 50)))
  (equipment-needed (list 15 (string-ascii 100)))
  (max-response-time uint)
  (communication-plan (string-ascii 500))
)
  (let ((protocol-id (var-get next-protocol-id)))
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (> (len protocol-name) u0) ERR-INVALID-INPUT)
    (asserts! (> max-response-time u0) ERR-INVALID-INPUT)

    (map-set emergency-protocols
      { protocol-id: protocol-id }
      {
        protocol-name: protocol-name,
        incident-types: incident-types,
        severity-levels: severity-levels,
        response-steps: response-steps,
        required-responders: required-responders,
        equipment-needed: equipment-needed,
        max-response-time: max-response-time,
        escalation-triggers: (list),
        communication-plan: communication-plan,
        active: true,
        created-at: block-height,
        updated-at: block-height
      }
    )

    (var-set next-protocol-id (+ protocol-id u1))

    (ok protocol-id)
  )
)

;; Update responder availability
(define-public (update-availability (availability-status (string-ascii 20)))
  (let ((responder-data (unwrap! (map-get? emergency-responders { responder: tx-sender }) ERR-RESPONDER-NOT-FOUND)))
    (asserts! (or
      (is-eq availability-status "available")
      (is-eq availability-status "busy")
      (is-eq availability-status "off-duty")
      (is-eq availability-status "emergency")
    ) ERR-INVALID-INPUT)

    (map-set emergency-responders
      { responder: tx-sender }
      (merge responder-data {
        availability-status: availability-status,
        updated-at: block-height
      })
    )

    (ok true)
  )
)

;; Read-only Functions

;; Get incident details
(define-read-only (get-incident (incident-id uint))
  (map-get? emergency-incidents { incident-id: incident-id })
)

;; Get protocol details
(define-read-only (get-protocol (protocol-id uint))
  (map-get? emergency-protocols { protocol-id: protocol-id })
)

;; Get responder details
(define-read-only (get-responder (responder principal))
  (map-get? emergency-responders { responder: responder })
)

;; Get response details
(define-read-only (get-response (response-id uint))
  (map-get? incident-responses { response-id: response-id })
)

;; Get elevator incidents
(define-read-only (get-elevator-incidents (elevator-id uint))
  (map-get? elevator-incidents { elevator-id: elevator-id })
)

;; Get responder incidents
(define-read-only (get-responder-incidents (responder principal))
  (map-get? responder-incidents { responder: responder })
)

;; Get active incidents by severity
(define-read-only (get-active-incidents (severity (string-ascii 20)))
  (map-get? active-incidents { severity: severity })
)

;; Check if incident is overdue
(define-read-only (is-incident-overdue (incident-id uint))
  (match (map-get? emergency-incidents { incident-id: incident-id })
    incident-data
      (let ((target-time (get-response-time-target (get severity incident-data)))
            (elapsed-time (- block-height (get reported-time incident-data))))
        (and
          (not (is-eq (get status incident-data) "resolved"))
          (> elapsed-time target-time)
        )
      )
    false
  )
)

;; Get next IDs
(define-read-only (get-next-incident-id)
  (var-get next-incident-id)
)

(define-read-only (get-next-protocol-id)
  (var-get next-protocol-id)
)

(define-read-only (get-next-response-id)
  (var-get next-response-id)
)
