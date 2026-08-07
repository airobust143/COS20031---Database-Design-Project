// ============================================================
// SmartFleet — App shell
// Real auth via PHP session + role-gated dashboards
// No emoji icons — all SVG via icons.ts
// ============================================================

import type { AuthUser } from './api.ts';
import { Auth, ApiError, Fleet, Safety, Workshop } from './api.ts';
import { icon, NAV_ICONS } from './icons.ts';
import { renderFleetAdmin }                                             from './views/fleetAdmin.ts';
import { renderSafetyOps }       from './views/safetyOps.ts';
import { renderWorkshopManager } from './views/workshopManager.ts';
import { renderMechanic }        from './views/mechanic.ts';
import { renderDriver }          from './views/driver.ts';

// ── Role config ──────────────────────────────────────────────────────

interface NavItem { id: string; label: string; badge?: boolean; }
interface RoleConfig { label: string; desc: string; nav: NavItem[]; }

const ROLE_CONFIGS: Record<string, RoleConfig> = {
  fleet_admin: {
    label: 'Fleet Admin',
    desc:  'Full system access: vehicles, depots, drivers, users',
    nav: [
      { id: 'dashboard'   , label: 'Dashboard'     },
      { id: 'vehicles'    , label: 'Vehicles'       },
      { id: 'depots'      , label: 'Depots'         },
      { id: 'assignments' , label: 'Assignments'    },
      { id: 'drivers'     , label: 'Drivers'        },
      { id: 'mechanics'   , label: 'Mechanics'      },
      { id: 'users'       , label: 'Users & Roles'  },
    ],
  },
  safety_ops: {
    label: 'Safety Ops',
    desc:  'Driver safety management: events, scores, coaching',
    nav: [
      { id: 'dashboard', label: 'Dashboard'           },
      { id: 'events'   , label: 'Safety Events'       },
      { id: 'review'   , label: 'Review Queue', badge: true },
      { id: 'scores'   , label: 'Driver Scores'       },
      { id: 'coaching' , label: 'Coaching Records'    },
      { id: 'suspend'  , label: 'Suspend / Reactivate'},
    ],
  },
  workshop_mgr: {
    label: 'Workshop Manager',
    desc:  'Maintenance ops: jobs, alerts, parts, warranty',
    nav: [
      { id: 'dashboard', label: 'Dashboard'          },
      { id: 'jobs'     , label: 'Job Board'          },
      { id: 'alerts'   , label: 'Alerts Inbox', badge: true },
      { id: 'parts'    , label: 'Parts & Suppliers'  },
      { id: 'warranty' , label: 'Warranty Claims'    },
      { id: 'roster'   , label: 'Mechanic Roster'    },
    ],
  },
  mechanic: {
    label: 'Mechanic',
    desc:  'My assigned activities only',
    nav: [
      { id: 'my-activities', label: 'My Activities' },
      { id: 'log-activity' , label: 'Log Activity'  },
    ],
  },
  driver: {
    label: 'Driver',
    desc:  'Personal read-only: scores, events, certifications',
    nav: [
      { id: 'dashboard'      , label: 'Dashboard'        },
      { id: 'my-score'       , label: 'My Safety Score'  },
      { id: 'my-events'      , label: 'Events'           },
      { id: 'my-certs'       , label: 'Certifications'   },
    ],
  },
};

// ── State ─────────────────────────────────────────────────────────────
let currentUser: AuthUser | null = null;

// ── Entry point ───────────────────────────────────────────────────────
export async function initApp(root: HTMLElement): Promise<void> {
  showLoader(root);
  try {
    currentUser = await Auth.me();
    renderAppShell(root);
  } catch {
    renderLoginScreen(root);
  }
}

// ── Loader ────────────────────────────────────────────────────────────
function showLoader(root: HTMLElement): void {
  root.innerHTML = `
<div class="loader-screen">
  <div class="loader-inner">
    <span class="loader-wordmark">SmartFleet</span>
    <p class="loader-text">Loading workspace…</p>
  </div>
</div>`;
}

// ── Login screen — plain credentials only ─────────────────────────────
function renderLoginScreen(root: HTMLElement, errorMsg = ''): void {
  root.innerHTML = `
<div id="login-screen">
  <div class="login-split">

    <!-- Left panel: plain, functional context — not a marketing hero -->
    <div class="login-brand">
      <div class="login-brand-inner">
        <img src="/smartfleet.svg" alt="SmartFleet" class="login-brand-logo" style="width:360px;height:auto;margin-bottom:16px">
        <h1 class="login-brand-tagline">Transform complex fleet data into actionable insights.</h1>
        <p class="login-brand-sub">
          Our intuitive, role-based platform aligns your vehicles, drivers,
          and maintenance schedules, giving every team member immediate
          access to the exact tools they need to drive efficiency.
        </p>
      </div>
    </div>

    <!-- Right panel: form -->
    <div class="login-form-panel">
      <div class="login-form-box">
        <div class="login-form-header">
          <h2>Sign in</h2>
          <p>Enter your credentials. Your role is resolved automatically.</p>
        </div>

        ${errorMsg ? `
        <div class="login-error-banner" role="alert">
          <div class="login-error-icon">${icon('alert', 16)}</div>
          <span>${errorMsg}</span>
        </div>` : ''}

        <div class="login-field">
          <label for="login-user" class="login-label">Username</label>
          <div class="login-input-wrap">
            <span class="login-input-icon">${icon('user', 16)}</span>
            <input
              id="login-user"
              class="login-input"
              type="text"
              placeholder="Enter your username"
              autocomplete="username"
              autofocus
            >
          </div>
        </div>

        <div class="login-field">
          <label for="login-pass" class="login-label">Password</label>
          <div class="login-input-wrap">
            <span class="login-input-icon">${icon('lock', 16)}</span>
            <input
              id="login-pass"
              class="login-input"
              type="password"
              placeholder="Enter your password"
              autocomplete="current-password"
            >
            <button class="login-eye-btn" id="toggle-pass" type="button" aria-label="Toggle password visibility" tabindex="-1">
              <span id="eye-icon">${icon('eye', 16)}</span>
            </button>
          </div>
        </div>

        <button id="login-btn" class="login-submit" type="button">
          <span id="login-btn-text">Sign in</span>
        </button>

        <p class="login-hint">
          Your account is managed by your system administrator.
          Contact them if you cannot log in.
        </p>
      </div>
    </div>

  </div>
</div>`;

  const userInput = root.querySelector<HTMLInputElement>('#login-user')!;
  const passInput = root.querySelector<HTMLInputElement>('#login-pass')!;
  const eyeBtn    = root.querySelector<HTMLButtonElement>('#toggle-pass')!;

  // Toggle password visibility
  eyeBtn.addEventListener('click', () => {
    const isText = passInput.type === 'text';
    passInput.type = isText ? 'password' : 'text';
    const eyeEl = root.querySelector<HTMLElement>('#eye-icon')!;
    eyeEl.innerHTML = icon(isText ? 'eye' : 'eyeOff', 16);
  });

  const doLogin = async () => {
    const username = userInput.value.trim();
    const password = passInput.value;
    if (!username || !password) {
      renderLoginScreen(root, 'Please enter both username and password.');
      return;
    }
    const btn  = root.querySelector<HTMLButtonElement>('#login-btn')!;
    const text = root.querySelector<HTMLElement>('#login-btn-text')!;
    btn.disabled = true;
    text.innerHTML = `<span class="login-spinner"></span> Signing in…`;
    try {
      currentUser = await Auth.login(username, password);
      renderAppShell(root);
    } catch (err) {
      const msg = err instanceof ApiError
        ? err.message
        : 'Could not reach the server. Make sure the PHP backend is running.';
      renderLoginScreen(root, msg);
    }
  };

  root.querySelector('#login-btn')?.addEventListener('click', () => void doLogin());
  passInput.addEventListener('keydown', (e) => { if (e.key === 'Enter') void doLogin(); });
  userInput.addEventListener('keydown', (e) => { if (e.key === 'Enter') passInput.focus(); });
}

