# SmartFleet – Dummy Data Generation Notes

Seed: `42` (Faker + `random` – fully reproducible)  
Context: Vietnam-based mixed logistics fleet

---

## Volume Summary

| # | Table | Rows | Role |
|---|-------|-----:|------|
| 01 | Depots | 8 | Reference |
| 02 | Vehicles | 200 | Core |
| 03 | Workshop | 10 | Reference |
| 04 | MechanicCertType | 4 | Lookup (enum) |
| 05 | Mechanic | 80 | Core |
| 06 | MechanicCertification | 121 | Transactional |
| 07 | Drivers | 250 | Core |
| 08 | VehicleAssignments | 400 | Transactional |
| 09 | CertificationType | 5 | Lookup (enum) |
| 10 | VehicleCertRequirement | 8 | Reference rules |
| 11 | DriverCertifications | 393 | Transactional |
| 12 | CoachingRecord | 150 | Transactional |
| 13 | DriverSafetyScore | 250 | Transactional |
| 14 | SafetyEventsType | 8 | Lookup (enum) |
| **15** | **SafetyEvents** | **600** | **Largest table** |
| 16 | PredictiveAlert | 300 | Transactional |
| 17 | MaintenanceJobs | 250 | Transactional |
| 18 | MaintenanceActivity | 454 | Transactional |
| 19 | ActivityMechanic | 710 | Junction |

---

## Table-by-Table Reasoning

### 01 · Depots (8 rows)
- **Why 8?** Covers Vietnam's major logistics corridors: HCMC, Hanoi, Da Nang, Hai Phong, Can Tho, Bien Hoa, Vung Tau, Nha Trang. This gives geographic diversity without making FK distributions trivially uniform.
- **ContactPhone – nullable?** Nullable in schema, but populated for all rows. In practice every physical depot has a staffed phone line; omitting it would represent bad data quality.
- **Name** is distinct and human-readable to aid debugging joins.

---

### 02 · Vehicles (200 rows)
- **Why 200?** Gives a realistic driver-to-vehicle ratio (~1.25:1) and makes SafetyEvents/Maintenance tables plausible in volume.
- **Category distribution:** Delivery Van 35%, Refrigerated Truck 20%, Electric Van 15%, Service Vehicle 15%, Heavy Transport Truck 15%. This mirrors a typical mixed urban/regional logistics company where light vans dominate.
- **OdometerReading – nullable?** Schema has `DEFAULT 0`, column is NOT NULL by implication. We generate realistic odometers: `(2025 − year_of_manufacture) × 15,000–35,000 km`. Older vehicles have higher readings.
- **OperationalStatus:** ~70% Active or Available; the remainder split across Under Maintenance, Awaiting Inspection, Out of Service, and Retired. This keeps the active fleet large enough to generate plentiful safety and maintenance records.
- **Model/Manufacturer:** Real vehicle make-model pairs matched to category (e.g. BYD T3 / VinFast VF e34 for Electric Van). These are VARCHAR and nullable in the schema but populated here for realism.

---

### 03 · Workshop (10 rows)
- **Distribution:** Large depots (HCMC=1, Hanoi=2) get 2 workshops; all others get 1. This prevents all 250 maintenance jobs queuing to a single bay.
- **NumBays – nullable?** Checked ≥ 0 in schema; always populated (4–16 bays). Leaving it NULL would break capacity-planning queries.
- **Contacts – nullable?** Populated for 85% of rows. The 15% NULL represents smaller depots where a general depot phone is used instead.

---

### 04 · MechanicCertType (4 rows – enum mirror)
- Fixed by the ENUM definition in the DDL; cannot have more or fewer rows.
- **Expire logic:** `Standard Vehicle Mechanic Licence` → `Expire = FALSE`. This is a lifetime trade credential in Vietnam; mechanics do not renew it. All three specialist certs (`EV Technician`, `Refrigeration Systems`, `Heavy Vehicle`) expire and require periodic renewal — reflected in `MechanicCertification.ExpireDate`.

---

