const API = window.location.origin;

function token() {
  return localStorage.getItem('pa_token') || document.getElementById('token').value.trim();
}

async function api(path, options = {}) {
  const res = await fetch(`${API}${path}`, {
    ...options,
    headers: {
      'content-type': 'application/json',
      authorization: `Bearer ${token()}`,
      ...(options.headers || {}),
    },
  });
  const text = await res.text();
  let data;
  try {
    data = JSON.parse(text);
  } catch {
    data = { raw: text };
  }
  if (!res.ok) throw new Error(data.error || text || res.statusText);
  return data;
}

document.getElementById('btnSession').onclick = async () => {
  const t = document.getElementById('token').value.trim() || 'dev:school_admin_1';
  localStorage.setItem('pa_token', t);
  document.getElementById('token').value = t;
  try {
    const session = await api('/api/v1/auth/session', {
      method: 'POST',
      body: JSON.stringify({
        name: document.getElementById('adminName').value.trim(),
        phone: document.getElementById('adminPhone').value.trim(),
        role: 'parent',
      }),
    });
    document.getElementById('sessionStatus').textContent =
      `Sesi OK · userId=${session.userId}`;
  } catch (e) {
    document.getElementById('sessionStatus').textContent = String(e.message || e);
  }
};

document.getElementById('btnCreateSchool').onclick = async () => {
  try {
    const school = await api('/api/v1/schools', {
      method: 'POST',
      body: JSON.stringify({
        name: document.getElementById('schoolName').value.trim(),
        panicContactPhone: document.getElementById('panicPhone').value.trim(),
        panicContactName: document.getElementById('panicName').value.trim(),
        lat: -6.2,
        lng: 106.816,
        radiusM: 200,
      }),
    });
    document.getElementById('schoolId').value = school.id;
    alert(`Sekolah dibuat: ${school.id}`);
    document.getElementById('btnLoadSchools').click();
  } catch (e) {
    alert(String(e.message || e));
  }
};

document.getElementById('btnLoadSchools').onclick = async () => {
  try {
    const data = await api('/api/v1/schools');
    const ul = document.getElementById('schoolList');
    ul.innerHTML = '';
    for (const s of data.schools || []) {
      const li = document.createElement('li');
      li.textContent = `${s.name} · ${s.id}`;
      li.onclick = () => {
        document.getElementById('schoolId').value = s.id;
      };
      ul.appendChild(li);
    }
  } catch (e) {
    alert(String(e.message || e));
  }
};

document.getElementById('btnAddRoster').onclick = async () => {
  const schoolId = document.getElementById('schoolId').value.trim();
  const childId = document.getElementById('childId').value.trim();
  try {
    await api(`/api/v1/schools/${schoolId}/roster`, {
      method: 'POST',
      body: JSON.stringify({ childId }),
    });
    alert('Roster ditambahkan');
    document.getElementById('btnLoadRoster').click();
  } catch (e) {
    alert(String(e.message || e));
  }
};

document.getElementById('btnLoadRoster').onclick = async () => {
  const schoolId = document.getElementById('schoolId').value.trim();
  try {
    const data = await api(`/api/v1/schools/${schoolId}/roster`);
    document.getElementById('rosterOut').textContent = JSON.stringify(data, null, 2);
  } catch (e) {
    document.getElementById('rosterOut').textContent = String(e.message || e);
  }
};

document.getElementById('btnNotify').onclick = async () => {
  const schoolId = document.getElementById('schoolId').value.trim();
  try {
    await api(`/api/v1/schools/${schoolId}/notify-panic`, {
      method: 'POST',
      body: JSON.stringify({}),
    });
    alert('SMS kontak panik dikirim (atau di-log di konsol API)');
  } catch (e) {
    alert(String(e.message || e));
  }
};

const saved = localStorage.getItem('pa_token');
if (saved) document.getElementById('token').value = saved;
