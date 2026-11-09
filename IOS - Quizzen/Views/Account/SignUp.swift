//
//  Signup.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 21.06.26.
//
import SwiftUI
import PhotosUI
import Combine
import Supabase

// MARK: - ProfileSetupView
struct SignupView: View {
    @EnvironmentObject var viewModel: UserViewModel
    @Environment(\.dismiss) private var dismiss
    
    @Binding var profileCreated: Bool
    
    @State private var currentPage: Int = 0
    @State private var introTextVisible = false
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var isLoadingImage = false
    
    @State private var countrySearchText: String = ""
    
    @State private var validationMessage: String?

    @State private var progress: CGFloat = 0
    @State private var loadingText = ""
    @State private var isLoading = false

    @State private var signUpFailed = false
    @State private var signUpErrorMessage: String?

    @State private var selectedContinent: UserViewModel.Continent = .europe
    private let lastPage = 2
    private func filteredCountries(for continent: UserViewModel.Continent) -> [UserViewModel.Country] {
        let base = viewModel.countries.filter { $0.continent == continent }
        guard !countrySearchText.isEmpty else { return base }
        return base.filter {
            $0.name.localizedCaseInsensitiveContains(countrySearchText)
        }
    }

    private func loadImage() async {
        isLoadingImage = true
        defer { isLoadingImage = false }
        if let data = try? await selectedItem?.loadTransferable(type: Data.self) {
            viewModel.profileImageData = ProfileImageCache.jpegForUpload(data) ?? data
        }
    }
    
    var body: some View {
        ZStack {
            switch currentPage {
            case 0:
                profilePage
            case 1:
                profilePicturePage
            case 2:
                countryPage
            default:
                getStartedPage
            }
        }
        .animation(.easeInOut(duration: 0.45), value: currentPage)
        .onAppear{ resetFormFields() }
    }
    
    private func resetFormFields() {
        viewModel.username = ""
        viewModel.email = ""
        viewModel.password = ""
        viewModel.profileImageData = nil
        viewModel.selectedOriginCode = ""
        selectedItem = nil
        countrySearchText = ""
        currentPage = 0
    }

    // MARK: - Seite 0: Intro
    private var introPage: some View {
        SetupPage(imageName: "AppIconDark", showProgress: false, currentPage: currentPage, lastPage: lastPage, buttonsDelay: 2) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Willkommen")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundColor(.white)
                Text("Lass uns dein Profil in wenigen\nSchritten einrichten.")
                    .font(.system(.callout, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)
            .padding(.top, 300)
            .offset(y: introTextVisible ? 0 : 40)
            .opacity(introTextVisible ? 1 : 0)
            .onAppear {
                withAnimation(.easeOut(duration: 1.5).delay(0.5)) {
                    introTextVisible = true
                }
            }
        } onBack: {
            goToPreviousPage()
        } onContinue: {
            goToNextPage()
        }
    }
    // MARK: - Seite 1: Profil (Username, E-Mail & Passwort)
    private var profilePage: some View {
        SetupPage(imageName: nil, showProgress: true, currentPage: currentPage, lastPage: lastPage) {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Deine Nutzerdaten")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundColor(.white)
                    Text("Dein Account wird sicher gespeichert und synchronisiert.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: "person.fill")
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 20)
                        TextField("", text: $viewModel.username, prompt: Text("Benutzername").foregroundColor(.white.opacity(0.4)))
                            .foregroundColor(.white)
                            .autocorrectionDisabled()
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(14)
                    HStack(spacing: 12) {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 20)
                        TextField("", text: $viewModel.email, prompt: Text("E-Mail").foregroundColor(.white.opacity(0.4)))
                            .foregroundColor(.white)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(14)
                    HStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 20)
                        SecureField("", text: $viewModel.password, prompt: Text("Passwort").foregroundColor(.white.opacity(0.4)))
                            .foregroundColor(.white)
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(14)
                }
                .padding(.horizontal, 24)

                legalConsent
                    .padding(.horizontal, 32)

