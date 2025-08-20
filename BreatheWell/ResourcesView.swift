import SwiftUI
import SwiftData
import SafariServices

struct ResourcesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Resource.publishedAt, order: .reverse) private var allItems: [Resource]

    @State private var selectedKind: KindFilter = .exercise
    @State private var professionalsOnly = true
    @State private var searchText = ""
    @State private var presentedLink: WebLink?   // Identifiable wrapper

    enum KindFilter: String, CaseIterable, Identifiable {
        case exercise = "Exercise Videos"
        case blog = "Blogs"
        var id: String { rawValue }
        var type: ResourceType { self == .exercise ? .exerciseVideo : .blog }
    }

    var filtered: [Resource] {
        allItems
            .filter { $0.resourceType == selectedKind.type }
            .filter { !professionalsOnly || $0.isProfessional }
            .filter {
                searchText.isEmpty
                || $0.title.localizedCaseInsensitiveContains(searchText)
                || $0.author.localizedCaseInsensitiveContains(searchText)
            }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category picker
                Picker("Category", selection: $selectedKind) {
                    ForEach(KindFilter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding([.horizontal, .top])

                // Content
                if filtered.isEmpty {
                    ContentPlaceholder().padding()
                } else {
                    List(filtered) { item in
                        ResourceRow(item: item) {
                            if let url = item.url { presentedLink = WebLink(url: url) }
                        }
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Resources")
            .searchable(text: $searchText, prompt: "Search title or author")
            .onAppear { seedIfNeeded() }
            .sheet(item: $presentedLink) { link in
                SafariView(url: link.url).ignoresSafeArea()
            }
        }
    }

    // Seed some demo professional resources (so the screen isn't empty)
    private func seedIfNeeded() {
        guard allItems.isEmpty else { return }
        let demo: [Resource] = [
            Resource(
                title: "Breathing Exercises for COPD (5 min)",
                author: "Respiratory Physiotherapist – NHS",
                isProfessional: true,
                type: .exerciseVideo,
                urlString: "https://example.com/nhs-breathing-5min",
                thumbnailURLString: "https://picsum.photos/seed/breathe1/640/360",
                publishedAt: Calendar.current.date(byAdding: .day, value: -20, to: .now),
                durationSeconds: 320
            ),
            Resource(
                title: "Pursed-Lips Breathing Tutorial",
                author: "Chartered Physiotherapist",
                isProfessional: true,
                type: .exerciseVideo,
                urlString: "https://example.com/pursed-lips",
                thumbnailURLString: "https://picsum.photos/seed/breathe2/640/360",
                publishedAt: Calendar.current.date(byAdding: .day, value: -12, to: .now),
                durationSeconds: 260
            ),
            Resource(
                title: "COPD: Staying Active Safely",
                author: "British Lung Foundation",
                isProfessional: true,
                type: .blog,
                urlString: "https://example.com/blf-active",
                thumbnailURLString: "https://picsum.photos/seed/blf1/640/360",
                publishedAt: Calendar.current.date(byAdding: .day, value: -8, to: .now)
            ),
            Resource(
                title: "Managing Breathlessness at Home",
                author: "NHS Respiratory Team",
                isProfessional: true,
                type: .blog,
                urlString: "https://example.com/nhs-managing-breathlessness",
                thumbnailURLString: "https://picsum.photos/seed/nhs1/640/360",
                publishedAt: Calendar.current.date(byAdding: .day, value: -5, to: .now)
            )
        ]
        demo.forEach { context.insert($0) }
        try? context.save()
    }
}

// MARK: - Row/Card

private struct ResourceRow: View {
    let item: Resource
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .top, spacing: 12) {
                Thumbnail(url: item.thumbnailURL, type: item.resourceType)
                    .frame(width: 96, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.15), lineWidth: 1))

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(item.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        if item.isProfessional {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.blue)
                                .accessibilityLabel("Verified healthcare professional")
                        }
                    }

                    HStack(spacing: 10) {
                        Label(item.resourceType.rawValue,
                              systemImage: item.resourceType == .exerciseVideo ? "figure.walk" : "doc.text")
                            .font(.caption).foregroundStyle(.secondary)
                        if let d = item.durationLabel {
                            Label(d, systemImage: "clock").font(.caption).foregroundStyle(.secondary)
                        }
                        if let dt = item.publishedAt {
                            Text(dt, style: .date).font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    Text(item.author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title), by \(item.author)")
    }
}

// MARK: - Thumbnail with fallback

private struct Thumbnail: View {
    let url: URL?
    let type: ResourceType

    var body: some View {
        ZStack {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    case .failure(_): placeholder
                    case .empty: ProgressView()
                    @unknown default: placeholder
                    }
                }
            } else {
                placeholder
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            Color.secondary.opacity(0.08)
            Image(systemName: type == .exerciseVideo ? "play.rectangle.fill" : "doc.text.image")
                .imageScale(.large)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Empty State

private struct ContentPlaceholder: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "stethoscope")
                .imageScale(.large)
                .foregroundColor(.secondary)
            Text("No resources yet")
                .font(.headline)
            Text("Trusted healthcare professionals will soon be uploading resources here. Please check back soon.")
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(Color(.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Safari wrapper & link model

private struct WebLink: Identifiable {
    let id = UUID()
    let url: URL
}

private struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.preferredBarTintColor = .systemBackground
        vc.preferredControlTintColor = .label
        return vc
    }
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
