# Repository guidelines

This package binds principals on Hummingbird. Read this before changing anything.

## What this package is

- One product, `AuthenticationHummingbird`: `BearerAuthenticationMiddleware`, a
  `RouterMiddleware` over any `AuthRequestContext`, taking any `Authenticator<String, Identity>`
  from swift-authentication.
- It sets the identity in both places Hummingbird code reads it: the request context's
  `identity`, for `IsAuthenticatedMiddleware` and handlers, and the `ServiceContext` principal,
  for everything downstream. Keep both in step.
- The three answers are honoured exactly: an identity binds, `nil` continues unbound, a throw is
  `HTTPError(.unauthorized)`. A request with no token never reaches the authenticator.
- The `Authorization` header is read with HummingbirdAuth's own `headers.bearer`; this package
  parses nothing itself.

## What does not belong here

- Authorization. Requiring a caller is `IsAuthenticatedMiddleware`'s job on the routes that
  need one; roles and permissions are the application's.
- A credential format. Proofs are swift-authentication-jwt and swift-authentication-x509.
- Client certificates. Hummingbird does not expose the peer certificate to middleware; that is
  the gRPC package's concern.

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
