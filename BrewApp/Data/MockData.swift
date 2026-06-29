import Foundation

enum MockData {
    static let satvikID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    static let mayaID = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
    static let theoID = UUID(uuidString: "10000000-0000-0000-0000-000000000003")!
    static let linaID = UUID(uuidString: "10000000-0000-0000-0000-000000000004")!

    static let paperPlaneID = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
    static let emberOakID = UUID(uuidString: "20000000-0000-0000-0000-000000000002")!
    static let littleWindowID = UUID(uuidString: "20000000-0000-0000-0000-000000000003")!
    static let ninthStreetID = UUID(uuidString: "20000000-0000-0000-0000-000000000004")!

    static let satvikEspressoID = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
    static let satvikPourOverID = UUID(uuidString: "30000000-0000-0000-0000-000000000002")!
    static let satvikColdBrewID = UUID(uuidString: "30000000-0000-0000-0000-000000000003")!
    static let mayaLatteID = UUID(uuidString: "30000000-0000-0000-0000-000000000004")!
    static let theoCortadoID = UUID(uuidString: "30000000-0000-0000-0000-000000000005")!
    static let homeBrewID = UUID(uuidString: "30000000-0000-0000-0000-000000000006")!

    static func makeStore() -> AppStore {
        let now = Date.now
        let today = now.addingTimeInterval(-60 * 45)
        let thisWeek = now.addingTimeInterval(-60 * 60 * 24 * 3)
        let earlier = now.addingTimeInterval(-60 * 60 * 24 * 11)

        let users = [
            BrewUser(
                id: satvikID,
                username: "satvik",
                displayName: "Satvik Talchuru",
                initials: "ST",
                isCurrentUser: true,
                isPublic: true,
                appearInChats: true
            ),
            BrewUser(
                id: mayaID,
                username: "maya",
                displayName: "Maya Chen",
                initials: "MC",
                isCurrentUser: false,
                isPublic: true,
                appearInChats: true
            ),
            BrewUser(
                id: theoID,
                username: "theo",
                displayName: "Theo Rivera",
                initials: "TR",
                isCurrentUser: false,
                isPublic: true,
                appearInChats: true
            ),
            BrewUser(
                id: linaID,
                username: "lina",
                displayName: "Lina Patel",
                initials: "LP",
                isCurrentUser: false,
                isPublic: true,
                appearInChats: true
            )
        ]

        let shops = [
            Shop(
                id: paperPlaneID,
                name: "Paper Plane Coffee",
                address: "718 Valencia St",
                hours: "7 AM - 5 PM",
                distance: "0.4 mi",
                heroSymbol: "paperplane.fill"
            ),
            Shop(
                id: emberOakID,
                name: "Ember & Oak",
                address: "2419 Mission St",
                hours: "8 AM - 6 PM",
                distance: "0.8 mi",
                heroSymbol: "flame.fill"
            ),
            Shop(
                id: littleWindowID,
                name: "Little Window",
                address: "1328 Castro St",
                hours: "7 AM - 4 PM",
                distance: "1.1 mi",
                heroSymbol: "rectangle.split.3x1.fill"
            ),
            Shop(
                id: ninthStreetID,
                name: "Ninth Street Espresso",
                address: "341 9th St",
                hours: "7 AM - 7 PM",
                distance: "1.7 mi",
                heroSymbol: "9.circle.fill"
            )
        ]

        let drinkLogs = [
            DrinkLog(
                id: satvikEspressoID,
                userID: satvikID,
                shopID: paperPlaneID,
                isHomeBrew: false,
                drinkName: "Single Origin Espresso",
                brewMethod: .espresso,
                roast: .medium,
                sweetness: 3,
                strength: 5,
                wouldOrder: .yes,
                notes: "Bright, syrupy shot with a clean finish.",
                flavorTags: [
                    FlavorTag(category: "Fruit", subcategory: "Citrus", descriptor: "Orange"),
                    FlavorTag(category: "Sweet", subcategory: "Sugar", descriptor: "Caramel")
                ],
                eloScore: 1518,
                loggedAt: today
            ),
            DrinkLog(
                id: satvikPourOverID,
                userID: satvikID,
                shopID: littleWindowID,
                isHomeBrew: false,
                drinkName: "Ethiopia Pour Over",
                brewMethod: .pourOver,
                roast: .light,
                sweetness: 4,
                strength: 3,
                wouldOrder: .yes,
                notes: "Tea-like body with berry sweetness.",
                flavorTags: [
                    FlavorTag(category: "Fruit", subcategory: "Berry", descriptor: "Blueberry"),
                    FlavorTag(category: "Floral", subcategory: "Fresh", descriptor: "Jasmine")
                ],
                eloScore: 1592,
                loggedAt: thisWeek
            ),
            DrinkLog(
                id: satvikColdBrewID,
                userID: satvikID,
                shopID: emberOakID,
                isHomeBrew: false,
                drinkName: "Maple Cold Brew",
                brewMethod: .coldBrew,
                roast: .dark,
                sweetness: 5,
                strength: 4,
                wouldOrder: .maybe,
                notes: "Smooth and sweet, almost dessert-like.",
                flavorTags: [
                    FlavorTag(category: "Sweet", subcategory: "Syrup", descriptor: "Maple"),
                    FlavorTag(category: "Roast", subcategory: "Chocolate", descriptor: "Cocoa")
                ],
                eloScore: 1446,
                loggedAt: earlier
            ),
            DrinkLog(
                id: mayaLatteID,
                userID: mayaID,
                shopID: ninthStreetID,
                isHomeBrew: false,
                drinkName: "Oat Milk Latte",
                brewMethod: .latte,
                roast: .medium,
                sweetness: 4,
                strength: 3,
                wouldOrder: .yes,
                notes: "Balanced milk texture with a nutty base.",
                flavorTags: [
                    FlavorTag(category: "Nutty", subcategory: "Tree Nut", descriptor: "Almond"),
                    FlavorTag(category: "Sweet", subcategory: "Bakery", descriptor: "Vanilla")
                ],
                eloScore: 1484,
                loggedAt: today.addingTimeInterval(-60 * 35)
            ),
            DrinkLog(
                id: theoCortadoID,
                userID: theoID,
                shopID: paperPlaneID,
                isHomeBrew: false,
                drinkName: "House Cortado",
                brewMethod: .cortado,
                roast: .medium,
                sweetness: 2,
                strength: 4,
                wouldOrder: .maybe,
                notes: "Compact and roasty with a dry finish.",
                flavorTags: [
                    FlavorTag(category: "Roast", subcategory: "Toast", descriptor: "Toasted Grain"),
                    FlavorTag(category: "Spice", subcategory: "Warm", descriptor: "Clove")
                ],
                eloScore: 1412,
                loggedAt: thisWeek.addingTimeInterval(-60 * 60 * 6)
            ),
            DrinkLog(
                id: homeBrewID,
                userID: satvikID,
                shopID: nil,
                isHomeBrew: true,
                drinkName: "V60 Home Brew",
                brewMethod: .pourOver,
                roast: .light,
                sweetness: 3,
                strength: 3,
                wouldOrder: .yes,
                notes: "Dialed finer today; better clarity and more sweetness.",
                flavorTags: [
                    FlavorTag(category: "Fruit", subcategory: "Stone Fruit", descriptor: "Peach"),
                    FlavorTag(category: "Acid", subcategory: "Crisp", descriptor: "Lemon")
                ],
                eloScore: 1536,
                loggedAt: earlier.addingTimeInterval(-60 * 60 * 18)
            )
        ]

        let friendships = [
            Friendship(
                id: UUID(uuidString: "40000000-0000-0000-0000-000000000001")!,
                requesterID: satvikID,
                addresseeID: mayaID,
                status: .accepted
            ),
            Friendship(
                id: UUID(uuidString: "40000000-0000-0000-0000-000000000002")!,
                requesterID: theoID,
                addresseeID: satvikID,
                status: .accepted
            )
        ]

        let chatRequests = [
            CoffeeChatRequest(
                id: UUID(uuidString: "50000000-0000-0000-0000-000000000001")!,
                requesterID: linaID,
                addresseeID: satvikID,
                shopID: emberOakID,
                status: .pending,
                requestedAt: today.addingTimeInterval(-60 * 20)
            ),
            CoffeeChatRequest(
                id: UUID(uuidString: "50000000-0000-0000-0000-000000000002")!,
                requesterID: satvikID,
                addresseeID: mayaID,
                shopID: paperPlaneID,
                status: .accepted,
                requestedAt: thisWeek.addingTimeInterval(-60 * 60 * 2)
            )
        ]

        let comparisons = [
            Comparison(
                id: UUID(uuidString: "60000000-0000-0000-0000-000000000001")!,
                userID: satvikID,
                winnerLogID: satvikPourOverID,
                loserLogID: satvikColdBrewID,
                comparedAt: thisWeek.addingTimeInterval(-60 * 30)
            )
        ]

        return AppStore(
            currentUserID: satvikID,
            users: users,
            shops: shops,
            drinkLogs: drinkLogs,
            friendships: friendships,
            chatRequests: chatRequests,
            comparisons: comparisons,
            likedLogIDs: [mayaLatteID, theoCortadoID]
        )
    }
}
