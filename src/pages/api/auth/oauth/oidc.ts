import config from 'lib/config';
import Logger from 'lib/logger';
import { OAuthQuery, OAuthResponse, withOAuth } from 'lib/middleware/withOAuth';
import { withZipline } from 'lib/middleware/withZipline';
import { oidc_auth } from 'lib/oauth';
import { notNullArray } from 'lib/util';

async function handler({ code, state, host }: OAuthQuery, logger: Logger): Promise<OAuthResponse> {
  if (!config.features.oauth_registration)
    return {
      error_code: 403,
      error: 'oauth registration is disabled',
    };

  if (
    !notNullArray([
      config.oauth?.oidc_client_id,
      config.oauth?.oidc_client_secret,
      config.oauth?.oidc_authorize_url,
      config.oauth?.oidc_userinfo_url,
    ])
  ) {
    logger.error('OIDC OAuth is not configured');
    return {
      error_code: 401,
      error: 'OIDC OAuth is not configured',
    };
  }

  if (!code)
    return {
      redirect: oidc_auth.oauth_url(
        config.oauth.oidc_client_id,
        `${config.core.return_https ? 'https' : 'http'}://${host}`,
        config.oauth.oidc_authorize_url,
        state
      ),
    };

  const body = new URLSearchParams({
    code,
    client_id: config.oauth.oidc_client_id,
    client_secret: config.oauth.oidc_client_secret,
    redirect_uri: `${config.core.return_https ? 'https' : 'http'}://${host}/api/auth/oauth/oidc`,
    grant_type: 'authorization_code',
  });

  const resp = await fetch(config.oauth.oidc_token_url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body,
  });

  const text = await resp.text();
  logger.debug(`oauth ${config.oauth.oidc_token_url} -> body(${body}) resp(${text})`);

  if (!resp.ok) return { error: 'invalid request' };

  const json = JSON.parse(text);

  if (!json.access_token) return { error: 'no access_token in response' };

  const userJson = await oidc_auth.oauth_user(json.access_token, config.oauth.oidc_userinfo_url);
  if (!userJson) return { error: 'invalid user request' };

  return {
    username: userJson.preferred_username,
    user_id: userJson.sub,
    access_token: json.access_token,
    refresh_token: json.refresh_token,
  };
}

export default withZipline(withOAuth('oidc', handler));