// ── App shell ─────────────────────────────────────────────────────────
function renderAppShell(root: HTMLElement): void {
  if (!currentUser) return;
  const cfg = ROLE_CONFIGS[currentUser.role];
  if (!cfg) {
    renderLoginScreen(root, `Unknown role "${currentUser.role}". Contact your administrator.`);
    return;
  }

  const initials = currentUser.username.substring(0, 2).toUpperCase();

  root.innerHTML = `
<div class="app-shell">

  <!-- ── Sidebar ── -->
  <aside class="sidebar" role="navigation" aria-label="Main navigation">
    <div class="sidebar-logo">
      <span class="sidebar-logo-text">SmartFleet</span>
    </div>

    <div class="sidebar-section">
      <span class="sidebar-section-label">Menu</span>
      ${cfg.nav.map((item, i) => `
      <button
        class="nav-item${i === 0 ? ' active' : ''}"
        data-nav="${item.id}"
        aria-current="${i === 0 ? 'page' : 'false'}"
      >
        <span class="nav-icon" aria-hidden="true">
          ${icon(NAV_ICONS[item.id] ?? 'dashboard', 16)}
        </span>
        <span class="nav-label">${item.label}</span>
        ${item.badge ? `<span class="nav-badge" id="badge-${item.id}" aria-label="has notifications"></span>` : ''}
      </button>`).join('')}
    </div>

    <div class="sidebar-footer">
      <div class="sidebar-user">
        <div class="sidebar-avatar">${initials}</div>
        <div class="sidebar-user-info">
          <span class="sidebar-user-name">${currentUser.username}</span>
          <span class="sidebar-user-role">${cfg.label}</span>
        </div>
      </div>
      <button class="nav-item nav-item-logout" id="logout-btn">
        <span class="nav-icon" aria-hidden="true">${icon('logout', 16)}</span>
        <span class="nav-label">Sign out</span>
      </button>
    </div>
  </aside>

  <!-- ── Topbar ── -->
  <header class="topbar" role="banner">
    <div class="topbar-left">
      <span class="topbar-title" id="topbar-title">${cfg.nav[0]!.label}</span>
    </div>
  </header>

  <!-- ── Main ── -->
  <main class="main-content" id="main-content" role="main">
    <div class="page-loading">
      <div class="page-loading-spinner"></div>
      <p>Loading…</p>
    </div>
  </main>
</div>`;

  const mainContent = root.querySelector<HTMLElement>('#main-content')!;
  const topbarTitle = root.querySelector<HTMLElement>('#topbar-title')!;

  async function navigate(navId: string): Promise<void> {
    const navItem = cfg.nav.find(n => n.id === navId) ?? cfg.nav[0]!;
    topbarTitle.textContent = navItem.label;

    // Active state
    root.querySelectorAll<HTMLElement>('.nav-item[data-nav]').forEach(el => {
      const isActive = el.dataset['nav'] === navId;
      el.classList.toggle('active', isActive);
      el.setAttribute('aria-current', isActive ? 'page' : 'false');
    });

    mainContent.innerHTML = `
      <div class="page-header">
        <div class="page-header-left">
          <h1>${navItem.label}</h1>
          <p>${cfg.desc}</p>
        </div>
      </div>
      <div class="page-loading"><div class="page-loading-spinner"></div><p>Loading data…</p></div>`;

    try {
      const html = await renderRoleContent(currentUser!.role, navId);
      mainContent.innerHTML = `
        <div class="page-header">
          <div class="page-header-left">
            <h1>${navItem.label}</h1>
            <p>${cfg.desc}</p>
          </div>
        </div>
        ${html}`;
      wireTabSwitchers(mainContent);
      wireActions(mainContent, currentUser!.role);
      wireTableFilters(mainContent);
    } catch (err) {
      const msg = err instanceof ApiError
        ? `Error ${err.status}: ${err.message}`
        : `Unexpected error: ${String(err)}`;
      mainContent.innerHTML = `
        <div class="alert-strip danger" style="margin-top:16px">
          <span>${icon('alert', 16)}</span>
          <div>
            <strong>Could not load data.</strong> ${msg}
            ${err instanceof ApiError && err.status === 401
              ? ' &mdash; <a href="#" id="relogin-link">Sign in again</a>' : ''}
          </div>
        </div>`;
      mainContent.querySelector('#relogin-link')?.addEventListener('click', (e) => {
        e.preventDefault();
        currentUser = null;
        renderLoginScreen(root);
      });
    }
  }

  root.querySelectorAll<HTMLButtonElement>('.nav-item[data-nav]').forEach(btn => {
    btn.addEventListener('click', () => void navigate(btn.dataset['nav'] ?? 'dashboard'));
  });

  root.querySelector('#logout-btn')?.addEventListener('click', () => {
    void Auth.logout().finally(() => { currentUser = null; renderLoginScreen(root); });
  });

  void navigate(cfg.nav[0]!.id);
}

