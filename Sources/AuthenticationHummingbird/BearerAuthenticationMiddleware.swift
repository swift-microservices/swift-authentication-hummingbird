// Copyright (c) 2026 Zaid Rahhawi
// SPDX-License-Identifier: MIT
// See LICENSE for license information.

public import Authentication
public import Hummingbird
public import HummingbirdAuth
import ServiceContextModule

/// Binds the principal a bearer token proves, for the length of the request.
///
/// The token is read from the `Authorization` header. A request with no token continues
/// anonymously, which is what an open route needs. The authenticator returns an identity or
/// throws. A failed authentication ends the request with `401 Unauthorized` before the route runs.
///
/// The proven identity is set in two places: the request context's `identity`, which
/// `IsAuthenticatedMiddleware` and route handlers read, and the task's `ServiceContext` under
/// `PrincipalKey<Context.Identity, String>`, which everything downstream of the handler reads,
/// including outgoing gRPC calls that present the same token onward.
///
/// Add it to the user route group, with `IsAuthenticatedMiddleware` after it where a route
/// requires a caller. Keep sign-in and refresh routes outside that group, so an expired token a
/// client still attaches cannot block recovery:
///
/// ```swift
/// let router = Router(context: BasicAuthRequestContext<AppToken>.self)
/// router.group("/account")
///     .add(middleware: BearerAuthenticationMiddleware(authenticator: authenticator))
///     .add(middleware: IsAuthenticatedMiddleware())
/// ```
public struct BearerAuthenticationMiddleware<Context: AuthRequestContext>: RouterMiddleware {
    private let authenticator: any Authenticator<String, Context.Identity>

    /// A middleware that proves bearer tokens with `authenticator`.
    ///
    /// - Parameter authenticator: Proves the token, such as a `JWTAuthenticator`.
    public init(authenticator: any Authenticator<String, Context.Identity>) {
        self.authenticator = authenticator
    }

    /// Authenticates the request's bearer token, if it has one, and runs `next` with the identity set.
    public func handle(
        _ request: Request,
        context: Context,
        next: @concurrent (Request, Context) async throws -> Response
    ) async throws -> Response {
        guard let token = request.headers.bearer?.token else {
            return try await next(request, context)
        }

        let identity = try await authenticate(token)

        var context = context
        context.identity = identity

        var serviceContext = ServiceContext.current ?? .topLevel
        serviceContext[PrincipalKey<Context.Identity, String>.self] = Principal(identity: identity, credential: token)

        return try await ServiceContext.withValue(serviceContext) {
            try await next(request, context)
        }
    }

    /// The rejection is an `HTTPError` rather than the authenticator's error, which carries no
    /// status and would be reported as a server fault: the wrong answer for the most ordinary
    /// request a client makes, one holding a token that has expired.
    private func authenticate(_ token: String) async throws -> Context.Identity {
        do {
            return try await authenticator.authenticate(token)
        } catch {
            throw HTTPError(.unauthorized, message: "Invalid or expired token.")
        }
    }
}
