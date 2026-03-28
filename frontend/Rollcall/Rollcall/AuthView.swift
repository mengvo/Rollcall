//
//  AuthView.swift
//  Rollcall
//
//  Created by Mengzhen Vo on 3/28/26.
//

import SwiftUI

struct AuthView: View {
    @ObservedObject var authManager: AuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text(isSignUp ? "Create Account" : "Welcome Back")
                .font(.largeTitle)
                .fontWeight(.bold)

            VStack(spacing: 16) {
                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal, 32)

            if let error = authManager.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal, 32)
            }

            Button(action: {
                Task {
                    if isSignUp {
                        await authManager.signUp(email: email, password: password)
                    } else {
                        await authManager.signIn(email: email, password: password)
                    }
                }
            }) {
                Text(isSignUp ? "Sign Up" : "Sign In")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(authManager.isLoading || email.isEmpty || password.isEmpty)
            .padding(.horizontal, 32)

            Button(action: { isSignUp.toggle() }) {
                Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                    .font(.footnote)
                    .foregroundColor(.blue)
            }

            Spacer()
        }
    }
}