                Button {
                    dismiss()
                } label: {
                    Text("Schon einen Account? Einloggen")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
        } onBack: {
            goToPreviousPage()
        } onContinue: {
            if let problem = UsernameFilter.validationError(for: viewModel.username) {
                showValidationMessage(problem)
                return
            }
            guard isValidEmail(viewModel.email) else {
                showValidationMessage("Bitte gib eine gültige E-Mail-Adresse ein")
                return
            }
            guard viewModel.password.count >= 6 else {
                showValidationMessage("Passwort muss mind. 6 Zeichen haben")
                return
            }
            goToNextPage()
        }
        .overlay(alignment: .top) {
            if let validationMessage {
                validationBanner(validationMessage)
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Validierungs-Banner (wiederverwendbar)
    private func validationBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.system(.subheadline, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.12))
        .clipShape(Capsule())
    }
    private func showValidationMessage(_ message: String) {
        withAnimation(.easeOut(duration: 0.25)) {
            validationMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeIn(duration: 0.25)) {
                validationMessage = nil
            }
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let regex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: regex, options: .regularExpression) != nil
    }
    
    // MARK: - Seite 2: Profilbild
    private var profilePicturePage: some View {
        SetupPage(imageName: nil, showProgress: true, currentPage: currentPage, lastPage: lastPage) {
            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Text("Wähle ein Profilbild")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundColor(.white)
                    Text("Optional – du kannst es jederzeit später ändern.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                // Werte vorab lesen: das PhotosPicker-Label ist nicht MainActor-isoliert
                let profileImage = viewModel.profileImage
                let isLoadingImage = isLoadingImage
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 140, height: 140)
                        profileImage
                            .resizable()
                            .scaledToFill()
                            .frame(width: 132, height: 132)
                            .clipShape(Circle())
                        Circle()
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                            .frame(width: 140, height: 140)
                        if isLoadingImage {
                            Circle()
                                .fill(Color.black.opacity(0.5))
                                .frame(width: 140, height: 140)
                            ProgressView()
                                .tint(.white)
                        }
                        Circle()
                            .fill(Color.brand)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .font(.system(.subheadline, weight: .semibold))
                                    .foregroundColor(.white)
                            )
                            .overlay(
                                Circle().strokeBorder(Color.black, lineWidth: 3)
                            )
                            .offset(x: 48, y: 48)
                    }
                }
                .onChange(of: selectedItem) { _, _ in
                    Task { await loadImage() }
                }
                if viewModel.profileImageData != nil {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.profileImageData = nil
                            selectedItem = nil
                        }
                    } label: {
                        Text("Bild entfernen")
                            .font(.system(.subheadline, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
        } onBack: {
            goToPreviousPage()
        } onContinue: {
            goToNextPage()
        }
    }
    // MARK: - Seite 3: Länderauswahl
    private var countryPage: some View {
        SetupPage(imageName: nil, showProgress: true, currentPage: currentPage, lastPage: lastPage) {
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Text("Repräsentiertes Land")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundColor(.white)
                    Text("Optional – wähle das Land, welches du repräsentieren möchtest.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.vertical, 25)
                CountrySelectionView(
                    selectedCode: $viewModel.selectedOriginCode,
                    searchText: $countrySearchText
                )
            }
        } onBack: {
            goToPreviousPage()
        } onContinue: {
            goToNextPage()
            startProfileCreation()
        }
    }
    // MARK: - Seite 4: Fertig
    private var getStartedPage: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 36) {
                ZStack {
                    // Hintergrund-Ring (statisch)
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 6)
                        .frame(width: 150, height: 150)
                    // Fortschritts-Ring
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            AngularGradient(
                                colors: [Color.brand, .white],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 150, height: 150)
                        .rotationEffect(.degrees(-90))
                        .shadow(color: Color.brand.opacity(0.6), radius: 12)
                    if signUpFailed {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .frame(width: 50, height: 50)
                            .foregroundColor(.red)
                    } else if showCheckmark {
                        Checkmark()
                            .trim(from: 0, to: checkmarkProgress)
                            .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .scaleEffect(checkmarkScale)
                    } else {
                        GIFView(gifName: "AppIconGif")
                            .frame(width: 90, height: 90)
                            .clipShape(RoundedRectangle(cornerRadius: 22))
                            .opacity(isLoading ? 1 : 0)
                    }
                    // Partikel-Burst beim Erfolg
                    if showBurst {
                        ForEach(0..<14, id: \.self) { i in
                            Circle()
                                .fill(i % 2 == 0 ? Color.brand : Color.white)
                                .frame(width: 6, height: 6)
                                .offset(burstOffset(for: i))
                                .opacity(burstOpacity)
                        }
                    }
                }
                VStack(spacing: 12) {
                    Text(loadingText)
                        .font(.system(.title3, design: .rounded, weight: .medium))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .id(loadingText) // erzwingt Transition bei Textwechsel
                        .transition(.opacity.combined(with: .move(edge: .bottom)))

                    if signUpFailed {
                        Button {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                currentPage = 1
                                signUpFailed = false
                                signUpErrorMessage = nil
                            }
                        } label: {
                            Text("Erneut versuchen")
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 40)
                .animation(.easeInOut(duration: 0.3), value: loadingText)
            }
        }
    }
    @State private var showCheckmark = false
    @State private var checkmarkProgress: CGFloat = 0
    @State private var checkmarkScale: CGFloat = 0.6
    @State private var showBurst = false
    @State private var burstOpacity: Double = 1
    @State private var burstRadius: CGFloat = 0
    private func burstOffset(for index: Int) -> CGSize {
        let angle = Double(index) / 14.0 * 2 * .pi
        return CGSize(
            width: cos(angle) * burstRadius,
            height: sin(angle) * burstRadius
        )
    }

    // MARK: - Profil-Erstellung
    private func startProfileCreation() {
        progress = 0
        loadingText = "Accountdaten werden verarbeitet"
        isLoading = true
        showCheckmark = false
        checkmarkProgress = 0
        checkmarkScale = 0.6
        showBurst = false
        burstOpacity = 1
        burstRadius = 0
        signUpFailed = false
        signUpErrorMessage = nil

        withAnimation(.linear(duration: 5)) {
            progress = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            withAnimation { loadingText = "Profil wird zusammengestellt" }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) {
            withAnimation { loadingText = "App wird vorbereitet" }
        }
        
        

        // Supabase-Call, läuft parallel zur Animation
        Task {
            do {
                let result = try await supabase.auth.signUp(
                    email: viewModel.email,
                    password: viewModel.password
                )
                
                var avatarUrl: String? = nil

                if let imageData = viewModel.profileImageData {
                    // Gleicher Pfad wie in SupabaseClient.uploadAvatar (Ordner = User-ID)
                    let fileName = "\(result.user.id.uuidString)/avatar.jpg"

                    try await supabase.storage
                        .from("avatars")
                        .upload(fileName, data: imageData, options: FileOptions(contentType: "image/jpeg", upsert: true))
                    
                    avatarUrl = try supabase.storage
                        .from("avatars")
                        .getPublicURL(path: fileName)
                        .absoluteString
                }

                try await supabase
                    .from("accounts")
                    .update([
                        "username": viewModel.username,
                        "avatar_url": avatarUrl,
                        "country": viewModel.selectedOriginCode
                    ])
                    .eq("id", value: result.user.id)
                    .select()
                    .execute()


                await MainActor.run {
                    showSuccessAnimation()
                }
            } catch {
                log.error("Fehler bei Supabase-Registrierung: \(error.localizedDescription)")
                await MainActor.run {
                    showFailureState(error)
                }
            }
        }
    }

    /// Hinweis auf Regeln und Datenschutz (App-Store-Richtlinie 1.2: keine Toleranz für anstößige Inhalte)
    private var legalConsent: some View {
        var text = AttributedString("Mit der Registrierung akzeptierst du unsere ")
        var terms = AttributedString("Nutzungsbedingungen")
        if let url = AppLinks.terms { terms.link = url; terms.underlineStyle = .single }
        var privacy = AttributedString("Datenschutzerklärung")
        if let url = AppLinks.privacyPolicy { privacy.link = url; privacy.underlineStyle = .single }
        text += terms + AttributedString(" und ") + privacy
            + AttributedString(". Beleidigende oder anstößige Inhalte werden nicht toleriert und führen zur Sperrung.")
        return Text(text)
            .font(.system(.caption, design: .rounded))
            .foregroundColor(.white.opacity(0.5))
            .tint(.white.opacity(0.8))
            .multilineTextAlignment(.center)
    }

    private func showSuccessAnimation() {
        loadingText = "Fertig!"
        let haptic = UINotificationFeedbackGenerator()
        haptic.notificationOccurred(.success)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            showCheckmark = true
            checkmarkScale = 1.0
        }
        withAnimation(.easeOut(duration: 0.4)) {
            checkmarkProgress = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showBurst = true
            withAnimation(.easeOut(duration: 0.6)) {
                burstRadius = 90
                burstOpacity = 0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.5)) {
                profileCreated = true
            }
        }
        
        viewModel.password = ""
    }

    private func showFailureState(_ error: Error) {
        let haptic = UINotificationFeedbackGenerator()
        haptic.notificationOccurred(.error)
        signUpFailed = true
        signUpErrorMessage = error.localizedDescription
        withAnimation {
            loadingText = "Etwas ist schiefgelaufen"
        }
    }

    // MARK: - Checkmark Shape
    nonisolated struct Checkmark: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            return path
        }
    }
    // MARK: - Navigation
    private func goToNextPage() {
        withAnimation(.easeInOut(duration: 0.4)) {
            currentPage += 1
        }
    }
    private func goToPreviousPage() {
        withAnimation(.easeInOut(duration: 0.4)) {
            currentPage -= 1
        }
    }
}
// MARK: - Wiederverwendbarer Seiten-Container
struct SetupPage<Content: View>: View {
    let imageName: String?
    let showProgress: Bool
    let currentPage: Int
    let lastPage: Int
    var continueTitle: String = "Weiter"
    var buttonsDelay: Double = 0
    