### 05 · Mechanic (80 rows)
- **Why 80?** ~8 mechanics per workshop on average. With 4–16 bays per workshop and shift-based work, a bay-to-mechanic ratio of roughly 1:1.5 is realistic.
- **EmploymentStatus:** 80% Active, 10% On Leave, 5% Suspended, 5% Terminated. A terminated employee's records are retained for auditability.
- **Names:** Vietnamese-style first + last names to match the Vietnam context.

---

### 06 · MechanicCertification (121 rows)
- **Minimum rule:** Every mechanic holds at least `MecCertTypeID = 1` (Standard Vehicle Mechanic Licence). This is a regulatory minimum for workshop employment.
- **Second cert rate:** ~45% of mechanics also hold one specialist cert (EV, Refrigeration, or Heavy Vehicle), distributed to match the vehicle fleet composition.
- **ExpireDate – nullable?** NULL only for cert type 1 (non-expiring). All specialist certs have an `ExpireDate`. Some `ExpireDate` values fall before TODAY (2025-06-01) — this deliberately represents lapsed certs that the system should flag; real databases contain stale records.
- **Date range:** `IssueDate` drawn from 2010–2022 for the base cert; specialist certs issued 2015–2023.

---

### 07 · Drivers (250 rows)
- **Why 250?** 200 vehicles × 1.25 = 250 drivers allows for shift coverage, part-time drivers, and some currently unassigned drivers, without requiring every driver to be in an active assignment.
- **LicenceType distribution:** 70% Standard Licence, 30% Heavy Vehicle Licence. Heavy licence holders are a minority — consistent with a fleet where most vehicles are delivery vans.
- **LicenceExpiryDate – nullable?** NOT NULL in schema and always populated. 8% of drivers have an expiry within the next 60 days to make expiry-alert queries return meaningful results.
- **ContactInformation – nullable?** Nullable in schema; populated for 90% of rows. The 10% NULL represents drivers who joined before electronic contact capture was mandatory.
- **EmergencyContactDetails – nullable?** Nullable; populated for 88%. A small fraction of records predate the emergency-contact policy.
- **EmploymentStatus:** Similar skew to mechanics — majority Active, small minorities in other states for realistic HR diversity.

---

### 08 · VehicleAssignments (400 rows)
- **Why 400?** Two assignments per vehicle on average, capturing historical reassignments over the 3-year window.
- **EndDate – nullable?** NULL for ~30% of rows (current open assignments, including all `IsPermanent = TRUE` rows). Closed assignments have `EndDate ≥ StartDate` (enforced by `chk_va_dates`).
- **IsPermanent:** ~30% flagged TRUE. These represent long-term dedicated driver-vehicle pairings (common for refrigerated trucks where driver familiarity with the vehicle matters).
- **AssignedDepot – nullable?** NULL for ~80% of assignments (home-depot operations). The 20% non-null values represent cross-depot temporary assignments (e.g. peak-season loan of vehicles between depots).
- **DepotID vs AssignedDepot:** `DepotID` (NOT NULL) is the administrative depot managing the record; `AssignedDepot` is the physical location if different. Both can reference the same depot.

---

### 09 · CertificationType (5 rows – enum mirror)
- Fixed by the ENUM definition.
- **Expire logic:** `Standard Licence → Expire = FALSE`. The standard licence is recorded here for completeness but the primary expiry tracking is via `Drivers.LicenceExpiryDate`. All specialist certs expire.

---

### 10 · VehicleCertRequirement (8 rows – reference rules)
- Encodes the compliance matrix: which vehicle category requires which driver certification.
- **Delivery Van & Service Vehicle:** Standard Licence only.
- **Heavy Transport Truck:** Standard Licence + Heavy Vehicle Licence.
- **Refrigerated Truck:** Standard Licence + Refrigerated Transport Certification.
- **Electric Van:** Standard Licence + EV Certification.
- Hazardous Goods Certification is in `CertificationType` but not mapped to any current vehicle category — it exists for future vehicle types.

---

### 11 · DriverCertifications (393 rows)
- **Minimum rule:** Every driver holds `CertTypeID = 1` (Standard Licence) — legally required to drive.
- **Heavy licence holders:** Also receive `CertTypeID = 2` with a 3–5 year expiry window.
- **Specialist cert rate:** ~25% of drivers have one additional specialist cert (Refrigerated Transport, EV, or Hazardous Goods), reflecting personal career development.
- **ExpireDate – nullable?** NULL only for cert type 1. All others have an expiry. Some are deliberately past TODAY to simulate real-world database lag where renewals have not been recorded yet.

