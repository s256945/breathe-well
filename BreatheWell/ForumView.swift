import SwiftUI
import SwiftData

struct ForumView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ForumPost.createdAt, order: .reverse) private var posts: [ForumPost]
    @Query private var profiles: [UserProfile]

    @State private var isShowingComposer = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if posts.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "bubble.left.and.bubble.right.fill").font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("Be the first to say hello 👋")
                            .font(.headline)
                        Text("Share how you’re doing today or ask a question.\nThis space is friendly and supportive.")
                            .multilineTextAlignment(.center)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }
                    .padding(.top, 60)
                } else {
                    List {
                        ForEach(posts) { post in
                            NavigationLink {
                                ThreadView(post: post)
                            } label: {
                                PostRow(post: post)
                            }
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                    }
                    .listStyle(.plain)
                }

                // Floating compose button
                Button {
                    isShowingComposer = true
                } label: {
                    ZStack {
                        Circle().fill(Color.blue).frame(width: 58, height: 58)
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                        Image(systemName: "square.and.pencil")
                            .foregroundStyle(.white)
                            .font(.system(size: 24, weight: .semibold))
                    }
                }
                .buttonStyle(.plain)
                .padding(.bottom, 22)
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .navigationTitle("Community")
            .sheet(isPresented: $isShowingComposer) {
                ComposePostSheet { text in
                    guard let p = profiles.first else { return }
                    let post = ForumPost(
                        authorDisplayName: p.displayName.isEmpty ? "Anonymous" : p.displayName,
                        authorAvatar: p.avatarSystemName,
                        text: text
                    )
                    context.insert(post)
                    try? context.save()
                }
                .presentationDetents([.medium, .large])
            }
        }
    }
}

// MARK: - Post row
private struct PostRow: View {
    let post: ForumPost

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: post.authorAvatar)
                    .font(.title3)
                    .foregroundStyle(.blue)
                    .frame(width: 36, height: 36)
                    .background(Color.blue.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.authorDisplayName.isEmpty ? "Anonymous" : post.authorDisplayName)
                        .font(.subheadline).fontWeight(.semibold)
                    Text(post.createdAt, style: .date)
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }

            Text(post.text)
                .font(.body)

            HStack(spacing: 16) {
                Label("\(post.likeCount)", systemImage: "hand.thumbsup")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Label("\(post.comments.count)", systemImage: "bubble.right")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Thread view (one post + comments)
private struct ThreadView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]

    @Bindable var post: ForumPost
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    PostRow(post: post)

                    // actions row
                    HStack(spacing: 16) {
                        Button {
                            post.likeCount += 1
                            try? context.save()
                        } label: {
                            Label("Like", systemImage: "hand.thumbsup")
                        }
                        .buttonStyle(.bordered)

                        Spacer()
                    }
                    .padding(.horizontal, 4)

                    if post.comments.isEmpty {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.secondary.opacity(0.08))
                            .frame(height: 80)
                            .overlay(
                                Text("No replies yet").foregroundStyle(.secondary)
                            )
                    } else {
                        VStack(spacing: 10) {
                            ForEach(post.comments) { c in
                                CommentRow(comment: c)
                            }
                        }
                    }
                }
                .padding()
            }

            // composer bar
            HStack(spacing: 10) {
                TextField("Write a supportive reply…", text: $draft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)

                Button {
                    guard !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    let profile = profiles.first
                    let c = ForumComment(
                        authorDisplayName: profile?.displayName.isEmpty == false ? profile!.displayName : "Anonymous",
                        authorAvatar: profile?.avatarSystemName ?? "person.circle.fill",
                        text: draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    post.comments.append(c)
                    draft = ""
                    try? context.save()
                } label: {
                    Image(systemName: "paperplane.fill").font(.title3)
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.thinMaterial)
        }
        .navigationTitle("Thread")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CommentRow: View {
    let comment: ForumComment
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: comment.authorAvatar)
                .font(.callout)
                .foregroundStyle(.blue)
                .frame(width: 28, height: 28)
                .background(Color.blue.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(comment.authorDisplayName.isEmpty ? "Anonymous" : comment.authorDisplayName)
                        .font(.subheadline).fontWeight(.semibold)
                    Spacer()
                    Text(comment.createdAt, style: .time)
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text(comment.text)
                    .font(.body)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Compose sheet
private struct ComposePostSheet: View {
    var onPost: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextEditor(text: $text)
                    .frame(minHeight: 160)
                    .padding(12)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                    )
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty {
                            Text("Share how you’re doing, ask a question, or encourage others…")
                                .foregroundStyle(.secondary)
                                .padding(18)
                        }
                    }

                Spacer()
            }
            .padding()
            .navigationTitle("New Post")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onPost(trimmed)
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
