//
// Wire
// Copyright (C) 2017 Wire Swiss GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
//


enum ConversationActionType {

    case none, started(withName: String?), added(herself: Bool), removed, left, teamMemberLeave
    
    var involvesUsersOtherThanSender: Bool {
        switch self {
        case .left, .teamMemberLeave, .added(herself: true): return false
        default:                                             return true
        }
    }

    func image(with color: UIColor?) -> UIImage? {
        let icon: ZetaIconType
        switch self {
        case .started, .none:                   icon = .conversation
        case .added:                            icon = .plus
        case .removed, .left, .teamMemberLeave: icon = .minus
        }
        
        return UIImage(for: icon, iconSize: .tiny, color: color)
    }
}

extension ZMConversationMessage {
    var actionType: ConversationActionType {
        guard let systemMessage = systemMessageData else { return .none }
        switch systemMessage.systemMessageType {
        case .participantsRemoved:  return systemMessage.userIsTheSender ? .left : .removed
        case .participantsAdded:    return .added(herself: systemMessage.userIsTheSender)
        case .newConversation:      return .started(withName: systemMessage.text)
        case .teamMemberLeave:      return .teamMemberLeave
        default:                    return .none
        }
    }
}

struct ParticipantsCellViewModel {
    
    private typealias NameList = ParticipantsStringFormatter.NameList
    static let showMoreLinkURL = NSURL(string: "action://show-all")!
    
    let font, boldFont, largeFont: UIFont?
    let textColor: UIColor?
    let message: ZMConversationMessage
    
    private var action: ConversationActionType {
        return message.actionType
    }
    
    private var maxShownUsers: Int {
        return isSelfIncludedInUsers ? 16 : 17
    }
    
    private var maxShownUsersWhenCollapsed: Int {
        return isSelfIncludedInUsers ? 14 : 15
    }
    
    var showInviteButton: Bool {
        guard case .started = action, let conversation = message.conversation else { return false }
        return conversation.canManageAccess && conversation.allowGuests
    }
    
    /// Users displayed in the system message, up to 17 when not collapsed
    /// but only 15 when there are more than 15 users and we collapse them.
    var shownUsers: [ZMUser] {
        let users = sortedUsersWithoutSelf()
        let boundary = users.count <= maxShownUsers ? users.count : maxShownUsersWhenCollapsed
        let result = users[..<boundary]
        return result + (isSelfIncludedInUsers ? [.selfUser()] : [])
    }
    
    /// Users not displayed in the system message but collapsed into a link.
    /// E.g. `and 5 others`.
    private var collapsedUsers: [ZMUser] {
        let users = sortedUsersWithoutSelf()
        guard users.count > maxShownUsers else { return [] }
        return Array(users.dropFirst(maxShownUsersWhenCollapsed))
    }
    
    /// The users represented by the collapsed link after being added to the
    /// conversation.
    var selectedUsers: [ZMUser] {
        switch action {
        case .added: return collapsedUsers
        default: return []
        }
    }
    
    var isSelfIncludedInUsers: Bool {
        return sortedUsers().any { $0.isSelfUser }
    }
    
    /// The users involved in the conversation action sorted alphabetically by
    /// name.
    func sortedUsers() -> [ZMUser] {
        guard let sender = message.sender else { return [] }
        guard action.involvesUsersOtherThanSender else { return [sender] }
        guard let systemMessage = message.systemMessageData else { return [] }
        return systemMessage.users.subtracting([sender]).sorted { name(for: $0) < name(for: $1) }
    }

    func sortedUsersWithoutSelf() -> [ZMUser] {
        return sortedUsers().filter { !$0.isSelfUser }
    }

    private func name(for user: ZMUser) -> String {
        if user.isSelfUser {
            return "content.system.you_\(grammaticalCase(for: user))".localized
        }
        if let conversation = message.conversation, conversation.activeParticipants.contains(user) {
            return user.displayName(in: conversation)
        } else {
            return user.displayName
        }
    }
    
    private var nameList: NameList {
        let userNames = shownUsers.map { self.name(for: $0) }
        return NameList(names: userNames, collapsed: collapsedUsers.count, selfIncluded: isSelfIncludedInUsers)
    }
    
    /// The user will, depending on the context, be in a specific case within the
    /// sentence. This is important for localization of "you".
    private func grammaticalCase(for user: ZMUser) -> String {
        // user is always the subject
        if user == message.sender { return "nominative" }
        // "started with ... user"
        if case .started = action { return "dative" }
        return "accusative"
    }
    
    // ------------------------------------------------------------
    
    func image() -> UIImage? {
        return action.image(with: textColor)
    }
    
    func attributedHeading() -> NSAttributedString? {
        guard
            case let .started(withName: conversationName?) = action,
            let sender = message.sender,
            let formatter = formatter(for: message)
            else { return nil }
        
        let senderName = name(for: sender).capitalized
        return formatter.heading(senderName: senderName, senderIsSelf: sender.isSelfUser, convName: conversationName)
    }

    func attributedTitle() -> NSAttributedString? {
        guard
            let sender = message.sender,
            let formatter = formatter(for: message)
            else { return nil }
        
        let senderName = name(for: sender).capitalized
        
        if action.involvesUsersOtherThanSender {
            return formatter.title(senderName: senderName, senderIsSelf: sender.isSelfUser, names: nameList)
        } else {
            return formatter.title(senderName: senderName, senderIsSelf: sender.isSelfUser)
        }
    }
    
    private func formatter(for message: ZMConversationMessage) -> ParticipantsStringFormatter? {
        guard let font = font, let boldFont = boldFont,
            let largeFont = largeFont, let textColor = textColor
            else { return nil }
        
        return ParticipantsStringFormatter(
            message: message, font: font, boldFont: boldFont,
            largeFont: largeFont, textColor: textColor
        )
    }
}
