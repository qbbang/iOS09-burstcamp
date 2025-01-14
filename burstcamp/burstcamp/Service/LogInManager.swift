//
//  LogInManager.swift
//  Eoljuga
//
//  Created by 김기훈 on 2022/11/18.
//

import Combine
import UIKit

import FirebaseAuth

final class LogInManager {

    static let shared = LogInManager()

    private init () {}

    private var cancelBag = Set<AnyCancellable>()

    var logInPublisher = PassthroughSubject<AuthCoordinatorEvent, Never>()

    var userUUID: String {
        return Auth.auth().currentUser?.uid ?? ""
    }

    private var githubAPIKey: Github? {
        guard let serviceInfoURL = Bundle.main.url(
            forResource: "Service-Info",
            withExtension: "plist"
        ),
              let data = try? Data(contentsOf: serviceInfoURL),
              let apiKey = try? PropertyListDecoder().decode(APIKey.self, from: data)
        else { return nil }
        return apiKey.github
    }

    func isLoggedIn() -> Bool {
        guard Auth.auth().currentUser != nil else { return false }
        return true
    }

    func openGithubLoginView() {
        let urlString = "https://github.com/login/oauth/authorize"

        guard var urlComponent = URLComponents(string: urlString),
              let clientID = githubAPIKey?.clientID
        else {
            return
        }

        urlComponent.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "scope", value: "admin:org")
        ]

        guard let url = urlComponent.url else { return }

        UIApplication.shared.open(url)
    }

    func logIn(code: String) {
        var token: String = ""
        var nickname: String = ""

        requestGithubAccessToken(code: code)
            .map { $0.accessToken }
            .flatMap { accessToken -> AnyPublisher<GithubUser, NetworkError> in
                token = accessToken
                return self.requestGithubUserInfo(token: accessToken)
            }
            .map { $0.login }
            .flatMap { name -> AnyPublisher<GithubMembership, NetworkError> in
                nickname = name
                return self.getOrganizationMembership(nickname: nickname, token: token)
            }
            .flatMap { _ -> AnyPublisher<User, NetworkError> in
                return FireStoreService.fetchUser(by: self.userUUID)
            }
            .receive(on: DispatchQueue.main)
            .sink { result in
                switch result {
                case .finished:
                    print("finished")
                case .failure(let error):
                    self.switchError(error: error, nickname: nickname)
                }
            } receiveValue: { user in
                self.signInToFirebase(user: user, token: token)
            }
            .store(in: &cancelBag)
    }

    func switchError(error: NetworkError, nickname: String) {
        // TODO: switch -> 함수 분리 필요
        switch error {
        case .responseDecoingError:
            /// 멤버 O, 회원가입 X
            self.logInPublisher.send(.moveToDomainScreen(userUUID, nickname))
        default:
            /// 멤버 X
            // TODO: alert
            print("default")
        }
    }

    func signInToFirebase(user: User, token: String) {
        let credential = GitHubAuthProvider.credential(withToken: token)

        Auth.auth().signIn(with: credential) { result, error in
            guard result != nil,
                  error == nil
            else {
                return
            }

            self.logInPublisher.send(.moveToTabBarScreen)
        }
    }

    func requestGithubAccessToken(code: String) -> AnyPublisher<GithubToken, NetworkError> {
        let urlString = "https://github.com/login/oauth/access_token"

        guard let githubAPIKey = githubAPIKey
        else {
            return Fail(error: NetworkError.unknownError).eraseToAnyPublisher()
        }

        let bodyInfos: [String: String] = [
            "client_id": githubAPIKey.clientID,
            "client_secret": githubAPIKey.clientSecret,
            "code": code
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: bodyInfos)
        else {
            return Fail(error: NetworkError.encodingError)
                .eraseToAnyPublisher()
        }

        let httpHeaders = [
            HTTPHeader.contentTypeApplicationJSON.keyValue,
            HTTPHeader.acceptApplicationJSON.keyValue
        ]

        let request = URLSessionService.request(
            urlString: urlString,
            httpMethod: .POST,
            httpHeaders: httpHeaders,
            httpBody: bodyData
        )

        return request
            .decode(type: GithubToken.self, decoder: JSONDecoder())
            .mapError { _ in NetworkError.responseDecoingError }
            .eraseToAnyPublisher()
    }

    func requestGithubUserInfo(token: String) -> AnyPublisher<GithubUser, NetworkError> {
        let urlString = "https:/api.github.com/user"

        let httpHeaders = [
            HTTPHeader.contentTypeApplicationJSON.keyValue,
            HTTPHeader.acceptApplicationVNDGithubJSON.keyValue,
            HTTPHeader.authorizationBearer(token: token).keyValue
        ]

        let request = URLSessionService.request(
            urlString: urlString,
            httpMethod: .GET,
            httpHeaders: httpHeaders
        )

        return request
            .decode(type: GithubUser.self, decoder: JSONDecoder())
            .mapError { _ in NetworkError.responseDecoingError }
            .eraseToAnyPublisher()
    }

    func getOrganizationMembership(
        nickname: String,
        token: String
    ) -> AnyPublisher<GithubMembership, NetworkError> {
        let urlString = "https://api.github.com/orgs/boostcampwm-2022/memberships/\(nickname)"

        let httpHeaders = [
            HTTPHeader.contentTypeApplicationJSON.keyValue,
            HTTPHeader.acceptApplicationVNDGithubJSON.keyValue,
            HTTPHeader.authorizationBearer(token: token).keyValue
        ]

        let request = URLSessionService.request(
            urlString: urlString,
            httpMethod: .GET,
            httpHeaders: httpHeaders
        )

        return request
            .decode(type: GithubMembership.self, decoder: JSONDecoder())
            .mapError { _ in NetworkError.responseDecoingError }
            .eraseToAnyPublisher()
    }
}
