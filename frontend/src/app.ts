// ============================================================
// SmartFleet — App shell
// Real auth via PHP session + role-gated dashboards
// No emoji icons — all SVG via icons.ts
// ============================================================

import type { AuthUser } from './api.ts';
import { Auth, ApiError, Fleet, Safety, Workshop } from './api.ts';
import { icon, NAV_ICONS } from './icons.ts';
import { renderFleetAdmin, wireVehicleFilters, wireDriverFilters }      from './views/fleetAdmin.ts';
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
    <div class="topbar-right">
      <div class="topbar-search" role="search">
        <span class="topbar-search-icon" aria-hidden="true">${icon('search', 15)}</span>
        <input
          class="topbar-search-input"
          type="search"
          placeholder="Search…"
          aria-label="Search SmartFleet"
        >
      </div>
      <div class="topbar-user">
        <div class="topbar-avatar">${initials}</div>
        <div class="topbar-user-info">
          <span class="topbar-user-name">${currentUser.username}</span>
          <span class="topbar-user-role">${cfg.label}</span>
        </div>
        <span class="topbar-chevron" aria-hidden="true">${icon('chevronDown', 14)}</span>
      </div>
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
      // Wire vehicle filters if on vehicles page
      if (currentUser!.role === 'fleet_admin' && navId === 'vehicles') {
        wireVehicleFilters(mainContent);
      }
      if (currentUser!.role === 'fleet_admin' && navId === 'drivers') {
        wireDriverFilters(mainContent);
      }
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
function wireActions(container: HTMLElement, role: string): void {
  container.addEventListener('click', (e) => {
    const btn = (e.target as HTMLElement).closest<HTMLButtonElement>('[data-action]');
    if (!btn) return;
    void handleAction(btn.dataset['action'] ?? '', btn.dataset['id'] ? Number(btn.dataset['id']) : undefined, role);
  });
  
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
    if (action === 'review-start'      && id) { await Safety.updateReviewStatus(id, 'In Review');  showToast('Review started.'); }
    if (action === 'review-complete'   && id) { await Safety.updateReviewStatus(id, 'Completed');  showToast('Review marked complete.'); }
    if (action === 'suspend-driver'    && id) { await Safety.setDriverStatus(id, 'Suspended');     showToast('Driver suspended.'); }
    if (action === 'reactivate-driver' && id) { await Safety.setDriverStatus(id, 'Active');        showToast('Driver reactivated.'); }
    if (action === 'ack-alert'         && id) { await Workshop.updateAlertStatus(id, 'Acknowledged'); showToast('Alert acknowledged.'); }
    if (action === 'escalate-alert'    && id) { await Workshop.updateAlertStatus(id, 'Escalated');    showToast('Alert escalated.'); }
    if (action === 'resolve-alert'     && id) { await Workshop.updateAlertStatus(id, 'Resolved');     showToast('Alert resolved.'); }
    
    // User deletion
    if (action === 'delete-user' && id) {
      if (!confirm('Delete this user account? This cannot be undone.')) return;
      await Fleet.deleteUser(id);
      showToast('User account deleted.');
      // Reload the current page by clicking the active nav item
      const activeNav = document.querySelector<HTMLElement>('.nav-item.active[data-nav]');
      if (activeNav) activeNav.click();
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

// ── Toast notification ────────────────────────────────────────────────
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