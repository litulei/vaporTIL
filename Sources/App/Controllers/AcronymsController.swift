import Vapor
import Fluent
import Authentication

struct AcronymsController: RouteCollection {
    func boot(router: Router) throws {
        let acronymsRoutes = router.grouped("api", "acronyms")
        acronymsRoutes.get(use: getAllHandler)
//        acronymsRoutes.post(Acronym.self, use: createHandler)
        acronymsRoutes.get(Acronym.parameter, use: getHandler)
//        acronymsRoutes.put(Acronym.parameter, use: updateHandler)
//        acronymsRoutes.delete(Acronym.parameter, use: deleteHandler)
        acronymsRoutes.get("search", use: searchHandler)
        acronymsRoutes.get("sorted", use: sortedHandler)
        acronymsRoutes.get(Acronym.parameter, "user", use: getUserFromAcronymHandler)
//        acronymsRoutes.post(Acronym.parameter, "categories", Category.parameter, use: addCategoriesHandler)
        acronymsRoutes.get(Acronym.parameter, "categories", use: getCategoriesHandler)
//        acronymsRoutes.delete(Acronym.parameter, "categories", Category.parameter, use: removeCategoriesHandler)
        // Instantiate a basic authentication middleware which users BCrypDigest to
        // verify passwords
//        let basicAuthMiddleware = User.basicAuthMiddleware(using: BCryptDigest())
        // Create an instance of GuardAuthenticationMiddleware which ensures that requests
        // contain valid authorization
//        let guardAuthMiddleware = User.guardAuthMiddleware()
//        let protected = acronymsRoutes.grouped(basicAuthMiddleware, guardAuthMiddleware)
//        protected.post(Acronym.self, use: createHandler)
        let tokenAuthMiddleware = User.tokenAuthMiddleware()
        let guardAuthMiddleware = User.guardAuthMiddleware()
        let tokenAuthGroup = acronymsRoutes.grouped(tokenAuthMiddleware, guardAuthMiddleware)
        tokenAuthGroup.post(AcronymCreateData.self, use: createHandler)
        tokenAuthGroup.delete(Acronym.parameter, use: deleteHandler)
        tokenAuthGroup.put(Acronym.parameter, use: updateHandler)
        tokenAuthGroup.post(Acronym.parameter, "categories", Category.parameter, use: addCategoriesHandler)
        tokenAuthGroup.delete(Acronym.parameter, "categories", Category.parameter, use: removeCategoriesHandler)
    }
}

func getAllHandler(_ req: Request) throws -> Future<[Acronym]> {
    return Acronym.query(on: req).all()
}
// This helper function takes the type to decode as the first parameter. You
// can provide any path components before the use: parameter, if required.
func createHandler(_ req: Request, data: AcronymCreateData) throws -> Future<Acronym> {
    // add parameter acronym, comment the following
//    return try req.content.decode(Acronym.self).flatMap(to: Acronym.self) { (acronym) in
        // Save the model using Fluent. This returns Future<Acronym> as it returns
        // the model once it’s saved.
    let user = try req.requireAuthenticated(User.self)
    let acronym = try Acronym(short: data.short, long: data.long, userID: user.requireID())
    return acronym.save(on: req)
//    }
}

func getHandler(_ req: Request) throws -> Future<Acronym> {
    // Register a route at /api/acronyms/<ID> to handle a GET request
    return try req.parameters.next(Acronym.self)
}

func updateHandler(_ req: Request) throws -> Future<Acronym> {
    return try flatMap(to: Acronym.self, req.parameters.next(Acronym.self), req.content.decode(AcronymCreateData.self), { (acronym, updatedAcronym) in
        acronym.short = updatedAcronym.short
        acronym.long = updatedAcronym.long
        
        let user = try req.requireAuthenticated(User.self)
        acronym.userID = try user.requireID()
        return acronym.save(on: req)
    })
}

func deleteHandler(_ req: Request) throws -> Future<HTTPStatus> {
    return try req.parameters.next(Acronym.self).delete(on: req).transform(to: .noContent)
}

func searchHandler(_ req: Request) throws -> Future<[Acronym]> {
    guard let searchTerm = req.query[String.self, at: "term"] else {
        throw Abort(.badRequest)
    }
    // If you want to search multiple fields, you must use a filter group
    return Acronym.query(on: req).group(.or, closure: { (or) in
        or.filter(\.short == searchTerm)
        or.filter(\.long == searchTerm)
    }).all()
}

func getFirstHandler(_ req: Request) throws -> Future<Acronym> {
    return Acronym.query(on: req).first().unwrap(or: Abort(.notFound))
}

func sortedHandler(_ req: Request) throws -> Future<[Acronym]> {
    return Acronym.query(on: req).sort(\.short, .descending).all()
}

func getUserFromAcronymHandler(_ req: Request) throws -> Future<User.Public> {
    return try req.parameters.next(Acronym.self).flatMap(to: User.Public.self, { (acronym) in
        acronym.user.get(on: req).convertToPublic()
    })
}

func addCategoriesHandler(_ req: Request) throws -> Future<HTTPStatus> {
    return try flatMap(to: HTTPStatus.self, req.parameters.next(Acronym.self), req.parameters.next(Category.self), { (acronym, category) in
        return acronym.categories.attach(category, on: req).transform(to: .created)
    })
}

func getCategoriesHandler(_ req: Request) throws -> Future<[Category]> {
    return try req.parameters.next(Acronym.self).flatMap(to: [Category].self
        , { (acronym) in
            try acronym.categories.query(on: req).all()
    })
}

func removeCategoriesHandler(_ req: Request) throws -> Future<HTTPStatus> {
    return try flatMap(to: HTTPStatus.self, req.parameters.next(Acronym.self), req.parameters.next(Category.self), { (acronym, category) in
        return acronym.categories.detach(category, on: req).transform(to: .noContent)
    })
}

struct AcronymCreateData: Content {
    let short: String
    let long: String
}
