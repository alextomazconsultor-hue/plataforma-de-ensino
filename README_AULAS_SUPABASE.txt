/* =============================================
   MÉTODO 3PS — LÓGICA DA PLATAFORMA
============================================= */

// ---- ESTADO ----
const STATE = {
  currentScreen:   'dashboard',
  currentModuleId: null,
  currentLessonId: null,
  logoClickCount:  0,
  logoClickTimer:  null
};

// ---- PROGRESSO (localStorage + Supabase por e-mail) ----
const KEY_DONE  = '3ps_completed';
const KEY_LAST  = '3ps_last';
const KEY_EMAIL = '3ps_email';

let CURRENT_EMAIL = localStorage.getItem(KEY_EMAIL) || '';
let COMPLETED_LESSONS = null;
let LAST_LESSON = null;

function normalizeEmail(email) {
  return String(email || '').trim().toLowerCase();
}

function hasSupabase() {
  return !!(window.supabaseClient && typeof window.supabaseClient.from === 'function');
}

// ---- CURSO DINÂMICO VIA SUPABASE ----
// O data.js continua como fallback. Quando o Supabase tiver módulos/aulas,
// esta função substitui o COURSE local pelos dados do banco.
let COURSE_LOADED_FROM_SUPABASE = false;

async function loadCourseFromSupabase() {
  if (!hasSupabase()) {
    console.log('Supabase não configurado. Usando COURSE local do data.js.');
    return COURSE;
  }

  try {
    const { data: modules, error: modError } = await window.supabaseClient
      .from('course_modules')
      .select('id,title,description,order_index,is_active')
      .eq('is_active', true)
      .order('order_index', { ascending: true });

    if (modError) throw modError;

    const { data: lessons, error: lessonError } = await window.supabaseClient
      .from('lessons')
      .select('id,module_id,title,description,video_url,order_index,is_active,release_status')
      .eq('is_active', true)
      .order('order_index', { ascending: true });

    if (lessonError) throw lessonError;

    if (!modules || modules.length === 0) {
      console.log('Nenhum módulo ativo no Supabase. Usando COURSE local.');
      return COURSE;
    }

    const mountedCourse = modules.map((mod, index) => {
      const moduleLessons = (lessons || [])
        .filter(lesson => lesson.module_id === mod.id)
        .sort((a, b) => (a.order_index || 0) - (b.order_index || 0))
        .map((lesson, lessonIndex) => ({
          id: lesson.id,
          n: lesson.order_index || lessonIndex + 1,
          title: lesson.title,
          desc: lesson.description || '',
          videoUrl: lesson.video_url || '',
          releaseStatus: lesson.release_status || 'available'
        }));

      return {
        id: mod.id,
        n: mod.order_index || index + 1,
        title: mod.title,
        desc: mod.description || '',
        lessons: moduleLessons
      };
    });

    COURSE = mountedCourse;
    COURSE_LOADED_FROM_SUPABASE = true;
    console.log('Curso carregado do Supabase:', COURSE);
    return COURSE;
  } catch (err) {
    console.error('Erro ao carregar aulas do Supabase. Usando COURSE local:', err);
    return COURSE;
  }
}

function resolveSafeFirstLesson() {
  const first = getAllAvailableLessonsFlat()[0];
  return first || null;
}


function getCompletedLocal() {
  try { return JSON.parse(localStorage.getItem(KEY_DONE)) || []; }
  catch { return []; }
}

function saveCompletedLocal(arr) {
  localStorage.setItem(KEY_DONE, JSON.stringify(arr || []));
}

function getLastLocal() {
  try { return JSON.parse(localStorage.getItem(KEY_LAST)) || null; }
  catch { return null; }
}

function saveLastLocal(moduleId, lessonId) {
  localStorage.setItem(KEY_LAST, JSON.stringify({ moduleId, lessonId }));
}

function getCompleted() {
  return Array.isArray(COMPLETED_LESSONS) ? COMPLETED_LESSONS : getCompletedLocal();
}

function saveCompleted(arr) {
  COMPLETED_LESSONS = arr || [];
  saveCompletedLocal(COMPLETED_LESSONS);
}

function getLast() {
  return LAST_LESSON || getLastLocal();
}