    @ViewBuilder var content: Content
    
    let onBack: () -> Void
    let onContinue: () -> Void
    
    @State private var buttonsVisible = false
    
    var body: some View {
        ZStack {
            if let imageName {
                SetupBackground(imageName: imageName)
            } else {
                Color.black.ignoresSafeArea()
            }
            VStack(spacing: 0) {
                if showProgress {
                    progressIndicator
                        .padding(.top, 80)
                        .padding(.horizontal, 32)
                }
                Spacer()
                content
                Spacer()
                buttons
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    .opacity(buttonsVisible ? 1 : 0)
                    .disabled(!buttonsVisible)
                    .onAppear {
                        buttonsVisible = false
                        withAnimation(.easeOut(duration: 0.5).delay(buttonsDelay)) {
                            buttonsVisible = true
                        }
                    }
            }
        }
        .ignoresSafeArea()
    }
    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(1...lastPage, id: \.self) { index in
                Capsule()
                    .fill(index <= currentPage ? Color.white : Color.white.opacity(0.2))
                    .frame(height: 5)
                    .frame(maxWidth: .infinity)
                    .animation(.easeInOut(duration: 0.3), value: currentPage)
            }
        }
    }
    private var buttons: some View {
        HStack(spacing: 16) {
            if currentPage >= 1 {
                Button(action: onBack) {
                    Text("Zurück")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(28)
                }
            }
            Button(action: onContinue) {
                Text(continueTitle)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .cornerRadius(28)
            }
        }
    }
}
// MARK: - Setup Hintergrund
struct SetupBackground: View {
    let imageName: String
    private let glowColor = Color.brand
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            GeometryReader { geo in
                let maxDimension = max(geo.size.width, geo.size.height)
                RadialGradient(
                    colors: [Color.black, glowColor],
                    center: .center,
                    startRadius: maxDimension * 0.25,
                    endRadius: maxDimension * 0.75
                )
            }
            // Scharfe Kontur am Rand
            RoundedRectangle(cornerRadius: 60)
                .strokeBorder(glowColor, lineWidth: 5)
                .shadow(color: glowColor.opacity(0.8), radius: 30)
                .ignoresSafeArea()
            Image(imageName)
                .resizable()
                .scaledToFit()
                .opacity(0.75)
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .ignoresSafeArea()
    }
}
// MARK: - Preview
#Preview {
    SignupView(profileCreated: .constant(false))
        .environmentObject(UserViewModel())
}
