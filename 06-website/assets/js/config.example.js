/**
 * WalkEEG cloud configuration — copy from config.example.js after sam deploy.
 * Do NOT commit real values if this file contains production IDs.
 */
window.WALKEEG_CONFIG = {
  region: 'us-west-2',
  userPoolId: 'REPLACE_USER_POOL_ID',
  userPoolClientId: 'REPLACE_CLIENT_ID',
  identityPoolId: 'REPLACE_IDENTITY_POOL_ID',
  dataBucket: 'walkeeg-data-prod',
  apiBaseUrl: 'https://REPLACE_API_ID.execute-api.us-west-2.amazonaws.com/prod',
};
