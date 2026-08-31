'use strict';

(() => {
  const startup = document.getElementById('hdc-startup');
  const message = document.getElementById('hdc-startup-message');
  const recover = document.getElementById('hdc-startup-recover');
  const detail = document.getElementById('hdc-startup-detail');

  if (!startup || !message || !recover || !detail) return;

  let finished = false;
  let startupTimer;

  const revealRecovery = (text) => {
    if (finished) return;
    message.textContent = text;
    recover.hidden = false;
    detail.hidden = false;
  };

  const finish = () => {
    if (finished) return;
    finished = true;
    window.clearTimeout(startupTimer);
    startup.setAttribute('aria-busy', 'false');
    startup.dataset.state = 'hidden';
    window.setTimeout(() => startup.remove(), 220);
  };

  window.addEventListener('flutter-first-frame', finish, { once: true });

  window.addEventListener(
    'error',
    (event) => {
      if (finished) return;
      const source = event.target;
      if (source instanceof HTMLScriptElement) {
        revealRecovery('Build 23 could not finish loading.');
      }
    },
    true,
  );

  window.addEventListener('unhandledrejection', () => {
    if (!document.querySelector('flutter-view')) {
      revealRecovery('Build 23 could not finish loading.');
    }
  });

  startupTimer = window.setTimeout(() => {
    revealRecovery('Loading is taking longer than expected.');
  }, 15000);

  recover.addEventListener('click', async () => {
    recover.disabled = true;
    message.textContent = 'Refreshing the latest Build 23 files…';

    try {
      if ('serviceWorker' in navigator) {
        const registrations = await navigator.serviceWorker.getRegistrations();
        await Promise.all(
          registrations.map((registration) => registration.unregister()),
        );
      }

      if ('caches' in window) {
        const cacheNames = await caches.keys();
        await Promise.all(cacheNames.map((cacheName) => caches.delete(cacheName)));
      }
    } catch (error) {
      console.warn('HDC startup cache recovery was incomplete.', error);
    }

    const refreshUrl = new URL(window.location.href);
    refreshUrl.searchParams.set('hdc_refresh', Date.now().toString());
    window.location.replace(refreshUrl.toString());
  });
})();