function saveLast(moduleId, lessonId) {
  LAST_LESSON = { moduleId, lessonId };
  saveLastLocal(moduleId, lessonId);
  saveLastLessonToSupabase(CURRENT_EMAIL, moduleId, lessonId);
}

async function loadProgressFromSupabase(email) {
  email = normalizeEmail(email);
  const localDone = getCompletedLocal();

  if (!email || !hasSupabase()) {
    COMPLETED_LESSONS = localDone;
    return COMPLETED_LESSONS;
  }

  try {
    const { data, error } = await window.supabaseClient
      .from('student_progress')
      .select('lesson_id')
      .eq('email', email)
      .eq('completed', true);

    if (error) throw error;

    COMPLETED_LESSONS = (data || []).map(row => row.lesson_id);
    saveCompletedLocal(COMPLETED_LESSONS);
    return COMPLETED_LESSONS;
  } catch (err) {
    console.error('Erro ao carregar progresso do Supabase:', err);
    COMPLETED_LESSONS = localDone;
    return COMPLETED_LESSONS;
  }
}

async function saveProgressToSupabase(email, lessonId) {
  email = normalizeEmail(email);

  if (!email || !hasSupabase()) return;

  try {
    const { error } = await window.supabaseClient
      .from('student_progress')
      .upsert({
        email: email,
        lesson_id: lessonId,
        completed: true,
        completed_at: new Date().toISOString()
      }, { onConflict: 'email,lesson_id' });

    if (error) throw error;
  } catch (err) {
    console.error('Erro ao salvar progresso no Supabase:', err);
    showToast('Não consegui salvar no servidor. Salvei neste navegador.');
  }
}

async function loadLastLessonFromSupabase(email) {
  email = normalizeEmail(email);
  const localLast = getLastLocal();

  if (!email || !hasSupabase()) {
    LAST_LESSON = localLast;
    return LAST_LESSON;
  }

  try {
    const { data, error } = await window.supabaseClient
      .from('student_state')
      .select('last_module_id,last_lesson_id')
      .eq('email', email)
      .maybeSingle();

    if (error) throw error;

    if (data && data.last_module_id && data.last_lesson_id) {
      LAST_LESSON = {
        moduleId: data.last_module_id,
        lessonId: data.last_lesson_id
      };
      saveLastLocal(LAST_LESSON.moduleId, LAST_LESSON.lessonId);
    } else {
      LAST_LESSON = localLast;
    }

    return LAST_LESSON;
  } catch (err) {
    console.error('Erro ao carregar última aula do Supabase:', err);
    LAST_LESSON = localLast;
    return LAST_LESSON;
  }
}

async function saveLastLessonToSupabase(email, moduleId, lessonId) {
  email = normalizeEmail(email);

  if (!email || !hasSupabase()) return;

  try {
    const { error } = await window.supabaseClient
      .from('student_state')
      .upsert({
        email: email,
        last_module_id: moduleId,
        last_lesson_id: lessonId,
        updated_at: new Date().toISOString()
      }, { onConflict: 'email' });

    if (error) throw error;
  } catch (err) {
    console.error('Erro ao salvar última aula no Supabase:', err);
  }
}

async function loadStudentData(email) {
  CURRENT_EMAIL = normalizeEmail(email || localStorage.getItem(KEY_EMAIL) || '');
  await loadProgressFromSupabase(CURRENT_EMAIL);
  await loadLastLessonFromSupabase(CURRENT_EMAIL);
}


// ---- LIBERAÇÃO GRADUAL DAS AULAS ----
function isLessonAvailable(lesson) {
  return !lesson.releaseStatus || lesson.releaseStatus === 'available';
}

function availableLessonsOfModule(mod) {
  return (mod.lessons || []).filter(isLessonAvailable);
}

function getAllAvailableLessonsFlat() {
  const flat = [];
  COURSE.forEach(mod => {
    (mod.lessons || []).forEach(lesson => {
      if (isLessonAvailable(lesson)) flat.push({ mod, lesson });
    });
  });
  return flat;
}

function getNextAvailableLesson(moduleId, lessonId) {
  const flat = getAllAvailableLessonsFlat();
  const idx = flat.findIndex(item => item.mod.id === moduleId && item.lesson.id === lessonId);
  if (idx >= 0 && idx < flat.length - 1) return flat[idx + 1];
  return null;
}

