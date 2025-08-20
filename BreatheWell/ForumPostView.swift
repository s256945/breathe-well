import SwiftUI

struct ForumPostView: View {
    let post: ForumPost
    @StateObject private var vm = ForumViewModel()

    @State private var replyText = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Post card
                    VStack(alignment: .leading, spacing: 8) {
                        Text(post.title)
                            .font(.title3.weight(.semibold))

                        HStack {
                            Text(post.authorName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            // Absolute date & time
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
                            .accessibilityLabel((post.id != nil && vm.likedPosts.contains(post.id!)) ? "Unlike post" : "Like post")
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
                                onToggleLike: {
                                    if let pid = post.id, let cid = c.id {
                                        Task { await vm.toggleCommentLike(postId: pid, commentId: cid) }
                                    }
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
                        vm.newCommentBody = replyText
                        if let id = post.id {
                            await vm.addComment(to: id)
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
        .task {
            vm.startListeningComments(postId: post.id ?? "")
            if let id = post.id { await vm.refreshLikedPosts(for: [id]) }
        }
    }
}

// MARK: - Comment Row (absolute date+time)
private struct CommentRow: View {
    let postId: String
    let comment: ForumComment
    let liked: Bool
    var onToggleLike: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(comment.authorName)
                    .font(.subheadline).bold()
                Spacer()
                // Absolute date & time
                Text(comment.createdAt, format: .dateTime.day().month().year().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Text(comment.body)

            HStack {
                Spacer()
                Button(action: onToggleLike) {
                    Label("\(comment.likeCount)", systemImage: liked ? "heart.fill" : "heart")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(liked ? "Unlike comment" : "Like comment")
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
