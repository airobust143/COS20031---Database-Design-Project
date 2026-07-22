# SmartFleet Sample Data — CSV Package

33 CSV files, one per table, prefixed with a load order number (FK-safe:
load `01_` before `02_`, etc.). Every row is hand-built to tell one coherent
story so it's easy to demo to the client — nothing here is randomly
generated.

## The scenario (walk the client through this)

**Fleet (4 depots, 5 vehicles, 5 drivers)**
- Ha Noi, Da Nang, HCMC, Can Tho depots, each with its own workshop (1:1, as required).
- `29A-123.45` (Delivery Van, Ha Noi) — permanently assigned to driver **D-112 Nguyễn Văn An**.
- `51C-789.01` (Refrigerated Truck, HCMC) — permanently assigned to **D-204 Trần Thị Bích**.
- `43E-456.78` (Electric Van, Đà Nẵng) — a **shared** vehicle: permanent driver D-502 Võ Thị Hà,
  plus a temporary 5-day assignment to D-112 while he covered an inter-depot job
  (`VehicleAssignments` rows 3 & 4 — demonstrates the brief's "shared between multiple drivers" rule).
- `92H-135.79` (Heavy Transport Truck, Cần Thơ) — `Under Maintenance`, so it is **not**
  currently assigned to anyone (demonstrates the "a vehicle under maintenance cannot
  be assigned" rule).
- `30G-246.80` (Service Vehicle) shows a depot transfer in `VehiclesDepotHistory`
  (Đà Nẵng → Ha Noi in April 2024) while staying in service.

**Certifications**
- `VehicleCertRequirement` encodes the Vehicle Certification Matrix exactly as given
  in the brief (e.g. Refrigerated Truck needs Standard + Heavy Vehicle + Refrigerated
  Transport; Heavy Transport Truck needs Heavy Vehicle + Hazardous Goods).
- `DriverCertifications` gives each driver exactly the certs their assigned vehicle
  requires, using the expiry dates from the brief's example table.

**Driver safety (May 2024, matches the brief's example event log)**
- 6 telematics events reproduced from the brief (`SafetyEvents`), correctly generating
  `ReviewRequired = 1` only for the High/Critical ones.
- `DriverSafetyScore` shows the penalty maths worked through for the month:
  - D-112: 100 − (1 low −2, 2 high −10 each) = **78** → above the 75 coaching threshold, no coaching required.
  - D-204: 100 − (1 medium −5, 1 critical −20) = **75** → hits the coaching threshold exactly,
    `CoachingRequired = 1`.
  - D-331: 100 − (1 low −2) = **98**.
- Because D-204 had a **Critical** event, her `EmploymentStatus` is set to `Inactive` and
  two `CoachingRecord` rows are created — one for the score threshold, one for the
  critical-event retraining — demonstrating the "critical event → driver inactive until
  review/training complete" rule.

**Maintenance (matches the brief's example job/activity tables)**
- `PredictiveAlert` #1 (Brake Wear Warning) → escalated into job **M1021** (Brake Service +
  Tyre Replacement), showing the alert-to-job link.
- `PredictiveAlert` #2 (Cooling System Anomaly) → job **M1022** (Preventative Servicing +
  Refrigeration Repair), which also produces a **Supplier** warranty claim on the
  compressor belt part — demonstrating `WarrantyClaim` → `WarrantyClaimPart`.
- `PredictiveAlert` #3 (Engine Overheating, Critical, on the Heavy Transport Truck) →
  job **M1023**, still open (`DateClosed` empty) — demonstrates a job in progress with
  no cost/downtime totals yet, and an activity requiring the Heavy Vehicle Mechanic
  certification.
- Parts, suppliers and a warranty claim are fully wired: `Part` → `SupplyPart`
  (primary/backup supplier + cost) → `ActivityPart` (parts actually consumed) →
  `WarrantyClaimPart`.

**People & access**
- 5 mechanics across the workshops, each holding exactly the certification their
  assigned activities require (e.g. the refrigeration mechanic on the fridge-truck job,
  the heavy-vehicle mechanic on the truck job).
- 4 roles / 8 permissions / role-permission mappings, and 4 user accounts showing the
  three account patterns the brief implies: an operations-staff login (no driver/mechanic
  link), a workshop-manager login, an admin login, and a **driver self-service login**
  linked to `DriverID`.

## Load order
Import files in numeric filename order (01 → 33) — this respects every foreign key.
Empty CSV cells are `NULL` (e.g. `EndDate`, `DateClosed`, `MovedTo`).

```sql
LOAD DATA LOCAL INFILE '01_Depots.csv' INTO TABLE Depots
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS;
-- repeat for each file in order, adjusting NULL columns with SET col = NULLIF(col,'') if needed
```

If your import tool complains about blank strings vs NULL on nullable DATE/DATETIME/INT
columns (`EndDate`, `DateClosed`, `MovedTo`, `ResolvedAt`, `AlertID`, `EventID`, `ScoreID`,
`DriverID`, `MechanicID`, `DepotID` in UserAccount, `OverallDowntime`, `TotalCost`), map
empty string → NULL during import (most GUI tools like MySQL Workbench / phpMyAdmin's
CSV import do this automatically when the field is empty).