// ── Role content router ───────────────────────────────────────────────
async function renderRoleContent(role: string, navId: string): Promise<string> {
  switch (role) {
    case 'fleet_admin':  return renderFleetAdmin(navId);
    case 'safety_ops':   return renderSafetyOps(navId);
    case 'workshop_mgr': return renderWorkshopManager(navId);
    case 'mechanic':     return renderMechanic(navId);
    case 'driver':       return renderDriver(navId);
    default:
      return `<div class="alert-strip warn"><span>${icon('alert',16)}</span><div>Unknown role: ${role}</div></div>`;
  }
}

// ── Tab switcher ──────────────────────────────────────────────────────
function wireTabSwitchers(container: HTMLElement): void {
  container.querySelectorAll<HTMLButtonElement>('.tab-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const targetId = btn.dataset['tab'];
      if (!targetId) return;
      const tabList = btn.closest('.tab-list');
      const card    = tabList?.closest('.card');
      if (!card || !tabList) return;
      tabList.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      card.querySelectorAll('.tab-panel').forEach(p =>
        p.classList.toggle('active', p.id === targetId)
      );
    });
  });
}

// ── Delegated action handling ─────────────────────────────────────────
// Wire declarative search fields and optional select filters to their tables.
function wireTableFilters(container: HTMLElement): void {
  let generatedTableId = 0;

  // Views with select filters provide their own data-table-* attributes.
  // All other rendered data tables receive the same searchable control here.
  container.querySelectorAll<HTMLTableElement>('table').forEach(table => {
    if (table.dataset['noSearch'] === 'true') return;

    const tbody = table.tBodies.item(0);
    if (!tbody) return;

    const tableId = tbody.dataset['tableBody'] ?? `auto-table-${++generatedTableId}`;
    tbody.dataset['tableBody'] = tableId;

    if (container.querySelector(`[data-table-search="${tableId}"]`)) return;

    const controls = document.createElement('div');
    controls.className = 'action-row table-search-row';

    const input = document.createElement('input');
    input.type = 'search';
    input.className = 'form-control';
    input.dataset['tableSearch'] = tableId;
    input.placeholder = 'Search table…';
    input.setAttribute('aria-label', 'Search this table');
    input.style.width = '220px';
    controls.append(input);

    const tableWrap = table.closest<HTMLElement>('.table-wrap');
    const anchor = tableWrap ?? table;
    anchor.parentElement?.insertBefore(controls, anchor);
  });

  container.querySelectorAll<HTMLInputElement>('[data-table-search]').forEach(searchInput => {
    const tableId = searchInput.dataset['tableSearch'];
    if (!tableId) return;

    const scope = searchInput.closest<HTMLElement>('.tab-panel, .card-body') ?? container;
    const tbody = scope.querySelector<HTMLTableSectionElement>(`tbody[data-table-body="${tableId}"]`);
    if (!tbody) return;

    const table = tbody.closest<HTMLTableElement>('table');
    if (!table) return;

    const categoricalFilter = scope.querySelector<HTMLSelectElement>(`select[data-table-filter="${tableId}"]`);
    let searchColumn = scope.querySelector<HTMLSelectElement>(`select[data-table-search-column="${tableId}"]`);

    // Build the searchable-field selector from the table's visible headers so
    // each view gets relevant choices without duplicating configuration.
    if (!searchColumn) {
      searchColumn = document.createElement('select');
      searchColumn.className = 'form-control table-search-column';
      searchColumn.dataset['tableSearchColumn'] = tableId;
      searchColumn.setAttribute('aria-label', 'Choose a field to search');

      const allFieldsOption = document.createElement('option');
      allFieldsOption.value = '';
      allFieldsOption.textContent = 'All fields';
      searchColumn.append(allFieldsOption);

      Array.from(table.tHead?.rows.item(0)?.cells ?? []).forEach((header, columnIndex) => {
        const label = (header.textContent ?? '').trim();
        if (!label || /^(actions?|controls?)$/i.test(label) || header.dataset['searchable'] === 'false') return;

        const option = document.createElement('option');
        option.value = String(columnIndex);
        option.textContent = label;
        searchColumn!.append(option);
      });

      searchInput.before(searchColumn);
    }

    const dataRows = Array.from(tbody.querySelectorAll<HTMLTableRowElement>('tr'))
      .filter(row => !row.querySelector('.empty-state'));
    if (dataRows.length === 0) return;

    const applyFilters = (): void => {
      tbody.querySelector('[data-filter-empty]')?.remove();

      const searchTerm = searchInput.value.trim().toLocaleLowerCase();
      const selectedSearchColumn = searchColumn?.value === '' ? -1 : Number(searchColumn?.value);
      const selectedValue = categoricalFilter?.value.trim().toLocaleLowerCase() ?? '';
      const filterColumn = Number(categoricalFilter?.dataset['filterColumn'] ?? -1);
      let visibleRows = 0;

      dataRows.forEach(row => {
        const searchableText = selectedSearchColumn >= 0
          ? (row.cells[selectedSearchColumn]?.textContent ?? '')
          : (row.textContent ?? '');
        const matchesSearch = !searchTerm || searchableText.toLocaleLowerCase().includes(searchTerm);
        const cellValue = filterColumn >= 0
          ? (row.cells[filterColumn]?.textContent ?? '').trim().toLocaleLowerCase()
          : '';
        const matchesSelect = !selectedValue || cellValue === selectedValue;
        const visible = matchesSearch && matchesSelect;
        row.hidden = !visible;
        if (visible) visibleRows += 1;
      });

      if (visibleRows === 0) {
        const emptyRow = tbody.insertRow();
        emptyRow.dataset['filterEmpty'] = 'true';
        const cell = emptyRow.insertCell();
        cell.colSpan = tbody.closest('table')?.querySelectorAll('thead th').length ?? 1;
        cell.innerHTML = '<div class="empty-state"><p>No matching records found.</p></div>';
      }
    };

    searchInput.addEventListener('input', applyFilters);
    searchColumn.addEventListener('change', applyFilters);
    categoricalFilter?.addEventListener('change', applyFilters);
  });
}

