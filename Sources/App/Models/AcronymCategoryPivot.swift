
import FluentMySQL
import Foundation

final class AcronymCategoryPivot: MySQLUUIDPivot {
    var id: UUID?
    var acronymID: Acronym.ID
    var categoryID: Category.ID
    
    typealias Left = Acronym
    typealias Right = Category
    
    static let leftIDKey: LeftIDKey = \.acronymID
    static let rightIDKey: RightIDKey = \.categoryID
    
    init(_ acronym: Acronym, _ category: Category) throws {
        self.categoryID = try category.requireID()
        self.acronymID = try acronym.requireID()
    }
}

extension AcronymCategoryPivot: Migration {
    static func prepare(on connection: MySQLConnection) -> Future<Void> {
        // create the table for AcronymCategoryPivot and the id property on Acronym.
        
        return Database.create(self, on: connection) { builder in
            try addProperties(to: builder)
            // Add a reference between the categoryID property on
            // AcronymCategoryPivot and the id property on Category.
            // This set up the foreign key constraint. Also set the
            // schema reference action for deletion when deleting the
            // category
            builder.reference(from: \.acronymID, to: \Acronym.id, onDelete:.cascade)
        }
    }
}
extension AcronymCategoryPivot: ModifiablePivot {}

