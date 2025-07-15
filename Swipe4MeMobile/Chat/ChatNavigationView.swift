import SwiftUI

struct ChatLoaderView: View {
    let chatRoomId: String
    
    @State private var chatRoom: ChatRoom?
    @State private var swipeRequest: SwipeRequest?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    @Environment(\.dismiss) private var dismiss
    
    private let chatManager = ChatManager.shared
    private let swipeRequestManager = SwipeRequestManager.shared
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading chat...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = errorMessage {
                    ContentUnavailableView(
                        "Unable to Load Chat",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else if let chatRoom = chatRoom, let swipeRequest = swipeRequest {
                    ChatConversationView(
                        chatRoom: chatRoom,
                        swipeRequest: swipeRequest
                    )
                } else {
                    ContentUnavailableView(
                        "Chat Not Found",
                        systemImage: "message.slash",
                        description: Text("This chat room could not be found.")
                    )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadChatData()
        }
    }
    
    private func loadChatData() async {
        do {
            // Load chat room
            guard let loadedChatRoom = await chatManager.getChatRoom(for: chatRoomId) else {
                errorMessage = "Chat room not found"
                isLoading = false
                return
            }
            
            // Load swipe request
            guard let loadedSwipeRequest = await loadSwipeRequest(for: chatRoomId) else {
                errorMessage = "Swipe request not found"
                isLoading = false
                return
            }
            
            // Set the loaded data
            chatRoom = loadedChatRoom
            swipeRequest = loadedSwipeRequest
            isLoading = false
            
        } catch {
            errorMessage = "Failed to load chat: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    private func loadSwipeRequest(for requestId: String) async -> SwipeRequest? {
        do {
            let document = try await swipeRequestManager.db.collection("swipeRequests").document(requestId).getDocument()
            return try document.data(as: SwipeRequest.self)
        } catch {
            print("Error loading swipe request: \(error)")
            return nil
        }
    }
}

#Preview {
    ChatLoaderView(chatRoomId: "sample-chat-room-id")
} 