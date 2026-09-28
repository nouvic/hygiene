const copyButton = document.querySelector('[data-copy]');

if (copyButton) {
  copyButton.addEventListener('click', async () => {
    try {
      await navigator.clipboard.writeText(copyButton.dataset.copy);
      copyButton.textContent = 'Copied';
      window.setTimeout(() => { copyButton.textContent = 'Copy'; }, 1800);
    } catch {
      copyButton.textContent = 'Select text';
    }
  });
}