const actionContainers = new WeakSet<HTMLElement>();

function wireActions(container: HTMLElement, role: string): void {
  // The main content element survives navigation while its innerHTML is replaced.
  // Only attach its delegated listener once, otherwise every navigation adds
  // another handler and produces repeated confirmations/API requests.
  if (!actionContainers.has(container)) {
    container.addEventListener('click', (e) => {
      const btn = (e.target as HTMLElement).closest<HTMLButtonElement>('[data-action]');
      if (!btn) return;
      void handleAction(btn.dataset['action'] ?? '', btn.dataset['id'] ? Number(btn.dataset['id']) : undefined, role);
    });
    actionContainers.add(container);
  }
  
  // Handle create user form submission
  const createUserForm = container.querySelector('#createUserForm') as HTMLFormElement;
  if (createUserForm) {
    createUserForm.addEventListener('submit', async (e) => {
      e.preventDefault();
      const errorDiv = document.getElementById('createUserError');
      if (errorDiv) errorDiv.style.display = 'none';
      
      const formData = new FormData(createUserForm);
      const password = formData.get('Password') as string;
      const confirmPassword = formData.get('ConfirmPassword') as string;
      
      // Client-side validation
      if (password !== confirmPassword) {
        if (errorDiv) {
          errorDiv.textContent = 'Password and confirmation do not match.';
          errorDiv.style.display = 'block';
        }
        return;
      }
      
      // Build payload
      const payload: Record<string, unknown> = {
        Username: formData.get('Username'),
        Password: password,
        RoleID: formData.get('RoleID'),
        IsActive: formData.get('IsActive') ? 1 : 0,
      };
      
      const driverId = formData.get('DriverID');
      const mechanicId = formData.get('MechanicID');
      const depotId = formData.get('DepotID');
      
      if (driverId) payload.DriverID = driverId;
      if (mechanicId) payload.MechanicID = mechanicId;
      if (depotId) payload.DepotID = depotId;
      
      try {
        await Fleet.createUser(payload);
        showToast('User account created successfully.');
        
        // Close modal
        const modal = document.getElementById('createUserModal');
        if (modal) modal.style.display = 'none';
        createUserForm.reset();
        
        // Reload the current page by clicking the active nav item
        const activeNav = document.querySelector<HTMLElement>('.nav-item.active[data-nav]');
        if (activeNav) activeNav.click();
      } catch (err) {
        if (errorDiv) {
          errorDiv.textContent = err instanceof ApiError ? err.message : String(err);
          errorDiv.style.display = 'block';
        }
      }
    });
  }
}

async function handleAction(action: string, id: number | undefined, _role: string): Promise<void> {
  try {
    if (action === 'create-safety-event') {
      await openSafetyEventEditor();
      return;
    }
    if (action === 'create-coaching-record') {
      await openCoachingRecordEditor();
      return;
    }
    if (action === 'create-workshop-job') {
      await openWorkshopJobEditor(id);
      return;
    }
    if (action === 'create-workshop-part') {
      openWorkshopPartEditor();
      return;
    }
    if (action === 'create-workshop-supplier') {
      openWorkshopSupplierEditor();
      return;
    }
    if (action === 'create-warranty-claim') {
      await openWarrantyClaimEditor();
      return;
    }
    if (action === 'create-workshop-mechanic') {
      await openWorkshopMechanicEditor();
      return;
    }
    if (action === 'review-start'      && id) { await Safety.updateReviewStatus(id, 'In Review');  showToast('Review started.'); }
    if (action === 'review-complete'   && id) { await Safety.updateReviewStatus(id, 'Completed');  showToast('Review marked complete.'); }
    if (action === 'suspend-driver'    && id) { await Safety.setDriverStatus(id, 'Suspended');     showToast('Driver suspended.'); }
    if (action === 'reactivate-driver' && id) { await Safety.setDriverStatus(id, 'Active');        showToast('Driver reactivated.'); }
    if (action === 'ack-alert'         && id) { await Workshop.updateAlertStatus(id, 'Acknowledged'); showToast('Alert acknowledged.'); }
    if (action === 'escalate-alert'    && id) { await Workshop.updateAlertStatus(id, 'Escalated');    showToast('Alert escalated.'); }
    if (action === 'resolve-alert'     && id) { await Workshop.updateAlertStatus(id, 'Resolved');     showToast('Alert resolved.'); }
    
    const deleteActions: Record<string, { remove: (recordId: number) => Promise<unknown>; label: string }> = {
      'delete-vehicle':    { remove: Fleet.deleteVehicle,    label: 'vehicle' },
      'delete-depot':      { remove: Fleet.deleteDepot,      label: 'depot' },
      'delete-assignment': { remove: Fleet.deleteAssignment, label: 'assignment' },
      'delete-driver':     { remove: Fleet.deleteDriver,     label: 'driver' },
      'delete-mechanic':   { remove: Fleet.deleteMechanic,   label: 'mechanic' },
      'delete-user':       { remove: Fleet.deleteUser,       label: 'user account' },
    };
    if (id && deleteActions[action]) {
      const { remove, label } = deleteActions[action];
      if (!confirm(`Delete this ${label}? This cannot be undone.`)) return;
      await remove(id);
      showToast(`${label[0].toUpperCase()}${label.slice(1)} deleted.`);
      return;
    }

    const editType = action.replace('edit-', '');
    if (id && ['vehicle', 'depot', 'assignment', 'driver', 'mechanic'].includes(editType)) {
      await openRecordEditor(editType as EditableRecordType, id);
      return;
    }
    const createType = action.replace('create-', '');
    if (['vehicle', 'depot', 'assignment', 'driver', 'mechanic'].includes(createType)) {
      await openRecordEditor(createType as EditableRecordType);
      return;
    }
    
    // User management actions
    if (action === 'show-create-user-modal') {
      const modal = document.getElementById('createUserModal');
      if (modal) {
        // Load dropdown data
        const [roles, drivers, mechanics, depots] = await Promise.all([
          Fleet.lookupRoles(),
          Fleet.lookupDriversList(),
          Fleet.lookupMechanicsList(),
          Fleet.lookupDepotsList(),
        ]);
        
        // Populate role dropdown
        const roleSelect = document.getElementById('new_role') as HTMLSelectElement;
        if (roleSelect) {
          roleSelect.innerHTML = '<option value="">— Select role —</option>' +
            roles.map(r => `<option value="${r.RoleID}">${r.RoleName}</option>`).join('');
        }
        
        // Populate driver dropdown
        const driverSelect = document.getElementById('new_driver') as HTMLSelectElement;
        if (driverSelect) {
          driverSelect.innerHTML = '<option value="">— None —</option>' +
            drivers.map(d => `<option value="${d.DriverID}">${d.DriverName}</option>`).join('');
        }
        
        // Populate mechanic dropdown
        const mechanicSelect = document.getElementById('new_mechanic') as HTMLSelectElement;
        if (mechanicSelect) {
          mechanicSelect.innerHTML = '<option value="">— None —</option>' +
            mechanics.map(m => `<option value="${m.MechanicID}">${m.MechanicName}</option>`).join('');
        }
        
        // Populate depot dropdown
        const depotSelect = document.getElementById('new_depot') as HTMLSelectElement;
        if (depotSelect) {
          depotSelect.innerHTML = '<option value="">— None —</option>' +
            depots.map(d => `<option value="${d.DepotID}">${d.Name}</option>`).join('');
        }
        
        modal.style.display = 'flex';
        
        // Focus username field
        setTimeout(() => document.getElementById('new_username')?.focus(), 100);
      }
    }
    
    if (action === 'close-create-user-modal') {
      const modal = document.getElementById('createUserModal');
      if (modal) {
        modal.style.display = 'none';
        // Reset form
        const form = document.getElementById('createUserForm') as HTMLFormElement;
        if (form) form.reset();
        // Hide error
        const error = document.getElementById('createUserError');
        if (error) error.style.display = 'none';
      }
    }
  } catch (err) {
    showToast(err instanceof ApiError ? err.message : String(err), true);
  }
}

