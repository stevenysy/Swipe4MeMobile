//
//  MasterView.swift
//  Swipe4MeMobile
//
//  Created by stevenysy on 5/6/25.
//

import SwiftUI

struct MasterView: View {
    @State private var authManager = AuthenticationManager()
    @State private var snackbarManager = SnackbarManager()
    @State private var showAlert = false
    @State private var showSignInView = false

    var body: some View {
        Group {
            switch authManager.authState {

            case .progress:
                ProgressView()

            case .unauthenticated:
                LoginView()
                    .environment(authManager)
            //                    .task {
            //                        do {
            //                            try await Task.sleep(nanoseconds: 2_000_000_000)
            //                            UserManager.shared.clearCurrentUser()
            //                        } catch {
            //                            print("Error \(error.localizedDescription)")
            //                        }
            //                    }

            case .authenticated:
                //                switch UserManager.shared.authenticationViewState {
                //                case .loading:
                //                    ProgressView()
                //                        .task {
                //                            await UserManager.shared.fetchUser()
                //                            UserManager.shared.startListeningForUserChanges()
                //                        }
                //                case .userOnBoarding:
                //                    UserOnboardingView()
                //                        .environment(authManager)
                //                case .home:
                //                    AppView()
                //                        .environment(authManager)
                //                        .task {
                //                            await UserManager.shared.fetchUser()
                //                            UserManager.shared.startListeningForUserChanges()
                //                        }
                //                }
                AppView()
                    .environment(authManager)
            }
        }
        .snackbar(manager: snackbarManager)
        .environment(snackbarManager)
        .animation(.default, value: authManager.authState)
        .onChange(of: authManager.errorMessage) {
            showAlert = !authManager.errorMessage.isEmpty
        }
        .onChange(of: SwipeRequestManager.shared.errorMessage) {
            showAlert = !SwipeRequestManager.shared.errorMessage.isEmpty
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Error"), message: Text(authManager.errorMessage),
                dismissButton: .default(Text("OK")) { authManager.errorMessage = "" })
        }
    }
}