---

### 12 · CoachingRecord (150 rows)
- **Who gets coached?** A pool of ~100 drivers (out of 250) who generated safety events. 50 extra rows are added as second coaching sessions for repeat offenders — realistic for high-risk drivers.
- **CompleteDate – nullable?** NULL for ~25% of rows (scheduled but not yet completed). This is important for queries filtering on outstanding coaching obligations.
- **Outcome – nullable?** NULL when `CompleteDate` is NULL (session not yet done, so outcome is unknown).
- **Reason:** Free-text VARCHAR; populated for all rows with plausible telematics-derived triggers.

---

### 13 · DriverSafetyScore (250 rows — one per driver)
- **Schema note:** The DDL has no `Year`/`Month` columns (unlike the ERD draft); each row is one score snapshot. One row per driver is generated — a production system would add a row monthly.
- **Scoring logic:** `FinalScore = BaseScore (100) − DeductedPoints`. Drivers with coaching records receive higher deductions (20–55 points) vs. clean drivers (0–25 points).
- **CoachingRequired:** TRUE when `FinalScore < 75`.
- **Suspended:** TRUE when `FinalScore < 50`.
- **BaseScore:** Always 100 (schema DEFAULT); deductions are tracked separately to allow forensic review.

---

### 14 · SafetyEventsType (8 rows – enum mirror)
- Fixed by the ENUM definition.
- **DefaultSeverity design rationale:**
  - `Critical`: Fatigue Warning, Phone Distraction Alert — highest crash correlation in telematics research.
  - `High`: Excessive Speeding, Seatbelt Violation — regulatory violations.
  - `Medium`: Harsh Braking, Sharp Cornering — high-frequency, training-responsive.
  - `Low`: Rapid Acceleration, Excessive Idling — fuel/cost impacts, lower safety risk.

---

### 15 · SafetyEvents (600 rows — target table)
- **Target:** ≥500 rows as specified. 600 chosen to allow meaningful aggregations per depot, driver, and vehicle.
- **Distribution:** Not uniform — 40% of events are assigned to a "high-risk driver pool" (drivers who appear in CoachingRecord). This creates realistic skew where a minority of drivers generate the majority of events, consistent with real telematics data.
- **VehicleID scope:** Only Active and Available vehicles generate events (under-maintenance or retired vehicles are off-road).
- **Odometer – nullable?** Nullable in schema but populated for all rows. Telematics devices always capture odometer at the event moment; NULL here would imply a sensor fault, which is an exception we exclude from seed data.
- **ReviewRequired / ReviewStatus:** `ReviewRequired = TRUE` for all High/Critical events, plus 10% of lower-severity events (supervisor discretion). `ReviewStatus` is NULL when `ReviewRequired = FALSE`; otherwise one of Pending / In Review / Resolved / Dismissed.
- **Timestamp range:** 2022-06-01 → 2025-06-01 (3 years), which matches the operational window.

---

### 16 · PredictiveAlert (300 rows)
- **Why 300?** ~1.5 alerts per vehicle over 3 years. High-frequency fleets generate more alerts; this is a conservative middle ground.
- **AlertType:** Free-text VARCHAR; uses realistic telematics/IoT sensor-derived names (e.g. "Brake Wear Critical", "EV Motor Efficiency Drop").
- **Status distribution:** Open 15%, Acknowledged 20%, In Progress 20%, Resolved 35%, Dismissed 10%. The majority are resolved — consistent with an operational fleet that acts on alerts.
- **ResolvedAt – nullable?** NULL for all statuses except `Resolved`. It is a `TIMESTAMP NULL` in the schema, enforcing that only closed alerts carry a resolution timestamp.

---

