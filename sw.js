// Push dal tablet dell'A3 a quadro spento: {lat, lon, acc, time}. L'ultima posizione resta in cache per la pagina.
const maps = p => `https://www.google.com/maps/search/?api=1&query=${p.lat},${p.lon}`;
self.addEventListener('push', e => {
  const p = e.data.json();
  const ora = new Date(p.time).toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit' });
  e.waitUntil(Promise.all([
    caches.open('park').then(c => c.put('park', new Response(JSON.stringify(p)))),
    self.registration.showNotification('Auto parcheggiata',
      { body: `Alle ${ora}, precisione ${p.acc} m. Tocca per Maps.`, tag: 'park', icon: 'icon.png', data: maps(p) }),
  ]));
});
self.addEventListener('notificationclick', e => {
  e.notification.close();
  e.waitUntil(clients.openWindow(e.notification.data));
});
self.addEventListener('fetch', () => {}); // installabile come app
