import SwiftUI
import SwiftData

struct ForumListView: View {
    @StateObject private var vm = ForumViewModel()
    @Environment(\.modelContext) private var context
    @State private var showingComposer = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(vm.posts) { post in
                        NavigationLink(value: post) {
                            PostRow(
                                post: post,
                                liked: post.id.map { vm.likedPosts.contains($0) } ?? false,
                                onToggleLike: { if let id = post.id { Task { await vm.togglePostLike(postId: id) } } }
                            )
                        }
                        .task { if let id = post.id { await vm.refreshLikedPosts(for: [id]) } }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            // Only show delete on your own post
                            if vm.currentUID == post.authorId, let id = post.id {
                                Button(role: .destructive) {
                                    Task { await vm.deletePost(id) }
                                } label: { Label("Delete", systemImage: "trash") }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Community")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingComposer = true } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("New post")
                }
            }
            .navigationDestination(for: ForumPost.self) { p in
                ForumPostView(post: p)
            }
            .sheet(isPresented: $showingComposer) {
                NewPostSheet(vm: vm, context: context)
                    .presentationDetents([.medium, .large])
            }
            .task { vm.startListeningPosts() }
            .overlay(alignment: .bottom) {
                if let err = vm.errorMessage {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 8)
                }
            }
        }
    }
}

private struct PostRow: View {
    let post: ForumPost
    let liked: Bool
    var onToggleLike: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(post.title).font(.headline)
            Text(post.body).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)

            HStack(spacing: 12) {
                Text(post.authorName).font(.caption).foregroundStyle(.secondary)
                Text(post.createdAt, format: .dateTime.day().month().year().hour().minute())
                    .font(.caption).foregroundStyle(.tertiary)
                Spacer()
                Button(action: onToggleLike) {
                    Label("\(post.likeCount)", systemImage: liked ? "heart.fill" : "heart")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(liked ? "Unlike post" : "Like post")
            }
        }
        .padding(.vertical, 4)
    }
}

private struct NewPostSheet: View {
    @ObservedObject var vm: ForumViewModel
    let context: ModelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") { TextField("What's on your mind?", text: $vm.newPostTitle) }
                Section("Message") { TextEditor(text: $vm.newPostBody).frame(minHeight: 120) }
            }
            .navigationTitle("New post")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        Task { await vm.createPost(context: context); dismiss() }
                    }
                    .disabled(vm.newPostTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              vm.newPostBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
