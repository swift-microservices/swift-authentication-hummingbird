# Repository guidelines

This package binds principals on Hummingbird. Read this before changing anything.

## What this package is

- One product, `AuthenticationHummingbird`: `BearerAuthenticationMiddleware`, a
  `RouterMiddleware` over any `AuthRequestContext`, taking any `Authenticator<String, Identity>`
  from swift-authentication.
- It sets the identity in both places Hummingbird code reads it: the request context's
  `identity`, for `IsAuthenticatedMiddleware` and handlers, and the `ServiceContext` principal,
  for everything downstream. Keep both in step.
- Authentication returns an identity or throws. An identity binds; a failure ends the request
  with `HTTPError(.unauthorized)` before the route runs. A request with no token never reaches
  the authenticator and continues anonymously.
- The `Authorization` header is read with HummingbirdAuth's own `headers.bearer`; this package
  parses nothing itself.

## Application standard

- Apply bearer middleware and user guards to user routes. Owning use cases authorize users.
- Backend RPC connections use mandatory mTLS. Forward the original user JWT only on user
  descriptors; each receiving service verifies it. User database settings follow user operations.
- Keep public, user, and internal RPC audiences separate and internal listeners private.

## What does not belong here

- Authorization. Requiring a caller is `IsAuthenticatedMiddleware`'s job on the routes that
  need one; roles and permissions are the application's.
- A credential format. swift-authentication-jwt provides user JWT verification.
- Backend transport configuration. Composition roots own mandatory mTLS, explicit CA trust,
  and certificate reloader lifecycle for outgoing service RPCs.

## Swift

- Swift 6.3, strict concurrency, `Sendable` everywhere it is meaningful.
- Tests use Swift Testing over HummingbirdTesting's router framework: a real router, the
  middleware, and a route that reports what it saw. No server is started.
- Doc comments on every public declaration; the DocC catalog is the long-form explanation.
- Format with `swift-format format --in-place --recursive Sources Tests`; the soundness check on
  every pull request runs the same rules, an API breakage check against the base branch, and
  shellcheck and yamllint.
- File headers follow the existing files: name, package, author, date.

## Releases

- Every pull request carries exactly one label: `⚠️ semver/major`, `🆕 semver/minor`,
  `🔨 semver/patch`, or `semver/none`. The label check blocks merging without one.
- Releases are GitHub Releases, created by the Auto Release workflow: run it by hand on `main`
  and it computes the next version from the labels of the pull requests merged since the last
  release, tags it, and writes the notes from `.github/release.yml`. A major bump is refused
  there and is cut by hand.
- Consumers pin by tag, never by branch or path.
