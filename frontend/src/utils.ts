// ============================================================
// SmartFleet — UI helper utilities
// ============================================================

import type { Severity, VehicleStatus, DriverStatus, AlertStatus, JobStatus } from './types.ts';

export function severityBadge(s: Severity): string {
  const map: Record<Severity, string> = {
    Low:      'badge badge-green',
    Medium:   'badge badge-yellow',
    High:     'badge badge-orange',
    Critical: 'badge badge-red',
  };
  return `<span class="${map[s]}">${s}</span>`;
}

export function vehicleStatusBadge(s: VehicleStatus): string {
  const map: Record<VehicleStatus, string> = {
    'Active':              'badge badge-green',
    'Available':          'badge badge-blue',
    'Under Maintenance':   'badge badge-orange',
    'Awaiting Inspection':'badge badge-yellow',
    'Out of Service':      'badge badge-red',
    'Retired':             'badge badge-gray',
  };
  return `<span class="${map[s]}">${s}</span>`;
}

export function driverStatusBadge(s: DriverStatus): string {
  const map: Record<DriverStatus, string> = {
    Active:     'badge badge-green',
    Inactive:   'badge badge-gray',
    Suspended:  'badge badge-red',
    Terminated: 'badge badge-red',
  };
  return `<span class="${map[s]}">${s}</span>`;
}

export function alertStatusBadge(s: AlertStatus): string {
  const map: Record<AlertStatus, string> = {
    New:          'badge badge-red',
    Acknowledged: 'badge badge-orange',
    Scheduled:    'badge badge-blue',
    Escalated:    'badge badge-purple',
    Resolved:     'badge badge-green',
  };
  return `<span class="${map[s]}">${s}</span>`;
}

export function jobStatusBadge(s: JobStatus): string {
  const map: Record<JobStatus, string> = {
    Open:        'badge badge-blue',
    'In Progress':'badge badge-orange',
    Closed:       'badge badge-green',
  };
  return `<span class="${map[s]}">${s}</span>`;
}

export function reviewStatusBadge(s: string): string {
  const map: Record<string, string> = {
    'Not Required': 'badge badge-gray',
    Pending:        'badge badge-orange',
    'In Review':    'badge badge-blue',
    Completed:      'badge badge-green',
  };
  return `<span class="${map[s] ?? 'badge badge-gray'}">${s}</span>`;
}

export function outcomeBadge(s: string): string {
  const map: Record<string, string> = {
    Pending:   'badge badge-yellow',
    Passed:    'badge badge-green',
    Failed:    'badge badge-red',
    Cancelled: 'badge badge-gray',
  };
  return `<span class="${map[s] ?? 'badge badge-gray'}">${s}</span>`;
}

export function scoreClass(score: number): string {
  if (score > 75) return 'good';
  if (score > 50) return 'caution';
  return 'danger';
}

export function fmtCurrency(n: number): string {
  return n.toLocaleString('vi-VN') + ' ₫';
}

export function fmtDate(s: string): string {
  return s.split(' ')[0] ?? s;
}

export function warrantyStatusBadge(s: string): string {
  const map: Record<string, string> = {
    Submitted: 'badge badge-blue',
    Approved:  'badge badge-green',
    Rejected:  'badge badge-red',
    Completed: 'badge badge-gray',
  };
  return `<span class="${map[s] ?? 'badge badge-gray'}">${s}</span>`;
}
