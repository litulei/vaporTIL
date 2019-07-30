
import Vapor
import Imperial
import Authentication


/**
 1 user
 Client ID
 cbb284f5ad43729e967d
 Client Secret
 5834bef7cb48901803c61acc2f630b478444c1f3
 ***/
struct ImperialController: RouteCollection {
    func boot(router: Router) throws {
        // This is the URL you set up when registering the application with GitHub
        guard let githubCallbackURL = Environment.get("GITHUB_CALLBACK_URL") else {
            fatalError("GitHub callback URL not set")
        }
        try router.oAuth(from: GitHub.self, authenticate: "login-github", callback: githubCallbackURL, completion: processGitHubLogin)
    }
    
    func processGitHubLogin(request: Request, token: String) throws -> Future<ResponseEncodable> {
        return try GitHub.getUser(on: request).flatMap(to: ResponseEncodable.self) { userInfo in
            return User.query(on: request).filter(\.username == userInfo.login)
                .first().flatMap(to: ResponseEncodable.self) { foundUser in
                    guard let existingUser = foundUser else {
                        let user = User(name: userInfo.name, username: userInfo.login, password: UUID().uuidString)
                        return user.save(on: request).map(to: ResponseEncodable.self) { user in
                            try request.authenticateSession(user)
                            return request.redirect(to: "/")
                        }
                    }
                    try request.authenticateSession(existingUser)
                    return request.future(request.redirect(to: "/"))
            }
        }
    }
}

struct GitHubUserInfo: Content {
    let name: String
    let login: String
}

extension GitHub {
    static func getUser(on request: Request) throws -> Future<GitHubUserInfo> {
        var headers = HTTPHeaders()
        headers.bearerAuthorization = try BearerAuthorization(token: request.accessToken())
        
        let githubUserAPIURL = "https://api.github.com/user"
        return try request.client().get(githubUserAPIURL, headers: headers).map(to: GitHubUserInfo.self) { response in
            guard response.http.status == .ok else {
                if response.http.status == .unauthorized {
                    throw Abort.redirect(to: "/login-github")
                } else {
                    throw Abort(.internalServerError)
                }
            }
            return try response.content.syncDecode(GitHubUserInfo.self)
        }
    }
}