function lessonUnavailableToast() {
  showToast('Esta aula será liberada em breve dentro da jornada do Método 3Ps.');
}

// ---- STATS ----
function totalLessons()   { return COURSE.reduce((s, m) => s + availableLessonsOfModule(m).length, 0); }
function completedCount() {
  const availableIds = new Set(getAllAvailableLessonsFlat().map(item => item.lesson.id));
  return getCompleted().filter(id => availableIds.has(id)).length;
}
function overallPct() {
  const t = totalLessons();
  return t ? Math.round((completedCount() / t) * 100) : 0;
}
function modulePct(mod) {
  const done = getCompleted();
  const availableLessons = availableLessonsOfModule(mod);
  const c = availableLessons.filter(l => done.includes(l.id)).length;
  return availableLessons.length ? Math.round((c / availableLessons.length) * 100) : 0;
}

// ---- TOAST ----
let toastTimer = null;
function showToast(msg) {
  const el = document.getElementById('toast');
  el.textContent = msg;
  el.classList.remove('hidden');
  if (toastTimer) clearTimeout(toastTimer);
  toastTimer = setTimeout(() => el.classList.add('hidden'), 3500);
}

// =============================================
// ROTEAMENTO DE TELAS
// =============================================
function showScreen(id) {
  document.querySelectorAll('.screen').forEach(s => s.classList.remove('active'));
  const t = document.getElementById('screen-' + id);
  if (t) t.classList.add('active');
  STATE.currentScreen = id;
  document.querySelectorAll('.nav-link').forEach(a =>
    a.classList.toggle('active', a.dataset.screen === id));
  document.querySelectorAll('.bottom-nav-item').forEach(a =>
    a.classList.toggle('active', a.dataset.screen === id));
  if (id === 'dashboard') renderDashboard();
  if (id === 'modules')   renderModulesList();
}

function showModuleDetail(moduleId) {
  STATE.currentModuleId = moduleId;
  renderModuleDetail(moduleId);
  document.querySelectorAll('.screen').forEach(s => s.classList.remove('active'));
  document.getElementById('screen-module-detail').classList.add('active');
  STATE.currentScreen = 'module-detail';
}

function showLesson(moduleId, lessonId) {
  const mod = COURSE.find(m => m.id === moduleId);
  const lesson = mod ? mod.lessons.find(l => l.id === lessonId) : null;

  if (!lesson || !isLessonAvailable(lesson)) {
    lessonUnavailableToast();
    return;
  }

  STATE.currentModuleId = moduleId;
  STATE.currentLessonId = lessonId;
  saveLast(moduleId, lessonId);
  renderLesson(moduleId, lessonId);
  document.querySelectorAll('.screen').forEach(s => s.classList.remove('active'));
  document.getElementById('screen-lesson').classList.add('active');
  STATE.currentScreen = 'lesson';
}

// =============================================
// VERIFICAR SESSÃO AO CARREGAR A PÁGINA
// =============================================
async function initAuth() {
  if (localStorage.getItem('3ps_loggedIn')) {
    const emailSalvo = localStorage.getItem(KEY_EMAIL) || '';
    await loadCourseFromSupabase();
    await loadStudentData(emailSalvo);
    enterApp();
  }

  const form = document.getElementById('form-login');
  if (!form) return;

  form.addEventListener('submit', async e => {
    e.preventDefault();

    const email = normalizeEmail(document.getElementById('input-email').value);
    const pass  = document.getElementById('input-pass').value.trim();
    const err   = document.getElementById('login-error');

    if (!email || !pass || pass.length < 3) {
      if (err) {
        err.textContent = 'Preencha e-mail e uma senha com pelo menos 3 caracteres.';
        err.classList.remove('hidden');
      }
      return;
    }

    if (err) err.classList.add('hidden');

    const btn = e.target.querySelector('button[type="submit"]');
    if (btn) {
      btn.textContent = 'Entrando...';
      btn.disabled = true;
    }

    const nome = email.split('@')[0] || 'Aluno';
    localStorage.setItem('3ps_loggedIn', '1');
    localStorage.setItem('3ps_name', nome);
    localStorage.setItem(KEY_EMAIL, email);
    CURRENT_EMAIL = email;

    await loadCourseFromSupabase();
    await loadStudentData(email);
    enterApp();

    if (btn) {
      btn.textContent = 'Entrar na plataforma';
      btn.disabled = false;
    }

    showToast('Acesso liberado. Progresso conectado.');
  });
}

