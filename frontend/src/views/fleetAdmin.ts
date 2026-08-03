// ============================================================
// SmartFleet — Fleet Admin Dashboard
// Role-gated content for Fleet Admins
// ============================================================

import { Fleet, type ApiVehicle } from '../api.ts';
import { icon, KPI_ICONS } from '../icons.ts';
import {
  vehicleStatusBadge, driverStatusBadge,
} from '../utils.ts';

// ── Main render ───────────────────────────────────────────────────────

export async function renderFleetAdmin(navId: string): Promise<string> {
  switch (navId) {
    case 'dashboard':
      return renderDashboard();
    case 'vehicles':
      return renderVehicles();
    case 'depots':
      return renderDepots();
    case 'assignments':
      return renderAssignments();
    case 'drivers':
      return renderDrivers();
    case 'mechanics':
      return renderMechanics();
    case 'users':
      return renderUsers();
    default:
      return renderDashboard();
  }
}

// ── Dashboard ─────────────────────────────────────────────────────────

async function renderDashboard(): Promise<string> {
  const kpis = await Fleet.kpis();

  return `
<div class="kpi-grid">
  <div class="kpi-card">
    <div class="kpi-icon green">${KPI_ICONS.green}</div>
    <div class="kpi-value">${kpis.totalVehicles}</div>
    <div class="kpi-label">Total Vehicles</div>
    <div class="kpi-change neutral">${kpis.operational} operational</div>
  </div>
  <div class="kpi-card">
    <div class="kpi-icon blue">${KPI_ICONS.blue}</div>
    <div class="kpi-value">${kpis.totalDrivers}</div>
    <div class="kpi-label">Total Drivers</div>
    <div class="kpi-change neutral">${kpis.activeDrivers} active</div>
  </div>
  <div class="kpi-card">
    <div class="kpi-icon purple">${KPI_ICONS.purple}</div>
    <div class="kpi-value">${kpis.totalMechanics}</div>
    <div class="kpi-label">Total Mechanics</div>
    <div class="kpi-change neutral">${kpis.activeMechanics} active</div>
  </div>
  <div class="kpi-card">
    <div class="kpi-icon orange">${KPI_ICONS.orange}</div>
    <div class="kpi-value">${kpis.underMaint}</div>
    <div class="kpi-label">Under Maintenance</div>
    <div class="kpi-change ${kpis.underMaint > 0 ? 'down' : 'neutral'}">${kpis.openJobs} open jobs</div>
  </div>
  <div class="kpi-card">
    <div class="kpi-icon yellow">${KPI_ICONS.yellow}</div>
    <div class="kpi-value">${kpis.totalDepots}</div>
    <div class="kpi-label">Total Depots</div>
    <div class="kpi-change neutral">${kpis.activeAssignments} active assignments</div>
  </div>
</div>`;
}

// ── Vehicles Page — Vehicles only ─────────────────────────────────────

