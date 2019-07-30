import Vapor
import Fluent

/// Register your application's routes here.
public func routes(_ router: Router) throws {

    /*****
    router.post(InfoData.self, at: "info") { (req, data) -> InfoResponse in
        return InfoResponse(request: data)
    }
    // accept a POST request and returns Future<Acronym>. It returns the acronym once
    // it's saved
    router.post("api", "acronyms") { (req) -> Future<Acronym> in
        // Decode the request's JSON into an Acronym model using Codable. This returns
        // Future<Acronym> so it uses a flatMap(to:) to extract the acronym when the
        // decoding completes. in this case, you're calling decode(_:) on Request yourself
        // You're then unwrapping the result as decode(_:) returns a Future<Acronym>
        return try req.content.decode(Acronym.self).flatMap(to: Acronym.self) { (acronym) in
            // Save the model using Fluent. This returns Future<Acronym> as it returns
            // the model once it’s saved.
            return acronym.save(on: req)
        }
    }
    
    router.get("api", "acronyms") { req -> Future<[Acronym]> in
        return Acronym.query(on: req).all()
    }
    
    // Register a route at /api/acronyms/<ID> to handle a GET request
    router.get("api", "acronyms", Acronym.parameter) { req -> Future<Acronym> in
        // Extract the acronym from the request using parameters.
        return try req.parameters.next(Acronym.self)
        
    }
    
    router.put("api", "acronyms", Acronym.parameter) { req -> Future<Acronym> in
        // Use flatMap(to:_:_), the dual future form of flatMap, to wait for both
        // the parameter extraction and content decoding to complete. This provides
        // both the acronym from the database and acronym from the request body to
        // to the closure
        return try flatMap(to: Acronym.self, req.parameters.next(Acronym.self), req.content.decode(Acronym.self), { (acronym, updatedAcronym) in
            acronym.short = updatedAcronym.short
            acronym.long = updatedAcronym.long
            return acronym.save(on: req)
        })
    }
    
    router.delete("api", "acronyms", Acronym.parameter) { (req) -> Future<HTTPStatus> in
        return try req.parameters.next(Acronym.self).delete(on: req).transform(to: .noContent)
    }
    
    router.get("api", "acronyms", "search") { (req) -> Future<[Acronym]> in
        // Retrieve the search term from the URL query string.
        guard let searchTerm = req.query[String.self, at: "term"] else {
            throw Abort(.badRequest)
        }
//        return Acronym.query(on: req).filter(\.short == searchTerm).all()
        
        // If you want to search multiple fields, you must use a filter group
        return Acronym.query(on: req).group(.or, closure: { (or) in
            or.filter(\.short == searchTerm)
            or.filter(\.long == searchTerm)
        }).all()
    }
    
    router.get("api", "acronyms", "first") { (req) -> Future<Acronym> in
        return Acronym.query(on: req).first().unwrap(or: Abort(.notFound))
    }
    
    router.get("api", "acronyms", "sorted") { (req) -> Future<[Acronym]> in
        return Acronym.query(on: req).sort(\.short, .descending).all()
    }
 *****/
    let acronymsController = AcronymsController()
    try router.register(collection: acronymsController)
    
    let usersController = UsersController()
    try router.register(collection: usersController)
    
    // 1
    let categoriesController = CategoriesController()
    // 2
    try router.register(collection: categoriesController)
    
    let websiteController = WebsiteController()
    try router.register(collection: websiteController)
    
//    let imperialController = ImperialController()
//    try router.register(collection: imperialController)
}

// This struct conforms to Content which is Vapor's wrapper around Codable
// Vapor uses Content to extract the request data, whether it's the default
// JSON-encoded or form URL-encoded.
struct InfoData: Content {
    let name: String
}

struct InfoResponse: Content {
    let request: InfoData
}
