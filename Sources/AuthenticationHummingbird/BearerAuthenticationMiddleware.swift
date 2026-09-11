//
//  BearerAuthenticationMiddleware.swift
//  swift-authentication-hummingbird
//
//  Created by Zaid Rahhawi on 9/11/26.
//

import Authentication
import Hummingbird
import HummingbirdAuth
import ServiceContextModule

/// Binds the principal a bearer token proves, for the length of the request.
///
/// The token is read from the `Authorization` header. A request with no token continues
/// anonymously, which is what an open route needs. A token the authenticator declines continues
/// unbound. A token it refuses fails the request with `401 Unauthorized`, because absent and
/// invalid are not the same thing.
///
/// The proven identity is set in two places: the request context's `identity`, which
/// `IsAuthenticatedMiddleware` and route handlers read, and the task's `ServiceContext` under
/// `PrincipalKey<Context.Identity, String>`, which everything downstream of the handler reads,
/// including outgoing gRPC calls that present the same token onward.
///
/// ```swift
/// let router = Router(context: BasicAuthRequestContext<AppToken>.self)
/// router.add(middleware: BearerAuthenticationMiddleware(authenticator: authenticator))
/// ```
///
/// Requiring a caller is a route's decision: add `IsAuthenticatedMiddleware` to the routes that
/// need one.
public struct BearerAuthenticationMiddleware<Context: AuthRequestContext>: RouterMiddleware {
    private let authenticator: any Authenticator<String, Context.Identity>

    /// - Parameter authenticator: Proves the token, such as a `JWTAuthenticator`.
    public init(authenticator: any Authenticator<String, Context.Identity>) {
        self.authenticator = authenticator
    }

    public func handle(
        _ request: Request,
        context: Context,
        next: (Request, Context) async throws -> Response
    ) async throws -> Response {
        guard let token = request.headers.bearer?.token else {
            return try await next(request, context)
        }

        guard let identity = try await authenticate(token) else {
            return try await next(request, context)
        }

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
    private func authenticate(_ token: String) async throws -> Context.Identity? {
        do {
            return try await authenticator.authenticate(token)
        } catch {
            throw HTTPError(.unauthorized, message: "Invalid or expired token.")
        }
    }
}
