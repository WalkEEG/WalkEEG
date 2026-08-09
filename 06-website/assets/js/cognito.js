/**
 * Cognito authentication + Identity Pool credentials (vanilla JS).
 */
const WalkEEGAuth = (() => {
  const cfg = () => window.WALKEEG_CONFIG;
  const idpEndpoint = () =>
    `https://cognito-idp.${cfg().region}.amazonaws.com/`;
  const identityEndpoint = () =>
    `https://cognito-identity.${cfg().region}.amazonaws.com/`;
  const providerKey = () =>
    `cognito-idp.${cfg().region}.amazonaws.com/${cfg().userPoolId}`;

  async function cognitoRequest(target, body) {
    const res = await fetch(idpEndpoint(), {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-amz-json-1.1',
        'X-Amz-Target': target,
      },
      body: JSON.stringify(body),
    });
    const data = await res.json();
    if (!res.ok) {
      const msg = data.message || data.__type || 'Cognito error';
      throw new Error(msg);
    }
    return data;
  }

  async function identityRequest(target, body) {
    const res = await fetch(identityEndpoint(), {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-amz-json-1.1',
        'X-Amz-Target': target,
      },
      body: JSON.stringify(body),
    });
    const data = await res.json();
    if (!res.ok) {
      const msg = data.message || data.__type || 'Identity error';
      throw new Error(msg);
    }
    return data;
  }

  function saveSession(tokens, user) {
    localStorage.setItem('walkeeg_id_token', tokens.idToken);
    localStorage.setItem('walkeeg_access_token', tokens.accessToken);
    localStorage.setItem('walkeeg_refresh_token', tokens.refreshToken || '');
    localStorage.setItem('walkeeg_token', tokens.idToken);
    localStorage.setItem('walkeeg_user', JSON.stringify(user));
    if (tokens.identityId) {
      localStorage.setItem('walkeeg_identity_id', tokens.identityId);
    }
  }

  function clearSession() {
    [
      'walkeeg_id_token',
      'walkeeg_access_token',
      'walkeeg_refresh_token',
      'walkeeg_token',
      'walkeeg_user',
      'walkeeg_identity_id',
    ].forEach((k) => localStorage.removeItem(k));
  }

  function getIdToken() {
    return localStorage.getItem('walkeeg_id_token');
  }

  function getIdentityId() {
    return localStorage.getItem('walkeeg_identity_id');
  }

  async function getIdentityIdFromPool(idToken) {
    const cached = getIdentityId();
    if (cached) return cached;
    const logins = { [providerKey()]: idToken };
    const data = await identityRequest('AWSCognitoIdentityService.GetId', {
      IdentityPoolId: cfg().identityPoolId,
      Logins: logins,
    });
    localStorage.setItem('walkeeg_identity_id', data.IdentityId);
    return data.IdentityId;
  }

  async function getCredentials(idToken) {
    const identityId = await getIdentityIdFromPool(idToken);
    const logins = { [providerKey()]: idToken };
    const data = await identityRequest(
      'AWSCognitoIdentityService.GetCredentialsForIdentity',
      { IdentityId: identityId, Logins: logins },
    );
    return {
      identityId,
      credentials: data.Credentials,
    };
  }

  async function login(email, password) {
    const data = await cognitoRequest(
      'AWSCognitoIdentityProviderService.InitiateAuth',
      {
        AuthFlow: 'USER_PASSWORD_AUTH',
        ClientId: cfg().userPoolClientId,
        AuthParameters: { USERNAME: email, PASSWORD: password },
      },
    );
    const ar = data.AuthenticationResult;
    const idToken = ar.IdToken;
    const { identityId } = await getCredentials(idToken);
    const payload = JSON.parse(atob(idToken.split('.')[1]));
    const user = {
      id: payload.sub,
      email: payload.email || email,
      name: payload.name || email.split('@')[0],
      identityId,
    };
    saveSession(
      {
        idToken,
        accessToken: ar.AccessToken,
        refreshToken: ar.RefreshToken,
        identityId,
      },
      user,
    );
    return user;
  }

  /**
   * Sign up only — does not log in. Caller should show confirmation UI.
   * Returns Cognito SignUp response (UserConfirmed may be true for some pools).
   */
  async function register(name, email, password) {
    return cognitoRequest('AWSCognitoIdentityProviderService.SignUp', {
      ClientId: cfg().userPoolClientId,
      Username: email,
      Password: password,
      UserAttributes: [
        { Name: 'email', Value: email },
        { Name: 'name', Value: name },
      ],
    });
  }

  async function confirmSignUp(email, code) {
    await cognitoRequest('AWSCognitoIdentityProviderService.ConfirmSignUp', {
      ClientId: cfg().userPoolClientId,
      Username: email,
      ConfirmationCode: code.trim(),
    });
  }

  async function resendConfirmationCode(email) {
    await cognitoRequest(
      'AWSCognitoIdentityProviderService.ResendConfirmationCode',
      {
        ClientId: cfg().userPoolClientId,
        Username: email,
      },
    );
  }

  function logout() {
    clearSession();
  }

  function isConfigured() {
    const c = cfg() || {};
    return !!(
      c.userPoolId &&
      !String(c.userPoolId).startsWith('REPLACE') &&
      c.identityPoolId &&
      !String(c.identityPoolId).startsWith('REPLACE') &&
      c.userPoolClientId &&
      !String(c.userPoolClientId).startsWith('REPLACE') &&
      c.apiBaseUrl &&
      !String(c.apiBaseUrl).includes('REPLACE')
    );
  }

  function isUserNotConfirmedError(err) {
    const msg = (err && err.message) || String(err || '');
    return /not confirmed|UserNotConfirmedException/i.test(msg);
  }

  return {
    login,
    register,
    confirmSignUp,
    resendConfirmationCode,
    logout,
    getIdToken,
    getIdentityId,
    getCredentials,
    isConfigured,
    clearSession,
    isUserNotConfirmedError,
  };
})();

window.WalkEEGAuth = WalkEEGAuth;
