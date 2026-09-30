# swift-authentication-hummingbird

Binding who is calling on Hummingbird: a bearer token, proved and set on the request context.

```swift
.package(url: "https://github.com/swift-microservices/swift-authentication-hummingbird.git", from: "0.3.0"),
```

```swift
.product(name: "AuthenticationHummingbird", package: "swift-authentication-hummingbird"),
```

## The middleware

`BearerAuthenticationMiddleware` reads the `Authorization` header, proves the token with an
`Authenticator<String, Identity>` from [swift-authentication](https://github.com/swift-microservices/swift-authentication),
and sets the identity in two places:

- the request context's `identity`, which HummingbirdAuth's `IsAuthenticatedMiddleware` and
  route handlers read;
- the task's `ServiceContext`, as a `Principal<Identity, String>` under
  `PrincipalKey<Identity, String>`, which everything downstream reads, including outgoing gRPC
  calls that present the same token onward through swift-authentication-grpc.

```swift
let router = Router(context: BasicAuthRequestContext<AppToken>.self)
router.add(middleware: BearerAuthenticationMiddleware(authenticator: JWTAuthenticator<AppToken>(keys: keys)))

router.group("/account")
    .add(middleware: IsAuthenticatedMiddleware())
    .get("/") { _, context in context.identity! }
```

A request with no token continues anonymously, which is what an open route needs: signing in
mints the first token and has no caller yet. `Authenticator.authenticate(_:)` returns an identity
or throws. A failed authentication ends the request with `401 Unauthorized` before the route
runs. Requiring a caller is a route's decision, made with `IsAuthenticatedMiddleware`.

## Requirements

Swift 6.3, macOS 15 or Linux. Hummingbird 2.27, HummingbirdAuth 2.5, swift-authentication 0.3.

## Development

```sh
swift test
swift-format lint --strict --recursive Sources Tests    # what the soundness check runs
```

## Contributing

Pull requests are welcome. Keep a change focused, prove new behaviour with a test, and label the
pull request with its semantic version impact.

## License

MIT. See [LICENSE](LICENSE).
