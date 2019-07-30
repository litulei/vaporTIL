//
//  Acronym.swift
//  App
//
//  Created by bitu on 2019/7/23.
//

import Foundation
import Vapor
import FluentSQLite

// All Fluent models must conform to Codable
final class Acronym: Codable {
    var id: Int?
    var short: String
    var long: String
    var userID: User.ID
    
    init(short: String, long: String, userID: User.ID) {
        self.short = short
        self.long = long
        self.userID = userID
    }
}

/****
// Make Acronym conform to Fluent's Model
extension Acronym: Model {
    // Tell Fluent what database to use for this model
    typealias Database = SQLiteDatabase
    // Tell Fluent what type the ID is
    typealias ID = Int
    // Tell Fluent the key path of the model's ID property
    public static var idKey: IDKey = \Acronym.id
}
****/
// above code can be improved further with SQLiteModel. replace:
extension Acronym: SQLiteModel {}
// The SQLiteModel protocol must have an ID of type Int? call id, but
// there are SQLiteUUIDModel and SQLiteStringModel protocols for models
// with IDs of type UUID or string.
// If you want to costomize the ID property name, you must conform to
// the standard Model protocol

// To save the model in the database, you must create table for it. Fluent
// does this with migration

// For basic models you can use the default implementation for Migration.
// If you need to change your model later or do more complex things, such
// as marking a property as unique, you may need to implement your own
// migrations.

// Migrations only run once; once they have run in a database, they are never
// executed again.

// Foreign key constraints are set up in the migration.
// 1
extension Acronym: Migration {
    // 2 override the default implementation
    static func prepare(on connection: SQLiteConnection) -> Future<Void> {
        // 3 create the table for Acronym in the database
        return Database.create(self, on: connection) { builder in
            // 4
            try addProperties(to: builder)
            // 5
            builder.reference(from: \.userID, to: \User.id)
        }
        
    }

}

// Vapor provides Content, a wrapper around Codable, which allows you to convert
// models and other data between various formats.
extension Acronym: Content {}

extension Acronym: Parameter {}

extension Acronym {
    var user: Parent<Acronym, User> {
        // Use Fluent's parent(_:) function. this takes the key path of the user reference on the acronym
        return parent(\.userID)
    }
    // add a computed property to Acronym to get an acronym's categories.
    // This returns Fluent's generic Sibling type. It returns the siblings
    // of an Acronym that are of type Category and held
    // using the AcronymCategoryPivot
    var categories: Siblings<Acronym, Category, AcronymCategoryPivot> {
        // Use Fluent's siblings() function to retrieve all the categories
        // Fluent handles everything else.
        return siblings()
    }
}


