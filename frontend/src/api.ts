// ============================================================
// SmartFleet — API client
// All fetch calls go to the PHP backend through a same-origin API base.
// In development, /api is handled by the Vite proxy in vite.config.js.
// The proxy derives the Apache path from the repository's real location,
// so the project can live in any subfolder below the document root.
// Production builds infer the project root from the /frontend/ URL segment.
// ============================================================

const API_BASE = (() => {
  const configured = import.meta.env.VITE_API_BASE_URL?.trim();
  if (configured) return configured.replace(/\/+$/, '');

  if (import.meta.env.DEV) {
    return '/api';
  }

  const marker = '/frontend/';
  const markerIndex = location.pathname.indexOf(marker);
  if (markerIndex >= 0) {
    return `${location.pathname.slice(0, markerIndex)}/backend/api`;
  }

  // Fallback for deployments that expose the API at the origin root.
  return '/api';
})();

// ── HTTP helpers ─────────────────────────────────────────────────────

async function apiFetch<T>(
  path: string,
  options: RequestInit = {}
): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, {
    credentials: 'include',
    headers: { 'Content-Type': 'application/json', ...((options.headers ?? {}) as Record<string, string>) },
    ...options,
  });

  let json: { ok: boolean; data?: T; error?: string };
  try {
    json = await res.json() as typeof json;
  } catch {
    throw new Error(`API error ${res.status}: non-JSON response`);
  }

  if (!json.ok) throw new ApiError(json.error ?? 'Unknown error', res.status);
  return json.data as T;
}

export class ApiError extends Error {
  readonly status: number;
  constructor(message: string, status: number) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
  }
}

const get  = <T>(path: string)             => apiFetch<T>(path);
const post = <T>(path: string, body: unknown) => apiFetch<T>(path, { method: 'POST', body: JSON.stringify(body) });
const put  = <T>(path: string, body: unknown) => apiFetch<T>(path, { method: 'PUT',  body: JSON.stringify(body) });
const del  = <T>(path: string)             => apiFetch<T>(path, { method: 'DELETE' });

// ── Auth ──────────────────────────────────────────────────────────────

export interface AuthUser {
  userId: number;
  username: string;
  role: string;
  roleName: string;
  driverId: number | null;
  mechanicId: number | null;
  depotId: number | null;
}

export const Auth = {
  me:     ()                            => get<AuthUser>('/auth.php?action=me'),
  login:  (username: string, password: string) => post<AuthUser>('/auth.php?action=login', { username, password }),
  logout: ()                            => post<{ ok: boolean }>('/auth.php?action=logout', {}),
};

// ── Fleet Admin ──────────────────────────────────────────────────────

export interface FleetKpis {
  totalVehicles: number; operational: number; underMaint: number;
  totalDrivers: number; activeDrivers: number;
  totalMechanics: number; activeMechanics: number;
  totalDepots: number; openJobs: number; activeAssignments: number;
}
export interface ApiVehicle {
  VehicleID: number; RegistrationNumber: string; Model: string;
  Manufacturer: string; YearOfManufacture: number;
  CurrentOdometerReading: number; OperationalStatus: string;
  CategoryName: string; DepotName: string;
}
export interface ApiDepot {
  DepotID: number; Name: string; City: string;
  Address: string; ContactPhone: string;
  VehicleCount: number; DriverCount: number;
}
export interface ApiAssignment {
  AssignmentID: number; RegistrationNumber: string; VehicleModel: string;
  DriverName: string; DepotName: string;
  StartDate: string; EndDate: string | null; IsPermanent: number;
}
export interface ApiDriver {
  DriverID: number; FirstName: string; LastName: string;
  DepotName: string; LicenceType: string; LicenceExpiryDate: string;
  EmploymentStatus: string; SafetyScore: number;
}
export interface ApiMechanic {
  MechanicID: number; FirstName: string; LastName: string;
  WorkshopName: string; EmploymentStatus: string; CertList: string[];
}
export interface ApiUser {
  UserID: number; Username: string; IsActive: number;
  RoleName: string; LinkedDriver: string | null;
  LinkedMechanic: string | null; DepotName: string | null; GrantedDate: string;
}
export interface ApiJob {
  JobID: number; RegistrationNumber: string; VehicleModel: string;
  WorkshopName: string; DateOpened: string; DateClosed: string | null;
  TotalCost: number; AlertID: number | null; Status: string;
}
export interface StatusBreakdown { status: string; count: number; }

