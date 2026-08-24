const form = document.querySelector('#reset-form');
const password = document.querySelector('#password');
const confirmPassword = document.querySelector('#confirm-password');
const submit = document.querySelector('#submit');
const status = document.querySelector('#status');
const token = new URLSearchParams(window.location.search).get('token') ?? '';

if (!token) {
  form.hidden = true;
  showStatus('This reset link is incomplete. Request a new HDC reset link.', true);
}

form.addEventListener('submit', async (event) => {
  event.preventDefault();
  if (password.value !== confirmPassword.value) {
    showStatus('The passwords do not match.', true);
    return;
  }
  submit.disabled = true;
  showStatus('Resetting your password…');
  try {
    const response = await fetch('/api/auth/password-reset/confirm', {
      method: 'POST',
      headers: { 'content-type': 'application/json', accept: 'application/json' },
      body: JSON.stringify({ token, password: password.value }),
    });
    const result = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw new Error(
        typeof result.message === 'string'
          ? result.message
          : 'This reset link is invalid, expired, or already used.',
      );
    }
    form.hidden = true;
    showStatus(
      'Your password was changed and prior sessions were signed out. You can now return to HDC and sign in.',
      false,
      true,
    );
  } catch (error) {
    showStatus(error instanceof Error ? error.message : 'Password reset failed.', true);
    submit.disabled = false;
  }
});

function showStatus(message, isError = false, isSuccess = false) {
  status.textContent = message;
  status.className = `status${isError ? ' error' : isSuccess ? ' success' : ''}`;
}
