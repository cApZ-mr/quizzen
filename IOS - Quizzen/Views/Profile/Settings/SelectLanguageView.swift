//
//  SelectLanguageView.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 23.06.26.
//

import Foundation
import SwiftUI

struct SelectLanguageView: View {
    
    var body: some View {
        VStack {
            ContentUnavailableView.search

        }
        .navigationTitle("Sprache")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}
