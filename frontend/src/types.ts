// ============================================================
// SmartFleet — Shared type definitions (mirrors DB schema)
// ============================================================

export type RoleName =
  | 'fleet_admin'
  | 'safety_ops'
  | 'workshop_manager'
  | 'mechanic'
  | 'driver';

export interface User {
  id: number;
  name: string;
  role: RoleName;
  depot?: string;
  avatarInitials: string;
}

// ── Core Fleet ──
export type VehicleStatus =
  | 'Active' | 'Available' | 'Under Maintenance'
  | 'Awaiting Inspection' | 'Out of Service' | 'Retired';

export interface Vehicle {
  id: number;
  registration: string;
  model: string;
  manufacturer: string;
  year: number;
  category: string;
  depot: string;
  status: VehicleStatus;
  odometer: number;
}

export interface Depot {
  id: number;
  name: string;
  city: string;
  address: string;
  phone: string;
  vehicleCount: number;
  driverCount: number;
}

export interface VehicleAssignment {
  id: number;
  vehicle: string;
  driver: string;
  depot: string;
  startDate: string;
  endDate: string | null;
  isPermanent: boolean;
}

// ── Driver Safety ──
export type DriverStatus = 'Active' | 'Inactive' | 'Suspended' | 'Terminated';
export type Severity = 'Low' | 'Medium' | 'High' | 'Critical';
export type ReviewStatus = 'Not Required' | 'Pending' | 'In Review' | 'Completed';

export interface Driver {
  id: number;
  firstName: string;
  lastName: string;
  depot: string;
  licenceType: string;
  licenceExpiry: string;
  status: DriverStatus;
  safetyScore: number;
}

export interface SafetyEvent {
  id: number;
  timestamp: string;
  driver: string;
  vehicle: string;
  eventType: string;
  severity: Severity;
  depot: string;
  reviewRequired: boolean;
  reviewStatus: ReviewStatus;
}

export interface CoachingRecord {
  id: number;
  driver: string;
  reason: string;
  scheduledDate: string;
  completeDate: string | null;
  outcome: 'Pending' | 'Passed' | 'Failed' | 'Cancelled';
  recordType: string;
}

export interface DriverScore {
  driverId: number;
  driver: string;
  period: string;
  finalScore: number;
  deducted: number;
  low: number;
  medium: number;
  high: number;
  critical: number;
  coachingRequired: boolean;
  suspended: boolean;
}

// ── Workshop / Maintenance ──
export type JobStatus = 'Open' | 'In Progress' | 'Closed';
export type AlertStatus = 'New' | 'Acknowledged' | 'Scheduled' | 'Escalated' | 'Resolved';

export interface MaintenanceJob {
  id: number;
  vehicle: string;
  workshop: string;
  dateOpened: string;
  dateClosed: string | null;
  status: JobStatus;
  totalCost: number;
  alertId: number | null;
}

export interface PredictiveAlert {
  id: number;
  vehicle: string;
  alertType: string;
  severity: Severity;
  generatedAt: string;
  status: AlertStatus;
}

export interface Part {
  id: number;
  partNumber: string;
  description: string;
  unitPrice: number;
  quantityInStock: number;
  reorderThreshold: number;
}

export interface Supplier {
  id: number;
  name: string;
  contactInfo: string;
  leadTimeDays: number;
}

export interface WarrantyClaim {
  id: number;
  activityId: number;
  job: string;
  warrantyType: 'Manufacturer' | 'Supplier';
  status: 'Submitted' | 'Approved' | 'Rejected' | 'Completed';
  claimDate: string;
}

export interface Mechanic {
  id: number;
  firstName: string;
  lastName: string;
  workshop: string;
  status: DriverStatus;
  certs: string[];
}

// ── My Activities (Mechanic role) ──
export interface MyActivity {
  id: number;
  jobId: number;
  vehicle: string;
  activityType: string;
  diagnosticResult: string | null;
  isRepeatFault: boolean;
  labourHours: number;
  startedAt: string | null;
  completeAt: string | null;
}

// ── Driver self-service ──
export interface DriverCertification {
  id: number;
  certType: string;
  issueDate: string;
  expireDate: string | null;
}

export interface MyDriverScore {
  period: string;
  finalScore: number;
  low: number;
  medium: number;
  high: number;
  critical: number;
}

export interface MySafetyEvent {
  timestamp: string;
  eventType: string;
  severity: Severity;
  vehicle: string;
  reviewStatus: ReviewStatus;
}
