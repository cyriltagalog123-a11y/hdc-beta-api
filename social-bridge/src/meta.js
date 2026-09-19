const scope = [
  'pages_show_list',
  'pages_read_engagement',
  'pages_manage_posts'
];

function required(name) {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
}

function graphVersion() {
  const version = required('META_GRAPH_VERSION');
  if (!/^v\d+\.\d+$/.test(version)) {
    throw new Error('META_GRAPH_VERSION must look like vXX.X');
  }
  return version;
}

function graphUrl(path) {
  return `https://graph.facebook.com/${graphVersion()}${path}`;
}

async function parseMetaResponse(response) {
  const data = await response.json().catch(() => ({}));
  if (!response.ok || data.error) {
    const message = data?.error?.message || `Meta request failed with HTTP ${response.status}`;
    const err = new Error(message);
    err.meta = data?.error || data;
    throw err;
  }
  return data;
}

export function buildFacebookLoginUrl(state) {
  const url = new URL(`https://www.facebook.com/${graphVersion()}/dialog/oauth`);
  url.searchParams.set('client_id', required('FACEBOOK_APP_ID'));
  url.searchParams.set('redirect_uri', `${required('BASE_URL')}/auth/facebook/callback`);
  url.searchParams.set('state', state);
  url.searchParams.set('scope', scope.join(','));
  url.searchParams.set('config_id', required('FACEBOOK_LOGIN_CONFIG_ID'));
  url.searchParams.set('response_type', 'code');
  url.searchParams.set('override_default_response_type', 'true');
  return url.toString();
}

export async function exchangeCode(code) {
  const url = new URL(graphUrl('/oauth/access_token'));
  url.searchParams.set('client_id', required('FACEBOOK_APP_ID'));
  url.searchParams.set('client_secret', required('FACEBOOK_APP_SECRET'));
  url.searchParams.set('redirect_uri', `${required('BASE_URL')}/auth/facebook/callback`);
  url.searchParams.set('code', code);
  const data = await parseMetaResponse(await fetch(url));
  return data.access_token;
}

export async function exchangeForLongLivedUserToken(shortLivedToken) {
  const url = new URL(graphUrl('/oauth/access_token'));
  url.searchParams.set('grant_type', 'fb_exchange_token');
  url.searchParams.set('client_id', required('FACEBOOK_APP_ID'));
  url.searchParams.set('client_secret', required('FACEBOOK_APP_SECRET'));
  url.searchParams.set('fb_exchange_token', shortLivedToken);
  const data = await parseMetaResponse(await fetch(url));
  return data.access_token || shortLivedToken;
}

export async function listManagedPages(userAccessToken) {
  const url = new URL(graphUrl('/me/accounts'));
  url.searchParams.set('fields', 'id,name,access_token,tasks');
  url.searchParams.set('limit', '100');
  url.searchParams.set('access_token', userAccessToken);
  const data = await parseMetaResponse(await fetch(url));
  return (data.data || []).map((page) => ({
    id: page.id,
    name: page.name,
    accessToken: page.access_token,
    tasks: page.tasks || []
  }));
}

export async function publishTextPost(pageId, pageAccessToken, message) {
  const body = new URLSearchParams({ message, access_token: pageAccessToken });
  const data = await parseMetaResponse(await fetch(graphUrl(`/${encodeURIComponent(pageId)}/feed`), {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body
  }));
  return data;
}

export async function listRecentPosts(pageId, pageAccessToken, limit = 10) {
  const url = new URL(graphUrl(`/${encodeURIComponent(pageId)}/published_posts`));
  url.searchParams.set('fields', 'id,message,created_time,permalink_url');
  url.searchParams.set('limit', String(Math.min(Math.max(Number(limit) || 10, 1), 25)));
  url.searchParams.set('access_token', pageAccessToken);
  const data = await parseMetaResponse(await fetch(url));
  return data.data || [];
}
