# Middleware and the request context

Where the proven identity goes on Hummingbird, and how a route asks for one.

## Two readers, two places

Hummingbird code reads an identity in two ways. Route handlers and HummingbirdAuth's
`IsAuthenticatedMiddleware` read the request context's `identity`, which is why the middleware's
context is any `AuthRequestContext`. Everything downstream of a handler that is not Hummingbird,
a use case, a repository, an outgoing gRPC call, reads the task's `ServiceContext`.
``BearerAuthenticationMiddleware`` sets both, so each reader finds the same caller.

The `ServiceContext` binding is what lets a Hummingbird gateway relay a person's call to a gRPC
service as that person: swift-authentication-grpc's propagation interceptor reads the principal
the middleware bound and presents its original token on upstream user descriptors.

## User routes

Apply bearer authentication and `IsAuthenticatedMiddleware` to the user route group. Missing
credentials continue unbound in the bearer middleware; `IsAuthenticatedMiddleware` requires the
identity before the handler runs. The owning use case checks user permissions and resource
access.

## Authenticating a presented token

`Authenticator.authenticate(_:)` returns an identity or throws. A presented token must
authenticate successfully; a failure ends the request with `401 Unauthorized` before the route
runs. The middleware maps the authenticator's error to an `HTTPError(.unauthorized)` so the
client receives the authentication status.
