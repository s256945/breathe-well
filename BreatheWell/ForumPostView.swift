import SwiftUI
import SwiftData

struct ForumPostView: View {
    let post: ForumPost
    @StateObject private var vm = ForumViewModel()
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var replyText = ""

    // Delete confirmation state
    @State private var showPostDeleteDialog = false
    @State private var pendingCommentToDelete: ForumComment? = nil
    @State private var showCommentDeleteDialog = false

    // Fetch current profile display name once for legacy fallback
    private var myDisplayName: String {
        if let uid = vm.currentUID,
           let all: [UserProfile] = try? context.fetch(FetchDescriptor<UserProfile>()),
           let me = all.first(where: { $0.authUID == uid }),
           !me.displayName.isEmpty {
            return me.displayName
        }
        return "Anonymous"
    }

    // Legacy-aware ownership check for comments
    private func isOwner(of comment: ForumComment) -> Bool {
        if let uid = vm.currentUID {
            if comment.authorId == uid { return true }                // preferred path
            if comment.authorId.isEmpty && comment.authorName == myDisplayName {
                return true                                           // legacy fallback
            }
        }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Post card
                    VStack(alignment: .leading, spacing: 8) {
                        Text(post.title)
                            .font(.title3.weight(.semibold))

                        HStack(spacing: 8) {
                            Image(systemName: post.authorAvatar)
                                .resizable()
                                .frame(width: 20, height: 20)
                                .foregroundStyle(.secondary)
                            Text(post.authorName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(post.createdAt, format: .dateTime.day().month().year().hour().minute())
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }

                        Text(post.body)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack {
                            Spacer()
                            Button {
                                if let id = post.id {
                                    Task { await vm.togglePostLike(postId: id) }
                                }
                            } label: {
                                let liked = (post.id != nil) && vm.likedPosts.contains(post.id!)
                                Label("\(post.likeCount)", systemImage: liked ? "heart.fill" : "heart")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Comments
                    Text("Comments")
                        .font(.headline)

                    VStack(spacing: 10) {
                        ForEach(vm.comments) { c in
                            CommentRow(
                                postId: post.id ?? "",
                                comment: c,
                                liked: vm.likedComments.contains("\(post.id ?? "")#\(c.id ?? "")"),
                                isOwner: isOwner(of: c),
                                onToggleLike: {
                                    if let pid = post.id, let cid = c.id {
                                        Task { await vm.toggleCommentLike(postId: pid, commentId: cid) }
                                    }
                                },
                                onRequestDelete: {
                                    // open confirm modal for this comment
                                    pendingCommentToDelete = c
                                    showCommentDeleteDialog = true
                                }
                            )
                            .task {
                                if let pid = post.id, let cid = c.id {
                                    await vm.refreshLikedComments(postId: pid, commentIds: [cid])
                                }
                            }
                        }
                    }
                }
                .padding()
            }

            // Composer
            HStack(spacing: 10) {
                TextField("Write a reply...", text: $replyText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)

                Button {
                    Task {
                        if let id = post.id {
                            await vm.addComment(to: id, body: replyText, context: context)
                            replyText = ""
                        }
                    }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.title3)
                }
                .disabled(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.bar)
        }
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Delete post button only for owner
            if vm.currentUID == post.authorId, let _ = post.id {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        showPostDeleteDialog = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Delete post")
                }
            }
        }
        // Post delete confirmation
        .confirmationDialog("Delete post?",
                            isPresented: $showPostDeleteDialog,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    if let id = post.id {
                        await vm.deletePost(id)
                        dismiss()
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action will permanently delete the post and all of its comments.")
        }
        // Comment delete confirmation
        .confirmationDialog("Delete comment?",
                            isPresented: $showCommentDeleteDialog,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    if let pid = post.id, let cid = pendingCommentToDelete?.id {
                        await vm.deleteComment(postId: pid, commentId: cid)
                    }
                    pendingCommentToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                pendingCommentToDelete = nil
            }
        } message: {
            Text("This action will permanently delete your comment.")
        }
        .task {
            vm.startListeningComments(postId: post.id ?? "")
            if let id = post.id { await vm.refreshLikedPosts(for: [id]) }
        }
    }
}

// MARK: - Comment Row
private struct CommentRow: View {
    let postId: String
    let comment: ForumComment
    let liked: Bool
    let isOwner: Bool
    var onToggleLike: () -> Void
    var onRequestDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label {
                    Text(comment.authorName)
                        .font(.subheadline).bold()
                } icon: {
                    Image(systemName: comment.authorAvatar.isEmpty ? "person.circle.fill" : comment.authorAvatar)
                        .resizable()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(comment.createdAt, format: .dateTime.day().month().year().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Text(comment.body)

            HStack {
                Spacer()
                if isOwner {
                    Button(role: .destructive, action: onRequestDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }
                Button(action: onToggleLike) {
                    Label("\(comment.likeCount)", systemImage: liked ? "heart.fill" : "heart")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .swipeActions(edge: .trailing) {
            if isOwner {
                Button(role: .destructive, action: onRequestDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}
