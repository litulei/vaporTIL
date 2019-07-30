
import Vapor

struct CategoriesController: RouteCollection {
    func boot(router: Router) throws {
        let categoriesRoute = router.grouped("api", "categories")
//        categoriesRoute.post(Category.self, use: createCategoryHandler)
        categoriesRoute.get(use: getAllCategoriesHandler)
        categoriesRoute.get(Category.parameter, use: getCategoryHandler)
        categoriesRoute.get(Category.parameter, "acronyms", use: getAcronymsFromCategoryHandler)
        
        let tokenAuthMiddleware = User.tokenAuthMiddleware()
        let guardAuthMiddleware = User.guardAuthMiddleware()
        let tokenAuthGroup = categoriesRoute.grouped(tokenAuthMiddleware, guardAuthMiddleware)
        tokenAuthGroup.post(Category.self, use: createCategoryHandler)
    }
}

func createCategoryHandler(_ req: Request, category: Category) throws -> Future<Category> {
    return category.save(on: req)
}

func getAllCategoriesHandler(_ req: Request) throws -> Future<[Category]> {
    return Category.query(on: req).all()
}

func getCategoryHandler(_ req: Request) throws -> Future<Category> {
    return try req.parameters.next(Category.self)
}

func getAcronymsFromCategoryHandler(_ req: Request) throws -> Future<[Acronym]> {
    return try req.parameters.next(Category.self).flatMap(to: [Acronym].self, { (category) in
        try category.acronyms.query(on: req).all()
    })
}
