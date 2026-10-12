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
                        value: $store.preferences.iconSize.sending(\.setIconSize),
                        in: UserPreferences.iconSizeRange,
                        step: 4
                    )
                    Text("\(Int(store.preferences.iconSize))pt")
                        .frame(width: 40, alignment: .trailing)
                }
                
                Stepper(
                    "Columns: \(store.preferences.columns)",
                    value: $store.preferences.columns.sending(\.setColumns),
                    in: UserPreferences.columnsRange
                )
            }
            
            Section("Apps") {
                Toggle(
                    "Show hidden apps",
                    isOn: $store.preferences.showHiddenApps.sending(\.setShowHiddenApps)
                )
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 280)
    }
}
