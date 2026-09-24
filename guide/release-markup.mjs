const start = '<!-- RELEASE_DOWNLOADS_START -->';
const end = '<!-- RELEASE_DOWNLOADS_END -->';

const platformNames = {
  'macos/universal/dmg': 'macOS universal installer',
  'ubuntu/amd64/deb': 'Ubuntu amd64 package',
  'ubuntu/arm64/deb': 'Ubuntu arm64 package',
  'nerves-rpi5/arm64/fw': 'Nerves Pi 5 appliance image',
};

function escapeHtml(value) {
  return value.replaceAll('&', '&amp;').replaceAll('"', '&quot;')
    .replaceAll('<', '&lt;').replaceAll('>', '&gt;');
}

export function installVerifiedRelease(html, manifest) {
  const begin = html.indexOf(start);
  const finish = html.indexOf(end);
  if (begin < 0 || finish < begin || html.indexOf(start, begin + start.length) >= 0 ||
      html.indexOf(end, finish + end.length) >= 0) {
    throw new Error('guide release placeholder is missing or ambiguous');
  }
  const links = manifest.artifacts.map((artifact) => {
    const name = platformNames[
      `${artifact.platform}/${artifact.architecture}/${artifact.format}`
    ];
    if (!name) throw new Error('unverified release target');
    return `<li><a href="${escapeHtml(artifact.url)}">${name}</a></li>`;
  }).join('');
  const note = `<div class="release-note release-ready"><span class="release-dot" aria-hidden="true"></span><div><h3>Verified host release ${escapeHtml(manifest.version)}</h3><p>Choose the package for your host. A frame still needs a compatible receiver and physical pairing.</p><ul class="release-links">${links}</ul></div></div>`;
  return html.slice(0, begin) + note + html.slice(finish + end.length);
}