// =============================================
// ENTRAR NO APP
// =============================================
function enterApp() {
  document.getElementById('screen-login').classList.remove('active');
  document.getElementById('input-email').value = '';
  document.getElementById('input-pass').value  = '';
  document.getElementById('app-shell').classList.remove('hidden');
  showScreen('dashboard');
}

// =============================================
// LOGOUT
// =============================================
async function logout() {
  localStorage.removeItem('3ps_loggedIn');
  localStorage.removeItem('3ps_name');
  localStorage.removeItem('3ps_email');

  const shell = document.getElementById('app-shell');
  const login = document.getElementById('screen-login');

  if (shell) shell.classList.add('hidden');
  if (login) login.classList.add('active');

  const email = document.getElementById('input-email');
  const pass = document.getElementById('input-pass');

  if (email) email.value = '';
  if (pass) pass.value = '';
}

// =============================================
// RESET DEMO — 5 cliques no logo
// =============================================
function handleLogoClick() {
  STATE.logoClickCount++;
  if (STATE.logoClickTimer) clearTimeout(STATE.logoClickTimer);
  STATE.logoClickTimer = setTimeout(() => { STATE.logoClickCount = 0; }, 2000);
  if (STATE.logoClickCount >= 5) {
    STATE.logoClickCount = 0;
    localStorage.removeItem(KEY_DONE);
    localStorage.removeItem(KEY_LAST);
    COMPLETED_LESSONS = [];
    LAST_LESSON = null;
    showToast('Progresso local resetado.');
    if (STATE.currentScreen === 'dashboard') renderDashboard();
  }
}

// =============================================
// RENDER — DASHBOARD
// =============================================
function renderDashboard() {
  const nome = localStorage.getItem('3ps_name') || 'Aluno';
  document.getElementById('dash-greeting').textContent =
    `Olá, ${nome}. Continue sua evolução no Método 3Ps.`;

  const pct = overallPct(), done = completedCount(), total = totalLessons();
  document.getElementById('dash-stats').innerHTML = `
    <div class="stat-card">
      <span class="stat-label">Progresso geral</span>
      <span class="stat-value">${pct}%</span>
      <div class="progress-bar-wrap"><div class="progress-bar-fill" style="width:${pct}%"></div></div>
    </div>
    <div class="stat-card">
      <span class="stat-label">Aulas concluídas</span>
      <span class="stat-value">${done}</span>
      <span class="stat-sub">de ${total} aulas</span>
    </div>
    <div class="stat-card">
      <span class="stat-label">Total de aulas</span>
      <span class="stat-value">${total}</span>
      <span class="stat-sub">${COURSE.length} módulos</span>
    </div>`;

  renderContinue();

  const grid = document.getElementById('dash-modules');
  grid.innerHTML = '';
  COURSE.forEach(mod => grid.appendChild(buildModuleCard(mod)));
}

function renderContinue() {
  const last = getLast();
  const el   = document.getElementById('dash-continue');

  if (!last) {
    const first = resolveSafeFirstLesson();
    if (!first) {
      el.innerHTML = `<div class="continue-info"><p style="color:var(--gray);font-weight:600;">Nenhuma aula disponível no momento.</p></div>`;
      el.onclick = null;
      return;
    }
    const mod = first.mod, lesson = first.lesson;
    el.innerHTML = continueCardHTML(mod, lesson, 'Começar do início');
    el.onclick = () => showLesson(mod.id, lesson.id);
    return;
  }

  const mod = COURSE.find(m => m.id === last.moduleId);
  if (!mod) return;
  const lesson = mod.lessons.find(l => l.id === last.lessonId);
  if (!lesson) return;

  const done = getCompleted();
  if (done.includes(lesson.id)) {
    const idx = mod.lessons.indexOf(lesson);
    if (idx < mod.lessons.length - 1) {
      const next = mod.lessons[idx + 1];
      el.innerHTML = continueCardHTML(mod, next, 'Próxima aula');
      el.onclick = () => showLesson(mod.id, next.id);
    } else {
      const mi = COURSE.indexOf(mod);
      if (mi < COURSE.length - 1) {
        const nm = COURSE[mi + 1];
        el.innerHTML = continueCardHTML(nm, nm.lessons[0], 'Próximo módulo');
        el.onclick = () => showLesson(nm.id, nm.lessons[0].id);
      } else {
        el.innerHTML = `<div class="continue-info"><p style="color:var(--gold);font-weight:700;">🎉 Curso concluído! Parabéns!</p></div>`;
        el.onclick = null;
      }
    }
  } else {
    el.innerHTML = continueCardHTML(mod, lesson, 'Continuar');
    el.onclick = () => showLesson(mod.id, lesson.id);
  }
}