function editorSelect(name: string, label: string, options: { value: string | number; label: string }[], value?: string | number): string {
  return `<div><label for="create_${name}">${label} *</label><select id="create_${name}" name="${name}" required>${options.map(option =>
    `<option value="${option.value}" ${String(option.value) === String(value ?? '') ? 'selected' : ''}>${escapeHtml(option.label)}</option>`
  ).join('')}</select></div>`;
}

function editorInput(name: string, label: string, value: string | number, type = 'text', required = true, extra = ''): string {
  return `<div><label for="create_${name}">${label}${required ? ' *' : ''}</label><input id="create_${name}" name="${name}" type="${type}" value="${escapeHtml(String(value))}" ${required ? 'required' : ''} ${extra}></div>`;
}

function openCreateModal(title: string, fields: string, submitLabel: string, save: (form: FormData) => Promise<unknown>): void {
  document.getElementById('createRecordModal')?.remove();
  const modal = document.createElement('div');
  modal.id = 'createRecordModal';
  modal.className = 'modal';
  modal.style.display = 'flex';
  modal.innerHTML = `<div class="modal-content" style="max-width:720px"><div class="modal-header"><h2>${title}</h2><button type="button" class="modal-close" aria-label="Close">${icon('x', 20)}</button></div><form id="createRecordForm"><div class="form-grid">${fields}</div><div id="createRecordError" class="alert alert-error" style="display:none;margin-top:16px"></div><div class="form-actions" style="margin-top:24px"><button type="button" class="btn btn-outline">Cancel</button><button type="submit" class="btn btn-primary">${submitLabel}</button></div></form></div>`;
  document.body.appendChild(modal);
  modal.querySelectorAll<HTMLButtonElement>('.modal-close, .btn-outline').forEach(button => button.addEventListener('click', () => modal.remove()));
  modal.querySelector<HTMLFormElement>('#createRecordForm')!.addEventListener('submit', event => {
    event.preventDefault();
    void save(new FormData(event.currentTarget as HTMLFormElement)).then(() => {
      modal.remove();
      showToast(`${title} created.`);
    }).catch(error => {
      const errorBox = modal.querySelector<HTMLElement>('#createRecordError')!;
      errorBox.textContent = error instanceof ApiError ? error.message : String(error);
      errorBox.style.display = 'block';
    });
  });
}

async function openSafetyEventEditor(): Promise<void> {
  const [drivers, vehicles, depots, eventTypes] = await Promise.all([
    Fleet.drivers(), Safety.lookupVehicles(), Safety.lookupDepots(), Safety.lookupEventTypes(),
  ]);
  if (!drivers.length || !vehicles.length || !depots.length || !eventTypes.length) throw new Error('A driver, vehicle, depot, and event type are required before logging an event.');
  const now = new Date();
  const timestamp = `${now.toISOString().slice(0, 10)}T${now.toTimeString().slice(0, 5)}`;
  const fields = editorInput('Timestamp', 'Date and time', timestamp, 'datetime-local') +
    editorSelect('DriverID', 'Driver', drivers.map(d => ({ value: d.DriverID, label: `${d.FirstName} ${d.LastName}` }))) +
    editorSelect('VehicleID', 'Vehicle', vehicles.map(v => ({ value: v.VehicleID, label: v.RegistrationNumber }))) +
    editorSelect('DepotID', 'Depot', depots.map(d => ({ value: d.DepotID, label: d.Name }))) +
    editorSelect('EventsTypeID', 'Event type', eventTypes.map(e => ({ value: e.EventsTypeID, label: e.Name }))) +
    editorSelect('Severity', 'Severity', ['Low', 'Medium', 'High', 'Critical'].map(value => ({ value, label: value })), 'Low') +
    editorInput('Odometer', 'Odometer', 0, 'number', false, 'min="0"');
  openCreateModal('Log Safety Event', fields, 'Log event', form => Safety.logEvent({
    Timestamp: formValue(form, 'Timestamp').replace('T', ' '), DriverID: formNumber(form, 'DriverID'), VehicleID: formNumber(form, 'VehicleID'), DepotID: formNumber(form, 'DepotID'), EventsTypeID: formNumber(form, 'EventsTypeID'), Severity: formValue(form, 'Severity'), Odometer: formNumber(form, 'Odometer'),
  }));
}

