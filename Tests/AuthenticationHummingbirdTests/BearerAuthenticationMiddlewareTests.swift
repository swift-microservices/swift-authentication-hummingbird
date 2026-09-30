//
//  BearerAuthenticationMiddlewareTests.swift
//  swift-authentication-hummingbird
//
//  Created by Zaid Rahhawi on 9/11/26.
//

import Authentication
import AuthenticationHummingbird
import Hummingbird
import HummingbirdAuth
import HummingbirdTesting
import ServiceContextModule
import Testing

@Suite
struct BearerAuthenticationMiddlewareTests {
    struct Claims: Sendable, Equatable {
        let subject: String
    }

    /// An authenticator over a table: known tokens prove their claims; unknown or
    /// refused tokens throw.
    struct TableAuthenticator: Authenticator {
        struct Refused: Error {}

        let identities: [String: Claims]
        let refused: Set<String>

        func authenticate(_ token: String) throws -> Claims {
            if refused.contains(token) {
                throw Refused()
            }
            guard let identity = identities[token] else {
                throw Refused()
            }
            return identity
        }
    }

    typealias Context = BasicAuthRequestContext<Claims>

    /// An application with the middleware and one route that reports what it saw: the request
    /// context's identity and the ServiceContext principal, or `-` for neither.
    func application(handlerCalls: HandlerCalls) -> Application<RouterResponder<Context>> {
        let router = Router(context: Context.self)
        router.add(
            middleware: BearerAuthenticationMiddleware(
                authenticator: TableAuthenticator(identities: ["alice-token": Claims(subject: "alice")], refused: ["expired-token"])
            )
        )
        router.get("/whoami") { _, context in
            await handlerCalls.record()
            let principal = ServiceContext.current?[PrincipalKey<Claims, String>.self]
            return "\(context.identity?.subject ?? "-") \(principal?.identity.subject ?? "-") \(principal?.credential ?? "-")"
        }
        return Application(router: router)
    }

    func whoami(authorization: String?, handlerCalls: HandlerCalls = HandlerCalls()) async throws -> (status: HTTPResponse.Status, body: String) {
        try await application(handlerCalls: handlerCalls).test(.router) { client in
            var headers = HTTPFields()
            if let authorization {
                headers[.authorization] = authorization
            }
            return try await client.execute(uri: "/whoami", method: .get, headers: headers) { response in
                (response.status, String(buffer: response.body))
            }
        }
    }

    @Test("A request with no token continues anonymously")
    func noTokenContinuesAnonymously() async throws {
        let calls = HandlerCalls()
        let response = try await whoami(authorization: nil, handlerCalls: calls)

        #expect(response.status == .ok)
        #expect(response.body == "- - -")
        #expect(await calls.count == 1)
    }

    @Test("A proved token sets the context identity and binds the principal")
    func provedTokenSetsIdentityAndPrincipal() async throws {
        let calls = HandlerCalls()
        let response = try await whoami(authorization: "Bearer alice-token", handlerCalls: calls)

        #expect(response.status == .ok)
        #expect(response.body == "alice alice alice-token")
        #expect(await calls.count == 1)
    }

    @Test("An unknown token is 401 Unauthorized before the route runs")
    func unknownTokenIsUnauthorized() async throws {
        let calls = HandlerCalls()
        let response = try await whoami(authorization: "Bearer unknown-token", handlerCalls: calls)

        #expect(response.status == .unauthorized)
        #expect(await calls.count == 0)
    }

    @Test("A refused token is 401 Unauthorized before the route runs")
    func refusedTokenIsUnauthorized() async throws {
        let calls = HandlerCalls()
        let response = try await whoami(authorization: "Bearer expired-token", handlerCalls: calls)

        #expect(response.status == .unauthorized)
        #expect(await calls.count == 0)
    }

    enum TraceKey: ServiceContextKey {
        typealias Value = String
    }

    @Test("A proved token adds the principal to the ServiceContext already bound")
    func provedTokenKeepsEnclosingServiceContext() async throws {
        var enclosing = ServiceContext.topLevel
        enclosing[TraceKey.self] = "trace-1"

        let body = try await ServiceContext.withValue(enclosing) {
            let router = Router(context: Context.self)
            router.add(
                middleware: BearerAuthenticationMiddleware(
                    authenticator: TableAuthenticator(identities: ["alice-token": Claims(subject: "alice")], refused: [])
                )
            )
            router.get("/context") { _, _ in
                let context = ServiceContext.current
                return "\(context?[TraceKey.self] ?? "-") \(context?[PrincipalKey<Claims, String>.self]?.identity.subject ?? "-")"
            }

            return try await Application(router: router).test(.router) { client in
                var headers = HTTPFields()
                headers[.authorization] = "Bearer alice-token"
                return try await client.execute(uri: "/context", method: .get, headers: headers) { String(buffer: $0.body) }
            }
        }

        #expect(body == "trace-1 alice")
    }

    @Test("A proved token satisfies IsAuthenticatedMiddleware on a protected route")
    func provedTokenPassesIsAuthenticated() async throws {
        let router = Router(context: Context.self)
        router.add(
            middleware: BearerAuthenticationMiddleware(
                authenticator: TableAuthenticator(identities: ["alice-token": Claims(subject: "alice")], refused: [])
            )
        )
        router.group("/protected")
            .add(middleware: IsAuthenticatedMiddleware())
            .get("/") { _, context in context.identity?.subject ?? "-" }

        try await Application(router: router).test(.router) { client in
            let anonymous = try await client.execute(uri: "/protected/", method: .get) { $0.status }
            #expect(anonymous == .unauthorized)

            var headers = HTTPFields()
            headers[.authorization] = "Bearer alice-token"
            let alice = try await client.execute(uri: "/protected/", method: .get, headers: headers) { (status: $0.status, body: String(buffer: $0.body)) }
            #expect(alice.status == .ok)
            #expect(alice.body == "alice")
        }
    }
}

/// Counts route invocations across the framework's responder tasks.
actor HandlerCalls {
    private(set) var count = 0

    func record() {
        count += 1
    }
}