async function renderVehicles(): Promise<string> {
  const vehicles = await Fleet.vehicles();

  return `
<div class="card">
  <div class="card-header">
    <div>
      <h2>Vehicles</h2>
      <p>Manage fleet vehicles</p>
    </div>
  </div>
  <div class="card-body">
    <div class="action-row" style="margin-bottom:16px">
      <div class="action-row-left">
        <input id="vehicle-search" class="form-control" placeholder="Search vehicles…" style="width:220px">
        <select id="vehicle-filter-status" class="form-control" style="width:160px">
          <option value="">All Statuses</option>
          ${['Active','Available','Under Maintenance','Awaiting Inspection','Out of Service','Retired'].map(s=>`<option value="${s}">${s}</option>`).join('')}
        </select>
      </div>
      <div class="action-row-right">
        <button id="export-vehicles" class="btn btn-secondary btn-sm">${icon('export',14)} Export</button>
        <button id="add-vehicle" class="btn btn-primary btn-sm">${icon('plus',14)} Add Vehicle</button>
      </div>
    </div>
    <div class="table-wrap">
      <table>
        <thead><tr>
          <th>Reg #</th><th>Model</th><th>Category</th>
          <th>Depot</th><th>Year</th><th>Odometer</th><th>Status</th><th>Actions</th>
        </tr></thead>
        <tbody id="vehicles-table-body">
          ${vehicles.length === 0 ? `<tr><td colspan="8"><div class="empty-state"><p>No vehicles found.</p></div></td></tr>` :
          vehicles.map(v => `
          <tr data-id="${v.VehicleID}">
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
</div>`;
}

// ── Depots Page — Depots only ─────────────────────────────────────────

async function renderDepots(): Promise<string> {
  const depots = await Fleet.depots();

  return `
<div class="card">
  <div class="card-header">
    <div>
      <h2>Depots</h2>
      <p>Manage depot locations</p>
    </div>
    <button id="add-depot" class="btn btn-primary btn-sm">${icon('plus',14)} Add Depot</button>
  </div>
  <div class="card-body">
    <div class="three-col">
      ${depots.map(d => `
      <div class="card">
        <div class="card-body">
          <div class="flex items-center gap-12" style="margin-bottom:12px">
            <div class="kpi-icon green" style="margin-bottom:0">${icon('map',20)}</div>
            <div>
              <div style="font-weight:600;font-size:15px">${d.Name}</div>
              <div class="text-muted text-sm">${d.City}</div>
            </div>
            <div class="flex gap-8" style="margin-left:auto">
              <button class="btn btn-secondary btn-sm btn-icon" title="Edit">${icon('edit',14)}</button>
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
</div>`;
}

// ── Assignments Page — Assignments only ───────────────────────────────

async function renderAssignments(): Promise<string> {
  const assignments = await Fleet.assignments();

  return `
<div class="card">
  <div class="card-header">
    <div>
      <h2>Vehicle Assignments</h2>
      <p>Manage driver-vehicle assignments</p>
    </div>
    <button id="new-assignment" class="btn btn-primary btn-sm">${icon('plus',14)} New Assignment</button>
  </div>
  <div class="card-body">
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
                <button class="btn btn-secondary btn-sm btn-icon" title="Edit">${icon('edit',14)}</button>
                <button class="btn btn-danger btn-sm btn-icon" title="Delete"
                        data-action="delete-assignment" data-id="${a.AssignmentID}">${icon('trash',14)}</button>
              </div>
            </td>
          </tr>`).join('')}
        </tbody>
      </table>
    </div>
  </div>
</div>`;
}

// ── Drivers Page — Drivers only ───────────────────────────────────────

async function renderDrivers(): Promise<string> {
  const drivers = await Fleet.drivers();

  return `
<div class="card">
  <div class="card-header">
    <div>
      <h2>Drivers</h2>
      <p>Manage driver roster</p>
    </div>
  </div>
  <div class="card-body">
    <div class="action-row" style="margin-bottom:16px">
      <div class="action-row-left">
        <input id="driver-search" class="form-control" placeholder="Search drivers…" style="width:220px">
        <select id="driver-filter-status" class="form-control" style="width:150px">
          <option value="">All Statuses</option>
          <option>Active</option><option>Suspended</option><option>Inactive</option>
        </select>
      </div>
      <div class="action-row-right">
        <button id="add-driver" class="btn btn-primary btn-sm">${icon('plus',14)} Add Driver</button>
      </div>
    </div>
    <div class="table-wrap">
      <table>
        <thead><tr>
          <th>Name</th><th>Depot</th><th>Licence</th>
          <th>Expiry</th><th>Safety Score</th><th>Status</th><th>Actions</th>
        </tr></thead>
        <tbody id="drivers-table-body">
          ${drivers.map(d => `
          <tr data-id="${d.DriverID}">
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
                <button class="btn btn-secondary btn-sm btn-icon" title="Edit">${icon('edit',14)}</button>
                <button class="btn btn-danger btn-sm btn-icon" title="Delete"
                        data-action="delete-driver" data-id="${d.DriverID}">${icon('trash',14)}</button>
              </div>
            </td>
          </tr>`).join('')}
        </tbody>
      </table>
    </div>
  </div>
</div>`;
}

// ── Mechanics Page — Mechanics only ───────────────────────────────────

async function renderMechanics(): Promise<string> {
  const mechanics = await Fleet.mechanics();

  return `
<div class="card">
  <div class="card-header">
    <div>
      <h2>Mechanics</h2>
      <p>Manage mechanic roster</p>
    </div>
    <button id="add-mechanic" class="btn btn-primary btn-sm">${icon('plus',14)} Add Mechanic</button>
  </div>
  <div class="card-body">
    <div class="table-wrap">
      <table>
        <thead><tr><th>Name</th><th>Workshop</th><th>Certifications</th><th>Status</th><th>Actions</th></tr></thead>
        <tbody>
          ${mechanics.map(m => `
          <tr data-id="${m.MechanicID}">
            <td><strong>${m.FirstName} ${m.LastName}</strong></td>
            <td>${m.WorkshopName}</td>
            <td>${m.CertList.map(c=>`<span class="badge badge-blue" style="margin-right:4px">${c}</span>`).join('') || '<span class="text-muted">None</span>'}</td>
            <td>${driverStatusBadge(m.EmploymentStatus as never)}</td>
            <td>
              <div class="flex gap-8">
                <button class="btn btn-secondary btn-sm btn-icon" title="Edit">${icon('edit',14)}</button>
                <button class="btn btn-danger btn-sm btn-icon" title="Delete"
                        data-action="delete-mechanic" data-id="${m.MechanicID}">${icon('trash',14)}</button>
              </div>
            </td>
          </tr>`).join('')}
        </tbody>
      </table>
    </div>
  </div>
</div>`;
}

// ── Users Page — Users & Roles only ───────────────────────────────────

async function renderUsers(): Promise<string> {
  const users = await Fleet.users();

  return `
<div class="card">
  <div class="card-header">
    <div>
      <h2>Users & Roles</h2>
      <p>Manage user accounts and role assignments</p>
    </div>
    <button id="show-create-user-modal" class="btn btn-primary btn-sm">${icon('plus',14)} Create Account</button>
  </div>
  <div class="card-body">
    <div class="table-wrap">
      <table>
        <thead><tr><th>Username</th><th>Role</th><th>Linked To</th><th>Depot</th><th>Active</th><th>Granted</th><th>Actions</th></tr></thead>
        <tbody>
          ${users.map(u => `
          <tr data-id="${u.UserID}">
            <td><strong>${u.Username}</strong></td>
            <td><span class="badge badge-purple">${u.RoleName ?? '—'}</span></td>
            <td class="text-muted">${u.LinkedDriver ? u.LinkedDriver : u.LinkedMechanic ? u.LinkedMechanic : '—'}</td>
            <td class="text-muted">${u.DepotName ?? '—'}</td>
            <td>${Number(u.IsActive) ? '<span class="badge badge-green">Active</span>' : '<span class="badge badge-gray">Inactive</span>'}</td>
            <td class="text-muted">${u.GrantedDate ?? '—'}</td>
            <td>
              <button class="btn btn-danger btn-sm btn-icon" title="Delete"
                      data-action="delete-user" data-id="${u.UserID}">${icon('trash',14)}</button>
            </td>
          </tr>`).join('')}
        </tbody>
      </table>
    </div>
  </div>
</div>

<!-- Create User Modal -->
<div id="createUserModal" class="modal" style="display:none">
  <div class="modal-content" style="max-width:600px">
    <div class="modal-header">
      <h2>Create New User Account</h2>
      <button class="modal-close" data-action="close-create-user-modal">${icon('x',20)}</button>
    </div>
    <form id="createUserForm">
      <div class="form-grid">
        <div>
          <label for="new_username">Username *</label>
          <input type="text" id="new_username" name="Username" required pattern="[A-Za-z0-9_.]{3,50}"
            title="3-50 characters: letters, numbers, dots, underscores" autofocus />
        </div>
        <div>
          <label for="new_active">Account Status</label>
          <label style="display:flex;align-items:center;gap:8px;cursor:pointer">
            <input type="checkbox" id="new_active" name="IsActive" value="1" checked />
            <span>Active (can log in immediately)</span>
          </label>
        </div>
        <div>
          <label for="new_password">Password *</label>
          <input type="password" id="new_password" name="Password" required minlength="8" maxlength="72"
            autocomplete="new-password" />
          <small class="text-muted">8–72 characters</small>
        </div>
        <div>
          <label for="new_confirm">Confirm Password *</label>
          <input type="password" id="new_confirm" name="ConfirmPassword" required minlength="8" maxlength="72"
            autocomplete="new-password" />
        </div>
        <div>
          <label for="new_role">Role *</label>
          <select id="new_role" name="RoleID" required>
            <option value="">— Select role —</option>
          </select>
        </div>
        <div>
          <label for="new_depot">Depot</label>
          <select id="new_depot" name="DepotID">
            <option value="">— None —</option>
          </select>
        </div>
        <div>
          <label for="new_driver">Linked Driver</label>
          <select id="new_driver" name="DriverID">
            <option value="">— None —</option>
          </select>
        </div>
        <div>
          <label for="new_mechanic">Linked Mechanic</label>
          <select id="new_mechanic" name="MechanicID">
            <option value="">— None —</option>
          </select>
        </div>
      </div>
      <div id="createUserError" class="alert alert-error" style="display:none;margin-top:16px"></div>
      <div class="form-actions" style="margin-top:24px">
        <button type="submit" class="btn btn-amber">Create Account</button>
        <button type="button" class="btn btn-outline" data-action="close-create-user-modal">Cancel</button>
      </div>
    </form>
  </div>
</div>`;
}

// ── Event wiring for vehicles filtering ───────────────────────────────

export function wireVehicleFilters(container: HTMLElement): void {
  const searchInput = container.querySelector('#vehicle-search') as HTMLInputElement;
  const statusFilter = container.querySelector('#vehicle-filter-status') as HTMLSelectElement;

  if (searchInput && statusFilter) {
    // Initial data cache
    let vehiclesData: ApiVehicle[] = [];

    // Load vehicles and cache - don't render immediately, vehicles are already rendered
    void Fleet.vehicles().then(data => {
      vehiclesData = data;
    });

    // Filter handler
    const filterVehicles = () => {
      // If data hasn't loaded yet, don't filter
      if (vehiclesData.length === 0) return;
      
      const searchTerm = searchInput.value.toLowerCase();
      const statusValue = statusFilter.value;

      const filtered = vehiclesData.filter(v => {
        const matchesSearch = searchTerm === '' ||
          v.RegistrationNumber.toLowerCase().includes(searchTerm) ||
          v.Model.toLowerCase().includes(searchTerm) ||
          v.Manufacturer.toLowerCase().includes(searchTerm) ||
          v.DepotName.toLowerCase().includes(searchTerm);
        const matchesStatus = statusValue === '' || v.OperationalStatus === statusValue;
        return matchesSearch && matchesStatus;
      });

      renderVehicleTable(filtered);
    };

    searchInput.addEventListener('input', filterVehicles);
    statusFilter.addEventListener('change', filterVehicles);
  }
}

function renderVehicleTable(vehicles: ApiVehicle[]): void {
  const tbody = document.querySelector('#vehicles-table-body');
  if (!tbody) return;

  if (vehicles.length === 0) {
    tbody.innerHTML = `<tr><td colspan="8"><div class="empty-state"><p>No vehicles found.</p></div></td></tr>`;
    return;
  }

  tbody.innerHTML = vehicles.map(v => `
    <tr data-id="${v.VehicleID}">
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
    </tr>`).join('');
}

// ── Event wiring for drivers filtering ───────────────────────────────

export function wireDriverFilters(container: HTMLElement): void {
  const searchInput = container.querySelector('#driver-search') as HTMLInputElement;
  const statusFilter = container.querySelector('#driver-filter-status') as HTMLSelectElement;

  if (searchInput && statusFilter) {
    let driversData: any[] = [];

    // Load drivers and cache - don't render immediately, drivers are already rendered
    void Fleet.drivers().then(data => {
      driversData = data;
    });

    const filterDrivers = () => {
      // If data hasn't loaded yet, don't filter
      if (driversData.length === 0) return;
      
      const searchTerm = searchInput.value.toLowerCase();
      const statusValue = statusFilter.value;

      const filtered = driversData.filter(d => {
        const matchesSearch = searchTerm === '' ||
          d.FirstName.toLowerCase().includes(searchTerm) ||
          d.LastName.toLowerCase().includes(searchTerm) ||
          d.DepotName.toLowerCase().includes(searchTerm);
        const matchesStatus = statusValue === '' || d.EmploymentStatus === statusValue;
        return matchesSearch && matchesStatus;
      });

      renderDriverTable(filtered);
    };

    searchInput.addEventListener('input', filterDrivers);
    statusFilter.addEventListener('change', filterDrivers);
  }
}

function renderDriverTable(drivers: any[]): void {
  const tbody = document.querySelector('#drivers-table-body');
  if (!tbody) return;

  tbody.innerHTML = drivers.map(d => `
    <tr data-id="${d.DriverID}">
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
          <button class="btn btn-secondary btn-sm btn-icon" title="Edit">${icon('edit',14)}</button>
          <button class="btn btn-danger btn-sm btn-icon" title="Delete"
                  data-action="delete-driver" data-id="${d.DriverID}">${icon('trash',14)}</button>
        </div>
      </td>
    </tr>`).join('');
}
