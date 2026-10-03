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
- Use the checked-in `.swift-format`, copied exactly from apple/swift-temporal-sdk at
  `508797b5468dbc532f77c317bf9df0cb3231f5c1`: four-space indentation, 150-column lines,
  and ordered imports. Format all tracked Swift files, including `Package.swift`, and run
  `swift-format lint --strict`. Public documentation remains a repository requirement even
  though this formatter does not enforce it.
- File headers follow the existing files: name, package, author, date.

## Releases

- Every pull request carries exactly one label: `⚠️ semver/major`, `🆕 semver/minor`,
  `🔨 semver/patch`, or `semver/none`. The label check blocks merging without one.
- Releases are GitHub Releases, created by the Auto Release workflow: run it by hand on `main`
  and it computes the next version from the labels of the pull requests merged since the last
  release, tags it, and writes the notes from `.github/release.yml`. A major bump is refused
  there and is cut by hand.
- Consumers pin by tag, never by branch or path.

## Library CI profile

- This repository profile overrides general service CI and formatting defaults. Libraries
  never commit `Package.resolved`; CI resolves released dependencies from the manifest.
- PRs run soundness checks, including API compatibility, documentation, formatting, shellcheck,
  and yamllint. The docs workflow adds the DocC plugin only in its temporary checkout.
  License-header checking stays disabled because source files use the author-header convention.
- PRs, main pushes, and the weekly schedule run Linux tests on Swift 6.3 and 6.4, next/main
  snapshots, release builds, and static Linux SDK compatibility. Require supported stable
  checks in branch protection; snapshot failures remain visible and advisory unless
  maintainers explicitly require them.
- CI is Linux-only by project choice. macOS and other Apple-platform builds/tests are
  outside this pipeline; Linux success does not establish Apple-platform compatibility.
- Actions and reusable workflows are SHA-pinned. The reviewed SwiftNIO main commit supplies
  Swift 6.4 inputs absent from release 2.103.0; its nested workflows and downloaded scripts
  still follow upstream main. Caller pins do not make that execution chain immutable.
- Keep the separate Foundation-linking consumer check; a successful static SDK build
  does not prove that the resolved graph avoids full Foundation.
