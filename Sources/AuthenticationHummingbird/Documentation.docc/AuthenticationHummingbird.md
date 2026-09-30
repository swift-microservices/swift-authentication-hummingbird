# ``AuthenticationHummingbird``

Binding who is calling on Hummingbird: a bearer token, proved and set on the request context.

## Overview

``BearerAuthenticationMiddleware`` reads the `Authorization` header, proves the token with an
`Authenticator<String, Identity>` from swift-authentication, and sets the identity in two
places: the request context's `identity`, which HummingbirdAuth's `IsAuthenticatedMiddleware`
and route handlers read, and the task's `ServiceContext` as a `Principal<Identity, String>`,
which everything downstream reads, including outgoing gRPC calls that present the same token
onward.

The middleware's context is any `AuthRequestContext`; the token's identity is the context's.
`BasicAuthRequestContext<Identity>` from HummingbirdAuth is enough for most applications.

Authentication returns an identity or throws. A missing credential continues anonymously;
a failed authentication ends the request with `401 Unauthorized` before the handler runs.

## Example

```swift
let router = Router(context: BasicAuthRequestContext<AppToken>.self)
router.add(middleware: BearerAuthenticationMiddleware(authenticator: authenticator))

router.group("/account")
    .add(middleware: IsAuthenticatedMiddleware())
    .get("/") { _, context in context.identity! }
```

## Topics

### Middleware

- ``BearerAuthenticationMiddleware``

### Design

- <doc:MiddlewareAndTheRequestContext>