async function openCoachingRecordEditor(): Promise<void> {
  const drivers = await Fleet.drivers();
  if (!drivers.length) throw new Error('Create a driver before adding a coaching record.');
  const fields = editorSelect('DriverID', 'Driver', drivers.map(d => ({ value: d.DriverID, label: `${d.FirstName} ${d.LastName}` }))) +
    editorInput('Reason', 'Reason', '') +
    editorSelect('RecordType', 'Record type', ['Other', 'Safety Event', 'Low Safety Score', 'Performance'].map(value => ({ value, label: value })), 'Other') +
    editorInput('ScheduledDate', 'Scheduled date', new Date().toISOString().slice(0, 10), 'date');
  openCreateModal('Coaching Record', fields, 'Create record', form => Safety.addCoaching({
    DriverID: formNumber(form, 'DriverID'), Reason: formValue(form, 'Reason'), RecordType: formValue(form, 'RecordType'), ScheduledDate: formValue(form, 'ScheduledDate'), Outcome: 'Pending',
  }));
}

async function openWorkshopJobEditor(alertId?: number): Promise<void> {
  const [vehicles, workshops] = await Promise.all([Workshop.lookupVehicles(), Workshop.lookupWorkshops()]);
  if (!vehicles.length || !workshops.length) throw new Error('A vehicle and workshop are required before creating a job.');
  const fields = editorSelect('VehicleID', 'Vehicle', vehicles.map(v => ({ value: v.VehicleID, label: v.RegistrationNumber }))) +
    editorSelect('WorkshopID', 'Workshop', workshops.map(w => ({ value: w.WorkshopID, label: w.Name }))) +
    editorInput('DateOpened', 'Date opened', new Date().toISOString().slice(0, 10), 'date') +
    editorInput('OverallDowntime', 'Downtime (hours)', 0, 'number', false, 'min="0" step="0.25"') +
    editorInput('TotalCost', 'Total cost', 0, 'number', false, 'min="0" step="0.01"');
  openCreateModal('Maintenance Job', fields, 'Create job', form => Workshop.saveJob({
    VehicleID: formNumber(form, 'VehicleID'), WorkshopID: formNumber(form, 'WorkshopID'), DateOpened: formValue(form, 'DateOpened'), OverallDowntime: formValue(form, 'OverallDowntime') || null, TotalCost: formNumber(form, 'TotalCost'), AlertID: alertId ?? null,
  }));
}

function openWorkshopPartEditor(): void {
  const fields = editorInput('PartNumber', 'Part number', '') +
    editorInput('Description', 'Description', '') +
    editorInput('UnitPrice', 'Unit price', 0, 'number', true, 'min="0" step="0.01"') +
    editorInput('QuantityInStock', 'Quantity in stock', 0, 'number', true, 'min="0"') +
    editorInput('ReorderThreshold', 'Reorder threshold', 0, 'number', true, 'min="0"');
  openCreateModal('Part', fields, 'Add part', form => Workshop.savePart({
    PartNumber: formValue(form, 'PartNumber'), Description: formValue(form, 'Description'), UnitPrice: formNumber(form, 'UnitPrice'), QuantityInStock: formNumber(form, 'QuantityInStock'), ReorderThreshold: formNumber(form, 'ReorderThreshold'),
  }));
}

function openWorkshopSupplierEditor(): void {
  const fields = editorInput('Name', 'Supplier name', '') +
    editorInput('ContactInfo', 'Contact information', '', 'text', false) +
    editorInput('LeadTimeDays', 'Lead time (days)', 0, 'number', true, 'min="0"');
  openCreateModal('Supplier', fields, 'Add supplier', form => Workshop.saveSupplier({
    Name: formValue(form, 'Name'), ContactInfo: formValue(form, 'ContactInfo') || null, LeadTimeDays: formNumber(form, 'LeadTimeDays'),
  }));
}

async function openWarrantyClaimEditor(): Promise<void> {
  const activities = await Workshop.lookupActivities();
  if (!activities.length) throw new Error('Create a maintenance activity before submitting a warranty claim.');
  const fields = editorSelect('ActivityID', 'Maintenance activity', activities.map(a => ({ value: a.ActivityID, label: `JOB-${String(a.JobID).padStart(4, '0')} — ${a.ActivityType}` }))) +
    editorSelect('WarrantyType', 'Warranty type', ['Parts', 'Labour', 'Manufacturer', 'Other'].map(value => ({ value, label: value }))) +
    editorInput('ClaimDate', 'Claim date', new Date().toISOString().slice(0, 10), 'date');
  openCreateModal('Warranty Claim', fields, 'Submit claim', form => Workshop.addWarrantyClaim({
    ActivityID: formNumber(form, 'ActivityID'), WarrantyType: formValue(form, 'WarrantyType'), ClaimDate: formValue(form, 'ClaimDate'), Status: 'Submitted',
  }));
}

async function openWorkshopMechanicEditor(): Promise<void> {
  const workshops = await Workshop.lookupWorkshops();
  if (!workshops.length) throw new Error('Create a workshop before adding a mechanic.');
  const fields = editorInput('FirstName', 'First name', '') + editorInput('LastName', 'Last name', '') +
    editorSelect('WorkshopID', 'Workshop', workshops.map(w => ({ value: w.WorkshopID, label: w.Name }))) +
    editorSelect('EmploymentStatus', 'Employment status', ['Active', 'Inactive', 'Suspended', 'Terminated'].map(value => ({ value, label: value })), 'Active');
  openCreateModal('Mechanic', fields, 'Add mechanic', form => Workshop.saveMechanic({
    FirstName: formValue(form, 'FirstName'), LastName: formValue(form, 'LastName'), WorkshopID: formNumber(form, 'WorkshopID'), EmploymentStatus: formValue(form, 'EmploymentStatus'),
  }));
}

