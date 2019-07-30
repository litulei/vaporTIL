
import Vapor
import Crypto

struct UsersController: RouteCollection {
    func boot(router: Router) throws {
        let usersRoute = router.grouped("api", "users")
        // This uses the POST helper method to decode the request body
        // into a User object.
//        usersRoute.post(User.self, use: createUserHandler)
        usersRoute.get(use: getAllUserHandler)
        usersRoute.get(User.parameter, use: getUserHandler)
        usersRoute.get(User.parameter, use: getAcronymsHandler)
        
        let basicAuthMiddleware = User.basicAuthMiddleware(using: BCryptDigest())
        let basicAuthGroup = usersRoute.grouped(basicAuthMiddleware)
        basicAuthGroup.post("login", use: loginHandler)
        
        let tokenAuthMiddleware = User.tokenAuthMiddleware()
        let guardAuthMiddleware = User.guardAuthMiddleware()
        let tokenAuthGroup = usersRoute.grouped(tokenAuthMiddleware, guardAuthMiddleware)
        tokenAuthGroup.post(User.self, use: createUserHandler)
    }
}

func createUserHandler(_ req: Request, user: User) throws -> Future<User.Public> {
    user.password = try BCrypt.hash(user.password)
    return user.save(on: req).convertToPublic()
}

func getAllUserHandler(_ req: Request) throws -> Future<[User.Public]> {
    return User.query(on: req).decode(data: User.Public.self).all()
}

func getUserHandler(_ req: Request) throws -> Future<User.Public> {
    return try req.parameters.next(User.self).convertToPublic()
}

func getAcronymsHandler(_ req: Request) throws -> Future<[Acronym]> {
    // Fetch the user specified in the request's parameters and unwrap
    // the returned futurn.
    return try req.parameters.next(User.self).flatMap(to: [Acronym].self
        , { (user) in
            try user.acronyms.query(on: req).all()
    })
}

func loginHandler(_ req: Request) throws -> Future<Token> {
    let user = try req.requireAuthenticated(User.self)
    let token = try Token.generate(for: user)
    return token.save(on: req)
}
