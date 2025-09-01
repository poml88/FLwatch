
(() => {
  const KEY = 'flwatch-theme';
  const mq  = window.matchMedia('(prefers-color-scheme: dark)');

  const applyTheme = (mode) => {
    // Body might not exist yet if script runs very early
    const body = document.body;
    if (!body) return;

    body.classList.remove('theme-dark', 'theme-light');

    if (mode === 'light') {
      body.classList.add('theme-light');
      document.documentElement.style.colorScheme = 'light';
    } else if (mode === 'dark') {
      body.classList.add('theme-dark');
      document.documentElement.style.colorScheme = 'dark';
    } else {
      // auto: follow system
      if (mq.matches) {
        body.classList.add('theme-dark');
        document.documentElement.style.colorScheme = 'dark';
      } else {
        body.classList.add('theme-light');
        document.documentElement.style.colorScheme = 'light';
      }
    }
  };

  // Handle system theme changes while in "auto"
  const onSystemChange = () => {
    if ((localStorage.getItem(KEY) || 'auto') === 'auto') {
      applyTheme('auto');
    }
  };
  if (typeof mq.addEventListener === 'function') mq.addEventListener('change', onSystemChange);
  else if (typeof mq.addListener === 'function') mq.addListener(onSystemChange); // Safari fallback

  // Init once DOM is ready (or immediately if already parsed)
  const init = () => {
    const prefer = localStorage.getItem(KEY) || 'auto';
    applyTheme(prefer);

    const menuBtn  = document.getElementById('menuToggle');
    const themeBtn = document.getElementById('themeToggle');
    const side     = document.getElementById('sideMenu');
    const overlay  = document.getElementById('overlay');
    const closeBtn = document.getElementById('menuClose');
    const year     = document.getElementById('year');
    if (year) year.textContent = new Date().getFullYear();

    const openMenu = () => {
      if (!side) return;
      side.classList.add('open');
      if (overlay) overlay.hidden = false;
      side.setAttribute('aria-hidden', 'false');
      if (!side.hasAttribute('tabindex')) side.setAttribute('tabindex', '-1');
      side.focus();
    };
    const closeMenu = () => {
      if (!side) return;
      side.classList.remove('open');
      if (overlay) overlay.hidden = true;
      side.setAttribute('aria-hidden', 'true');
    };

    if (menuBtn && side)  menuBtn.addEventListener('click', openMenu);
    if (closeBtn && side) closeBtn.addEventListener('click', closeMenu);
    if (overlay)          overlay.addEventListener('click', closeMenu);
    document.addEventListener('keydown', (e) => { if (e.key === 'Escape') closeMenu(); });

    // Theme toggle: auto → dark → light → auto
    // Now only toggle dark -> light
if (themeBtn) {
  const updateBtn = (mode) => {
    themeBtn.dataset.theme = mode;
    themeBtn.title = `Theme: ${mode}`;
    themeBtn.setAttribute('aria-label', `Theme: ${mode}`);
  };

  themeBtn.addEventListener('click', (e) => {
    const stored = localStorage.getItem(KEY) || 'auto';
    let next;

    if (e.shiftKey) {
      // Shift+click = go to auto
      next = 'auto';
    } else if (stored === 'auto') {
      // From auto, switch to the *opposite* of system so it visibly changes
      next = mq.matches ? 'light' : 'dark';
    } else {
      // From explicit, flip to the other explicit
      next = (stored === 'dark') ? 'light' : 'dark';
    }

    localStorage.setItem(KEY, next);
    applyTheme(next);
    updateBtn(next);
  });

  // initialize label
  updateBtn(localStorage.getItem(KEY) || 'auto');
}


    // Generate ToC from headings h1/h2/h3
    const toc = document.getElementById('toc');
    if (toc) {
      const content = document.querySelector('.content');
      if (content) {
        const headings = content.querySelectorAll('h1, h2, h3');
        const frag = document.createDocumentFragment();
        headings.forEach(h => {
          if (!h.id) {
            const slug = h.textContent.trim().toLowerCase()
              .replace(/[^a-z0-9\u00C0-\u024f\u4e00-\u9fa5\s-]/g, '')
              .replace(/\s+/g, '-');
            h.id = slug;
          }
          const li = document.createElement('li');
          li.style.marginLeft = (h.tagName === 'H2' ? '8px' : h.tagName === 'H3' ? '16px' : '0');
          const a = document.createElement('a');
          a.href = '#' + h.id;
          a.textContent = h.textContent;
          li.appendChild(a);
          frag.appendChild(li);
        });
        toc.appendChild(frag);
      }
    }
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();

