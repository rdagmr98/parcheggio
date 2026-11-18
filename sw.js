self.addEventListener('push', e => {
  const d = e.data.json();
  e.waitUntil(self.registration.showNotification(d.title, { body: d.body, tag: 'park', data: d.url }));
});
self.addEventListener('notificationclick', e => {
  e.notification.close();
  e.waitUntil(clients.openWindow(e.notification.data));
});
