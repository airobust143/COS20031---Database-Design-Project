// ============================================================
// Fleet Admin Dashboard — live data from /api/fleet.php
// ============================================================

import { Fleet } from '../api.ts';
import { icon, KPI_ICONS } from '../icons.ts';
import {
  vehicleStatusBadge, driverStatusBadge,
  jobStatusBadge, fmtCurrency,
} from '../utils.ts';

export async function renderFleetAdmin(_navId: string): Promise<string> {
  // Fetch all data in parallel
  const [kpis, vehicles, depots, assignments, drivers, mechanics, users, recentJobs, statusBreakdown] =
    await Promise.all([
      Fleet.kpis(),
      Fleet.vehicles(),
      Fleet.depots(),
      Fleet.assignments(),
      Fleet.drivers(),
      Fleet.mechanics(),
      Fleet.users(),
      Fleet.recentJobs(),
      Fleet.statusBreakdown(),
    ]);

  const totalVehicles = vehicles.length;

  return `
<!-- KPI row -->
<div class="kpi-grid">
  <div class="kpi-card">
    <div class="kpi-icon green">${KPI_ICONS.green}</div>
    <div class="kpi-value">${kpis.totalVehicles}</div>
    <div class="kpi-label">Total Vehicles</div>
    <div class="kpi-change up">${kpis.operational} operational</div>
  </div>
  <div class="kpi-card">
    <div class="kpi-icon orange">${KPI_ICONS.orange}</div>
    <div class="kpi-value">${kpis.underMaint}</div>
    <div class="kpi-label">Under Maintenance</div>
    <div class="kpi-change neutral">${kpis.openJobs} open jobs</div>
  </div>
  <div class="kpi-card">
    <div class="kpi-icon blue">${KPI_ICONS.blue}</div>
    <div class="kpi-value">${kpis.totalDrivers}</div>
    <div class="kpi-label">Drivers</div>
    <div class="kpi-change up">${kpis.activeDrivers} active</div>
  </div>
  <div class="kpi-card">
    <div class="kpi-icon green">${KPI_ICONS.green}</div>
    <div class="kpi-value">${kpis.totalDepots}</div>
    <div class="kpi-label">Depots</div>
    <div class="kpi-change neutral">All operational</div>
  </div>
  <div class="kpi-card">
    <div class="kpi-icon purple">${KPI_ICONS.purple}</div>
    <div class="kpi-value">${kpis.totalMechanics}</div>
    <div class="kpi-label">Mechanics</div>
    <div class="kpi-change up">${kpis.activeMechanics} active</div>
  </div>
  <div class="kpi-card">
    <div class="kpi-icon yellow">${KPI_ICONS.yellow}</div>
    <div class="kpi-value">${kpis.activeAssignments}</div>
    <div class="kpi-label">Active Assignments</div>
    <div class="kpi-change neutral">Current</div>
  </div>
</div>

<!-- Main tabbed card -->
<div class="card">
  <div class="tab-list">
    <button class="tab-btn active" data-tab="tab-vehicles">Vehicles</button>
    <button class="tab-btn" data-tab="tab-depots">Depots</button>
    <button class="tab-btn" data-tab="tab-assignments">Assignments</button>
    <button class="tab-btn" data-tab="tab-drivers">Drivers</button>
    <button class="tab-btn" data-tab="tab-mechanics">Mechanics</button>
    <button class="tab-btn" data-tab="tab-users">Users &amp; Roles</button>
  </div>

  <!-- Vehicles -->
  <div id="tab-vehicles" class="tab-panel active">
    <div class="action-row" style="margin-bottom:16px">
      <div class="action-row-left">
        <input class="form-control" placeholder="Search vehicles…" style="width:220px">
        <select class="form-control" style="width:160px">
          <option>All Statuses</option>
          ${['Active','Available','Under Maintenance','Awaiting Inspection','Out of Service','Retired'].map(s=>`<option>${s}</option>`).join('')}
        </select>
      </div>
      <div class="action-row-right">
        <button class="btn btn-secondary btn-sm">${icon('export',14)} Export</button>
        <button class="btn btn-primary btn-sm">${icon('plus',14)} Add Vehicle</button>
      </div>
    </div>
    <div class="table-wrap">
      <table>
        <thead><tr>
          <th>Reg #</th><th>Model</th><th>Category</th>
          <th>Depot</th><th>Year</th><th>Odometer</th><th>Status</th><th>Actions</th>
        </tr></thead>
        <tbody>
          ${vehicles.length === 0 ? `<tr><td colspan="8"><div class="empty-state"><p>No vehicles found.</p></div></td></tr>` :
          vehicles.map(v => `
          <tr>
            <td><strong>${v.RegistrationNumber}</strong></td>
            <td>${v.Manufacturer} ${v.Model}</td>
            <td><span class="badge badge-gray">${v.CategoryName}</span></td>
            <td>${v.DepotName}</td>
            <td>${v.YearOfManufacture}</td>
            <td>${Number(v.CurrentOdometerReading).toLocaleString()} km</td>
            <td>${vehicleStatusBadge(v.OperationalStatus as never)}</td>
            <td>
              <div class="flex gap-8">
                <button class="btn btn-secondary btn-sm btn-icon" title="Edit">${icon('edit',14)}</button>
                <button class="btn btn-danger btn-sm btn-icon" title="Delete"
                        data-action="delete-vehicle" data-id="${v.VehicleID}">${icon('trash',14)}</button>
              </div>
            </td>
          </tr>`).join('')}
        </tbody>
      </table>
    </div>
  </div>

  <!-- Depots -->
  <div id="tab-depots" class="tab-panel">
    <div class="action-row" style="margin-bottom:16px">
      <div class="action-row-right">
        <button class="btn btn-primary btn-sm">${icon('plus',14)} Add Depot</button>
      </div>
    </div>
    <div class="three-col">
      ${depots.map(d => `
      <div class="card">
        <div class="card-body">
          <div class="flex items-center gap-12" style="margin-bottom:12px">
            <div class="kpi-icon green" style="margin-bottom:0">${KPI_ICONS.green}</div>
            <div>
              <div style="font-weight:600;font-size:15px">${d.Name}</div>
              <div class="text-muted text-sm">${d.City}</div>
            </div>
            <div class="flex gap-8" style="margin-left:auto">
              <button class="btn btn-secondary btn-sm btn-icon">${icon('edit',14)}</button>
            </div>
          </div>
          <div class="text-sm text-muted" style="margin-bottom:6px">${d.Address}</div>
          <div class="text-sm text-muted" style="margin-bottom:14px">${d.ContactPhone ?? '—'}</div>
          <div class="flex gap-12">
            <div><div style="font-weight:700;font-size:18px">${d.VehicleCount}</div><div class="text-xs text-muted">Vehicles</div></div>
            <div><div style="font-weight:700;font-size:18px">${d.DriverCount}</div><div class="text-xs text-muted">Drivers</div></div>
          </div>
        </div>
      </div>`).join('')}
    </div>
  </div>

  <!-- Assignments -->
  <div id="tab-assignments" class="tab-panel">
    <div class="action-row" style="margin-bottom:16px">
      <div class="action-row-right">
        <button class="btn btn-primary btn-sm">${icon('plus',14)} New Assignment</button>
      </div>
    </div>
    <div class="table-wrap">
      <table>
        <thead><tr>
          <th>Reg #</th><th>Vehicle</th><th>Driver</th><th>Depot</th>
          <th>Start</th><th>End</th><th>Type</th><th>Actions</th>
        </tr></thead>
        <tbody>
          ${assignments.length === 0 ? `<tr><td colspan="8"><div class="empty-state"><p>No assignments found.</p></div></td></tr>` :
          assignments.map(a => `
          <tr>
            <td><strong>${a.RegistrationNumber}</strong></td>
            <td class="text-muted">${a.VehicleModel}</td>
            <td>${a.DriverName}</td>
            <td>${a.DepotName}</td>
            <td>${a.StartDate}</td>
            <td>${a.EndDate ?? '—'}</td>
            <td>${Number(a.IsPermanent) ? '<span class="badge badge-green">Permanent</span>' : '<span class="badge badge-blue">Temporary</span>'}</td>
            <td>
              <div class="flex gap-8">
                <button class="btn btn-secondary btn-sm btn-icon">${icon('edit',14)}</button>
                <button class="btn btn-danger btn-sm btn-icon"
                        data-action="delete-assignment" data-id="${a.AssignmentID}">${icon('trash',14)}</button>
              </div>
            </td>
          </tr>`).join('')}
        </tbody>
      </table>
    </div>
  </div>

  <!-- Drivers -->
  <div id="tab-drivers" class="tab-panel">
    <div class="action-row" style="margin-bottom:16px">
      <div class="action-row-left">
        <input class="form-control" placeholder="Search drivers…" style="width:220px">
        <select class="form-control" style="width:150px">
          <option>All Statuses</option><option>Active</option><option>Suspended</option><option>Inactive</option>
        </select>
      </div>
      <div class="action-row-right">
        <button class="btn btn-primary btn-sm">${icon('plus',14)} Add Driver</button>
      </div>
    </div>
    <div class="table-wrap">
      <table>
        <thead><tr>
          <th>Name</th><th>Depot</th><th>Licence</th>
          <th>Expiry</th><th>Safety Score</th><th>Status</th><th>Actions</th>
        </tr></thead>
        <tbody>
          ${drivers.map(d => `
          <tr>
            <td><strong>${d.FirstName} ${d.LastName}</strong></td>
            <td>${d.DepotName}</td>
            <td>${d.LicenceType}</td>
            <td>${d.LicenceExpiryDate}</td>
            <td>
              <div class="flex items-center gap-8">
                <div style="flex:1;max-width:80px">
                  <div class="progress-bar"><div class="progress-fill ${Number(d.SafetyScore)<=50?'danger':Number(d.SafetyScore)<=75?'warning':''}" style="width:${d.SafetyScore}%"></div></div>
                </div>
                <span style="font-weight:600">${d.SafetyScore}</span>
              </div>
            </td>
            <td>${driverStatusBadge(d.EmploymentStatus as never)}</td>
            <td>
              <div class="flex gap-8">
                <button class="btn btn-secondary btn-sm btn-icon">${icon('edit',14)}</button>
                <button class="btn btn-danger btn-sm btn-icon"
                        data-action="delete-driver" data-id="${d.DriverID}">${icon('trash',14)}</button>
              </div>
            </td>
          </tr>`).join('')}
        </tbody>
      </table>
    </div>
  </div>

  <!-- Mechanics -->
  <div id="tab-mechanics" class="tab-panel">
    <div class="action-row" style="margin-bottom:16px">
      <div class="action-row-right">
        <button class="btn btn-primary btn-sm">${icon('plus',14)} Add Mechanic</button>
      </div>
    </div>
    <div class="table-wrap">
      <table>
        <thead><tr><th>Name</th><th>Workshop</th><th>Certifications</th><th>Status</th><th>Actions</th></tr></thead>
        <tbody>
          ${mechanics.map(m => `
          <tr>
            <td><strong>${m.FirstName} ${m.LastName}</strong></td>
            <td>${m.WorkshopName}</td>
            <td>${m.CertList.map(c=>`<span class="badge badge-blue" style="margin-right:4px">${c}</span>`).join('') || '<span class="text-muted">None</span>'}</td>
            <td>${driverStatusBadge(m.EmploymentStatus as never)}</td>
            <td>
              <div class="flex gap-8">
                <button class="btn btn-secondary btn-sm btn-icon">${icon('edit',14)}</button>
                <button class="btn btn-danger btn-sm btn-icon"
                        data-action="delete-mechanic" data-id="${m.MechanicID}">${icon('trash',14)}</button>
              </div>
            </td>
          </tr>`).join('')}
        </tbody>
      </table>
    </div>
  </div>

  <!-- Users & Roles -->
  <div id="tab-users" class="tab-panel">
    <div class="action-row" style="margin-bottom:16px">
      <div class="action-row-right">
        <a href="../create_account.php" target="_blank" class="btn btn-primary btn-sm">${icon('plus',14)} Create Account</a>
      </div>
    </div>
    <div class="table-wrap">
      <table>
        <thead><tr><th>Username</th><th>Role</th><th>Linked To</th><th>Depot</th><th>Active</th><th>Granted</th><th>Actions</th></tr></thead>
        <tbody>
          ${users.map(u => `
          <tr>
            <td><strong>${u.Username}</strong></td>
            <td><span class="badge badge-purple">${u.RoleName ?? '—'}</span></td>
            <td class="text-muted">${u.LinkedDriver ? u.LinkedDriver : u.LinkedMechanic ? u.LinkedMechanic : '—'}</td>
            <td class="text-muted">${u.DepotName ?? '—'}</td>
            <td>${Number(u.IsActive) ? '<span class="badge badge-green">Active</span>' : '<span class="badge badge-gray">Inactive</span>'}</td>
            <td class="text-muted">${u.GrantedDate ?? '—'}</td>
            <td>
              <button class="btn btn-danger btn-sm btn-icon"
                      data-action="delete-user" data-id="${u.UserID}">${icon('trash',14)}</button>
            </td>
          </tr>`).join('')}
        </tbody>
      </table>
    </div>
  </div>
</div>

<!-- Bottom: status breakdown + recent jobs -->
<div class="two-col">
  <div class="card">
    <div class="card-header">
      <div><h2>Fleet Status Breakdown</h2><p>Live operational status</p></div>
    </div>
    <div class="card-body">
      ${(() => {
        const colorMap: Record<string, string> = {
          'Active':'var(--accent)','Available':'var(--blue)',
          'Under Maintenance':'var(--orange)','Awaiting Inspection':'var(--yellow)',
          'Out of Service':'var(--red)','Retired':'var(--text-muted)',
        };
        return statusBreakdown.map(item => `
        <div class="flex items-center gap-12" style="margin-bottom:12px">
          <div style="width:130px;font-size:12px;color:var(--text-secondary)">${item.status}</div>
          <div style="flex:1">
            <div class="progress-bar">
              <div class="progress-fill" style="width:${totalVehicles>0?Math.round((Number(item.count)/totalVehicles)*100):0}%;background:${colorMap[item.status]??'var(--accent)'}"></div>
            </div>
          </div>
          <div style="font-weight:600;font-size:13px;width:20px;text-align:right">${item.count}</div>
        </div>`).join('');
      })()}
    </div>
  </div>

  <div class="card">
    <div class="card-header">
      <div><h2>Recent Maintenance Jobs</h2><p>Latest across all workshops</p></div>
      <a href="../list.php?t=mj" target="_blank" class="btn btn-secondary btn-sm">View All</a>
    </div>
    <div class="timeline" style="padding:0 20px">
      ${recentJobs.length === 0 ? '<div class="empty-state"><p>No jobs yet.</p></div>' :
      recentJobs.slice(0, 8).map(j => `
      <div class="timeline-item">
        <div class="timeline-dot ${j.Status==='Closed'?'green':j.Status==='In Progress'?'orange':'blue'}"></div>
        <div style="flex:1">
          <div style="font-weight:500;font-size:13px">${j.RegistrationNumber} — ${j.VehicleModel}</div>
          <div class="text-xs text-muted">${j.WorkshopName} · ${j.DateOpened.split(' ')[0]}</div>
        </div>
        <div class="flex items-center gap-8">
          ${jobStatusBadge(j.Status as never)}
          <span class="text-sm" style="color:var(--text-secondary)">${fmtCurrency(Number(j.TotalCost))}</span>
        </div>
      </div>`).join('')}
    </div>
  </div>
</div>`;
}
