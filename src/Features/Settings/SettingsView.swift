import SwiftUI
import ComposableArchitecture

struct SettingsView: View {
    @Bindable var store: StoreOf<SettingsFeature>
    
    var body: some View {
        Form {
            Section("Display") {
                HStack {
                    Text("Icon Size")
                    Slider(
                        value: Binding(
                            get: { store.preferences.iconSize },
                            set: { store.send(.setIconSize($0)) }
                        ),
                        in: 48...128,
                        step: 8
                    )
                    Text("\(Int(store.preferences.iconSize))pt")
                        .frame(width: 40, alignment: .trailing)
                }
                
                Stepper(
                    "Columns: \(store.preferences.columns)",
                    value: Binding(
                        get: { store.preferences.columns },
                        set: { store.send(.setColumns($0)) }
                    ),
                    in: 3...10
                )
            }
            
            Section("Apps") {
                Toggle(
                    "Show hidden apps",
                    isOn: Binding(
                        get: { store.preferences.showHiddenApps },
                        set: { store.send(.setShowHiddenApps($0)) }
                    )
                )
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 280)
    }
}