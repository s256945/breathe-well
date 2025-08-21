import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import SwiftData
import SwiftUI

@MainActor
final class ForumViewModel: ObservableObject {

    // MARK: - Published UI state
    @Published var posts: [ForumPost] = []
    @Published var comments: [ForumComment] = []
    @Published var likedPosts: Set<String> = []
    @Published var likedComments: Set<String> = []
    @Published var newPostTitle: String = ""
    @Published var newPostBody: String = ""
    @Published var newCommentBody: String = ""
    @Published var errorMessage: String?

    // MARK: - Firestore
    private let db = Firestore.firestore()
    private var postsListener: ListenerRegistration?
    private var commentsListener: ListenerRegistration?

    // MARK: - Identity helpers
    var currentUID: String? { Auth.auth().currentUser?.uid }

    // Pull displayName + avatar from SwiftData profile when possible
    private func currentDisplayName(context: ModelContext?) -> String {
        if let uid = currentUID, let context {
            if let p: UserProfile = try? context.fetch(FetchDescriptor<UserProfile>()).first(where: { $0.authUID == uid }) {
                if !p.displayName.isEmpty { return p.displayName }
            }
        }
        let u = Auth.auth().currentUser
        return u?.displayName ?? u?.email ?? "Anonymous"
    }

    private func currentAvatar(context: ModelContext?) -> String {
        if let uid = currentUID, let context {
            if let p: UserProfile = try? context.fetch(FetchDescriptor<UserProfile>()).first(where: { $0.authUID == uid }) {
                return p.avatarSystemName
            }
        }
        return "person.circle.fill"
    }

    deinit {
        postsListener?.remove()
        commentsListener?.remove()
    }

    // MARK: - Live streams

