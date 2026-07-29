<?php
/**
 * Table metadata driving the generic admin CRUD engine.
 *
 * Each table entry:
 *   label     - human readable name
 *   group     - domain grouping used in the sidebar nav
 *   pk        - primary key column name
 *   order_by  - default ORDER BY for list view
 *   columns   - ordered list of column definitions:
 *       name     - column name
 *       label    - display label
 *       type     - text | textarea | int | decimal | date | datetime | select | fk | bool
 *       required - bool, adds HTML5 required + basic server check
 *       options  - array of allowed values (type = select)
 *       fk_table - referenced table (type = fk)
 *       fk_label - column(s) on the referenced table used to build the option label
 *       list     - show this column in the list view (default true)
 */

$TABLES = [

    // ================= CORE FLEET =================
    'Depots' => [
        'label' => 'Depots', 'group' => 'Core Fleet', 'pk' => 'DepotID', 'order_by' => 'Name', 'alias' => 'dep',
        'columns' => [
            ['name' => 'Name', 'label' => 'Name', 'type' => 'text', 'required' => true],
            ['name' => 'City', 'label' => 'City', 'type' => 'text', 'required' => true],
            ['name' => 'Address', 'label' => 'Address', 'type' => 'text', 'required' => true],
            ['name' => 'ContactPhone', 'label' => 'Contact Phone', 'type' => 'text'],
        ],
    ],
    'VehiclesCategory' => [
        'label' => 'Vehicle Categories', 'group' => 'Core Fleet', 'pk' => 'CategoryID', 'order_by' => 'CategoryName', 'alias' => 'vc',
        'columns' => [
            ['name' => 'CategoryName', 'label' => 'Category Name', 'type' => 'text', 'required' => true],
        ],
    ],
    'Vehicles' => [
        'label' => 'Vehicles', 'group' => 'Core Fleet', 'pk' => 'VehicleID', 'order_by' => 'RegistrationNumber', 'alias' => 'v',
        'columns' => [
            ['name' => 'RegistrationNumber', 'label' => 'Registration No.', 'type' => 'text', 'required' => true],
            ['name' => 'CategoryID', 'label' => 'Category', 'type' => 'fk', 'fk_table' => 'VehiclesCategory', 'fk_label' => 'CategoryName', 'required' => true],
            ['name' => 'Manufacturer', 'label' => 'Manufacturer', 'type' => 'text', 'required' => true],
            ['name' => 'Model', 'label' => 'Model', 'type' => 'text', 'required' => true],
            ['name' => 'YearOfManufacture', 'label' => 'Year', 'type' => 'int', 'required' => true],
            ['name' => 'CurrentOdometerReading', 'label' => 'Odometer (km)', 'type' => 'int', 'required' => true],
            ['name' => 'DepotID', 'label' => 'Depot', 'type' => 'fk', 'fk_table' => 'Depots', 'fk_label' => 'Name', 'required' => true],
            ['name' => 'OperationalStatus', 'label' => 'Status', 'type' => 'select', 'required' => true,
                'options' => ['Active','Available','Under Maintenance','Awaiting Inspection','Out of Service','Retired']],
        ],
    ],
    'VehiclesDepotHistory' => [
        'label' => 'Vehicle Depot History', 'group' => 'Core Fleet', 'pk' => 'HistoryID', 'order_by' => 'MovedFrom DESC', 'alias' => 'vdh',
        'columns' => [
            ['name' => 'VehicleID', 'label' => 'Vehicle', 'type' => 'fk', 'fk_table' => 'Vehicles', 'fk_label' => 'RegistrationNumber', 'required' => true],
            ['name' => 'DepotID', 'label' => 'Depot', 'type' => 'fk', 'fk_table' => 'Depots', 'fk_label' => 'Name', 'required' => true],
            ['name' => 'MovedFrom', 'label' => 'Moved From', 'type' => 'datetime', 'required' => true],
            ['name' => 'MovedTo', 'label' => 'Moved To', 'type' => 'datetime'],
        ],
    ],
    'Drivers' => [
        'label' => 'Drivers', 'group' => 'Core Fleet', 'pk' => 'DriverID', 'order_by' => 'LastName', 'alias' => 'd',
        'columns' => [
            ['name' => 'FirstName', 'label' => 'First Name', 'type' => 'text', 'required' => true],
            ['name' => 'LastName', 'label' => 'Last Name', 'type' => 'text', 'required' => true],
            ['name' => 'ContactInformation', 'label' => 'Contact Info', 'type' => 'text'],
            ['name' => 'DepotID', 'label' => 'Depot', 'type' => 'fk', 'fk_table' => 'Depots', 'fk_label' => 'Name', 'required' => true],
            ['name' => 'LicenceType', 'label' => 'Licence Type', 'type' => 'text', 'required' => true],
            ['name' => 'LicenceExpiryDate', 'label' => 'Licence Expiry', 'type' => 'date', 'required' => true],
            ['name' => 'EmploymentStatus', 'label' => 'Employment Status', 'type' => 'select', 'required' => true,
                'options' => ['Active','Inactive','Suspended','Terminated']],
            ['name' => 'EmergencyContactDetails', 'label' => 'Emergency Contact', 'type' => 'text', 'list' => false],
        ],
    ],
    'VehicleAssignments' => [
        'label' => 'Vehicle Assignments', 'group' => 'Core Fleet', 'pk' => 'AssignmentID', 'order_by' => 'StartDate DESC', 'alias' => 'va',
        'columns' => [
            ['name' => 'VehicleID', 'label' => 'Vehicle', 'type' => 'fk', 'fk_table' => 'Vehicles', 'fk_label' => 'RegistrationNumber', 'required' => true],
            ['name' => 'DriverID', 'label' => 'Driver', 'type' => 'fk', 'fk_table' => 'Drivers', 'fk_label' => ['FirstName','LastName'], 'required' => true],
            ['name' => 'DepotID', 'label' => 'Depot', 'type' => 'fk', 'fk_table' => 'Depots', 'fk_label' => 'Name', 'required' => true],
            ['name' => 'StartDate', 'label' => 'Start Date', 'type' => 'date', 'required' => true],
            ['name' => 'EndDate', 'label' => 'End Date', 'type' => 'date'],
            ['name' => 'IsPermanent', 'label' => 'Permanent?', 'type' => 'bool'],
        ],
    ],

    // ================= DRIVER & SAFETY =================
    'CertificationType' => [
        'label' => 'Driver Certification Types', 'group' => 'Driver & Safety', 'pk' => 'CertTypeID', 'order_by' => 'Name', 'alias' => 'ct',
        'columns' => [
            ['name' => 'Name', 'label' => 'Name', 'type' => 'text', 'required' => true],
            ['name' => 'Expire', 'label' => 'Requires Renewal?', 'type' => 'bool'],
        ],
    ],
    'VehicleCertRequirement' => [
        'label' => 'Vehicle Certification Matrix', 'group' => 'Driver & Safety', 'pk' => 'ReqID', 'order_by' => 'CategoryID', 'alias' => 'vcr',
        'columns' => [
            ['name' => 'CategoryID', 'label' => 'Vehicle Category', 'type' => 'fk', 'fk_table' => 'VehiclesCategory', 'fk_label' => 'CategoryName', 'required' => true],
            ['name' => 'CertTypeID', 'label' => 'Required Certification', 'type' => 'fk', 'fk_table' => 'CertificationType', 'fk_label' => 'Name', 'required' => true],
        ],
    ],
    'DriverCertifications' => [
        'label' => 'Driver Certifications', 'group' => 'Driver & Safety', 'pk' => 'DriverCertID', 'order_by' => 'ExpireDate', 'alias' => 'dc',
        'columns' => [
            ['name' => 'DriverID', 'label' => 'Driver', 'type' => 'fk', 'fk_table' => 'Drivers', 'fk_label' => ['FirstName','LastName'], 'required' => true],
            ['name' => 'CertTypeID', 'label' => 'Certification', 'type' => 'fk', 'fk_table' => 'CertificationType', 'fk_label' => 'Name', 'required' => true],
            ['name' => 'IssueDate', 'label' => 'Issue Date', 'type' => 'date', 'required' => true],
            ['name' => 'ExpireDate', 'label' => 'Expiry Date', 'type' => 'date'],
        ],
    ],
    'SafetyEventsType' => [
        'label' => 'Safety Event Types', 'group' => 'Driver & Safety', 'pk' => 'EventsTypeID', 'order_by' => 'Name', 'alias' => 'set',
        'columns' => [
            ['name' => 'Name', 'label' => 'Name', 'type' => 'text', 'required' => true],
            ['name' => 'DefaultSeverity', 'label' => 'Default Severity', 'type' => 'select', 'required' => true,
                'options' => ['Low','Medium','High','Critical']],
        ],
    ],
    'SafetyEvents' => [
        'label' => 'Safety Events', 'group' => 'Driver & Safety', 'pk' => 'EventID', 'order_by' => 'Timestamp DESC', 'alias' => 'se',
        'columns' => [
            ['name' => 'Timestamp', 'label' => 'Timestamp', 'type' => 'datetime', 'required' => true],
            ['name' => 'DriverID', 'label' => 'Driver', 'type' => 'fk', 'fk_table' => 'Drivers', 'fk_label' => ['FirstName','LastName'], 'required' => true],
            ['name' => 'VehicleID', 'label' => 'Vehicle', 'type' => 'fk', 'fk_table' => 'Vehicles', 'fk_label' => 'RegistrationNumber', 'required' => true],
            ['name' => 'DepotID', 'label' => 'Depot', 'type' => 'fk', 'fk_table' => 'Depots', 'fk_label' => 'Name', 'required' => true],
            ['name' => 'EventsTypeID', 'label' => 'Event Type', 'type' => 'fk', 'fk_table' => 'SafetyEventsType', 'fk_label' => 'Name', 'required' => true],
            ['name' => 'Severity', 'label' => 'Severity', 'type' => 'select', 'required' => true,
                'options' => ['Low','Medium','High','Critical']],
            ['name' => 'Odometer', 'label' => 'Odometer (km)', 'type' => 'int', 'required' => true],
            ['name' => 'ReviewRequired', 'label' => 'Review Required?', 'type' => 'bool'],
            ['name' => 'ReviewStatus', 'label' => 'Review Status', 'type' => 'select', 'required' => true,
                'options' => ['Not Required','Pending','In Review','Completed']],
        ],
    ],
    'DriverSafetyScore' => [
        'label' => 'Driver Safety Scores', 'group' => 'Driver & Safety', 'pk' => 'ScoreID', 'order_by' => 'ScorePeriod DESC', 'alias' => 'dss',
        'columns' => [
            ['name' => 'DriverID', 'label' => 'Driver', 'type' => 'fk', 'fk_table' => 'Drivers', 'fk_label' => ['FirstName','LastName'], 'required' => true],
            ['name' => 'ScorePeriod', 'label' => 'Period (YYYY-MM)', 'type' => 'text', 'required' => true],
            ['name' => 'BaseScore', 'label' => 'Base Score', 'type' => 'int', 'required' => true],
            ['name' => 'DeductedPoints', 'label' => 'Deducted Points', 'type' => 'int', 'required' => true],
            ['name' => 'FinalScore', 'label' => 'Final Score', 'type' => 'int', 'required' => true],
            ['name' => 'CoachingRequired', 'label' => 'Coaching Required?', 'type' => 'bool'],
            ['name' => 'Suspended', 'label' => 'Suspended?', 'type' => 'bool'],
            ['name' => 'LowCount', 'label' => 'Low Events', 'type' => 'int', 'list' => false],
            ['name' => 'MediumCount', 'label' => 'Medium Events', 'type' => 'int', 'list' => false],
            ['name' => 'HighCount', 'label' => 'High Events', 'type' => 'int', 'list' => false],
            ['name' => 'CriticalCount', 'label' => 'Critical Events', 'type' => 'int', 'list' => false],
        ],
    ],
    'CoachingRecord' => [
        'label' => 'Coaching Records', 'group' => 'Driver & Safety', 'pk' => 'CoachingID', 'order_by' => 'ScheduledDate DESC', 'alias' => 'cr',
        'columns' => [
            ['name' => 'DriverID', 'label' => 'Driver', 'type' => 'fk', 'fk_table' => 'Drivers', 'fk_label' => ['FirstName','LastName'], 'required' => true],
            ['name' => 'RecordType', 'label' => 'Type', 'type' => 'select', 'required' => true,
                'options' => ['Low Safety Score','Repeated High-Severity Incidents','Critical Event','Other']],
            ['name' => 'Reason', 'label' => 'Reason', 'type' => 'textarea', 'required' => true],
            ['name' => 'ScheduledDate', 'label' => 'Scheduled Date', 'type' => 'date', 'required' => true],
            ['name' => 'CompleteDate', 'label' => 'Completed Date', 'type' => 'date'],
            ['name' => 'Outcome', 'label' => 'Outcome', 'type' => 'select', 'required' => true,
                'options' => ['Pending','Passed','Failed','Cancelled']],
            ['name' => 'EventID', 'label' => 'Linked Safety Event', 'type' => 'fk', 'fk_table' => 'SafetyEvents', 'fk_label' => 'EventID', 'list' => false],
            ['name' => 'ScoreID', 'label' => 'Linked Safety Score', 'type' => 'fk', 'fk_table' => 'DriverSafetyScore', 'fk_label' => 'ScorePeriod', 'list' => false],
        ],
    ],

    // ================= WORKSHOPS & PEOPLE =================
    'Workshop' => [
        'label' => 'Workshops', 'group' => 'Workshops & People', 'pk' => 'WorkshopID', 'order_by' => 'Name', 'alias' => 'ws',
        'columns' => [
            ['name' => 'Name', 'label' => 'Name', 'type' => 'text', 'required' => true],
            ['name' => 'DepotID', 'label' => 'Depot', 'type' => 'fk', 'fk_table' => 'Depots', 'fk_label' => 'Name', 'required' => true],
            ['name' => 'NumBays', 'label' => 'Service Bays', 'type' => 'int', 'required' => true],
            ['name' => 'Contacts', 'label' => 'Contacts', 'type' => 'text'],
        ],
    ],
    'Mechanic' => [
        'label' => 'Mechanics', 'group' => 'Workshops & People', 'pk' => 'MechanicID', 'order_by' => 'LastName', 'alias' => 'm',
        'columns' => [
            ['name' => 'FirstName', 'label' => 'First Name', 'type' => 'text', 'required' => true],
            ['name' => 'LastName', 'label' => 'Last Name', 'type' => 'text', 'required' => true],
            ['name' => 'WorkshopID', 'label' => 'Workshop', 'type' => 'fk', 'fk_table' => 'Workshop', 'fk_label' => 'Name', 'required' => true],
            ['name' => 'EmploymentStatus', 'label' => 'Employment Status', 'type' => 'select', 'required' => true,
                'options' => ['Active','Inactive','Suspended','Terminated']],
        ],
    ],
    'MechanicCertType' => [
        'label' => 'Mechanic Certification Types', 'group' => 'Workshops & People', 'pk' => 'MecCertTypeID', 'order_by' => 'Name', 'alias' => 'mct',
        'columns' => [
            ['name' => 'Name', 'label' => 'Name', 'type' => 'text', 'required' => true],
            ['name' => 'Expire', 'label' => 'Requires Renewal?', 'type' => 'bool'],
        ],
    ],
    'MechanicCertification' => [
        'label' => 'Mechanic Certifications', 'group' => 'Workshops & People', 'pk' => 'MecCertID', 'order_by' => 'ExpireDate', 'alias' => 'mc',
        'columns' => [
            ['name' => 'MechanicID', 'label' => 'Mechanic', 'type' => 'fk', 'fk_table' => 'Mechanic', 'fk_label' => ['FirstName','LastName'], 'required' => true],
            ['name' => 'MecCertTypeID', 'label' => 'Certification', 'type' => 'fk', 'fk_table' => 'MechanicCertType', 'fk_label' => 'Name', 'required' => true],
            ['name' => 'IssueDate', 'label' => 'Issue Date', 'type' => 'date', 'required' => true],
            ['name' => 'ExpireDate', 'label' => 'Expiry Date', 'type' => 'date'],
        ],
    ],

    // ================= MAINTENANCE =================
    'ActivityType' => [
        'label' => 'Activity Types', 'group' => 'Maintenance', 'pk' => 'ActivityTypeID', 'order_by' => 'Name', 'alias' => 'at',
        'columns' => [
            ['name' => 'Name', 'label' => 'Name', 'type' => 'text', 'required' => true],
            ['name' => 'MecCertTypeID', 'label' => 'Required Mechanic Certification', 'type' => 'fk', 'fk_table' => 'MechanicCertType', 'fk_label' => 'Name', 'required' => true],
        ],
    ],
    'PredictiveAlert' => [
        'label' => 'Predictive Alerts', 'group' => 'Maintenance', 'pk' => 'AlertID', 'order_by' => 'GeneratedAt DESC', 'alias' => 'pa',
        'columns' => [
            ['name' => 'VehicleID', 'label' => 'Vehicle', 'type' => 'fk', 'fk_table' => 'Vehicles', 'fk_label' => 'RegistrationNumber', 'required' => true],
            ['name' => 'AlertType', 'label' => 'Alert Type', 'type' => 'select', 'required' => true, 'options' => [
                'Brake Wear Warning','Engine Overheating Risk','Battery Degradation','Oil Quality Deterioration',
                'Transmission Fault Warning','Cooling System Anomaly','Tyre Pressure Irregularity','Other']],
            ['name' => 'Severity', 'label' => 'Severity', 'type' => 'select', 'required' => true,
                'options' => ['Low','Medium','High','Critical']],
            ['name' => 'GeneratedAt', 'label' => 'Generated At', 'type' => 'datetime', 'required' => true],
            ['name' => 'Status', 'label' => 'Status', 'type' => 'select', 'required' => true,
                'options' => ['New','Acknowledged','Scheduled','Escalated','Resolved']],
            ['name' => 'ResolvedAt', 'label' => 'Resolved At', 'type' => 'datetime'],
        ],
    ],
    'MaintenanceJobs' => [
        'label' => 'Maintenance Jobs', 'group' => 'Maintenance', 'pk' => 'JobID', 'order_by' => 'DateOpened DESC', 'alias' => 'mj',
        'columns' => [
            ['name' => 'VehicleID', 'label' => 'Vehicle', 'type' => 'fk', 'fk_table' => 'Vehicles', 'fk_label' => 'RegistrationNumber', 'required' => true],
            ['name' => 'WorkshopID', 'label' => 'Workshop', 'type' => 'fk', 'fk_table' => 'Workshop', 'fk_label' => 'Name', 'required' => true],
            ['name' => 'DateOpened', 'label' => 'Date Opened', 'type' => 'datetime', 'required' => true],
            ['name' => 'DateClosed', 'label' => 'Date Closed', 'type' => 'datetime'],
            ['name' => 'OverallDowntime', 'label' => 'Downtime (hrs)', 'type' => 'decimal'],
            ['name' => 'TotalCost', 'label' => 'Total Cost (VND)', 'type' => 'decimal'],
            ['name' => 'AlertID', 'label' => 'Linked Alert', 'type' => 'fk', 'fk_table' => 'PredictiveAlert', 'fk_label' => 'AlertType'],
        ],
    ],
    'MaintenanceActivity' => [
        'label' => 'Maintenance Activities', 'group' => 'Maintenance', 'pk' => 'ActivityID', 'order_by' => 'StartedAt DESC', 'alias' => 'ma',
        'columns' => [
            ['name' => 'JobID', 'label' => 'Job', 'type' => 'fk', 'fk_table' => 'MaintenanceJobs', 'fk_label' => 'JobID', 'required' => true],
            ['name' => 'ActivityTypeID', 'label' => 'Activity Type', 'type' => 'fk', 'fk_table' => 'ActivityType', 'fk_label' => 'Name', 'required' => true],
            ['name' => 'DiagnosticResult', 'label' => 'Diagnostic Result', 'type' => 'textarea'],
            ['name' => 'IsRepeatFault', 'label' => 'Repeat Fault?', 'type' => 'bool'],
            ['name' => 'StartedAt', 'label' => 'Started At', 'type' => 'datetime', 'required' => true],
            ['name' => 'CompleteAt', 'label' => 'Completed At', 'type' => 'datetime'],
        ],
    ],
    'ActivityMechanic' => [
        'label' => 'Activity ↔ Mechanics', 'group' => 'Maintenance', 'pk' => 'ActivityID,MechanicID', 'order_by' => 'ActivityID', 'alias' => 'am',
        'composite' => true,
        'columns' => [
            ['name' => 'ActivityID', 'label' => 'Activity', 'type' => 'fk', 'fk_table' => 'MaintenanceActivity', 'fk_label' => 'ActivityID', 'required' => true, 'part_of_pk' => true],
            ['name' => 'MechanicID', 'label' => 'Mechanic', 'type' => 'fk', 'fk_table' => 'Mechanic', 'fk_label' => ['FirstName','LastName'], 'required' => true, 'part_of_pk' => true],
            ['name' => 'LabourHours', 'label' => 'Labour Hours', 'type' => 'decimal', 'required' => true],
        ],
    ],
    'WarrantyClaim' => [
        'label' => 'Warranty Claims', 'group' => 'Maintenance', 'pk' => 'ClaimID', 'order_by' => 'ClaimDate DESC', 'alias' => 'wc',
        'columns' => [
            ['name' => 'ActivityID', 'label' => 'Activity', 'type' => 'fk', 'fk_table' => 'MaintenanceActivity', 'fk_label' => 'ActivityID', 'required' => true],
            ['name' => 'WarrantyType', 'label' => 'Warranty Type', 'type' => 'select', 'required' => true, 'options' => ['Manufacturer','Supplier']],
            ['name' => 'Status', 'label' => 'Status', 'type' => 'select', 'required' => true,
                'options' => ['Submitted','Approved','Rejected','Completed']],
            ['name' => 'ClaimDate', 'label' => 'Claim Date', 'type' => 'date', 'required' => true],
        ],
    ],
    'WarrantyClaimPart' => [
        'label' => 'Warranty Claim ↔ Parts', 'group' => 'Maintenance', 'pk' => 'ClaimID,PartID', 'order_by' => 'ClaimID', 'alias' => 'wcp',
        'composite' => true,
        'columns' => [
            ['name' => 'ClaimID', 'label' => 'Warranty Claim', 'type' => 'fk', 'fk_table' => 'WarrantyClaim', 'fk_label' => 'ClaimID', 'required' => true, 'part_of_pk' => true],
            ['name' => 'PartID', 'label' => 'Part', 'type' => 'fk', 'fk_table' => 'Part', 'fk_label' => 'PartNumber', 'required' => true, 'part_of_pk' => true],
        ],
    ],
    'Part' => [
        'label' => 'Parts', 'group' => 'Maintenance', 'pk' => 'PartID', 'order_by' => 'PartNumber', 'alias' => 'p',
        'columns' => [
            ['name' => 'PartNumber', 'label' => 'Part Number', 'type' => 'text', 'required' => true],
            ['name' => 'Description', 'label' => 'Description', 'type' => 'text'],
            ['name' => 'UnitPrice', 'label' => 'Unit Price (VND)', 'type' => 'decimal', 'required' => true],
        ],
    ],
    'ActivityPart' => [
        'label' => 'Activity ↔ Parts Used', 'group' => 'Maintenance', 'pk' => 'ActivityID,PartID', 'order_by' => 'ActivityID', 'alias' => 'ap',
        'composite' => true,
        'columns' => [
            ['name' => 'ActivityID', 'label' => 'Activity', 'type' => 'fk', 'fk_table' => 'MaintenanceActivity', 'fk_label' => 'ActivityID', 'required' => true, 'part_of_pk' => true],
            ['name' => 'PartID', 'label' => 'Part', 'type' => 'fk', 'fk_table' => 'Part', 'fk_label' => 'PartNumber', 'required' => true, 'part_of_pk' => true],
            ['name' => 'QuantityUsed', 'label' => 'Quantity Used', 'type' => 'int', 'required' => true],
            ['name' => 'UnitPriceAtTime', 'label' => 'Unit Price At Time', 'type' => 'decimal', 'required' => true],
        ],
    ],
    'Supplier' => [
        'label' => 'Suppliers', 'group' => 'Maintenance', 'pk' => 'SupplierID', 'order_by' => 'Name', 'alias' => 's',
        'columns' => [
            ['name' => 'Name', 'label' => 'Name', 'type' => 'text', 'required' => true],
            ['name' => 'ContactInfo', 'label' => 'Contact Info', 'type' => 'text'],
            ['name' => 'LeadTimeDays', 'label' => 'Lead Time (days)', 'type' => 'int'],
        ],
    ],
    'SupplyPart' => [
        'label' => 'Supplier ↔ Parts', 'group' => 'Maintenance', 'pk' => 'PartID,SupplierID', 'order_by' => 'PartID', 'alias' => 'sp',
        'composite' => true,
        'columns' => [
            ['name' => 'PartID', 'label' => 'Part', 'type' => 'fk', 'fk_table' => 'Part', 'fk_label' => 'PartNumber', 'required' => true, 'part_of_pk' => true],
            ['name' => 'SupplierID', 'label' => 'Supplier', 'type' => 'fk', 'fk_table' => 'Supplier', 'fk_label' => 'Name', 'required' => true, 'part_of_pk' => true],
            ['name' => 'UnitCost', 'label' => 'Unit Cost (VND)', 'type' => 'decimal', 'required' => true],
            ['name' => 'IsPrimary', 'label' => 'Primary Supplier?', 'type' => 'bool'],
        ],
    ],

    // ================= USER & ROLES =================
    'UserAccount' => [
        'label' => 'User Accounts', 'group' => 'Users & Roles', 'pk' => 'UserID', 'order_by' => 'Username', 'alias' => 'ua',
        'columns' => [
            ['name' => 'Username', 'label' => 'Username', 'type' => 'text', 'required' => true],
            ['name' => 'PasswordHash', 'label' => 'Password Hash', 'type' => 'text', 'required' => true, 'list' => false],
            ['name' => 'IsActive', 'label' => 'Active?', 'type' => 'bool'],
            ['name' => 'DriverID', 'label' => 'Linked Driver', 'type' => 'fk', 'fk_table' => 'Drivers', 'fk_label' => ['FirstName','LastName']],
            ['name' => 'MechanicID', 'label' => 'Linked Mechanic', 'type' => 'fk', 'fk_table' => 'Mechanic', 'fk_label' => ['FirstName','LastName']],
            ['name' => 'DepotID', 'label' => 'Depot', 'type' => 'fk', 'fk_table' => 'Depots', 'fk_label' => 'Name'],
        ],
    ],
    'Role' => [
        'label' => 'Roles', 'group' => 'Users & Roles', 'pk' => 'RoleID', 'order_by' => 'RoleName', 'alias' => 'r',
        'columns' => [
            ['name' => 'RoleName', 'label' => 'Role Name', 'type' => 'text', 'required' => true],
        ],
    ],
    'Permission' => [
        'label' => 'Permissions', 'group' => 'Users & Roles', 'pk' => 'PermissionID', 'order_by' => 'TableName', 'alias' => 'perm',
        'columns' => [
            ['name' => 'TableName', 'label' => 'Table Name', 'type' => 'text', 'required' => true],
            ['name' => 'Action', 'label' => 'Action', 'type' => 'select', 'required' => true,
                'options' => ['SELECT','INSERT','UPDATE','DELETE','ALL']],
        ],
    ],
    'UserRole' => [
        'label' => 'User ↔ Roles', 'group' => 'Users & Roles', 'pk' => 'UserID,RoleID', 'order_by' => 'UserID', 'alias' => 'ur',
        'composite' => true,
        'columns' => [
            ['name' => 'UserID', 'label' => 'User', 'type' => 'fk', 'fk_table' => 'UserAccount', 'fk_label' => 'Username', 'required' => true, 'part_of_pk' => true],
            ['name' => 'RoleID', 'label' => 'Role', 'type' => 'fk', 'fk_table' => 'Role', 'fk_label' => 'RoleName', 'required' => true, 'part_of_pk' => true],
            ['name' => 'GrantedDate', 'label' => 'Granted Date', 'type' => 'date', 'required' => true],
        ],
    ],
    'RolePermission' => [
        'label' => 'Role ↔ Permissions', 'group' => 'Users & Roles', 'pk' => 'RoleID,PermissionID', 'order_by' => 'RoleID', 'alias' => 'rp',
        'composite' => true,
        'columns' => [
            ['name' => 'RoleID', 'label' => 'Role', 'type' => 'fk', 'fk_table' => 'Role', 'fk_label' => 'RoleName', 'required' => true, 'part_of_pk' => true],
            ['name' => 'PermissionID', 'label' => 'Permission', 'type' => 'fk', 'fk_table' => 'Permission', 'fk_label' => 'TableName', 'required' => true, 'part_of_pk' => true],
        ],
    ],
];

// Ordered list of nav groups
$TABLE_GROUPS = ['Core Fleet', 'Driver & Safety', 'Workshops & People', 'Maintenance', 'Users & Roles'];
