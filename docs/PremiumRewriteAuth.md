# Premium Rewrite Auth

JuniorGlobe's Premium rewrite feed should not be exposed as a public unauthenticated endpoint.

This document defines the current minimum app-to-backend contract for:

- `GET /juniorglobe/v1/feed?rewrite=full&locale=...&limit=...`

## App-side requirements

The iOS app now only attempts Premium rewrite requests when both of these are configured:

- `JUNIORGLOBE_PREMIUM_REWRITE_BASE_URL`
- `JUNIORGLOBE_PREMIUM_REWRITE_BEARER_TOKEN`

When enabled, the app sends these headers:

```http
Authorization: Bearer <JUNIORGLOBE_PREMIUM_REWRITE_BEARER_TOKEN>
X-JuniorGlobe-Entitlement: premium
X-JuniorGlobe-Platform: ios
X-JuniorGlobe-Client: <JUNIORGLOBE_PREMIUM_REWRITE_CLIENT_ID or "ios-app">
```

If the bearer token is missing, the app disables Premium rewrite and falls back to the normal feed.

## Minimum backend validation

For a first secure-enough production pass, the rewrite backend should:

1. Reject requests that do not include `Authorization: Bearer ...`
2. Reject requests whose bearer token does not match the configured server secret
3. Reject requests whose `X-JuniorGlobe-Entitlement` is not `premium`
4. Apply rate limiting per IP and per client id
5. Return `401` or `403` for failed authorization

Example pseudocode:

```js
const expectedToken = process.env.JUNIORGLOBE_PREMIUM_REWRITE_BEARER_TOKEN;

function requirePremiumRewriteAuth(req, res, next) {
  const authorization = req.get("Authorization") || "";
  const entitlement = req.get("X-JuniorGlobe-Entitlement") || "";
  const clientID = req.get("X-JuniorGlobe-Client") || "unknown";

  if (!authorization.startsWith("Bearer ")) {
    return res.status(401).json({ error: "missing_bearer_token" });
  }

  const token = authorization.slice("Bearer ".length).trim();

  if (!expectedToken || token !== expectedToken) {
    return res.status(403).json({ error: "invalid_bearer_token" });
  }

  if (entitlement !== "premium") {
    return res.status(403).json({ error: "premium_entitlement_required" });
  }

  req.juniorGlobeClientID = clientID;
  next();
}
```

## Stronger v2 recommendation

The static bearer token approach is only a minimum barrier. It protects against a casual public endpoint, but it is not a perfect anti-abuse system because a mobile app secret can be extracted.

For a stronger v2 design:

1. The app authenticates a subscriber session with your backend
2. Your backend verifies Premium entitlement server-side
3. Your backend issues a short-lived signed token
4. The app uses that short-lived token for `rewrite=full`
5. The rewrite service accepts only short-lived signed tokens

That stronger design is the version to use if Premium rewrite becomes a significant paid feature or a frequent abuse target.