export const Fleet = {
  kpis:          ()       => get<FleetKpis>('/fleet.php?resource=kpis'),
  vehicles:      ()       => get<ApiVehicle[]>('/fleet.php?resource=vehicles'),
  depots:        ()       => get<ApiDepot[]>('/fleet.php?resource=depots'),
  assignments:   ()       => get<ApiAssignment[]>('/fleet.php?resource=assignments'),
  drivers:       ()       => get<ApiDriver[]>('/fleet.php?resource=drivers'),
  mechanics:     ()       => get<ApiMechanic[]>('/fleet.php?resource=mechanics'),
  users:         ()       => get<ApiUser[]>('/fleet.php?resource=users'),
  recentJobs:    ()       => get<ApiJob[]>('/fleet.php?resource=recent_jobs'),
  statusBreakdown: ()     => get<StatusBreakdown[]>('/fleet.php?resource=vehicle_status_breakdown'),

  saveVehicle:   (data: Record<string, unknown>, id?: number) =>
    id ? put<{ updated: number }>(`/fleet.php?resource=vehicles&id=${id}`, data)
       : post<{ id: number }>('/fleet.php?resource=vehicles', data),
  deleteVehicle: (id: number) => del<{ deleted: number }>(`/fleet.php?resource=vehicles&id=${id}`),

  saveDepot:     (data: Record<string, unknown>, id?: number) =>
    id ? put<{ updated: number }>(`/fleet.php?resource=depots&id=${id}`, data)
       : post<{ id: number }>('/fleet.php?resource=depots', data),
  deleteDepot:   (id: number) => del<{ deleted: number }>(`/fleet.php?resource=depots&id=${id}`),

  saveAssignment:(data: Record<string, unknown>, id?: number) =>
    id ? put<{ updated: number }>(`/fleet.php?resource=assignments&id=${id}`, data)
       : post<{ id: number }>('/fleet.php?resource=assignments', data),
  deleteAssignment:(id: number) => del<{ deleted: number }>(`/fleet.php?resource=assignments&id=${id}`),

  saveDriver:    (data: Record<string, unknown>, id?: number) =>
    id ? put<{ updated: number }>(`/fleet.php?resource=drivers&id=${id}`, data)
       : post<{ id: number }>('/fleet.php?resource=drivers', data),
  deleteDriver:  (id: number) => del<{ deleted: number }>(`/fleet.php?resource=drivers&id=${id}`),

  saveMechanic:  (data: Record<string, unknown>, id?: number) =>
    id ? put<{ updated: number }>(`/fleet.php?resource=mechanics&id=${id}`, data)
       : post<{ id: number }>('/fleet.php?resource=mechanics', data),
  deleteMechanic:(id: number) => del<{ deleted: number }>(`/fleet.php?resource=mechanics&id=${id}`),
  
  createUser:    (data: Record<string, unknown>) => post<{ id: number }>('/fleet.php?resource=users', data),
  deleteUser:    (id: number) => del<{ deleted: number }>(`/fleet.php?resource=users&id=${id}`),
  
  lookupRoles:        () => get<{ RoleID: number; RoleName: string }[]>('/fleet.php?resource=lookup&type=roles'),
  lookupDriversList:  () => get<{ DriverID: number; DriverName: string }[]>('/fleet.php?resource=lookup&type=drivers_list'),
  lookupMechanicsList:() => get<{ MechanicID: number; MechanicName: string }[]>('/fleet.php?resource=lookup&type=mechanics_list'),
  lookupDepotsList:   () => get<{ DepotID: number; Name: string }[]>('/fleet.php?resource=lookup&type=depots_list'),
};

// ── Safety Ops ───────────────────────────────────────────────────────

export interface SafetyKpis {
  criticalThisMonth: number; pendingReview: number;
  pendingCoaching: number; suspendedDrivers: number; driversFlagged: number;
}
export interface ApiSafetyEvent {
  EventID: number; Timestamp: string; DriverName: string; Vehicle: string;
  EventType: string; Severity: string; DepotName: string;
  ReviewRequired: number; ReviewStatus: string;
}
export interface ApiScore {
  ScoreID: number; DriverName: string; ScorePeriod: string;
  BaseScore: number; DeductedPoints: number; FinalScore: number;
  CoachingRequired: number; Suspended: number;
  LowCount: number; MediumCount: number; HighCount: number; CriticalCount: number;
}
export interface ApiCoaching {
  CoachingID: number; DriverName: string; Reason: string;
  RecordType: string; ScheduledDate: string;
  CompleteDate: string | null; Outcome: string;
}
export interface ApiDriverSafety {
  DriverID: number; DriverName: string;
  DepotName: string; EmploymentStatus: string; SafetyScore: number;
}

