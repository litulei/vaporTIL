
import Foundation
import Vapor
import FluentSQLite
import Authentication

final class User: Codable {
    var id: UUID?
    var name: String
    var username: String
    var password: String
    
    init(name: String, username: String, password: String) {
        self.name = name
        self.username = username
        self.password = password
    }
    // This creates an inner class to represent a public view of User.
    final class Public: Codable {
        var id: UUID?
        var name: String
        var username: String
        
        init(id: UUID?, name: String, username: String) {
            self.id = id
            self.name = name
            self.username = username
        }
    }
}

// Because the model's id property is a UUID
extension User: SQLiteUUIDModel {}
extension User: Content {}
extension User: Migration {
    static func prepare(on connection: SQLiteConnection) -> Future<Void> {
        // Create User table
        return Database.create(self, on: connection) { builder in
            try addProperties(to: builder)
            builder.unique(on: \.username)
        }
    }
}
extension User: Parameter {}

extension User.Public: Content {}

extension User {
    var acronyms: Children<User, Acronym> {
        // Use Fluent's children(_:) function to retrieve the children.
        // This takes the key path of the user reference on the acronym.
        return children(\.userID)
    }
}

extension User {
    func convertToPublic() -> User.Public {
        return User.Public(id: id, name: name, username: username)
    }
}

extension Future where T: User {
    func convertToPublic() -> Future<User.Public> {
        return self.map(to: User.Public.self, { (user) in
            return user.convertToPublic()
        })
    }
}

extension User: BasicAuthenticatable {
    // Tell Vapor which key path of User is the username
    static let usernameKey: UsernameKey = \User.username
    // Tell Vapor which key path of User is the password
    static let passwordKey: PasswordKey = \User.password
}


// Conform User to TokenAuthenticatable. This allow a token
// to authenticate a user
extension User: TokenAuthenticatable {
    typealias TokenType = Token
}

struct AdminUser: Migration {
    typealias Database = SQLiteDatabase
    static func prepare(on connnection: SQLiteConnection) -> Future<Void> {
        let password = try? BCrypt.hash("password")
        guard let hashedPassword = password else {
            fatalError("Failed to create admin user")
        }
        let user = User(name: "Admin", username: "Admin", password: hashedPassword)
        return user.save(on: connnection).transform(to: ())
    }
    
    static func revert(on connnection: SQLiteConnection) -> Future<Void> {
        return .done(on: connnection)
    }
}

// Conform User to PasswordAuthenticatable. This allows Vapor to authenticate users
// with a username and password when they log in. Since you have already implemented
// the necessary properties for PasswordAuthenticatable in BasicAuthenticatable, there
// is nothing to do here
extension User: PasswordAuthenticatable {}
// Conform User to SessionAuthenticatable. This allows the application to save and retrieve
// your user as part of a session
extension User: SessionAuthenticatable {}
