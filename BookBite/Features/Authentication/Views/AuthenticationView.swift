import SwiftUI

struct AuthenticationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: SupabaseAuthService
    @StateObject private var viewModel: AuthViewModel
    @State private var selectedTab = 0
    
    init(authService: SupabaseAuthService) {
        _viewModel = StateObject(wrappedValue: AuthViewModel(authService: authService))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("Welcome to BookBite")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    
                    Text("Sign in to save your reading progress")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                .padding(.bottom, 30)
                
                // Tab Selection
                Picker("", selection: $selectedTab) {
                    Text("Sign In").tag(0)
                    Text("Sign Up").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.bottom, 20)
                
                ScrollView {
                    VStack(spacing: 20) {
                        if selectedTab == 0 {
                            SignInView(viewModel: viewModel)
                        } else {
                            SignUpView(viewModel: viewModel)
                        }
                        
                        // Error Message
                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal)
                                .multilineTextAlignment(.center)
                        }
                        
                        Divider()
                            .padding(.vertical)
                        
                        // Anonymous Option
                        VStack(spacing: 12) {
                            Text("Want to explore first?")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                viewModel.continueAsAnonymous()
                                dismiss()
                            }) {
                                Text("Continue as Guest")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.blue)
                            }
                            
                            Text("You can create an account anytime to save your progress")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.bottom, 30)
                    }
                }
            }
            .background(Color(.systemBackground))
            .sheet(isPresented: $viewModel.showingForgotPassword) {
                ForgotPasswordView(viewModel: viewModel)
            }
            .onChange(of: authService.authState) { _, newState in
                if newState.isAuthenticated {
                    dismiss()
                }
            }
        }
    }
}

struct SignInView: View {
    @ObservedObject var viewModel: AuthViewModel
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Email Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("email@example.com", text: $viewModel.email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .focused($focusedField, equals: .email)
                    .disabled(viewModel.isLoading)
            }
            
            // Password Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                SecureField("Enter your password", text: $viewModel.password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
                    .disabled(viewModel.isLoading)
            }
            
            // Forgot Password
            HStack {
                Spacer()
                Button("Forgot Password?") {
                    viewModel.showingForgotPassword = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            // Sign In Button
            Button(action: {
                Task {
                    await viewModel.signIn()
                }
            }) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                } else {
                    Text("Sign In")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
            }
            .background(viewModel.canSignIn ? Color.blue : Color.gray)
            .cornerRadius(10)
            .disabled(!viewModel.canSignIn)
        }
        .padding(.horizontal)
        .onSubmit {
            if focusedField == .email {
                focusedField = .password
            } else if viewModel.canSignIn {
                Task {
                    await viewModel.signIn()
                }
            }
        }
    }
}

struct SignUpView: View {
    @ObservedObject var viewModel: AuthViewModel
    @FocusState private var focusedField: Field?
    
    enum Field {
        case displayName, email, password, confirmPassword
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Display Name Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Display Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("Your name", text: $viewModel.displayName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.name)
                    .focused($focusedField, equals: .displayName)
                    .disabled(viewModel.isLoading)
            }
            
            // Email Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("email@example.com", text: $viewModel.email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .focused($focusedField, equals: .email)
                    .disabled(viewModel.isLoading)
            }
            
            // Password Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                SecureField("Minimum 6 characters", text: $viewModel.password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .password)
                    .disabled(viewModel.isLoading)
            }
            
            // Confirm Password Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Confirm Password")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                SecureField("Re-enter your password", text: $viewModel.confirmPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .confirmPassword)
                    .disabled(viewModel.isLoading)
            }
            
            // Password Requirements
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.isValidPassword ? "checkmark.circle.fill" : "circle")
                        .font(.caption)
                        .foregroundColor(viewModel.isValidPassword ? .green : .secondary)
                    Text("At least 6 characters")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: viewModel.passwordsMatch && !viewModel.password.isEmpty ? "checkmark.circle.fill" : "circle")
                        .font(.caption)
                        .foregroundColor(viewModel.passwordsMatch && !viewModel.password.isEmpty ? .green : .secondary)
                    Text("Passwords match")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Sign Up Button
            Button(action: {
                Task {
                    await viewModel.signUp()
                }
            }) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                } else {
                    Text("Create Account")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
            }
            .background(viewModel.canSignUp ? Color.green : Color.gray)
            .cornerRadius(10)
            .disabled(!viewModel.canSignUp)
        }
        .padding(.horizontal)
        .onSubmit {
            switch focusedField {
            case .displayName:
                focusedField = .email
            case .email:
                focusedField = .password
            case .password:
                focusedField = .confirmPassword
            case .confirmPassword, .none:
                if viewModel.canSignUp {
                    Task {
                        await viewModel.signUp()
                    }
                }
            }
        }
    }
}

struct ForgotPasswordView: View {
    @ObservedObject var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "envelope.badge")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("Reset Password")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Enter your email address and we'll send you a link to reset your password")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)
                
                if viewModel.resetEmailSent {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.green)
                        
                        Text("Check your email")
                            .font(.headline)
                        
                        Text("We've sent a password reset link to \(viewModel.email)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Done") {
                            dismiss()
                        }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                    .padding(.top, 20)
                } else {
                    VStack(spacing: 16) {
                        TextField("email@example.com", text: $viewModel.email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .disabled(viewModel.isLoading)
                        
                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button(action: {
                            Task {
                                await viewModel.resetPassword()
                            }
                        }) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                            } else {
                                Text("Send Reset Link")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                            }
                        }
                        .background(viewModel.isValidEmail ? Color.blue : Color.gray)
                        .cornerRadius(10)
                        .disabled(!viewModel.isValidEmail || viewModel.isLoading)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}