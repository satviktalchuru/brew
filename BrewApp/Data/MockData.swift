import Foundation

enum MockData {
    static let satvikID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    static let mayaID = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
    static let theoID = UUID(uuidString: "10000000-0000-0000-0000-000000000003")!
    static let linaID = UUID(uuidString: "10000000-0000-0000-0000-000000000004")!
    static let priyaID = UUID(uuidString: "10000000-0000-0000-0000-000000000005")!
    static let marcusID = UUID(uuidString: "10000000-0000-0000-0000-000000000006")!

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

    static let priyaAmericanoID = UUID(uuidString: "30000000-0000-0000-0000-000000000007")!
    static let priyaCortadoID = UUID(uuidString: "30000000-0000-0000-0000-000000000008")!
    static let marcusEspressoID = UUID(uuidString: "30000000-0000-0000-0000-000000000009")!
    static let marcusColdBrewID = UUID(uuidString: "30000000-0000-0000-0000-000000000010")!
    static let linaLatteID = UUID(uuidString: "30000000-0000-0000-0000-000000000011")!

    static let orangeFlavorTagID = UUID(uuidString: "70000000-0000-0000-0000-000000000001")!
    static let caramelFlavorTagID = UUID(uuidString: "70000000-0000-0000-0000-000000000002")!
    static let blueberryFlavorTagID = UUID(uuidString: "70000000-0000-0000-0000-000000000003")!
    static let jasmineFlavorTagID = UUID(uuidString: "70000000-0000-0000-0000-000000000004")!
    static let mapleFlavorTagID = UUID(uuidString: "70000000-0000-0000-0000-000000000005")!
    static let cocoaFlavorTagID = UUID(uuidString: "70000000-0000-0000-0000-000000000006")!
    static let almondFlavorTagID = UUID(uuidString: "70000000-0000-0000-0000-000000000007")!
    static let vanillaFlavorTagID = UUID(uuidString: "70000000-0000-0000-0000-000000000008")!
    static let toastedGrainFlavorTagID = UUID(uuidString: "70000000-0000-0000-0000-000000000009")!
    static let cloveFlavorTagID = UUID(uuidString: "70000000-0000-0000-0000-000000000010")!
    static let peachFlavorTagID = UUID(uuidString: "70000000-0000-0000-0000-000000000011")!
    static let lemonFlavorTagID = UUID(uuidString: "70000000-0000-0000-0000-000000000012")!

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
            ),
            BrewUser(
                id: priyaID,
                username: "priya",
                displayName: "Priya Sharma",
                initials: "PS",
                isCurrentUser: false,
                isPublic: true,
                appearInChats: true
            ),
            BrewUser(
                id: marcusID,
                username: "marcus",
                displayName: "Marcus Chen",
                initials: "MC",
                isCurrentUser: false,
                isPublic: true,
                appearInChats: false
            )
        ]

        let shops = [
            Shop(id: paperPlaneID,   name: "Paper Plane Coffee",     address: "718 Valencia St",  hours: "7 AM - 5 PM", distance: "0.4 mi", heroSymbol: "paperplane.fill",          latitude: 37.7622, longitude: -122.4216),
            Shop(id: emberOakID,     name: "Ember & Oak",             address: "2419 Mission St",  hours: "8 AM - 6 PM", distance: "0.8 mi", heroSymbol: "flame.fill",               latitude: 37.7571, longitude: -122.4183),
            Shop(id: littleWindowID, name: "Little Window",           address: "1328 Castro St",   hours: "7 AM - 4 PM", distance: "1.1 mi", heroSymbol: "rectangle.split.3x1.fill", latitude: 37.7508, longitude: -122.4308),
            Shop(id: ninthStreetID,  name: "Ninth Street Espresso",   address: "341 9th St",       hours: "7 AM - 7 PM", distance: "1.7 mi", heroSymbol: "9.circle.fill",            latitude: 37.7748, longitude: -122.4098),
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
                    FlavorTag(id: orangeFlavorTagID, category: "Fruit", subcategory: "Citrus", descriptor: "Orange"),
                    FlavorTag(id: caramelFlavorTagID, category: "Sweet", subcategory: "Sugar", descriptor: "Caramel")
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
                    FlavorTag(id: blueberryFlavorTagID, category: "Fruit", subcategory: "Berry", descriptor: "Blueberry"),
                    FlavorTag(id: jasmineFlavorTagID, category: "Floral", subcategory: "Fresh", descriptor: "Jasmine")
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
                    FlavorTag(id: mapleFlavorTagID, category: "Sweet", subcategory: "Syrup", descriptor: "Maple"),
                    FlavorTag(id: cocoaFlavorTagID, category: "Roast", subcategory: "Chocolate", descriptor: "Cocoa")
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
                    FlavorTag(id: almondFlavorTagID, category: "Nutty", subcategory: "Tree Nut", descriptor: "Almond"),
                    FlavorTag(id: vanillaFlavorTagID, category: "Sweet", subcategory: "Bakery", descriptor: "Vanilla")
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
                    FlavorTag(id: toastedGrainFlavorTagID, category: "Roast", subcategory: "Toast", descriptor: "Toasted Grain"),
                    FlavorTag(id: cloveFlavorTagID, category: "Spice", subcategory: "Warm", descriptor: "Clove")
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
                    FlavorTag(id: peachFlavorTagID, category: "Fruit", subcategory: "Stone Fruit", descriptor: "Peach"),
                    FlavorTag(id: lemonFlavorTagID, category: "Acid", subcategory: "Crisp", descriptor: "Lemon")
                ],
                eloScore: 1536,
                loggedAt: earlier.addingTimeInterval(-60 * 60 * 18)
            ),
            DrinkLog(
                id: priyaAmericanoID,
                userID: priyaID,
                shopID: paperPlaneID,
                isHomeBrew: false,
                drinkName: "Iced Americano",
                brewMethod: .espresso,
                roast: .medium,
                sweetness: 2,
                strength: 5,
                wouldOrder: .yes,
                notes: "Clean and bold over ice. No sugar needed.",
                flavorTags: [
                    FlavorTag(id: UUID(), category: "Roast", subcategory: "Chocolate", descriptor: "Dark Chocolate"),
                    FlavorTag(id: UUID(), category: "Fruit", subcategory: "Citrus", descriptor: "Lemon")
                ],
                eloScore: 1455,
                loggedAt: today.addingTimeInterval(-60 * 90)
            ),
            DrinkLog(
                id: priyaCortadoID,
                userID: priyaID,
                shopID: littleWindowID,
                isHomeBrew: false,
                drinkName: "Light Roast Cortado",
                brewMethod: .cortado,
                roast: .light,
                sweetness: 3,
                strength: 4,
                wouldOrder: .yes,
                notes: "Floral and bright with a lovely milk ratio.",
                flavorTags: [
                    FlavorTag(id: UUID(), category: "Floral", subcategory: "Fresh", descriptor: "Jasmine"),
                    FlavorTag(id: UUID(), category: "Fruit", subcategory: "Stone Fruit", descriptor: "Peach")
                ],
                eloScore: 1480,
                loggedAt: thisWeek.addingTimeInterval(-60 * 60 * 2)
            ),
            DrinkLog(
                id: marcusEspressoID,
                userID: marcusID,
                shopID: emberOakID,
                isHomeBrew: false,
                drinkName: "Ethiopia Natural Espresso",
                brewMethod: .espresso,
                roast: .light,
                sweetness: 4,
                strength: 4,
                wouldOrder: .yes,
                notes: "Fruit-forward and vibrant. Like drinking wine.",
                flavorTags: [
                    FlavorTag(id: UUID(), category: "Fruit", subcategory: "Berry", descriptor: "Blueberry"),
                    FlavorTag(id: UUID(), category: "Sweet", subcategory: "Sugar", descriptor: "Brown Sugar")
                ],
                eloScore: 1512,
                loggedAt: today.addingTimeInterval(-60 * 120)
            ),
            DrinkLog(
                id: marcusColdBrewID,
                userID: marcusID,
                shopID: ninthStreetID,
                isHomeBrew: false,
                drinkName: "Nitro Cold Brew",
                brewMethod: .coldBrew,
                roast: .dark,
                sweetness: 3,
                strength: 5,
                wouldOrder: .maybe,
                notes: "Creamy head, heavy body. Bold but one was enough.",
                flavorTags: [
                    FlavorTag(id: UUID(), category: "Roast", subcategory: "Chocolate", descriptor: "Cocoa"),
                    FlavorTag(id: UUID(), category: "Nutty", subcategory: "Tree Nut", descriptor: "Walnut")
                ],
                eloScore: 1388,
                loggedAt: thisWeek.addingTimeInterval(-60 * 60 * 30)
            ),
            DrinkLog(
                id: linaLatteID,
                userID: linaID,
                shopID: emberOakID,
                isHomeBrew: false,
                drinkName: "Brown Sugar Oat Latte",
                brewMethod: .latte,
                roast: .medium,
                sweetness: 5,
                strength: 2,
                wouldOrder: .yes,
                notes: "Sweet, smooth, very approachable.",
                flavorTags: [
                    FlavorTag(id: UUID(), category: "Sweet", subcategory: "Sugar", descriptor: "Brown Sugar"),
                    FlavorTag(id: UUID(), category: "Sweet", subcategory: "Sugar", descriptor: "Caramel")
                ],
                eloScore: 1471,
                loggedAt: today.addingTimeInterval(-60 * 50)
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
            ),
            Friendship(
                id: UUID(uuidString: "40000000-0000-0000-0000-000000000003")!,
                requesterID: marcusID,
                addresseeID: satvikID,
                status: .accepted
            ),
            // Priya sent a friend request — shows up in activity feed
            Friendship(
                id: UUID(uuidString: "40000000-0000-0000-0000-000000000004")!,
                requesterID: priyaID,
                addresseeID: satvikID,
                status: .pending
            ),
            // Lina isn't connected to satvik yet, but is friends with two of
            // satvik's friends — gives the "Suggested for You" feature real
            // friends-of-friends data to demonstrate in demo mode.
            Friendship(
                id: UUID(uuidString: "40000000-0000-0000-0000-000000000005")!,
                requesterID: mayaID,
                addresseeID: linaID,
                status: .accepted
            ),
            Friendship(
                id: UUID(uuidString: "40000000-0000-0000-0000-000000000006")!,
                requesterID: marcusID,
                addresseeID: linaID,
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
            ),
            Comparison(
                id: UUID(uuidString: "60000000-0000-0000-0000-000000000002")!,
                userID: satvikID,
                winnerLogID: satvikEspressoID,
                loserLogID: satvikColdBrewID,
                comparedAt: today.addingTimeInterval(-60 * 10)
            ),
            Comparison(
                id: UUID(uuidString: "60000000-0000-0000-0000-000000000003")!,
                userID: satvikID,
                winnerLogID: satvikPourOverID,
                loserLogID: satvikEspressoID,
                comparedAt: thisWeek.addingTimeInterval(-60 * 60 * 4)
            ),
            Comparison(
                id: UUID(uuidString: "60000000-0000-0000-0000-000000000004")!,
                userID: satvikID,
                winnerLogID: homeBrewID,
                loserLogID: satvikColdBrewID,
                comparedAt: thisWeek.addingTimeInterval(-60 * 60 * 48)
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
