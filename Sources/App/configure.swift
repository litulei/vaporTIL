//import FluentMySQL
import FluentSQLite
import Vapor
import Leaf
import Authentication


/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
    // Register the FluentSQLiteProvider as a service to allow the application to interact
    // with SQLite via Fluent
//    try services.register(FluentMySQLProvider())
    try services.register(FluentSQLiteProvider())
    try services.register(LeafProvider())
    try services.register(AuthenticationProvider())

    // Register routes to the router
    let router = EngineRouter.default()
    try routes(router)
    services.register(router, as: Router.self)

    // Register middleware
    var middlewares = MiddlewareConfig() // Create _empty_ middleware config
    middlewares.use(FileMiddleware.self) // Serves files from `Public/` directory
    middlewares.use(ErrorMiddleware.self) // Catches errors and converts to HTTP response
    middlewares.use(SessionsMiddleware.self)
    services.register(middlewares)
    
    var databases = DatabasesConfig()
    let sqlite = try SQLiteDatabase(storage: .memory)
//    let hostname = Environment.get("DATABASE_HOSTNAME") ?? "localhost"
//    let username = Environment.get("DATABASE_USER") ?? "vapor"
//    let password = Environment.get("DATABASE_PASSWORD") ?? "password"
//    let databaseName = Environment.get("DATABASE_DB") ?? "vapor"
//    let databasePort = 3306
//    // Configure a SQLite database
//    let databaseConfig = MySQLDatabaseConfig(hostname: hostname,port: databasePort, username: username, password: password, database: databaseName)


    // Register the configured SQLite database to the database config.
//    let database = MySQLDatabase(config: databaseConfig)
    databases.add(database: sqlite, as: .sqlite)
    services.register(databases)

    // Configure migrations
    var migrations = MigrationConfig()
    migrations.add(model: User.self, database: .sqlite)
    migrations.add(model: Acronym.self, database: .sqlite)
    migrations.add(model: Category.self, database: .sqlite)
    migrations.add(model: AcronymCategoryPivot.self, database: .sqlite)
    migrations.add(model: Token.self, database: .sqlite)
    migrations.add(migration: AdminUser.self, database: .sqlite)
    services.register(migrations)
    // This tells Vapor to use LeafRenderer when asked for a ViewRenderer type
    config.prefer(LeafRenderer.self, for: ViewRenderer.self)
    // The KeyedCache service is a key-value cache that backs sessions
    config.prefer(MemoryKeyedCache.self, for: KeyedCache.self)
}
