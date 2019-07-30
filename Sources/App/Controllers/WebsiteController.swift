
import Vapor
import Leaf
import Authentication

struct WebsiteController: RouteCollection {
    func boot(router: Router) throws {
        let authSessionRoutes = router.grouped(User.authSessionsMiddleware())
        authSessionRoutes.get(use: indexHandler)
        authSessionRoutes.get("acronyms", Acronym.parameter, use:acronymForWebHandler)
        authSessionRoutes.get("users", User.parameter, use: userForWebHandler)
        authSessionRoutes.get("users", use: allUsersHandler)
        authSessionRoutes.get("categories", use: allCategoriesHandler)
        authSessionRoutes.get("categories", Category.parameter, use: categoryForWebHandler)
        
        authSessionRoutes.get("login", use: loginForWebHandler)
        authSessionRoutes.post(LoginPostData.self, at: "login", use: loginPostHandler)
        authSessionRoutes.post("logout", use: logoutHandler)
        authSessionRoutes.get("register", use: registerHandler)
        authSessionRoutes.post(RegisterData.self, at: "register", use: registerPostHandler)
        let protectedRoutes = authSessionRoutes.grouped(RedirectMiddleware<User>(path: "/login"))
        protectedRoutes.get("acronyms", "create", use: createAcronymForWebHandler)
        protectedRoutes.post(CreateAcronymData.self, at: "acronyms", "create", use: createAcronymPostHandler)
        protectedRoutes.get("acronyms", Acronym.parameter, "edit", use: EditAcronymForWebHandler)
        protectedRoutes.post("acronyms", Acronym.parameter, "edit",  use: editAcronymPostHandler)
        protectedRoutes.post("acronyms", Acronym.parameter, "delete", use: deleteAcronymForWebHandler)
    }
}

func indexHandler(_ req: Request) throws -> Future<View> {
    // Use a Fluent query to get all acronyms from the database
    return Acronym.query(on: req).all().flatMap(to: View.self, { (acronyms) in
        let userLoggedIn = try req.isAuthenticated(User.self)
        let context = IndexContext(title: "Home Page", acronyms: acronyms, userLoggedIn: userLoggedIn)
        // Leaf generates a page from a template called index.leaf
        // inside the Resources/Views
        return try req.view().render("index", context)
    })
}

func acronymForWebHandler(_ req: Request) throws -> Future<View> {
    return try req.parameters.next(Acronym.self).flatMap(to: View.self, { (acronym)  in
        return acronym.user.get(on: req).flatMap(to: View.self, { (user) in
            let categories = try acronym.categories.query(on: req).all()
            let context = AcronymContext(title: acronym.short, acronym: acronym, user: user, categories: categories)
            return try req.view().render("acronym", context)
        })
    })
}

func userForWebHandler(_ req: Request) throws -> Future<View> {
    return try req.parameters.next(User.self).flatMap(to: View.self, { (user)  in
        return try user.acronyms.query(on: req).all().flatMap(to: View.self, { (acronyms)  in
            let context = UserContext(title: user.name, user: user, acronyms: acronyms)
            return try req.view().render("user", context)
        })
    })
}

func allUsersHandler(_ req: Request) throws -> Future<View> {
    return User.query(on: req).all().flatMap(to: View.self, { (users)  in
        let context = AllUersContext(title: "All Users", users: users)
        return try req.view().render("allUsers", context)
    })
}

func allCategoriesHandler(_ req: Request) throws -> Future<View> {
    let categories = Category.query(on: req).all()
    let context = AllCategoriesContext(categories: categories)
    return try req.view().render("allCategories", context)
}

func categoryForWebHandler(_ req: Request) throws -> Future<View> {
    return try req.parameters.next(Category.self).flatMap(to: View.self, { (category)  in
        let acronyms = try category.acronyms.query(on: req).all()
        let context = CategoryContext(title: category.name, category: category, acronyms: acronyms)
        return try req.view().render("category", context)
    })
}


func createAcronymForWebHandler(_ req: Request) throws -> Future<View> {
    let token = try CryptoRandom().generateData(count: 16).base64EncodedString()
    
    let context = CreateAcronymContext(csrfToken: token)
    try req.session()["CSRF_TOKEN"] = token
    return try req.view().render("createAcronym", context)
}

func createAcronymPostHandler(_ req: Request, data: CreateAcronymData) throws -> Future<Response> {
    let expectedToken = try req.session()["CSRF_TOKEN"]
    try req.session()["CSRF_TOKEN"] = nil
    guard let csrfToken = data.csrfToken, expectedToken == csrfToken else {
        throw Abort(.badRequest)
    }
    let user = try req.requireAuthenticated(User.self)
    let acronym = try Acronym(short: data.short, long: data.long, userID: user.requireID())
    return acronym.save(on: req).flatMap(to: Response.self, { (acronym)  in
        guard let id = acronym.id else {
            throw Abort(.internalServerError)
        }
        var categorySaves: [Future<Void>] = []
        for category in data.categories ?? [] {
            try categorySaves.append(Category.addCategory(category, to: acronym, on: req))
        }
        let redirect = req.redirect(to: "/acronyms/\(id)")
        return categorySaves.flatten(on: req).transform(to: redirect)
    })
}

func EditAcronymForWebHandler(_ req: Request) throws -> Future<View> {
    return try req.parameters.next(Acronym.self).flatMap(to: View.self, { (acronym) in
        let categories = try acronym.categories.query(on: req).all()
        let context = EditAcronymContext(acronym: acronym, categories: categories)
        return try req.view().render("createAcronym", context)
    })
}