    func startListeningPosts() {
        postsListener?.remove()
        postsListener = db.collection("posts")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snap, err in
                Task { @MainActor in
                    guard let self else { return }
                    if let err = err { self.errorMessage = err.localizedDescription; return }
                    let docs = snap?.documents ?? []
                    self.posts = docs.compactMap(Self.post(from:))
                    await self.refreshLikedPosts(for: docs.map { $0.documentID })
                }
            }
    }

    func startListeningComments(postId: String) {
        commentsListener?.remove()
        commentsListener = db.collection("posts")
            .document(postId)
            .collection("comments")
            .order(by: "createdAt")
            .addSnapshotListener { [weak self] snap, err in
                Task { @MainActor in
                    guard let self else { return }
                    if let err = err { self.errorMessage = err.localizedDescription; return }
                    let docs = snap?.documents ?? []
                    self.comments = docs.compactMap(Self.comment(from:))
                    await self.refreshLikedComments(postId: postId, commentIds: docs.map { $0.documentID })
                }
            }
    }

    // MARK: - Create

    func createPost(context: ModelContext?) async {
        guard let uid = currentUID else { errorMessage = "You must be signed in."; return }

        let data: [String: Any] = [
            "title": newPostTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            "body": newPostBody.trimmingCharacters(in: .whitespacesAndNewlines),
            "authorId": uid,                                              // ← NEW
            "authorName": currentDisplayName(context: context),
            "authorAvatar": currentAvatar(context: context),
            "createdAt": FieldValue.serverTimestamp(),
            "likeCount": 0
        ]

        do {
            _ = try await db.collection("posts").addDocument(data: data)
            newPostTitle = ""; newPostBody = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addComment(to postId: String, body: String, context: ModelContext?) async {
        guard let uid = currentUID else { errorMessage = "You must be signed in."; return }
        let text = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let data: [String: Any] = [
            "body": text,
            "authorId": uid,                                              // ← NEW
            "authorName": currentDisplayName(context: context),
            "authorAvatar": currentAvatar(context: context),
            "createdAt": FieldValue.serverTimestamp(),
            "likeCount": 0
        ]

        do {
            _ = try await db.collection("posts")
                .document(postId)
                .collection("comments")
                .addDocument(data: data)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Delete (only author)

    func deletePost(_ postId: String) async {
        do {
            try await db.collection("posts").document(postId).delete()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteComment(postId: String, commentId: String) async {
        do {
            try await db.collection("posts")
                .document(postId)
                .collection("comments")
                .document(commentId)
                .delete()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Likes (posts)

    func refreshLikedPosts(for postIds: [String]) async {
        guard let uid = currentUID, !postIds.isEmpty else { return }
        do {
            var liked: Set<String> = []
            try await withThrowingTaskGroup(of: (String, Bool).self) { group in
                for id in postIds {
                    group.addTask {
                        let ref = self.db.collection("posts").document(id)
                            .collection("likes").document(uid)
                        let snap = try await ref.getDocument()
                        return (id, snap.exists)
                    }
                }
                for try await (id, exists) in group { if exists { liked.insert(id) } }
            }
            self.likedPosts = liked
        } catch { self.errorMessage = error.localizedDescription }
    }

    func togglePostLike(postId: String) async {
        guard let uid = currentUID else { errorMessage = "You must be signed in."; return }
        let postRef = db.collection("posts").document(postId)
        let likeRef = postRef.collection("likes").document(uid)

        do {
            _ = try await db.runTransaction { (tx, errPtr) -> Any? in
                do {
                    let likeSnap = try tx.getDocument(likeRef)
                    let postSnap = try tx.getDocument(postRef)
                    var likeCount = (postSnap.data()?["likeCount"] as? Int) ?? 0
                    if likeSnap.exists {
                        tx.deleteDocument(likeRef); likeCount = max(0, likeCount - 1)
                    } else {
                        tx.setData([:], forDocument: likeRef); likeCount += 1
                    }
                    tx.updateData(["likeCount": likeCount], forDocument: postRef)
                } catch { errPtr?.pointee = error as NSError; return nil }
                return nil
            }

            // Optimistic
            if likedPosts.contains(postId) {
                likedPosts.remove(postId)
                if let i = posts.firstIndex(where: { $0.id == postId }) {
                    posts[i].likeCount = max(0, posts[i].likeCount - 1)
                }
            } else {
                likedPosts.insert(postId)
                if let i = posts.firstIndex(where: { $0.id == postId }) {
                    posts[i].likeCount += 1
                }
            }
        } catch { errorMessage = "Failed to toggle like: \(error.localizedDescription)" }
    }

    // MARK: - Likes (comments)

    func refreshLikedComments(postId: String, commentIds: [String]) async {
        guard let uid = currentUID, !commentIds.isEmpty else { return }
        do {
            var liked: Set<String> = []
            try await withThrowingTaskGroup(of: (String, Bool).self) { group in
                for cid in commentIds {
                    group.addTask {
                        let ref = self.db.collection("posts").document(postId)
                            .collection("comments").document(cid)
                            .collection("likes").document(uid)
                        let snap = try await ref.getDocument()
                        return ("\(postId)#\(cid)", snap.exists)
                    }
                }
                for try await (key, exists) in group { if exists { liked.insert(key) } }
            }
            self.likedComments = liked
        } catch { self.errorMessage = error.localizedDescription }
    }

    func toggleCommentLike(postId: String, commentId: String) async {
        guard let uid = currentUID else { errorMessage = "You must be signed in."; return }
        let cRef = db.collection("posts").document(postId).collection("comments").document(commentId)
        let likeRef = cRef.collection("likes").document(uid)

        do {
            _ = try await db.runTransaction { (tx, errPtr) -> Any? in
                do {
                    let likeSnap = try tx.getDocument(likeRef)
                    let cSnap = try tx.getDocument(cRef)
                    var likeCount = (cSnap.data()?["likeCount"] as? Int) ?? 0
                    if likeSnap.exists {
                        tx.deleteDocument(likeRef); likeCount = max(0, likeCount - 1)
                    } else {
                        tx.setData([:], forDocument: likeRef); likeCount += 1
                    }
                    tx.updateData(["likeCount": likeCount], forDocument: cRef)
                } catch { errPtr?.pointee = error as NSError; return nil }
                return nil
            }

            // Optimistic
            let key = "\(postId)#\(commentId)"
            if likedComments.contains(key) {
                likedComments.remove(key)
                if let i = comments.firstIndex(where: { $0.id == commentId }) {
                    comments[i].likeCount = max(0, comments[i].likeCount - 1)
                }
            } else {
                likedComments.insert(key)
                if let i = comments.firstIndex(where: { $0.id == commentId }) {
                    comments[i].likeCount += 1
                }
            }
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Mapping

    private static func post(from doc: DocumentSnapshot) -> ForumPost? {
        guard let data = doc.data() else { return nil }
        let ts = data["createdAt"] as? Timestamp
        return ForumPost(
            id: doc.documentID,
            title: data["title"] as? String ?? "",
            body: data["body"] as? String ?? "",
            authorId: data["authorId"] as? String ?? "",
            authorName: data["authorName"] as? String ?? "Anonymous",
            authorAvatar: data["authorAvatar"] as? String ?? "person.circle.fill",
            createdAt: ts?.dateValue() ?? Date(),
            likeCount: data["likeCount"] as? Int ?? 0
        )
    }

    private static func comment(from doc: DocumentSnapshot) -> ForumComment? {
        guard let data = doc.data() else { return nil }
        let ts = data["createdAt"] as? Timestamp
        return ForumComment(
            id: doc.documentID,
            body: data["body"] as? String ?? "",
            authorId: data["authorId"] as? String ?? "",
            authorName: data["authorName"] as? String ?? "Anonymous",
            authorAvatar: data["authorAvatar"] as? String ?? "person.circle.fill",
            createdAt: ts?.dateValue() ?? Date(),
            likeCount: data["likeCount"] as? Int ?? 0
        )
    }
}
