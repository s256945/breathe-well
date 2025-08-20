import SwiftUI

struct CommunityChatView: View {
    @StateObject private var vm = ChatViewModel()
    @EnvironmentObject var auth: AuthViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(vm.messages) { msg in
                            MessageRow(
                                msg: msg,
                                isCurrentUser: msg.senderId == auth.user?.uid
                            )
                            .id(msg.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .onChange(of: vm.messages.count) { _, _ in
                    if let last = vm.messages.last?.id {
                        withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                    }
                }
            }

            Divider()

            HStack(spacing: 10) {
                TextField("Message…", text: $vm.newMessageText)
                    .textFieldStyle(.roundedBorder)

                Button {
                    vm.sendMessage(displayNameFallback: "Anonymous")
                } label: {
                    Image(systemName: "paperplane.fill")
                        .imageScale(.large)
                }
                .disabled(vm.newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isSending)
            }
            .padding(12)
        }
        .navigationTitle("Community")
    }
}

struct MessageRow: View {
    let msg: ChatMessage
    let isCurrentUser: Bool

    var body: some View {
        HStack {
            if isCurrentUser { Spacer() }
            VStack(alignment: .leading, spacing: 4) {
                Text(msg.senderName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(msg.text)
                    .padding(10)
                    .background(isCurrentUser ? Color.blue : Color.gray.opacity(0.2))
                    .foregroundStyle(isCurrentUser ? Color.white : Color.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .frame(maxWidth: 260, alignment: isCurrentUser ? .trailing : .leading)
            if !isCurrentUser { Spacer() }
        }
    }
}