func editAcronymPostHandler(_ req: Request) throws -> Future<Response> {
    return try flatMap(to: Response.self, req.parameters.next(Acronym.self), req.content.decode(CreateAcronymData.self), { (acronym, data) in
        let user = try req.requireAuthenticated(User.self)
        acronym.short = data.short
        acronym.long = data.long
        acronym.userID = try user.requireID()
        
        guard let id = acronym.id else {
            throw Abort(.internalServerError)
        }
        return acronym.save(on: req).flatMap(to: [Category].self, { (_) in
            try acronym.categories.query(on: req).all()
        }).flatMap(to: Response.self, { (existingCategories)  in
            let existingStringArray = existingCategories.map {
                $0.name
            }
            let existingSet = Set<String>(existingStringArray)
            let newSet = Set<String>(data.categories ?? [])
            
            let categoriesToAdd = newSet.subtracting(existingSet)
            let categoriesToRemove = existingSet.subtracting(newSet)
            
            var categoryResults: [Future<Void>] = []
            for newCategory in categoriesToAdd {
                
                categoryResults.append(try Category.addCategory(newCategory, to: acronym, on: req))
            }
            for categoryNameToRemove in categoriesToRemove {
                let categoryToRemove = existingCategories.first {
                    $0.name == categoryNameToRemove
                }
                if let category = categoryToRemove {
                    categoryResults.append(acronym.categories.detach(category, on: req))
                }
                
            }
            let redirect = req.redirect(to: "/acronyms/\(id)")
            return categoryResults.flatten(on: req).transform(to: redirect)
        })
    })
}

func deleteAcronymForWebHandler(_ req: Request) throws -> Future<Response> {
    return try req.parameters.next(Acronym.self).delete(on: req).transform(to: req.redirect(to: "/"))
}

func loginForWebHandler(_ req: Request) throws -> Future<View> {
    let context: LoginContext
    if req.query[Bool.self, at: "error"] != nil {
        context = LoginContext(loginError: true)
    } else {
        context = LoginContext()
    }
    return try req.view().render("login", context)
}

func loginPostHandler(_ req: Request, userData: LoginPostData) throws -> Future<Response> {
    return User.authenticate(username: userData.username, password: userData.password, using: BCryptDigest(), on: req).map(to: Response.self) { user in
        guard let user = user else {
            return req.redirect(to: "/login?error")
        }
        // This saves the authenticated User into the request's session so
        // Vapor can retrieve it in later request.
        try req.authenticateSession(user)
        return req.redirect(to: "/")
    }
}

func logoutHandler(_ req: Request) throws -> Response {
    // This deletes the user from the session so it can't be used to authenticate
    // future requests.
    try req.unauthenticateSession(User.self)
    return req.redirect(to: "/")
}

func registerHandler(_ req: Request) throws -> Future<View> {
    let context: RegisterContext
    if let message = req.query[String.self, at: "message"] {
        context = RegisterContext(message: message)
    } else {
        context = RegisterContext()
    }
    return try req.view().render("register", context)
}

func registerPostHandler(_ req: Request, data: RegisterData) throws -> Future<Response> {
    do {
        try data.validate()
    } catch (let error) {
        let redirect: String
        if let error = error as? ValidationError, let message = error.reason.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            redirect = "/register?message=\(message)"
        } else {
            redirect = "/register?message=Unknow+error"
        }
        return req.future(req.redirect(to: redirect))
    }
    let password = try BCrypt.hash(data.password)
    let user = User(name: data.name, username: data.username, password: password)
    return user.save(on: req).map(to: Response.self, { (user)  in
        try req.authenticateSession(user)
        return req.redirect(to: "/")
    })
}


// As data only flows to Leaf, you only need to conform to Encodable.
// IndexContext is the data for your view, similar to a view model
// in the MVVM design pattern
struct IndexContext: Encodable {
    let title: String
    let acronyms: [Acronym]
    let userLoggedIn: Bool
}

struct AcronymContext: Encodable {
    let title: String
    let acronym: Acronym
    let user: User
    let categories: Future<[Category]>
}

struct UserContext: Encodable {
    let title: String
    let user: User
    let acronyms: [Acronym]
}

struct AllUersContext: Encodable {
    let title: String
    let users: [User]
}

struct AllCategoriesContext: Encodable {
    let title = "All Categories"
    let categories: Future<[Category]>
}

struct CategoryContext: Encodable {
    let title: String
    let category: Category
    let acronyms: Future<[Acronym]>
}

struct CreateAcronymContext: Encodable {
    let title = "Create An Acronym"
//    let users: Future<[User]>
    let csrfToken: String
}

struct EditAcronymContext: Encodable {
    let title = "Edit Acronym"
    let acronym: Acronym
//    let users: Future<[User]>
    let editing = true
    let categories: Future<[Category]>
}

struct CreateAcronymData: Content {
//    let userID: User.ID
    let short: String
    let long: String
    let categories: [String]?
    let csrfToken: String?
}

struct LoginContext: Encodable {
    let title = "Log In"
    let loginError: Bool
    
    init(loginError: Bool = false) {
        self.loginError = loginError
    }
}

struct LoginPostData: Content {
    let username: String
    let password: String
}

struct RegisterContext: Encodable {
    let title = "Register"
    let message: String?
    init(message: String? = nil) {
        self.message = message
    }
}

struct RegisterData: Content {
    let name: String
    let username: String
    let password: String
    let confirmPassword: String
}

extension RegisterData: Validatable, Reflectable {
    static func validations() throws -> Validations<RegisterData> {
        var validations = Validations(RegisterData.self)
        try validations.add(\.name, .ascii)
        try validations.add(\.username, .alphanumeric && .count(3...))
        try validations.add(\.password, .count(8...))
        validations.add("passwords match") { (model) in
            guard model.password == model.confirmPassword else {
                throw BasicValidationError("password don't match")
            }
        }
        return validations
    }
}

