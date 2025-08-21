import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import SwiftData

@MainActor
final class ForumViewModel: ObservableObject {

    // Provide/overwrite this from the views when you know the user
    @Published var userProfile: UserProfile?

    // MARK: - Published UI state
    @Published var posts: [ForumPost] = []
    @Published var comments: [ForumComment] = []

    // Which items this user has liked (for quick UI state)
    @Published var likedPosts: Set<String> = []
    @Published var likedComments: Set<String> = []

    // Composer state
    @Published var newPostTitle: String = ""
    @Published var newPostBody: String = ""
    @Published var newCommentBody: String = ""
    @Published var errorMessage: String?

    // MARK: - Firestore
    private let db = Firestore.firestore()
    private var postsListener: ListenerRegistration?
    private var commentsListener: ListenerRegistration?

    // MARK: - Auth helpers
    private var uid: String? { Auth.auth().currentUser?.uid }

    private var effectiveDisplayName: String {
        if let p = userProfile, !p.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return p.displayName
        }
        let u = Auth.auth().currentUser
        return u?.displayName ?? u?.email ?? "Anonymous"
    }

    private var effectiveAvatarSymbol: String {
        userProfile?.avatarSystemName ?? "person.circle.fill"
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
                    if let err = err {
                        self.errorMessage = err.localizedDescription
                        return
                    }
                    let docs = snap?.documents ?? []
                    self.posts = docs.compactMap(Self.post(from:))
                    let ids = docs.map { $0.documentID }
                    await self.refreshLikedPosts(for: ids)
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
                    if let err = err {
                        self.errorMessage = err.localizedDescription
                        return
                    }
                    let docs = snap?.documents ?? []
                    self.comments = docs.compactMap(Self.comment(from:))
                    await self.refreshLikedComments(postId: postId, commentIds: docs.map { $0.documentID })
                }
            }
    }

    // MARK: - Create
    func createPost() async {
        guard uid != nil else {
            errorMessage = "You must be signed in."
            return
        }

        let data: [String: Any] = [
            "title": newPostTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            "body": newPostBody.trimmingCharacters(in: .whitespacesAndNewlines),
            "authorName": effectiveDisplayName,
            "authorAvatar": effectiveAvatarSymbol,
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

    func addComment(to postId: String, body: String) async {
        guard uid != nil else {
            errorMessage = "You must be signed in."
            return
        }
        let text = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let data: [String: Any] = [
            "body": text,
            "authorName": effectiveDisplayName,
            "authorAvatar": effectiveAvatarSymbol,
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

    // MARK: - Likes (posts)
    func refreshLikedPosts(for postIds: [String]) async {
        guard let uid = uid, !postIds.isEmpty else { return }
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
                for try await (id, exists) in group {
                    if exists { liked.insert(id) }
                }
            }
            self.likedPosts = liked
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func togglePostLike(postId: String) async {
        guard let uid = uid else {
            errorMessage = "You must be signed in."
            return
        }
        let postRef = db.collection("posts").document(postId)
        let likeRef = postRef.collection("likes").document(uid)

        do {
            _ = try await db.runTransaction { (tx, errPtr) -> Any? in
                do {
                    let likeSnap = try tx.getDocument(likeRef)
                    let postSnap = try tx.getDocument(postRef)

                    var likeCount = (postSnap.data()?["likeCount"] as? Int) ?? 0

                    if likeSnap.exists {
                        tx.deleteDocument(likeRef)
                        likeCount = max(0, likeCount - 1)
                    } else {
                        tx.setData([:], forDocument: likeRef)
                        likeCount += 1
                    }
                    tx.updateData(["likeCount": likeCount], forDocument: postRef)
                } catch {
                    errPtr?.pointee = error as NSError
                    return nil
                }
                return nil
            }

            // Optimistic UI
            if likedPosts.contains(postId) {
                likedPosts.remove(postId)
                if let idx = posts.firstIndex(where: { $0.id == postId }) {
                    posts[idx].likeCount = max(0, posts[idx].likeCount - 1)
                }
            } else {
                likedPosts.insert(postId)
                if let idx = posts.firstIndex(where: { $0.id == postId }) {
                    posts[idx].likeCount += 1
                }
            }
        } catch {
            errorMessage = "Failed to toggle like: \(error.localizedDescription)"
        }
    }

    // MARK: - Likes (comments)
    func refreshLikedComments(postId: String, commentIds: [String]) async {
        guard let uid = uid, !commentIds.isEmpty else { return }
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
                for try await (key, exists) in group {
                    if exists { liked.insert(key) }
                }
            }
            self.likedComments = liked
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func toggleCommentLike(postId: String, commentId: String) async {
        guard let uid = uid else {
            errorMessage = "You must be signed in."
            return
        }
        let cRef = db.collection("posts").document(postId)
            .collection("comments").document(commentId)
        let likeRef = cRef.collection("likes").document(uid)

        do {
            _ = try await db.runTransaction { (tx, errPtr) -> Any? in
                do {
                    let likeSnap = try tx.getDocument(likeRef)
                    let cSnap = try tx.getDocument(cRef)

                    var likeCount = (cSnap.data()?["likeCount"] as? Int) ?? 0

                    if likeSnap.exists {
                        tx.deleteDocument(likeRef)
                        likeCount = max(0, likeCount - 1)
                    } else {
                        tx.setData([:], forDocument: likeRef)
                        likeCount += 1
                    }
                    tx.updateData(["likeCount": likeCount], forDocument: cRef)
                } catch {
                    errPtr?.pointee = error as NSError
                    return nil
                }
                return nil
            }

            // Optimistic UI
            let key = "\(postId)#\(commentId)"
            if likedComments.contains(key) {
                likedComments.remove(key)
                if let idx = comments.firstIndex(where: { $0.id == commentId }) {
                    comments[idx].likeCount = max(0, comments[idx].likeCount - 1)
                }
            } else {
                likedComments.insert(key)
                if let idx = comments.firstIndex(where: { $0.id == commentId }) {
                    comments[idx].likeCount += 1
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Mapping helpers
    private static func post(from doc: DocumentSnapshot) -> ForumPost? {
        guard let data = doc.data() else { return nil }
        let ts = data["createdAt"] as? Timestamp
        return ForumPost(
            id: doc.documentID,
            title: data["title"] as? String ?? "",
            body: data["body"] as? String ?? "",
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
            authorName: data["authorName"] as? String ?? "Anonymous",
            authorAvatar: data["authorAvatar"] as? String ?? "person.circle.fill",
            createdAt: ts?.dateValue() ?? Date(),
            likeCount: data["likeCount"] as? Int ?? 0
        )
    }
}
