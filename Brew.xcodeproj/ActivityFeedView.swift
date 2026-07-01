import SwiftUI

struct ActivityFeedView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Activity Feed")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(Color("PrimaryTextColor"))
            
            Text("Your recent activity will appear here.")
                .font(.body)
                .foregroundColor(Color("SecondaryTextColor"))
        }
        .padding()
        .background(Color("BackgroundColor"))
        .cornerRadius(10)
        .shadow(radius: 5)
    }
}

struct ActivityFeedView_Previews: PreviewProvider {
    static var previews: some View {
        ActivityFeedView()
            .preferredColorScheme(.light)
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