function continueCardHTML(mod, lesson, label) {
  return `
    <div class="continue-thumb">▶</div>
    <div class="continue-info">
      <div class="continue-module">Módulo ${mod.n} — ${label}</div>
      <div class="continue-title">${lesson.n}. ${lesson.title}</div>
      <div class="continue-progress">${modulePct(mod)}% do módulo concluído</div>
    </div>
    <div class="continue-arrow">›</div>`;
}

// =============================================
// RENDER — MÓDULOS
// =============================================
function renderModulesList() {
  const list = document.getElementById('modules-list');
  list.innerHTML = '';
  COURSE.forEach(mod => list.appendChild(buildModuleCard(mod)));
}

function buildModuleCard(mod) {
  const pct = modulePct(mod);
  const div = document.createElement('div');
  div.className = 'module-card';
  div.innerHTML = `
    <div class="module-card-header">
      <div class="module-num">${mod.n}</div>
      <div><div class="module-card-title">${mod.title}</div></div>
    </div>
    <div class="module-card-desc">${mod.desc}</div>
    <div class="progress-bar-wrap"><div class="progress-bar-fill" style="width:${pct}%"></div></div>
    <div class="module-card-footer">
      <span class="module-lessons-count">${availableLessonsOfModule(mod).length} liberadas · ${mod.lessons.length} total</span>
      <span class="module-pct">${pct}%</span>
    </div>`;
  div.addEventListener('click', () => showModuleDetail(mod.id));
  return div;
}

// =============================================
// RENDER — DETALHE DO MÓDULO
// =============================================
function renderModuleDetail(moduleId) {
  const mod = COURSE.find(m => m.id === moduleId);
  if (!mod) return;

  const pct = modulePct(mod);
  document.getElementById('module-detail-header').innerHTML = `
    <div class="module-detail-title">Módulo ${mod.n}: ${mod.title}</div>
    <div class="module-detail-desc">${mod.desc}</div>
    <div class="module-detail-progress">
      <span class="module-detail-pct">${pct}%</span>
      <div class="progress-bar-wrap wide"><div class="progress-bar-fill" style="width:${pct}%"></div></div>
    </div>`;

  const list = document.getElementById('lessons-list');
  list.innerHTML = '';
  const done = getCompleted(), last = getLast();

  mod.lessons.forEach(lesson => {
    const available = isLessonAvailable(lesson);
    const isDone    = available && done.includes(lesson.id);
    const isCurrent = available && last && last.lessonId === lesson.id;

    const statusLabel = !available ? 'Em breve' : isDone ? 'Concluída' : isCurrent ? 'Atual' : 'Disponível';
    const statusClass = !available ? 'locked' : isDone ? 'done' : isCurrent ? 'current' : 'pending';
    const displayTitle = available ? lesson.title : (lesson.title && lesson.title !== 'Em breve' ? lesson.title : 'Aula em breve');

    const item = document.createElement('div');
    item.className = `lesson-item ${isDone ? 'done' : ''} ${isCurrent && !isDone ? 'active' : ''} ${!available ? 'locked' : ''}`;
    item.innerHTML = `
      <div class="lesson-item-num">${!available ? '🔒' : isDone ? '✓' : lesson.n}</div>
      <div class="lesson-item-info">
        <div class="lesson-item-title">${displayTitle}</div>
        <div class="lesson-item-status ${statusClass}">${statusLabel}</div>
      </div>
      <div class="lesson-item-check">${!available ? '⏳' : isDone ? '✅' : '▶'}</div>`;

    item.addEventListener('click', () => {
      if (!available) {
        lessonUnavailableToast();
        return;
      }
      showLesson(moduleId, lesson.id);
    });

    list.appendChild(item);
  });
}

