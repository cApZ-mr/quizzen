//
//  CountrySelectionSheet.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 22.07.26.
//

import Foundation
import SwiftUI

struct CountrySelectionSheet: View {
    @Binding var selectedCode: String
    @Binding var searchText: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            CountrySelectionView(
                selectedCode: $selectedCode,
                searchText: $searchText
            )
            .navigationTitle("Land wählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}
