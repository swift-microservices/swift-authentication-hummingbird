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
the middleware bound and presents its token onward.

## Open routes and protected routes

A request with no token continues anonymously. That is what an open route needs, and the
middleware is applied to the whole router: signing in and registering mint the first token and
have no caller yet.

Requiring a caller is a route's decision, not the middleware's. `IsAuthenticatedMiddleware` on a
route group refuses requests whose context has no identity, and a handler on such a route can
unwrap `context.identity` without a check.

## Authenticating a presented token

`Authenticator.authenticate(_:)` returns an identity or throws. A presented token must
authenticate successfully; a failure ends the request with `401 Unauthorized` before the route
runs. The middleware maps the authenticator's error to an `HTTPError(.unauthorized)` so the
client receives the authentication status.
