//
//  SettingsView.swift
//  NutrAItion
//

import SwiftUI

struct SettingsView: View {
    @State private var usdaApiKeyInput = ""
    @State private var anthropicApiKeyInput = ""
    @State private var usdaSavedNotice = false
    @State private var anthropicSavedNotice = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField(
                        "Paste key here",
                        text: $usdaApiKeyInput
                    )
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    Button("Save USDA key") {
                        saveUSDA()
                    }
                    if usdaSavedNotice {
                        Text("Saved")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("USDA Food Database Key (free — api.nal.usda.gov)")
                } footer: {
                    Text("Get a free key at FoodData Central. Required for food search.")
                }

                Section {
                    SecureField(
                        "Paste key here",
                        text: $anthropicApiKeyInput
                    )
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    Button("Save Claude key") {
                        saveAnthropic()
                    }
                    if anthropicSavedNotice {
                        Text("Saved")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Anthropic API Key")
                } footer: {
                    Text("Used when barcode data is incomplete (macro fill) and for chat in later phases.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                usdaApiKeyInput = KeychainManager.load(key: Keys.usdaApiKey) ?? ""
                anthropicApiKeyInput = KeychainManager.load(key: Keys.anthropicApiKey) ?? ""
            }
        }
    }

    private func saveUSDA() {
        usdaSavedNotice = KeychainManager.save(key: Keys.usdaApiKey, value: usdaApiKeyInput)
        if usdaSavedNotice {
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run { usdaSavedNotice = false }
            }
        }
    }

    private func saveAnthropic() {
        anthropicSavedNotice = KeychainManager.save(key: Keys.anthropicApiKey, value: anthropicApiKeyInput)
        if anthropicSavedNotice {
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run { anthropicSavedNotice = false }
            }
        }
    }
}

#Preview {
    SettingsView()
}
