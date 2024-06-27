import Foundation
import Mockable
import OpenAPIURLSession
import TuistSupport

@Mockable
public protocol CreateProjectServicing {
    func createProject(
        name: String,
        organization: String?,
        serverURL: URL
    ) async throws -> CloudProject
}

enum CreateProjectServiceError: FatalError {
    case unknownError(Int)
    case forbidden(String)
    case badRequest(String)
    case unauthorized(String)

    var type: ErrorType {
        switch self {
        case .unknownError:
            return .bug
        case .forbidden, .badRequest, .unauthorized:
            return .abort
        }
    }

    var description: String {
        switch self {
        case let .unknownError(statusCode):
            return "The project could not be created due to an unknown Cloud response of \(statusCode)."
        case let .forbidden(message), let .badRequest(message), let .unauthorized(message):
            return message
        }
    }
}

public final class CreateProjectService: CreateProjectServicing {
    public init() {}

    public func createProject(
        name: String,
        organization: String?,
        serverURL: URL
    ) async throws -> CloudProject {
        let client = Client.cloud(serverURL: serverURL)

        let response = try await client.createProject(
            .init(
                body: .json(
                    .init(
                        name: name,
                        organization: organization
                    )
                )
            )
        )
        switch response {
        case let .ok(okResponse):
            switch okResponse.body {
            case let .json(project):
                return CloudProject(project)
            }
        case let .forbidden(forbiddenResponse):
            switch forbiddenResponse.body {
            case let .json(error):
                throw CreateProjectServiceError.forbidden(error.message)
            }
        case let .undocumented(statusCode: statusCode, _):
            throw CreateProjectServiceError.unknownError(statusCode)
        case let .badRequest(badRequestResponse):
            switch badRequestResponse.body {
            case let .json(error):
                throw CreateProjectServiceError.badRequest(error.message)
            }
        case let .unauthorized(unauthorized):
            switch unauthorized.body {
            case let .json(error):
                throw DeleteOrganizationServiceError.unauthorized(error.message)
            }
        }
    }
}