export const Safety = {
  kpis:        ()             => get<SafetyKpis>('/safety.php?resource=kpis'),
  events:      (params = '')  => get<ApiSafetyEvent[]>(`/safety.php?resource=events${params}`),
  reviewQueue: ()             => get<ApiSafetyEvent[]>('/safety.php?resource=review_queue'),
  scores:      (period = '')  => get<ApiScore[]>(`/safety.php?resource=scores${period ? '&period='+period : ''}`),
  coaching:    (outcome = '') => get<ApiCoaching[]>(`/safety.php?resource=coaching${outcome ? '&outcome='+outcome : ''}`),
  drivers:     ()             => get<ApiDriverSafety[]>('/safety.php?resource=drivers'),

  logEvent:    (data: Record<string, unknown>) => post<{ id: number }>('/safety.php?resource=events', data),
  updateReviewStatus: (id: number, status: string) => put<{ updated: number }>(`/safety.php?resource=events&id=${id}`, { ReviewStatus: status }),

  addCoaching: (data: Record<string, unknown>) => post<{ id: number }>('/safety.php?resource=coaching', data),
  updateCoaching: (id: number, data: Record<string, unknown>) => put<{ updated: number }>(`/safety.php?resource=coaching&id=${id}`, data),
  setDriverStatus: (id: number, status: string) => put<{ updated: number }>(`/safety.php?resource=driver_status&id=${id}`, { EmploymentStatus: status }),

  lookupEventTypes: () => get<{ EventsTypeID: number; Name: string }[]>('/safety.php?resource=lookup&type=event_types'),
  lookupVehicles:   () => get<{ VehicleID: number; RegistrationNumber: string }[]>('/safety.php?resource=lookup&type=vehicles'),
  lookupDepots:     () => get<{ DepotID: number; Name: string }[]>('/safety.php?resource=lookup&type=depots'),
  lookupPeriods:    () => get<{ ScorePeriod: string }[]>('/safety.php?resource=lookup&type=score_periods'),
};

// ── Workshop Manager ─────────────────────────────────────────────────

export interface WorkshopKpis {
  openJobs: number; inProgress: number; newAlerts: number;
  lowStock: number; pendingClaims: number; activeMechanics: number; totalCost: number;
}
export interface ApiAlert {
  AlertID: number; Vehicle: string; AlertType: string;
  Severity: string; GeneratedAt: string; Status: string;
}
export interface ApiPart {
  PartID: number; PartNumber: string; Description: string;
  UnitPrice: number; QuantityInStock: number; ReorderThreshold: number;
}
export interface ApiSupplier {
  SupplierID: number; Name: string; ContactInfo: string; LeadTimeDays: number;
}
export interface ApiWarrantyClaim {
  ClaimID: number; ActivityID: number; JobRef: string;
  WarrantyType: string; Status: string; ClaimDate: string;
}