// ── Toast notification ────────────────────────────────────────────────
type EditableRecordType = 'vehicle' | 'depot' | 'assignment' | 'driver' | 'mechanic';

async function openRecordEditor(type: EditableRecordType, id?: number): Promise<void> {
  const [vehicles, depots, drivers, mechanics, categories, workshops] = await Promise.all([
    Fleet.vehicles(), Fleet.depots(), Fleet.drivers(), Fleet.mechanics(),
    Fleet.lookupVehicleCategories(), Fleet.lookupWorkshopsList(),
  ]);
  const select = (name: string, label: string, options: { value: string | number; label: string }[], value: string | number) => `
    <div><label for="edit_${name}">${label}</label>
      <select id="edit_${name}" name="${name}" required>${options.map(option =>
        `<option value="${option.value}" ${String(option.value) === String(value) ? 'selected' : ''}>${escapeHtml(option.label)}</option>`
      ).join('')}</select>
    </div>`;
  const input = (name: string, label: string, value: string | number | null, type = 'text', required = true, extra = '') => `
    <div><label for="edit_${name}">${label}${required ? ' *' : ''}</label>
      <input id="edit_${name}" name="${name}" type="${type}" value="${escapeHtml(String(value ?? ''))}" ${required ? 'required' : ''} ${extra}></div>`;
  const statusOptions = ['Active', 'Available', 'Under Maintenance', 'Awaiting Inspection', 'Out of Service', 'Retired'];
  const employmentOptions = ['Active', 'Inactive', 'Suspended', 'Terminated'];
  const depotOptions = depots.map(d => ({ value: d.DepotID, label: d.Name }));
  let title = '';
  let fields = '';
  let save: (form: FormData) => Promise<unknown>;

  if (type === 'vehicle') {
    const record = id ? vehicles.find(v => v.VehicleID === id) : {
      RegistrationNumber: '', CategoryID: categories[0]?.CategoryID ?? 0, Manufacturer: '', Model: '',
      YearOfManufacture: new Date().getFullYear(), CurrentOdometerReading: 0, DepotID: depots[0]?.DepotID ?? 0,
      OperationalStatus: 'Available',
    };
    if (!record || !record.CategoryID || !record.DepotID) throw new Error('Create a depot and vehicle category before adding a vehicle.');
    title = id ? 'Edit Vehicle' : 'Add Vehicle';
    fields = input('RegistrationNumber', 'Registration number', record.RegistrationNumber) +
      select('CategoryID', 'Category', categories.map(c => ({ value: c.CategoryID, label: c.CategoryName })), record.CategoryID) +
      input('Manufacturer', 'Manufacturer', record.Manufacturer) + input('Model', 'Model', record.Model) +
      input('YearOfManufacture', 'Year of manufacture', record.YearOfManufacture, 'number', true, 'min="1886" max="9999"') +
      input('CurrentOdometerReading', 'Odometer reading', record.CurrentOdometerReading, 'number', true, 'min="0"') +
      select('DepotID', 'Depot', depotOptions, record.DepotID) +
      select('OperationalStatus', 'Operational status', statusOptions.map(s => ({ value: s, label: s })), record.OperationalStatus);
    save = async form => Fleet.saveVehicle({
      RegistrationNumber: formValue(form, 'RegistrationNumber'), CategoryID: formNumber(form, 'CategoryID'),
      Manufacturer: formValue(form, 'Manufacturer'), Model: formValue(form, 'Model'),
      YearOfManufacture: formNumber(form, 'YearOfManufacture'), CurrentOdometerReading: formNumber(form, 'CurrentOdometerReading'),
      DepotID: formNumber(form, 'DepotID'), OperationalStatus: formValue(form, 'OperationalStatus'),
    }, id);
  } else if (type === 'depot') {
    const record = id ? depots.find(d => d.DepotID === id) : {
      Name: '', StreetAddress: '', District: '', City: '', ContactPhone: '',
    };
    if (!record) throw new Error('Depot not found.');
    title = id ? 'Edit Depot' : 'Add Depot';
    fields = input('Name', 'Depot name', record.Name) +
      input('StreetAddress', 'Street address', record.StreetAddress) +
      input('District', 'District', record.District) + input('City', 'City', record.City) +
      input('ContactPhone', 'Contact phone', record.ContactPhone, 'tel', false);
    save = async form => Fleet.saveDepot({
      Name: formValue(form, 'Name'), StreetAddress: formValue(form, 'StreetAddress'),
      District: formValue(form, 'District'), City: formValue(form, 'City'),
      ContactPhone: formValue(form, 'ContactPhone') || null,
    }, id);
  } else if (type === 'driver') {
    const record = id ? drivers.find(d => d.DriverID === id) : {
      FirstName: '', LastName: '', ContactInformation: '', DepotID: depots[0]?.DepotID ?? 0,
      LicenceType: '', LicenceExpiryDate: '', EmploymentStatus: 'Active', EmergencyContactDetails: '',
    };
    if (!record || !record.DepotID) throw new Error('Create a depot before adding a driver.');
    title = id ? 'Edit Driver' : 'Add Driver';
    fields = input('FirstName', 'First name', record.FirstName) + input('LastName', 'Last name', record.LastName) +
      input('ContactInformation', 'Contact information', record.ContactInformation, 'text', false) +
      select('DepotID', 'Depot', depotOptions, record.DepotID) + input('LicenceType', 'Licence type', record.LicenceType) +
      input('LicenceExpiryDate', 'Licence expiry date', record.LicenceExpiryDate, 'date') +
      select('EmploymentStatus', 'Employment status', employmentOptions.map(s => ({ value: s, label: s })), record.EmploymentStatus) +
      input('EmergencyContactDetails', 'Emergency contact details', record.EmergencyContactDetails, 'text', false);
    save = async form => Fleet.saveDriver({
      FirstName: formValue(form, 'FirstName'), LastName: formValue(form, 'LastName'),
      ContactInformation: formValue(form, 'ContactInformation') || null, DepotID: formNumber(form, 'DepotID'),
      LicenceType: formValue(form, 'LicenceType'), LicenceExpiryDate: formValue(form, 'LicenceExpiryDate'),
      EmploymentStatus: formValue(form, 'EmploymentStatus'), EmergencyContactDetails: formValue(form, 'EmergencyContactDetails') || null,
    }, id);
  } else if (type === 'mechanic') {
    const record = id ? mechanics.find(m => m.MechanicID === id) : {
      FirstName: '', LastName: '', WorkshopID: workshops[0]?.WorkshopID ?? 0, EmploymentStatus: 'Active',
    };
    if (!record || !record.WorkshopID) throw new Error('Create a workshop before adding a mechanic.');
    title = id ? 'Edit Mechanic' : 'Add Mechanic';
    fields = input('FirstName', 'First name', record.FirstName) + input('LastName', 'Last name', record.LastName) +
      select('WorkshopID', 'Workshop', workshops.map(w => ({ value: w.WorkshopID, label: w.Name })), record.WorkshopID) +
      select('EmploymentStatus', 'Employment status', employmentOptions.map(s => ({ value: s, label: s })), record.EmploymentStatus);
    save = async form => Fleet.saveMechanic({ FirstName: formValue(form, 'FirstName'), LastName: formValue(form, 'LastName'), WorkshopID: formNumber(form, 'WorkshopID'), EmploymentStatus: formValue(form, 'EmploymentStatus') }, id);
  } else {
    const assignments = id ? await Fleet.assignments() : [];
    const record = id ? assignments.find(a => a.AssignmentID === id) : {
      VehicleID: vehicles[0]?.VehicleID ?? 0, DriverID: drivers[0]?.DriverID ?? 0,
      DepotID: depots[0]?.DepotID ?? 0, StartDate: new Date().toISOString().slice(0, 10), EndDate: null, IsPermanent: 0,
    };
    if (!record || !record.VehicleID || !record.DriverID || !record.DepotID) throw new Error('Create a vehicle, driver, and depot before adding an assignment.');
    title = id ? 'Edit Vehicle Assignment' : 'New Vehicle Assignment';
    fields = select('VehicleID', 'Vehicle', vehicles.map(v => ({ value: v.VehicleID, label: v.RegistrationNumber })), record.VehicleID) +
      select('DriverID', 'Driver', drivers.map(d => ({ value: d.DriverID, label: `${d.FirstName} ${d.LastName}` })), record.DriverID) +
      select('DepotID', 'Depot', depotOptions, record.DepotID) + input('StartDate', 'Start date', record.StartDate, 'date') +
      input('EndDate', 'End date', record.EndDate, 'date', false) +
      `<div><label><input name="IsPermanent" type="checkbox" ${Number(record.IsPermanent) ? 'checked' : ''}> Permanent assignment</label></div>`;
    save = async form => Fleet.saveAssignment({
      VehicleID: formNumber(form, 'VehicleID'), DriverID: formNumber(form, 'DriverID'), DepotID: formNumber(form, 'DepotID'),
      StartDate: formValue(form, 'StartDate'), EndDate: formValue(form, 'EndDate') || null, IsPermanent: form.has('IsPermanent') ? 1 : 0,
    }, id);
  }

  document.getElementById('editRecordModal')?.remove();
  const modal = document.createElement('div');
  modal.id = 'editRecordModal';
  modal.className = 'modal';
  modal.style.display = 'flex';
  modal.innerHTML = `<div class="modal-content" style="max-width:720px">
    <div class="modal-header"><h2>${title}</h2><button type="button" class="modal-close" aria-label="Close">${icon('x', 20)}</button></div>
    <form id="editRecordForm"><div class="form-grid">${fields}</div>
      <div id="editRecordError" class="alert alert-error" style="display:none;margin-top:16px"></div>
      <div class="form-actions" style="margin-top:24px"><button type="button" class="btn btn-outline">Cancel</button><button type="submit" class="btn btn-primary">${id ? 'Save changes' : 'Add record'}</button></div>
    </form></div>`;
  document.body.appendChild(modal);
  modal.querySelectorAll<HTMLButtonElement>('.modal-close, .btn-outline').forEach(button => button.addEventListener('click', () => modal.remove()));
  modal.querySelector<HTMLFormElement>('#editRecordForm')!.addEventListener('submit', event => {
    event.preventDefault();
    void save(new FormData(event.currentTarget as HTMLFormElement)).then(() => {
      modal.remove();
      showToast(id ? `${title.replace('Edit ', '')} updated.` : `${title.replace(/Add |New /, '')} added.`);
    }).catch(error => {
      const errorBox = modal.querySelector<HTMLElement>('#editRecordError')!;
      errorBox.textContent = error instanceof ApiError ? error.message : String(error);
      errorBox.style.display = 'block';
    });
  });
}

function formValue(form: FormData, name: string): string {
  return String(form.get(name) ?? '').trim();
}

function formNumber(form: FormData, name: string): number {
  return Number(formValue(form, name));
}

function escapeHtml(value: string): string {
  return value.replace(/[&<>"']/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char]!);
}

function showToast(msg: string, isError = false): void {
  const el = document.createElement('div');
  el.className = `toast ${isError ? 'toast-error' : 'toast-success'}`;
  el.innerHTML = `
    <span class="toast-icon">${icon(isError ? 'alert' : 'check', 15)}</span>
    <span>${msg}</span>`;
  document.body.appendChild(el);
  requestAnimationFrame(() => el.classList.add('toast-visible'));
  setTimeout(() => {
    el.classList.remove('toast-visible');
    setTimeout(() => el.remove(), 300);
  }, 3200);
  // Re-render current view after a mutating action
  if (!isError) {
    setTimeout(() => {
      const active = document.querySelector<HTMLElement>('.nav-item.active[data-nav]');
      active?.click();
    }, 500);
  }
}
