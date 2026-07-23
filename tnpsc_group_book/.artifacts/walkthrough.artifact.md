# Walkthrough - Ultra HD (4K) Promotion & Daily Topic Rotation

I have upgraded the "Promote App" feature to generate Ultra HD (4K) quality content and implemented an automated daily topic rotation logic for better content variety.

## Changes Made

### 1. Ultra HD (4K) Image Generation
- **High Resolution**: Increased the `pixelRatio` from `4.0` to `8.0` in both **[ProfileScreen](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/screens/profile_screen.dart)** and **[AdminPromoteScreen](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/screens/admin_promote_screen.dart)**.
- **Crystal Clear Text**: Shared posters now have a width of ~3600px, ensuring they look incredibly sharp on 4K TVs, high-end mobile displays, and YouTube Shorts.

### 2. Daily Topic Rotation Logic
- **Automated Variety**: The app now automatically cycles through TNPSC subjects (Tamil, History, Geography, etc.) every day.
- **Smart Querying**: Added `getRandomQuizzesByTopic` in **[FirestoreService](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/services/firestore_service.dart)** to fetch 3 unique questions from the chosen topic of the day.

### 3. YouTube Shorts Style UI
- **[AdminPromoteScreen](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/screens/admin_promote_screen.dart)**:
    - **Header**: "DAILY TNPSC CHALLENGE" banner with red/orange gradients.
    - **Topic Badge**: Displays "Today's Topic: [Subject]" clearly.
    - **Social Overlays**: Floating "LIKE", "SUBSCRIBE", and "SHARE" icons added to mimic social media interfaces.
    - **Animated Reveal**: The correct answer now pops in with an elastic scale animation.
    - **CTA Footer**: "DOWNLOAD LINK IN BIO" call-to-action for viewers.

## Verification Results

### Manual Test Steps
1. Navigate to **Admin Dashboard** > **Promote App (Video Format)**.
2. Verify the **Topic Rotation**: Confirm the topic changes daily (e.g., today might be Tamil, tomorrow History).
3. Test **Share Quality**: Tap the share icon. The generated image in the sharing preview/WhatsApp will be extremely sharp even when zoomed in.
4. Verify **UI Overlay**: All YouTube Shorts elements are positioned correctly for a 9:16 screen recording.

> [!IMPORTANT]
> Because of the 4K resolution (8.0 pixel ratio), generating the share image might take an extra second compared to before. This is normal and ensures the highest possible quality for your marketing.
