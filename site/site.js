// The copy button needs JavaScript, so it is hidden until this runs.
document.querySelectorAll('[data-copy]').forEach((button) => {
  const source = document.querySelector(button.dataset.copy);
  const status = button.closest('.command')?.querySelector('.command__status');
  if (!source || !navigator.clipboard) return;
  button.hidden = false;
  button.addEventListener('click', async () => {
    try {
      await navigator.clipboard.writeText(source.textContent.trim());
      if (status) status.textContent = 'Copied. Paste it in a terminal.';
    } catch {
      if (status) status.textContent = 'Could not copy. Select the command and copy it.';
    }
  });
});
