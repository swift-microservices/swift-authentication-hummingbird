# Swift Authentication for Hummingbird

[![Documentation](https://img.shields.io/badge/docc-read_documentation-blue)](https://swiftpackageindex.com/swift-microservices/swift-authentication-hummingbird/documentation)
[![Release](https://img.shields.io/github/v/release/swift-microservices/swift-authentication-hummingbird)](https://github.com/swift-microservices/swift-authentication-hummingbird/releases)
[![Swift versions](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fswift-microservices%2Fswift-authentication-hummingbird%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/swift-microservices/swift-authentication-hummingbird)
[![CI](https://github.com/swift-microservices/swift-authentication-hummingbird/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/swift-microservices/swift-authentication-hummingbird/actions/workflows/ci.yml)

Swift Authentication for Hummingbird tells a [Hummingbird](https://github.com/hummingbird-project/hummingbird)
server who is calling. One middleware reads the bearer token, proves it with an
[swift-authentication](https://github.com/swift-microservices/swift-authentication) `Authenticator`,
and sets the caller on the request context.

- 🔐 One middleware, `BearerAuthenticationMiddleware`, for any `AuthRequestContext`
- 📦 Swift Package Manager, built on Hummingbird 2.28 and HummingbirdAuth 2.5
- 🐧 Supports Linux (x86_64 and aarch64, including the static SDK) and macOS 15+
- 🔧 Built with Swift 6.3+ in the Swift 6 language mode

🔗 Jump to:
- 📖 [Overview](#-overview)
- 🏁 [Getting Started](#-getting-started)
- 📘 [Documentation](#-documentation)
- 🧰 [Release Info](#-release-info)
- 🛠️ [Support](#%EF%B8%8F-support)

## 📖 Overview

A request arrives with `Authorization: Bearer <token>`. `BearerAuthenticationMiddleware` hands the
token to an `Authenticator<String, Identity>`, such as `JWTAuthenticator` from
[swift-authentication-jwt](https://github.com/swift-microservices/swift-authentication-jwt). The
authenticator returns an identity or throws. The middleware then sets that identity in two places,
so every reader finds the same caller:

- the request context's `identity`, which HummingbirdAuth's `IsAuthenticatedMiddleware` and route
  handlers read;
- the task's `OperationContext`, as a `Principal<Identity, String>` under
  `PrincipalKey<Identity, String>`, added to whatever context is already bound. Everything
  downstream reads it there, including outgoing gRPC calls that present the same token onward
  through [swift-authentication-grpc](https://github.com/swift-microservices/swift-authentication-grpc).

**Key Features:**
- 🚪 **Open routes stay open**: a request with no token continues anonymously, which is what an
  open route needs: signing in mints the first token and has no caller yet.
- ⛔ **Bad tokens stop early**: a token that fails authentication ends the request with
  `401 Unauthorized` before the route runs. The authenticator's error is mapped to
  `HTTPError(.unauthorized)`, so the client gets the authentication status, not a server fault.
- 🎯 **Routes decide who must be signed in**: requiring a caller is a route's decision, made with
  `IsAuthenticatedMiddleware` after the bearer middleware.
- 🧩 **Your context, your identity**: the middleware works with any `AuthRequestContext`, and the
  token's identity is the context's `Identity`. HummingbirdAuth's `BasicAuthRequestContext<Identity>`
  is enough for most applications.
- 🔁 **Relays as the caller**: the principal keeps the token as presented, so a Hummingbird gateway
  can call a gRPC service as the same person.

## 🏁 Getting Started

### Prerequisites

- Swift version: Swift 6.3+
- Platforms: macOS 15+ or Linux

To install/upgrade Swift, see https://www.swift.org/install/

### Adding as a dependency

Add the package and its product to your `Package.swift`. The examples below also use
`JWTAuthenticator` from swift-authentication-jwt:

```swift
dependencies: [
    .package(url: "https://github.com/swift-microservices/swift-authentication-hummingbird.git", from: "1.0.0"),
    .package(url: "https://github.com/swift-microservices/swift-authentication-jwt.git", from: "1.0.0"),
],
targets: [
    .executableTarget(
        name: "App",
        dependencies: [
            .product(name: "AuthenticationHummingbird", package: "swift-authentication-hummingbird"),
            .product(name: "AuthenticationJWT", package: "swift-authentication-jwt"),
        ]
    ),
]
```

### Usage

Put the middleware on the group of routes that need a caller, with `IsAuthenticatedMiddleware`
after it. Keep sign-in and refresh routes outside that group, so an expired token a client still
attaches cannot block recovery:

```swift
import AuthenticationHummingbird
import AuthenticationJWT
import Hummingbird
import HummingbirdAuth
import JWTKit

// Your token's payload. The authenticator returns it once the signature and `verify` pass.
struct AppToken: JWTPayload {
    let sub: SubjectClaim
    let exp: ExpirationClaim

    func verify(using algorithm: some JWTAlgorithm) throws {
        try exp.verifyNotExpired()
    }
}

// Verify tokens against your issuer's Ed25519 public key (its JWK "x" value).
let publicKey = try EdDSA.PublicKey(x: "<your issuer's public key>", curve: .ed25519)
let keys = JWTKeyCollection()
await keys.add(eddsa: publicKey)

let router = Router(context: BasicAuthRequestContext<AppToken>.self)

// Open: no token needed, so a client with an expired one can still sign in.
router.post("/sign-in") { _, _ in "issue a token here" }

// Authenticated: the bearer middleware proves the token, IsAuthenticatedMiddleware requires one.
router.group("/account")
    .add(middleware: BearerAuthenticationMiddleware(authenticator: JWTAuthenticator<AppToken>(keys: keys)))
    .add(middleware: IsAuthenticatedMiddleware())
    .get("/") { _, context in
        let token = try context.requireIdentity()
        return "Signed in as \(token.sub.value)"
    }

let app = Application(router: router)
try await app.runService()
```

A request to `/account` with no token, or with one that fails verification, gets
`401 Unauthorized` and never reaches the handler.

#### Reading the principal downstream

The handler passes the verified identity explicitly to a user use case. Code that has no request
context, such as an adapter relaying the call to another service, reads the principal from the
task's `OperationContext` instead. Spell the lookup once:

```swift
import Authentication
import OperationContext

extension OperationContext {
    var caller: Principal<AppToken, String>? {
        self[PrincipalKey<AppToken, String>.self]
    }
}

// Anywhere below the middleware, in the same task:
if let caller = OperationContext.current.caller {
    print(caller.identity.sub.value)  // who the token proved
    print(caller.credential)          // the token as presented, to forward unchanged
}
```

#### Calling backend services

mTLS secures connections to backend services. Forward the original user JWT only on upstream user
RPC descriptors, where the receiving service verifies it and the owning use case checks
permissions. User database settings follow the user operation. swift-authentication-grpc's
propagation interceptor reads the principal this middleware bound and presents its token on those
descriptors.

## 📘 Documentation

- [API Documentation](https://swiftpackageindex.com/swift-microservices/swift-authentication-hummingbird/documentation) -
  the full reference on Swift Package Index
- [Middleware and the request context](https://swiftpackageindex.com/swift-microservices/swift-authentication-hummingbird/documentation/authenticationhummingbird/middlewareandtherequestcontext) -
  where the proven identity goes, how a route asks for one, and how a presented token is handled

Related packages:

- [swift-authentication](https://github.com/swift-microservices/swift-authentication) - the
  `Authenticator`, `Principal` and `PrincipalKey` this package binds
- [swift-authentication-jwt](https://github.com/swift-microservices/swift-authentication-jwt) -
  `JWTAuthenticator` and `JWTIssuer`
- [swift-authentication-grpc](https://github.com/swift-microservices/swift-authentication-grpc) -
  the same binding for gRPC, and propagation of the token onward
- [swift-authentication-vapor](https://github.com/swift-microservices/swift-authentication-vapor) -
  the same middleware for Vapor

## 🧰 Release Info

- Versioning: [Semantic Versioning](https://semver.org). The public API is stable from 1.0.0 and
  only a major release breaks it; CI checks every pull request for API breakage.
- Release notes: [GitHub Releases](https://github.com/swift-microservices/swift-authentication-hummingbird/releases)
- Swift versions: CI tests Swift 6.3 and 6.4 on Linux, plus the 6.4 and main nightly toolchains.
- Dependencies: Hummingbird 2.28, HummingbirdAuth 2.5, swift-authentication 1.0,
  swift-operation-context 1.0.

## 🛠️ Support

If you have any questions or need help, feel free to reach out by [opening an
issue](https://github.com/swift-microservices/swift-authentication-hummingbird/issues).

Pull requests are welcome. Keep a change focused, prove new behaviour with a test, and label the
pull request with its semantic version impact.

### Development

```sh
swift test
swift-format lint --strict --recursive Sources Tests    # what the soundness check runs
```

## License

MIT. See [LICENSE](LICENSE).
