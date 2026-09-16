const { expect } = require('@playwright/test');
async function submitted(page, action) {
  const response = page.waitForResponse(r => r.url().includes('/api/sessions/') && r.request().method() === 'PUT' && r.request().postDataJSON()?.final);
  await action();
  const result = await response;
  expect(result.status()).toBe(200);
  expect((await result.json()).completedAt).toBeTruthy();
  await expect(page.getByText('Vos réponses ont bien été reçues.', { exact: false })).toBeVisible();
  const local = await page.evaluate(() => JSON.parse(localStorage.getItem('matheval-participation-v1')));
  const persisted = await page.request.get('api/sessions/' + local.id, { headers: { 'X-Session-Token': local.secret } });
  expect(persisted.ok()).toBeTruthy();
  const saved = await persisted.json();
  expect(saved.snapshot).toEqual(result.request().postDataJSON().snapshot);
  return { ...saved.snapshot, events: result.request().postDataJSON().events, session: saved };
}
module.exports = { submitted };
