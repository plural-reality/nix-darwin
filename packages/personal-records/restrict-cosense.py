from pathlib import Path
p = Path('node_modules/@helpfeel/cosense-cli/src/lib/request.ts')
s = p.read_text()
needle = 'export const requestJson = async ('
assert s.count(needle) == 1
s = s.replace(needle, '''export const requestJson = (url: string, options?: RequestOptions): Promise<unknown> => {
  const target = new URL(url);
  const allowed = target.username === '' && target.password === '' && (
    target.origin === 'https://scrapbox.io' || (
      target.origin === 'https://api.gyazo.com' && target.pathname === '/api/oembed' &&
      !options?.credential && (!options?.method || options.method === 'GET')
    )
  );
  return allowed ? requestJsonAllowed(url, options) : Promise.reject(new Error('Cosense request origin is not allowed'));
};
const requestJsonAllowed = async (''', 1)
needle = 'const init: RequestInit = { method, headers };'
assert s.count(needle) == 1
s = s.replace(needle, "const init: RequestInit = { method, headers, redirect: 'error' };")
needle = '${params.body.slice(0, 500)}'
assert s.count(needle) == 1
s = s.replace(needle, '[response body omitted]')
p.write_text(s)
