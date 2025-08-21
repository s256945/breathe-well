import SwiftUI
import SwiftData
import FirebaseAuth

struct ForumPostView: View {
    let post: ForumPost

    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.modelContext) private var context
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
                        if let id = post.id {
                            await vm.addComment(to: id, body: replyText)
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
            // Load SwiftData profile once here too (detail may be opened directly)
            if let uid = auth.user?.uid {
                let all: [UserProfile] = (try? context.fetch(FetchDescriptor<UserProfile>())) ?? []
                vm.userProfile = all.first(where: { $0.authUID == uid })
            }
            vm.startListeningComments(postId: post.id ?? "")
            if let id = post.id { await vm.refreshLikedPosts(for: [id]) }
        }
    }
}

// MARK: - Comment Row (with avatar + absolute date/time)
private struct CommentRow: View {
    let postId: String
    let comment: ForumComment
    let liked: Bool
    var onToggleLike: () -> Void

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
