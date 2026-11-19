// Pruebas de seguridad del prototipo (design/prototipo.html) con Playwright.
// Uso:  node tests/seguridad_prototipo.js
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), os = require('os');

const HTML = fs.readFileSync(path.join(__dirname, '..', 'design', 'prototipo.html'), 'utf8');
const PAYLOADS = ['<img src=x onerror="window.__xss=(window.__xss||0)+1">', '"><svg onload="window.__xss=(window.__xss||0)+1">', "'><script>window.__xss=1</script>"];
const res = []; let fallos = 0;
const caso = (sec, desc, pasa, det='') => { res.push({sec, desc, pasa, det}); if (!pasa) fallos++; };

(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1200, height: 900 } });
  const errores = []; p.on('pageerror', e => errores.push(e.message));
  const cargar = async () => { await p.goto('about:blank'); await p.setContent('<!doctype html><html><head><meta charset="utf-8"><style>[hidden]{display:none!important}</style></head><body>' + HTML + '</body></html>', { waitUntil: 'load' }); await p.waitForTimeout(400);
    await p.evaluate(() => { Object.keys(ROLES).forEach(r => { S.legal.aceptaciones[r] = {version: LEGAL.version, fecha: '2026-11-19T10:00', items: {}}; }); render(true); }); };
  const c = async s => { await p.click(s, { timeout: 8000 }); await p.waitForTimeout(80); };
  const xss = () => p.evaluate(() => (window.__xss || 0) + document.querySelectorAll('img[src="x"], #sheet svg[onload], #view svg[onload]').length);
  const rol = async r => p.evaluate(r => { ui.rol = r; ui.view = null; ui.tab = 'inicio'; ui.anaSeg = (r==='entrenador'||r==='staff') ? 'temporada' : 'yo'; ui.eqSeg = r==='padre' ? 'sedes' : 'plantel'; render(true); }, r);
  const recorrer = async () => { for (const t of ['inicio','calendario','competicion','analisis','equipo']) { await c(`[data-tab="${t}"]`); }
    await p.evaluate(() => { for (const s of ['plantel','rivales','sedes']) { ui.eqSeg = s; render(); } for (const s of ['temporada','jugadores','rivales']) { ui.anaSeg = s; render(); } });
    for (const pid of ['p13','p0','p1']) { await p.evaluate(id => { ui.view = {name:'partido', id}; for (const t of ['eventos','convocatoria','cancha','stats','sede']) { ui.pTab = t; render(); } ui.view = null; render(); }, pid); } };

  // ---------- 1. Inyección de código (XSS) en todos los campos de texto ----------
  const S1 = '1 · Inyección de código (XSS) en campos de texto';
  await cargar();
  for (const [i, pl] of PAYLOADS.entries()) {
    await c('[data-tab="equipo"]'); await p.evaluate(() => { ui.eqSeg = 'plantel'; render(); }); await c('[data-act="eq-add"]'); await p.fill('#f-nom', pl); await p.fill('#f-dor', String(40 + i)); await c('.sheet button[type=submit]');
    await p.evaluate(() => { ui.eqSeg = 'rivales'; render(); }); await c('[data-act="eq-add"]'); await p.fill('#f-rn', pl); await p.fill('#f-rc', pl.slice(0,3)); await c('.sheet button[type=submit]');
    await p.evaluate(() => { ui.eqSeg = 'sedes'; render(); }); await c('[data-act="eq-add"]'); await p.fill('#f-sn', pl); await p.fill('#f-sd', pl); await p.fill('#f-sno', pl); await c('.sheet button[type=submit]');
    await c('[data-act="edit-equipo"]'); await p.fill('#f-en', pl); await c('.sheet button[type=submit]');
    await c('[data-tab="competicion"]'); await c('[data-act="comp-nueva"]'); await p.fill('#f-cn', pl); await p.fill('#f-ct', pl); await c('.sheet button[type=submit]');
    await c('#fab'); await p.fill('#f-jor', 'J99'); await p.fill('#f-notas', pl); await p.selectOption('#f-comp', 'liga'); await c('.sheet button[type=submit]');
    await c('[data-act="iniciar"]');
    await c('[data-act="back"]');
  }
  await recorrer();
  for (const r of ['staff','jugador','padre']) { await rol(r); await recorrer(); }
  caso(S1, `Ningún payload se ejecutó en ${PAYLOADS.length} variantes × 11 campos × 4 roles`, (await xss()) === 0, `ejecuciones: ${await xss()}`);

  // ---------- 2. Enlaces y colores manipulados ----------
  const S2 = '2 · Enlaces y colores manipulados';
  await cargar();
  const probarMaps = async url => { await c('[data-tab="equipo"]'); await p.evaluate(() => { ui.eqSeg = 'sedes'; render(); }); await c('[data-act="eq-add"]');
    await p.fill('#f-sn', 'Prueba'); await p.fill('#f-murl', url); await c('.sheet button[type=submit]');
    const err = await p.evaluate(() => document.querySelector('#ferr')?.textContent || ''); await p.evaluate(() => closeSheet()); return err.length > 0; };
  for (const url of ['javascript:window.__xss=1', 'https://www.google.com.evil.example/maps', 'https://evil.example/?google.com/maps', 'data:text/html,<script>1</script>', 'https://maps.app.goo.gl.evil.example/abc'])
    caso(S2, `Rechaza enlace falso de Maps: ${url}`, await probarMaps(url));
  for (const url of ['https://maps.app.goo.gl/AbC123', 'https://www.google.com/maps/place/X/@32.5,-117.0,17z', 'https://www.google.com.mx/maps?q=cancha'])
    caso(S2, `Acepta enlace real de Maps: ${url}`, !(await probarMaps(url)));
  const colorMalo = 'red;background-image:url(https://evil.example/x)';
  await p.evaluate(() => { ui.eqSeg = 'rivales'; render(); }); await c('[data-act="eq-add"]'); await p.fill('#f-rn', 'Color raro');
  await p.evaluate(v => { const i = document.querySelector('#f-rcol'); i.type = 'text'; i.value = v; }, colorMalo); await c('.sheet button[type=submit]');
  const guardado = await p.evaluate(() => S.rivales.find(r => r.nombre === 'Color raro')?.color);
  caso(S2, 'Un color manipulado no se guarda tal cual (evita inyección de CSS)', guardado !== colorMalo, `guardado: ${guardado}`);
  await p.evaluate(() => closeSheet());
  await c('[data-act="eq-add"]'); await p.evaluate(() => { document.querySelector('#f-rn').removeAttribute('maxlength'); }); await p.fill('#f-rn', 'A'.repeat(5000)); await c('.sheet button[type=submit]');
  const largo = await p.evaluate(() => Math.max(...S.rivales.map(r => r.nombre.length)));
  caso(S2, 'Textos gigantes se recortan (5 000 caracteres)', largo <= 80, `largo guardado: ${largo}`);
  await p.evaluate(() => closeSheet());

  // ---------- 3. Imagen de escudo con código ----------
  const S3 = '3 · Imagen de escudo con código escondido';
  const svg = path.join(os.tmpdir(), 'escudo_malicioso.svg');
  fs.writeFileSync(svg, '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10" onload="window.__xss=1"><script>window.__xss=1</script><rect width="10" height="10" fill="red"/></svg>');
  await c('[data-act="edit-equipo"]'); await p.setInputFiles('#f-escudo', svg); await p.waitForTimeout(500); await c('.sheet button[type=submit]');
  const esc = await p.evaluate(() => (S.equipo.escudo || '').slice(0, 22));
  caso(S3, 'El SVG no ejecuta código y se guarda como imagen PNG', (await xss()) === 0 && (esc === '' || esc.startsWith('data:image/png')), `guardado como: ${esc || '(rechazado)'}`);

  // ---------- 4. Forzar acciones prohibidas ----------
  const S4 = '4 · Forzar acciones y formularios prohibidos por rol';
  for (const r of ['jugador', 'padre', 'staff']) {
    await cargar(); await rol(r);
    const prohibidas = await p.evaluate(() => Object.entries(ACT_PERM).filter(([, k]) => !can(k)).map(([a]) => a));
    const antes = await p.evaluate(() => JSON.stringify(S));
    for (const a of prohibidas) await p.evaluate(a => { const btn = document.createElement('button'); btn.dataset.act = a; btn.dataset.id = 'p13'; btn.dataset.c = 'liga'; btn.dataset.r = 'Cuartos'; btn.dataset.i = '1'; btn.dataset.j = 'j1'; btn.dataset.v = 'NO'; btn.dataset.e = ''; document.body.appendChild(btn); btn.click(); btn.remove(); closeSheet(); }, a);
    const forms = await p.evaluate(() => Object.entries(FORM_PERM).filter(([, k]) => !can(k)).map(([f]) => f));
    for (const f of forms) await p.evaluate(f => { const fm = document.createElement('form'); fm.dataset.form = f; fm.dataset.id = 'p13'; fm.dataset.c = 'liga';
      for (const [n, v] of Object.entries({nombre:'Hack', gf:'9', gc:'0', dorsal:'77', pos:'DEL', min:'5', tipo:'GOL', rival:'0', jugadorId:'j1', g0:'99', clasifican:'1', dia:'2026-12-01', hora:'10:00', rivalId:'av', comp:'liga', local:'1', jornada:'X', notas:'', corto:'HK', color:'#000000', direccion:'', cancha:'', superficie:'Natural', modalidad:'F7', mapsUrl:'', temporada:'' })) { const i = document.createElement('input'); i.name = n; i.value = v; fm.appendChild(i); }
      const err = document.createElement('div'); err.id = 'ferr'; fm.appendChild(err); document.body.appendChild(fm); fm.requestSubmit(); fm.remove(); closeSheet(); }, f);
    const despues = await p.evaluate(() => JSON.stringify(S));
    caso(S4, `${r}: ${prohibidas.length} acciones y ${forms.length} formularios prohibidos no cambian ningún dato`, antes === despues);
  }

  // ---------- 5. Lo que ve un padre (decisiones de producto del 19 nov 2026) ----------
  const S5 = '5 · Lo que ve un padre';
  await cargar(); await rol('padre');
  const otros = await p.evaluate(() => S.jugadores.filter(j => j.id !== ROLES.padre.jugadorId).map(j => j.nombre.split(' ').slice(-1)[0]));
  const ver = async (fn) => p.evaluate(fn);
  const analisis = await ver(() => { ui.view = null; ui.tab = 'analisis'; ui.anaSeg = 'equipo'; render(); return document.querySelector('#view').textContent; });
  caso(S5, 'No ve la tabla de goleadores', !/Goleadores/.test(analisis) && !otros.some(n => analisis.includes(n)));
  const conv = await ver(() => { ui.view = {name:'partido', id:'p13'}; ui.pTab = 'convocatoria'; render(); return document.querySelector('#view').textContent; });
  caso(S5, 'No ve las respuestas de convocatoria de otros', !otros.some(n => conv.includes(n)));
  const cancha = await ver(() => { ui.view = {name:'partido', id:'p13'}; ui.pTab = 'cancha'; render(); return document.querySelector('#view').textContent; });
  caso(S5, 'Sí ve los nombres en la alineación publicada', otros.some(n => cancha.includes(n)));
  const equipo = await ver(() => { ui.view = null; ui.tab = 'equipo'; ui.eqSeg = 'plantel'; render(); return document.querySelector('#view').textContent; });
  caso(S5, 'Sí ve el plantel (nombre, dorsal, posición)', otros.some(n => equipo.includes(n)));
  caso(S5, 'No ve Miembros y accesos ni el plan', !/Miembros y accesos/.test(equipo) && !/\$59/.test(equipo));
  const tipos = await ver(() => { ui.view = {name:'partido', id:'p13'}; render(); const f = (formEvento('p13'), document.querySelector('#sheet').textContent); closeSheet(); return f; });
  caso(S5, 'El formulario de eventos ya no ofrece lesiones', !/Lesi/.test(tipos));

  // ---------- 6. Términos e invitaciones ----------
  const S6 = '6 · Términos y credenciales';
  await p.goto('about:blank'); await p.setContent('<!doctype html><html><head><meta charset="utf-8"><style>[hidden]{display:none!important}</style></head><body>' + HTML + '</body></html>', { waitUntil: 'load' }); await p.waitForTimeout(400);
  caso(S6, 'Sin aceptar términos no se puede entrar a la app', await p.evaluate(() => !!document.querySelector('.onb') && !document.querySelector('[data-tab]')));
  const antesT = await p.evaluate(() => JSON.stringify(S));
  await p.evaluate(() => { for (const a of ['tab','invitar','premium-confirmar','nuevo-partido']) { const b = document.createElement('button'); b.dataset.act = a; b.dataset.tab = 'analisis'; document.body.appendChild(b); b.click(); b.remove(); } });
  caso(S6, 'Forzar acciones antes de aceptar no hace nada', antesT === await p.evaluate(() => JSON.stringify(S)) && await p.evaluate(() => !!document.querySelector('.onb')));
  await p.evaluate(() => { const f = document.querySelector('form[data-form="aceptar"]'); f.requestSubmit(); });
  caso(S6, 'Enviar el formulario sin casillas no registra aceptación', await p.evaluate(() => !S.legal.aceptaciones.entrenador));
  await p.evaluate(() => { Object.keys(ROLES).forEach(r => { S.legal.aceptaciones[r] = {version: LEGAL.version, fecha: 'x', items: {}}; }); render(true); });
  for (const r of ['staff','jugador','padre']) { await rol(r);
    const nInv = await p.evaluate(() => S.acc.invitaciones.length + S.acc.miembros.filter(m => m.estado === 'activo').length);
    await p.evaluate(() => { const fm = document.createElement('form'); fm.dataset.form = 'invitar'; for (const [n, v] of Object.entries({rol:'staff', para:'Intruso', horas:'168'})) { const i = document.createElement('input'); i.name = n; i.value = v; fm.appendChild(i); } const e = document.createElement('div'); e.id = 'ferr'; fm.appendChild(e); document.body.appendChild(fm); fm.requestSubmit(); fm.remove();
      const id = S.acc.miembros.find(m => m.estado === 'por_aprobar')?.id; for (const a of ['aprobar-miembro','quitar-miembro','do-quitar-miembro']) { const b = document.createElement('button'); b.dataset.act = a; b.dataset.id = id || 'm2'; document.body.appendChild(b); b.click(); b.remove(); } closeSheet(); });
    await p.waitForTimeout(150);
    caso(S6, `${r}: no puede crear invitaciones, aprobar ni quitar accesos`, nInv === await p.evaluate(() => S.acc.invitaciones.length + S.acc.miembros.filter(m => m.estado === 'activo').length)); }
  await rol('entrenador');
  await p.evaluate(() => { ui.view = {name:'miembros'}; render(); }); await c('[data-act="invitar"]'); await c('label:has(input[name=rol][value=jugador])'); await p.selectOption('#f-ij', 'j10'); await p.fill('#f-ipara', 'Duplicado'); await c('.sheet button[type=submit]');
  caso(S6, 'No deja invitar a un jugador que ya tiene cuenta', /ya tiene cuenta/.test(await p.textContent('#ferr')));
  await p.selectOption('#f-ij', 'j14'); await c('.sheet button[type=submit]'); await p.waitForTimeout(400);
  const code = await p.textContent('.code'); await p.evaluate(() => closeSheet());
  const inv = await p.evaluate(c => { const i = S.acc.invitaciones.at(-1); return {hashOk: /^[0-9a-f]{64}$/.test(i.hash), sinCodigo: !JSON.stringify({...i, codigoDemo:undefined}).includes(c)}; }, code);
  caso(S6, 'Se guarda solo el hash del código (formato FUT-XXXXX-XXXXX, sin O/0/I/1)', /^FUT-[A-HJ-NP-Z2-9]{5}-[A-HJ-NP-Z2-9]{5}$/.test(code) && inv.hashOk && inv.sinCodigo, code);
  await p.evaluate(() => hojaCanje()); for (let k = 0; k < 5; k++) { await p.fill('#f-code', 'FUT-ZZZZZ-ZZZZZ'); await p.fill('#f-cnom', 'X'); await c('.sheet button[type=submit]'); await p.waitForTimeout(80); }
  await p.evaluate(() => { closeSheet(); hojaCanje(); }); await p.fill('#f-code', code); await p.fill('#f-cnom', 'Bloqueado'); await p.evaluate(() => document.querySelector('.sheet button[type=submit]').disabled = false); await c('.sheet button[type=submit]'); await p.waitForTimeout(200);
  caso(S6, 'Tras 5 intentos fallidos se bloquea, aun con el código correcto', /Demasiados intentos/.test(await p.evaluate(() => document.querySelector('#ferr')?.textContent || '')) && await p.evaluate(() => S.acc.invitaciones.at(-1).estado === 'pendiente'));
  await p.evaluate(() => { S.acc.intentos = {fallidos:[], bloqueadoHasta:null}; closeSheet(); hojaCanje(); }); await p.fill('#f-code', code); await p.fill('#f-cnom', 'Pablo Ríos'); await c('.sheet button[type=submit]'); await p.waitForTimeout(250);
  const nuevo = await p.evaluate(() => S.acc.miembros.at(-1));
  caso(S6, 'Canjear deja la cuenta “por aprobar”, con el rol y jugador de la invitación', nuevo.estado === 'por_aprobar' && nuevo.rol === 'jugador' && nuevo.jugadorId === 'j14');
  await p.evaluate(() => hojaCanje()); await p.fill('#f-code', code); await p.fill('#f-cnom', 'Otro'); await c('.sheet button[type=submit]'); await p.waitForTimeout(200);
  caso(S6, 'Un código no sirve dos veces', await p.evaluate(() => S.acc.miembros.filter(m => m.persona === 'Otro').length === 0));
  await p.evaluate(() => { closeSheet(); const i = S.acc.invitaciones.find(x => x.id === 'i1'); i.expira = '2020-01-01T00:00'; hojaCanje(); }); await p.fill('#f-code', 'FUT-K7Q2M-X9PTA'); await p.fill('#f-cnom', 'Tarde'); await c('.sheet button[type=submit]'); await p.waitForTimeout(200);
  caso(S6, 'Un código vencido no sirve', await p.evaluate(() => S.acc.miembros.filter(m => m.persona === 'Tarde').length === 0));
  await p.evaluate(() => closeSheet());

  caso('7 · Estabilidad', 'Sin errores de JavaScript durante todas las pruebas', errores.length === 0, errores.slice(0,3).join(' | '));
  await b.close();
  let sec = ''; for (const r of res) { if (r.sec !== sec) { sec = r.sec; console.log('\n' + sec); } console.log(`  ${r.pasa ? '✓' : '✗'} ${r.desc}${r.det ? `  [${r.det}]` : ''}`); }
  console.log(`\n${res.length - fallos}/${res.length} pruebas pasaron.`); process.exit(fallos ? 1 : 0);
})();
