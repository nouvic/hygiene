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

const themeButton = document.createElement('button');
themeButton.type = 'button';
themeButton.className = 'theme-toggle';
document.body.append(themeButton);

const themeMeta = document.querySelector('meta[name="theme-color"]');
const systemTheme = window.matchMedia('(prefers-color-scheme: dark)');

function currentTheme() {
  return document.documentElement.dataset.theme || (systemTheme.matches ? 'dark' : 'light');
}

function renderTheme(theme) {
  const dark = theme === 'dark';
  document.documentElement.dataset.theme = theme;
  document.documentElement.style.colorScheme = theme;
  themeButton.textContent = dark ? '☀️ Light' : '🌙 Dark';
  themeButton.setAttribute('aria-label', `Switch to ${dark ? 'light' : 'dark'} mode`);
  themeButton.setAttribute('aria-pressed', String(dark));
  themeButton.title = `Switch to ${dark ? 'light' : 'dark'} mode`;
  if (themeMeta) themeMeta.content = dark ? '#11130f' : '#171815';
}

renderTheme(currentTheme());

themeButton.addEventListener('click', () => {
  const nextTheme = currentTheme() === 'dark' ? 'light' : 'dark';
  try { localStorage.setItem('hygiene-theme', nextTheme); } catch (_) {}
  renderTheme(nextTheme);
});

systemTheme.addEventListener('change', (event) => {
  try {
    if (localStorage.getItem('hygiene-theme')) return;
  } catch (_) {}
  renderTheme(event.matches ? 'dark' : 'light');
});