export const Workshop = {
  kpis:       ()            => get<WorkshopKpis>('/workshop.php?resource=kpis'),
  jobs:       (status = '') => get<ApiJob[]>(`/workshop.php?resource=jobs${status ? '&status='+encodeURIComponent(status) : ''}`),
  alerts:     (status = '') => get<ApiAlert[]>(`/workshop.php?resource=alerts${status ? '&status='+encodeURIComponent(status) : ''}`),
  parts:      (lowOnly = false) => get<ApiPart[]>(`/workshop.php?resource=parts${lowOnly ? '&low_stock=1' : ''}`),
  suppliers:  ()            => get<ApiSupplier[]>('/workshop.php?resource=suppliers'),
  warranty:   (status = '') => get<ApiWarrantyClaim[]>(`/workshop.php?resource=warranty${status ? '&status='+encodeURIComponent(status) : ''}`),
  mechanics:  ()            => get<ApiMechanic[]>('/workshop.php?resource=mechanics'),

  saveJob:    (data: Record<string, unknown>, id?: number) =>
    id ? put<{ updated: number }>(`/workshop.php?resource=jobs&id=${id}`, data)
       : post<{ id: number }>('/workshop.php?resource=jobs', data),
  deleteJob:  (id: number) => del<{ deleted: number }>(`/workshop.php?resource=jobs&id=${id}`),

  updateAlertStatus: (id: number, status: string) => put<{ updated: number }>(`/workshop.php?resource=alerts&id=${id}`, { Status: status }),

  savePart:   (data: Record<string, unknown>, id?: number) =>
    id ? put<{ updated: number }>(`/workshop.php?resource=parts&id=${id}`, data)
       : post<{ id: number }>('/workshop.php?resource=parts', data),
  deletePart: (id: number) => del<{ deleted: number }>(`/workshop.php?resource=parts&id=${id}`),

  saveSupplier:   (data: Record<string, unknown>, id?: number) =>
    id ? put<{ updated: number }>(`/workshop.php?resource=suppliers&id=${id}`, data)
       : post<{ id: number }>('/workshop.php?resource=suppliers', data),
  deleteSupplier: (id: number) => del<{ deleted: number }>(`/workshop.php?resource=suppliers&id=${id}`),

  addWarrantyClaim:    (data: Record<string, unknown>) => post<{ id: number }>('/workshop.php?resource=warranty', data),
  updateWarrantyStatus:(id: number, status: string) => put<{ updated: number }>(`/workshop.php?resource=warranty&id=${id}`, { Status: status }),

  saveMechanic:  (data: Record<string, unknown>, id?: number) =>
    id ? put<{ updated: number }>(`/workshop.php?resource=mechanics&id=${id}`, data)
       : post<{ id: number }>('/workshop.php?resource=mechanics', data),

  lookupVehicles:  () => get<{ VehicleID: number; RegistrationNumber: string }[]>('/workshop.php?resource=lookup&type=vehicles'),
  lookupWorkshops: () => get<{ WorkshopID: number; Name: string }[]>('/workshop.php?resource=lookup&type=workshops'),
  lookupActivities:() => get<{ ActivityID: number; JobID: number; ActivityType: string }[]>('/workshop.php?resource=lookup&type=activities'),
};

// ── Mechanic ─────────────────────────────────────────────────────────

export interface MechanicKpis {
  total: number; completed: number; inProgress: number;
  repeatFaults: number; totalHours: number;
}
export interface ApiMyActivity {
  ActivityID: number; JobID: number;
  RegistrationNumber: string; VehicleModel: string;
  ActivityType: string; DiagnosticResult: string | null;
  IsRepeatFault: number; StartedAt: string | null; CompleteAt: string | null;
  LabourHours: number;
}

export const Mechanic = {
  kpis:           () => get<MechanicKpis>('/mechanic.php?resource=kpis'),
  myActivities:   () => get<ApiMyActivity[]>('/mechanic.php?resource=my_activities'),
  updateActivity: (id: number, data: Record<string, unknown>) =>
    put<{ updated: number }>(`/mechanic.php?resource=my_activity&id=${id}`, data),
  updateLabour:   (id: number, labourHours: number) =>
    put<{ updated: number }>(`/mechanic.php?resource=my_labour&id=${id}`, { LabourHours: labourHours }),
};

// ── Driver ───────────────────────────────────────────────────────────

export interface DriverKpis {
  name: string; status: string; licenceType: string; licenceExpiry: string;
  latestScore: number; coachingRequired: boolean; suspended: boolean;
  expiringSoon: number; expiredCerts: number; recentEvents: number;
}
export interface ApiMyEvent {
  EventID: number; Timestamp: string; EventType: string;
  Severity: string; Vehicle: string; ReviewStatus: string;
}
export interface ApiMyScore {
  ScorePeriod: string; BaseScore: number; DeductedPoints: number; FinalScore: number;
  CoachingRequired: number; Suspended: number;
  LowCount: number; MediumCount: number; HighCount: number; CriticalCount: number;
}
export interface ApiMyCert {
  DriverCertID: number; CertType: string; IssueDate: string; ExpireDate: string | null;
}

export const Driver = {
  kpis:            () => get<DriverKpis>('/driver.php?resource=kpis'),
  myEvents:        () => get<ApiMyEvent[]>('/driver.php?resource=my_events'),
  myScores:        () => get<ApiMyScore[]>('/driver.php?resource=my_scores'),
  myCertifications:() => get<ApiMyCert[]>('/driver.php?resource=my_certifications'),
};
