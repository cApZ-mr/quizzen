//
//  CountrySelectionView.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 30.06.26.
//

import Foundation
import SwiftUI

struct CountrySelectionView: View {
    @Binding var selectedCode: String
    @Binding var searchText: String

    @State private var selectedContinent: UserViewModel.Continent = .europe

    private let countries: [UserViewModel.Country] = UserViewModel.allCountries

    private func filteredCountries(for continent: UserViewModel.Continent) -> [UserViewModel.Country] {
        let base = countries.filter { $0.continent == continent }

        guard !searchText.isEmpty else { return base }

        return base.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.5))

                TextField("Land suchen", text: $searchText)
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
            }
            .padding(12)
            .background(Color.white.opacity(0.08))
            .cornerRadius(12)
            .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(UserViewModel.Continent.allCases) { continent in
                        continentChip(continent)
                    }
                }
                .padding(.horizontal, 24)
            }

            TabView(selection: $selectedContinent) {
                ForEach(UserViewModel.Continent.allCases) { continent in
                    continentGrid(continent)
                        .tag(continent)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 420)
        }
    }

    private func continentChip(_ continent: UserViewModel.Continent) -> some View {
        let isSelected = selectedContinent == continent

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedContinent = continent
            }
        } label: {
            Text(continent.rawValue)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .white.opacity(0.5))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.brand : Color.white.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
    }

    private func continentGrid(_ continent: UserViewModel.Continent) -> some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 16) {
                ForEach(filteredCountries(for: continent), id: \.code) { country in
                    countryTile(country)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)
            .padding(.bottom, 12)
        }
    }

    private func countryTile(_ country: UserViewModel.Country) -> some View {
        let isSelected = selectedCode == country.code

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedCode = isSelected ? "" : country.code
            }
        } label: {
            VStack(spacing: 6) {
                FlagImage(name: country.code, width: 64, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                isSelected ? Color.brand : Color.white.opacity(0.12),
                                lineWidth: isSelected ? 2.5 : 1
                            )
                    )

                Text(country.name)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(8)
            .background(isSelected ? Color.white.opacity(0.06) : Color.clear)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}
