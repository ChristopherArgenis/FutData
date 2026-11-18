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
  const cargar = async () => { await p.goto('about:blank'); await p.setContent('<!doctype html><html><head><meta charset="utf-8"><style>[hidden]{display:none!important}</style></head><body>' + HTML + '</body></html>', { waitUntil: 'load' }); await p.waitForTimeout(400); };
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
    await c('[data-act="iniciar"]'); await c('[data-act="nuevo-evento"]'); await c('label:has(input[value=LESION])'); await p.fill('#f-min', '50'); await p.fill('#f-det', pl); await c('.sheet button[type=submit]');
    await c('[data-act="back"]');
  }
  await recorrer();
  for (const r of ['staff','jugador','padre']) { await rol(r); await recorrer(); }
  caso(S1, `Ningún payload se ejecutó en ${PAYLOADS.length} variantes × 12 campos × 4 roles`, (await xss()) === 0, `ejecuciones: ${await xss()}`);

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

  // ---------- 5. Datos que un padre no debe ver ----------
  const S5 = '5 · Datos de otros menores visibles para un padre';
  await cargar(); await rol('padre');
  const otros = await p.evaluate(() => S.jugadores.filter(j => j.id !== ROLES.padre.jugadorId).map(j => j.nombre.split(' ').slice(-1)[0]));
  const textos = [];
  for (const t of ['inicio','calendario','competicion','analisis','equipo']) { await c(`[data-tab="${t}"]`); textos.push([t, await p.textContent('#view')]); }
  await p.evaluate(() => { ui.anaSeg = 'equipo'; render(); }); textos.push(['análisis › equipo', await p.textContent('#view')]);
  for (const pid of ['p13','p0']) for (const t of ['convocatoria','cancha','stats','sede']) if (!(pid==='p0' && t==='cancha'))  // un partido jugado no tiene pestaña Cancha
    textos.push([`partido ${pid} › ${t}`, await p.evaluate(([id, t]) => { ui.view = {name:'partido', id}; ui.pTab = t; render(); return document.querySelector('#view').textContent; }, [pid, t])]);
  const fugas = textos.flatMap(([d, txt]) => otros.filter(n => txt.includes(n)).map(n => `${n} en ${d}`));
  caso(S5, 'Ningún nombre de otro jugador aparece fuera de los eventos del partido', fugas.length === 0, fugas.slice(0, 6).join(' · '));
  const ev = await p.evaluate(() => { ui.view = {name:'partido', id:'p0'}; ui.pTab = 'eventos'; render(); return document.querySelector('#view').textContent; });
  caso(S5, 'Los goles del partido sí se ven (información pública)', otros.some(n => ev.includes(n)));

  await cargar(); await p.evaluate(() => { partido('p0').eventos.push({id:'les1', min:70, tipo:'LESION', rival:false, jugadorId:'j9', detalle:'Tobillo'}); });
  for (const r of ['padre','jugador']) { await rol(r); const t = await p.evaluate(() => { ui.view = {name:'partido', id:'p0'}; ui.pTab = 'eventos'; render(); return document.querySelector('#view').textContent; });
    caso(S5, `${r}: no ve la lesión de otro jugador (dato de salud)`, !t.includes('Tobillo') && !t.includes('Lesión')); }
  await rol('staff'); { const t = await p.evaluate(() => { ui.view = {name:'partido', id:'p0'}; ui.pTab = 'eventos'; render(); return document.querySelector('#view').textContent; });
    caso(S5, 'cuerpo técnico: sí ve la lesión', t.includes('Tobillo')); }
  caso('6 · Estabilidad', 'Sin errores de JavaScript durante todas las pruebas', errores.length === 0, errores.slice(0,3).join(' | '));
  await b.close();
  let sec = ''; for (const r of res) { if (r.sec !== sec) { sec = r.sec; console.log('\n' + sec); } console.log(`  ${r.pasa ? '✓' : '✗'} ${r.desc}${r.det ? `  [${r.det}]` : ''}`); }
  console.log(`\n${res.length - fallos}/${res.length} pruebas pasaron.`); process.exit(fallos ? 1 : 0);
})();
