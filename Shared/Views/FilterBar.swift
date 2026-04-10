import SwiftUI

struct FilterBar: View {
    @Binding var selectedFilter: ClipboardHistoryViewModel.FilterType
    @Binding var searchText: String

    var body: some View {
        VStack(spacing: 8) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search clipboard history...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.background)
                    .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
            )

            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(ClipboardHistoryViewModel.FilterType.allCases, id: \.self) { filter in
                        FilterChip(
                            title: filter.rawValue,
                            isSelected: selectedFilter == filter,
                            action: { selectedFilter = filter }
                        )
                    }
                }
            }
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.borderless)
    }
}