### 17 · MaintenanceJobs (250 rows)
- **Why 250?** ~1.25 jobs per vehicle over 3 years; realistic for a professionally maintained fleet on a mix of scheduled and reactive work.
- **WorkshopID assignment:** Jobs are routed to a workshop in the vehicle's home depot. This reflects real logistics practice where vehicles are maintained at their operating base unless specialist equipment is needed elsewhere.
- **AlertID – nullable?** ~40% of jobs are linked to a predictive alert that triggered the job. The other 60% are scheduled maintenance or driver-reported issues (no pre-existing alert).
- **DateClosed – nullable?** NULL for ~15% of jobs (currently open work orders). `OverallDowntime` is also NULL for open jobs.
- **TotalCost:** In Vietnamese Dong (VND). Range 500,000–50,000,000 VND (~$20–$2,000 USD), covering oil changes at the low end to major component replacements at the high end.

---

### 18 · MaintenanceActivity (454 rows)
- **Why ~450?** ~1.6 activities per job. Simple jobs (routine inspection) have 1 activity; complex jobs (emergency repair + component replacement) have 2–3.
- **ActivityType selection:** Drawn from the full ENUM; no artificial restriction by vehicle type in seed data (that constraint would live in application logic, not the DB layer).
- **DiagnosticResult – nullable?** TEXT, nullable. Populated only for `Diagnostic Testing` activities with realistic mechanic note text. All other activity types leave this NULL — a mechanic replacing brake pads does not write a diagnostic note.
- **IsRepeatFault:** TRUE for ~15% of activities — flagging components that have been repaired before, enabling repeat-fault trend analysis.
- **WarrantyIndicator:** TRUE for ~10% — newer vehicles (post-2022) are more likely to have components still under manufacturer warranty.
- **StartedAt / CompleteAt:** Both are nullable TIMESTAMPs. `StartedAt` is NULL for ~15% of activities (scheduled but not yet started). `CompleteAt` is NULL for unfinished or future activities. The constraint `CompleteAt >= StartedAt` is respected in all generated rows.

---

### 19 · ActivityMechanic (710 rows — junction)
- **Why 710?** ~1.55 mechanics per activity on average. Simple inspections use 1 mechanic; heavy repairs or EV work use 2–3. The UNIQUE constraint on `(ActivityID, MechanicID)` is respected by tracking assigned pairs in a set during generation.
- **LabourHours – nullable?** NOT NULL, DEFAULT 0 in schema. A value of 0 is technically valid but operationally meaningless for completed work; all generated values are 0.5–10.0 hours to reflect real labour allocation.
- **MechanicID assignment:** Randomly drawn from the full mechanic roster. A production system would restrict to mechanics in the same workshop as the job — that enforcement belongs in application logic or a trigger, not enforced by FK in the schema.

---

## Referential Integrity Summary

All FK relationships are satisfied:
- Every `Vehicle.DepotID` → valid `Depots.DepotID`
- Every `Workshop.DepotID` → valid `Depots.DepotID`
- Every `Mechanic.WorkshopID` → valid `Workshop.WorkshopID`
- Every `Driver.DepotID` → valid `Depots.DepotID`
- Every `VehicleAssignment.VehicleID/DriverID/DepotID/AssignedDepot` → valid parent rows
- Every `DriverCertification.CertTypeID` → valid `CertificationType.CertTypeID`
- Every `SafetyEvent.VehicleID/DriverID/EventsTypeID/DepotID` → valid parent rows
- Every `MaintenanceJob.VehicleID/WorkshopID/AlertID` → valid parent rows
- Every `MaintenanceActivity.JobID` → valid `MaintenanceJobs.JobID`
- Every `ActivityMechanic.(ActivityID, MechanicID)` → valid parents, unique pairs

## Loading Order

Load CSVs strictly in numeric filename order (01 → 19). The dependency graph requires:
1. Depots (no FK dependencies)
2. Vehicles, Workshop (depend on Depots)
3. MechanicCertType, Mechanic (Mechanic depends on Workshop)
4. MechanicCertification (depends on Mechanic, MechanicCertType)
5. Drivers, CertificationType (Drivers depends on Depots)
6. VehicleAssignments, VehicleCertRequirement, DriverCertifications
7. CoachingRecord, DriverSafetyScore, SafetyEventsType
8. SafetyEvents, PredictiveAlert
9. MaintenanceJobs (depends on Vehicles, Workshop, PredictiveAlert)
10. MaintenanceActivity → ActivityMechanic