// =============================================
// RENDER — AULA
// =============================================
function renderLesson(moduleId, lessonId) {
  const mod = COURSE.find(m => m.id === moduleId);
  if (!mod) return;
  const lesson = mod.lessons.find(l => l.id === lessonId);
  if (!lesson) return;

  document.getElementById('lesson-iframe').src = lesson.videoUrl || 'about:blank';
  document.getElementById('lesson-title').textContent = `${lesson.n}. ${lesson.title}`;
  document.getElementById('lesson-desc').textContent  = lesson.desc;

  const btnC = document.getElementById('btn-complete');
  if (getCompleted().includes(lessonId)) {
    btnC.textContent = '✓ Aula concluída'; btnC.disabled = true; btnC.style.opacity = '0.5';
  } else {
    btnC.textContent = '✓ Marcar como concluída'; btnC.disabled = false; btnC.style.opacity = '1';
  }
  btnC.onclick = () => markComplete(moduleId, lessonId);

  const btnN = document.getElementById('btn-next');
  const nextAvailable = getNextAvailableLesson(moduleId, lessonId);
  btnN.style.display = '';
  if (nextAvailable) {
    btnN.textContent = 'Próxima aula →';
    btnN.onclick = () => showLesson(nextAvailable.mod.id, nextAvailable.lesson.id);
  } else {
    btnN.textContent = 'Finalizar curso';
    btnN.onclick = () => showToast('Você concluiu todas as aulas disponíveis. Parabéns!');
  }
  renderSidebar(mod, lessonId);
}

function renderSidebar(mod, currentLessonId) {
  const list = document.getElementById('sidebar-lessons');
  list.innerHTML = '';
  const done = getCompleted();
  mod.lessons.forEach(lesson => {
    const isDone = done.includes(lesson.id);
    const isCurr = lesson.id === currentLessonId;
    const item = document.createElement('div');
    item.className = `lesson-item ${isDone ? 'done' : ''} ${isCurr ? 'active' : ''}`;
    item.style.cursor = 'pointer';
    item.innerHTML = `
      <div class="lesson-item-num">${isDone ? '✓' : lesson.n}</div>
      <div class="lesson-item-info"><div class="lesson-item-title">${lesson.title}</div></div>`;
    item.addEventListener('click', () => showLesson(mod.id, lesson.id));
    list.appendChild(item);
  });
}

// =============================================
// MARCAR AULA COMO CONCLUÍDA
// =============================================
function markComplete(moduleId, lessonId) {
  const done = getCompleted();
  if (!done.includes(lessonId)) {
    done.push(lessonId);
    saveCompleted(done);
    saveProgressToSupabase(CURRENT_EMAIL, lessonId);
  }
  const btnC = document.getElementById('btn-complete');
  btnC.textContent = '✓ Aula concluída'; btnC.disabled = true; btnC.style.opacity = '0.5';
  const mod = COURSE.find(m => m.id === moduleId);
  if (mod) renderSidebar(mod, lessonId);
  showToast('Aula concluída e salva.');
}

// =============================================
// INIT
// =============================================
function init() {
  initAuth();

  document.getElementById('btn-logout').addEventListener('click', logout);

  const btnLogoutMobile = document.getElementById('btn-logout-mobile');
  if (btnLogoutMobile) btnLogoutMobile.addEventListener('click', logout);

  document.querySelectorAll('.nav-link[data-screen]').forEach(a =>
    a.addEventListener('click', e => { e.preventDefault(); showScreen(a.dataset.screen); }));

  document.querySelectorAll('.bottom-nav-item[data-screen]').forEach(a =>
    a.addEventListener('click', e => { e.preventDefault(); showScreen(a.dataset.screen); }));

  document.getElementById('btn-back-modules').addEventListener('click', () =>
    showScreen('modules'));

  document.getElementById('btn-back-module').addEventListener('click', () => {
    document.getElementById('lesson-iframe').src = '';
    if (STATE.currentModuleId) showModuleDetail(STATE.currentModuleId);
    else showScreen('modules');
  });

  document.getElementById('logo-click').addEventListener('click', handleLogoClick);
}

document.addEventListener('DOMContentLoaded', init);
