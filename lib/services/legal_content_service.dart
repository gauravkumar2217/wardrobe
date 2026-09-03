import '../constants/app_constants.dart';

/// Service to provide legal content for Privacy Policy and Terms & Conditions
class LegalContentService {
  /// Get Privacy Policy content
  static String getPrivacyPolicy() {
    return '''
PRIVACY POLICY

Last Updated: ${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}

1. INTRODUCTION

Welcome to ${AppConstants.appName} (the "App"), also known as Wardrobe Chat. We respect your privacy and are committed to protecting your personal data. This privacy policy explains how we collect, use, and safeguard your information when you use our mobile application, website (www.wardrobe.chat), and related services.

By using ${AppConstants.appName}, you agree to the collection and use of information in accordance with this policy.

2. INFORMATION WE COLLECT

2.1 Account and Authentication Information
- Email Address / Username / Password: Collected when you create an account with credentials.
- Phone Number: Optional verification and recovery via Firebase Authentication / SMS where enabled.
- Google Account Information: If you sign in with Google, we access basic profile information (name, email, profile picture) you authorize.
- Apple Account Information: If you sign in with Apple, we receive information you authorize.
- Profile Information: Display name, gender, date of birth, and profile photo.

2.2 Wardrobe and Clothing Data
- Wardrobe Information: Wardrobe names, locations, item counts, and creation dates.
- Clothing Items: Images of your clothing, cloth types, colors, seasons, categories, occasions, placement status (InWardrobe, OutWardrobe, Laundry, DryCleaning, Repairing), and placement details (shop name, given date, return date when applicable).
- Wear History: Dates and times when you mark clothing items as worn.
- AI Detection Data: When you add clothing items, we use Google ML Kit to analyze images for cloth type detection and Palette Generator to extract color information. This processing occurs locally on your device and does not send images to external servers.

2.3 Social and Communication Data
- Friends List: Users you have added as friends.
- Friend Requests: Incoming and outgoing friend requests.
- Direct Messages: Text messages and shared clothing items sent through direct messaging.
- Comments: Comments you post on clothing items.
- Likes: Clothing items you have liked.
- Style Posts: Style content you create or interact with.
- Shared Clothing: Clothing items you share with friends via direct messages.
- Blocks and Reports: Users you block and content/users you report for safety.

2.4 Notifications and Preferences
- Notification Settings: Your preferences for receiving notifications (friend requests, friend accepts, direct messages, cloth likes, cloth comments, suggestions).
- Quiet Hours: Your preferred quiet hours for notifications.
- Push Notification Tokens: Device tokens for sending push notifications.

2.5 Device and Usage Information
- Device Information: Device type, operating system, app version, and device identifiers collected through Firebase Analytics.
- Usage Analytics: App usage patterns, feature usage, and performance metrics to improve the app experience.
- Crash Reports: Error logs and crash reports to identify and fix issues.

2.6 Images and Media
- Clothing Photos: Images you upload to organize your wardrobe.
- Profile Photos: Your profile picture.
- Image Processing: Some analysis (e.g. cloth type/color) may run on-device. Other AI features may send images or related data to our servers and AI providers.

2.7 Virtual Avatar and Try-On Data
- Body photos you upload to create a personal avatar.
- Generated avatar images and virtual try-on results.
- These are processed on our servers and may use third-party AI providers solely to provide avatar and try-on features.

2.8 AI Chat and Suggestions
- Messages you send to the AI styling assistant.
- Wardrobe context used to generate outfit suggestions and chat responses.

3. HOW WE USE YOUR INFORMATION

3.1 Core App Services
- To provide wardrobe organization and management features
- To enable AI-powered cloth type and color detection
- To track clothing placement and wear history
- To generate personalized outfit suggestions and AI styling chat
- To provide virtual avatar generation and try-on features
- To enable social features including friends, messaging, comments, likes, and style posts
- To send push notifications based on your preferences

3.2 Social Features
- To display your profile to other users (based on privacy settings)
- To enable friend requests and friend connections
- To facilitate direct messaging between users
- To show comments and likes on clothing items
- To enable sharing of clothing items with friends

3.3 Service Improvement
- To analyze app usage patterns through Firebase Analytics
- To improve app performance and user experience
- To fix bugs and develop new features
- To understand how features are used to prioritize improvements

3.4 Communication
- To send you push notifications about friend requests, messages, likes, comments, and suggestions
- To respond to your inquiries and provide customer support
- To notify you of important app updates or policy changes

3.5 Legal and Safety
- To comply with legal obligations
- To enforce our Terms and Conditions
- To protect the rights and safety of users
- To prevent fraud and abuse

4. DATA STORAGE AND SECURITY

4.1 Infrastructure and Services
We use:
- Firebase Authentication: For secure user authentication (email/password, Google, Apple, phone verification where enabled)
- Wardrobe Chat API (Laravel / www.wardrobe.chat): For storing and serving app data such as wardrobes, clothing, social features, avatars, try-on results, and related content
- Secure cloud storage: For clothing images, profile photos, and avatar images
- Firebase Analytics: For understanding app usage (anonymized/aggregated where applicable)
- Firebase Cloud Messaging: For sending push notifications
- Firebase App Check: For additional security and abuse prevention where enabled

4.2 Data Security Measures
- All data is encrypted in transit using HTTPS/TLS
- Server and storage access is protected with authentication and access controls
- User authentication is handled securely through Firebase Authentication
- Access to user data is controlled through server-side authorization

4.3 Data Location
Your data may be stored and processed on servers in various regions operated by us or our providers. We aim to comply with applicable data protection laws including GDPR, CCPA, and other regional requirements.

5. THIRD-PARTY SERVICES

5.1 Google Services
- Firebase (Google): Used for authentication, analytics, messaging, and related services. Firebase's privacy policy: https://firebase.google.com/support/privacy
- Google Sign-In: If you choose to sign in with Google, authentication is handled by Google. We only receive basic profile information you authorize.
- Google ML Kit: May be used for on-device image labeling to detect cloth types.
- Google Play Services: Required for push notifications and app functionality on Android devices.

5.2 Apple Services
- Apple Sign-In: Authentication is handled by Apple. We only receive information you authorize.
- Apple Push Notification Service: Used for push notifications on iOS devices.

5.3 AI and Image Processing Providers
- We may use third-party AI services (such as OpenAI or Google Gemini) and image processing providers to power outfit suggestions, styling chat, cloth detection, avatar generation, and virtual try-on.
- These providers process only the data needed to deliver the requested feature.

5.4 Analytics
- Firebase Analytics: Used to understand app usage. Analytics data is anonymized and aggregated where applicable.

6. DATA SHARING AND DISCLOSURE

6.1 With Other Users
- Your profile information (username, display name, profile photo) may be visible to other users based on your privacy settings
- Clothing items you share via direct messages are visible to the recipient
- Comments and likes you post are visible to the clothing item owner and other users who can view that item
- Your wardrobe visibility is controlled by your privacy settings (friends only by default)

6.2 We Do Not Sell Your Data
- We do not sell, rent, or trade your personal information to third parties
- We do not share your data with advertisers or marketing companies

6.3 Legal Requirements
We may disclose your information if required by law, court order, or government regulation, or to:
- Protect our rights and property
- Prevent fraud or abuse
- Ensure user safety
- Comply with legal obligations

7. YOUR RIGHTS AND CHOICES

7.1 Access Your Data
- You can access all your data through the app at any time
- You can view your profile, wardrobes, clothing items, friends, messages, and settings

7.2 Edit Your Data
- You can update your profile information at any time
- You can edit or delete your clothing items
- You can modify your notification preferences
- You can update your privacy settings

7.3 Delete Your Data
- You can delete individual clothing items, wardrobes, or messages at any time
- You can delete your account and all associated data through Account Settings > Delete Account
- Account deletion will permanently remove:
  * Your user profile and account information
  * All wardrobes and clothing items
  * All images associated with your account
  * Friend connections and friend requests
  * Direct messages and chat history
  * Comments, likes, and style posts
  * Avatar and virtual try-on data
  * Notification preferences
- Deletion is permanent and cannot be undone
- Some anonymized analytics data may be retained for service improvement
- Full policy also available at ${AppConstants.privacyPolicyUrl}

7.4 Data Export
- You can view all your data within the app
- For a complete data export in a machine-readable format, please contact us at ${AppConstants.privacyEmail}
- We will provide your data export within 30 days of your request

7.5 Opt-Out Options
- You can disable push notifications in your device settings or app notification settings
- You can control which types of notifications you receive in the app settings
- You can set quiet hours to limit when you receive notifications
- You can delete your account at any time

7.6 Privacy Settings
- Profile Visibility: Control who can see your profile (friends only by default)
- Wardrobe Visibility: Control who can see your wardrobes (friends only by default)
- Direct Messages: Control who can send you direct messages (friends only by default)

8. CHILDREN'S PRIVACY

Our app is not intended for users under the age of 13. We do not knowingly collect personal information from children under 13. If you are a parent or guardian and believe your child under 13 has provided us with personal information, please contact us immediately at ${AppConstants.privacyEmail}. If we become aware that we have collected personal information from a child under 13, we will take steps to delete that information promptly.

9. INTERNATIONAL USERS

If you are using our app from outside the United States, please note that your information may be transferred to, stored, and processed in the United States or other countries where our service providers operate. By using our app, you consent to the transfer of your information to these countries. We ensure compliance with applicable data protection laws in your jurisdiction.

10. DATA RETENTION

- We retain your data as long as your account is active
- Upon account deletion, all personal data is permanently removed within 30 days
- Some anonymized analytics data may be retained for service improvement
- Backup data may be retained for up to 90 days before permanent deletion

11. CHANGES TO THIS PRIVACY POLICY

We may update this privacy policy from time to time to reflect changes in our practices or legal requirements. We will notify you of any material changes by:
- Posting the new privacy policy in the app
- Updating the "Last Updated" date
- Sending you a push notification if changes are significant
- Displaying a notice in the app for significant changes

Your continued use of the app after changes constitutes acceptance of the updated policy. We encourage you to review this policy periodically.

12. CALIFORNIA PRIVACY RIGHTS (CCPA)

If you are a California resident, you have additional rights under the California Consumer Privacy Act (CCPA):
- Right to know what personal information we collect
- Right to delete your personal information
- Right to opt-out of the sale of personal information (we do not sell your data)
- Right to non-discrimination for exercising your privacy rights

To exercise these rights, please contact us at ${AppConstants.privacyEmail}.

13. EUROPEAN PRIVACY RIGHTS (GDPR)

If you are located in the European Economic Area (EEA), you have additional rights under the General Data Protection Regulation (GDPR):
- Right to access your personal data
- Right to rectification of inaccurate data
- Right to erasure ("right to be forgotten")
- Right to restrict processing
- Right to data portability
- Right to object to processing
- Right to withdraw consent

To exercise these rights, please contact us at ${AppConstants.privacyEmail}.

14. CONTACT US

If you have questions, concerns, or requests regarding this privacy policy or our data practices, please contact us:

Privacy Inquiries: ${AppConstants.privacyEmail}
Support: ${AppConstants.supportEmail}

We will respond to your inquiry within 30 days.

15. GOVERNING LAW

This privacy policy is governed by applicable data protection laws in your jurisdiction, including but not limited to GDPR (for EEA users), CCPA (for California residents), and other applicable regional laws.

16. ACKNOWLEDGMENT

By using ${AppConstants.appName}, you acknowledge that you have read, understood, and agree to this privacy policy. If you do not agree with this policy, please do not use our app.

${AppConstants.appName} - Organize Your Wardrobe, Style Your Life
''';
  }

  /// Get Terms & Conditions content
  static String getTermsAndConditions() {
    return '''
TERMS AND CONDITIONS

Last Updated: ${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}

1. ACCEPTANCE OF TERMS

By downloading, installing, accessing, or using ${AppConstants.appName} (the "App"), also known as Wardrobe Chat, including our website at www.wardrobe.chat, you agree to be bound by these Terms and Conditions ("Terms"). If you do not agree to these Terms, please do not use the App.

These Terms constitute a legally binding agreement between you and us. We may update these Terms from time to time, and your continued use of the App after changes constitutes acceptance. The website version is available at ${AppConstants.termsOfServiceUrl}.

2. DESCRIPTION OF SERVICE

${AppConstants.appName} is a mobile application (Wardrobe Chat) that provides the following services:
- Wardrobe organization and management
- Clothing item tracking with images, categories, and metadata
- AI-powered cloth type and color detection
- Placement tracking (InWardrobe, OutWardrobe, Laundry, DryCleaning, Repairing)
- Wear history tracking and saved outfits
- AI outfit suggestions and styling chat assistant
- Virtual avatar creation and try-on features
- Social features including friends, direct messaging, comments, likes, and style posts
- Clothing item sharing with friends
- User blocking and content reporting for safety
- Push notifications for social interactions and suggestions
- Profile management and privacy controls

3. ELIGIBILITY AND ACCOUNT CREATION

3.1 Age Requirement
- You must be at least 13 years old to use this App
- If you are under 18, you must have parental or guardian consent
- We reserve the right to verify your age and may suspend accounts of users under 13

3.2 Account Creation
- You must provide accurate, current, and complete information when creating an account
- You are responsible for maintaining the security of your account credentials
- You must not share your account with others
- You are responsible for all activities that occur under your account

3.3 Account Types
- You may create an account using username/password, Google Sign-In, or Apple Sign-In
- Phone numbers and email addresses may be verified where enabled
- Google or Apple Sign-In requires authorization from your provider account

4. ACCEPTABLE USE

4.1 Permitted Use
You may use the App to:
- Organize and manage your personal wardrobe
- Track your clothing items and wear history
- Connect with friends and share clothing items
- Comment on and like clothing items
- Send direct messages to friends
- Use AI features for cloth type and color detection

4.2 Prohibited Activities
You agree NOT to:
- Upload illegal, offensive, harmful, or inappropriate content
- Upload images that are not your own clothing items or that infringe on others' rights
- Upload content that violates any laws or regulations
- Harass, abuse, threaten, or harm other users
- Impersonate any person or entity
- Attempt to hack, reverse engineer, or compromise the App or its security
- Use automated systems, bots, or scripts to access the App
- Create multiple accounts to circumvent limitations or violate these Terms
- Share your account credentials with others
- Use the App for commercial purposes without authorization
- Violate intellectual property rights of others
- Interfere with or disrupt the App's functionality or servers
- Collect or harvest information about other users without consent
- Send spam, unsolicited messages, or unwanted communications

4.3 ZERO TOLERANCE POLICY FOR OBJECTIONABLE CONTENT AND ABUSIVE USERS

${AppConstants.appName} maintains a ZERO TOLERANCE policy for objectionable content and abusive behavior. This policy applies to all user-generated content including but not limited to comments, direct messages, clothing item descriptions, and profile information.

By using this App, you acknowledge and agree that:

- There is ABSOLUTELY NO TOLERANCE for objectionable content, harassment, abuse, threats, or harmful behavior directed at other users
- Any content that is illegal, offensive, harmful, inappropriate, or violates community standards will be removed immediately
- Users who post objectionable content or engage in abusive behavior will have their content removed instantly and may be permanently banned from the platform
- We reserve the right to remove any content and eject any user who violates these Terms without prior notice
- You can report objectionable content or abusive users using the reporting mechanisms provided in the App
- You can block abusive users, which will immediately remove their content from your feed
- We will act on reports of objectionable content within 24 hours by removing the content and ejecting users who provided offending content
- Violations of this policy may result in immediate account termination and permanent ban from the platform

This zero tolerance policy is non-negotiable and applies to all users equally. By accepting these Terms & Conditions, you explicitly acknowledge that you understand and agree to comply with this policy.

5. CONTENT AND INTELLECTUAL PROPERTY

5.1 Your Content
- You retain ownership of images and data you upload to the App
- You grant us a worldwide, non-exclusive, royalty-free license to use, store, display, and process your content to provide the App's services
- You are responsible for ensuring you have all necessary rights to upload any content
- You represent that your content does not violate any laws or third-party rights
- We reserve the right to remove content that violates these Terms

5.2 Our Content
- The App, including its design, features, code, AI technology, and branding, is our intellectual property
- You may not copy, modify, distribute, or create derivative works without permission
- All trademarks, logos, and service marks are our property
- You may not use our intellectual property for any purpose without authorization

5.3 AI-Generated Content and Features
- Cloth type detection, color extraction, outfit suggestions, styling chat, avatar generation, and virtual try-on may use AI/ML technology
- Some processing occurs on-device; other features are processed on our servers and/or by third-party AI providers
- We do not guarantee the accuracy of AI detections, suggestions, or try-on results
- You are responsible for verifying AI-generated information and for your fashion choices
- We are not liable for any decisions made based on AI suggestions or try-on results

6. SOCIAL FEATURES AND USER INTERACTIONS

6.1 Friends and Connections
- You can send and receive friend requests
- Friend connections allow you to see each other's profiles and shared content (based on privacy settings)
- You are responsible for your interactions with other users
- We are not responsible for disputes between users

6.2 Direct Messaging
- You can send direct messages to your friends
- You can share clothing items via direct messages
- Messages are private between sender and recipient
- You must not send spam, harassment, or inappropriate content
- We reserve the right to monitor messages for safety and compliance
- You can report inappropriate messages using the reporting feature
- You can block users who send abusive or unwanted messages

6.3 Comments and Likes
- You can comment on and like clothing items
- Comments must be respectful and appropriate
- You are responsible for your comments
- We reserve the right to remove inappropriate comments immediately
- You can report objectionable comments using the reporting feature
- You can block users who post abusive comments

6.4 Content Sharing
- You can share your own clothing items with friends
- Shared items are visible only to the recipient
- Recipients cannot edit, save, or re-share items you share with them
- You must respect others' privacy and not share content without permission

6.5 Reporting and Blocking Mechanisms
- The App provides mechanisms for users to flag objectionable content
- The App provides mechanisms for users to block abusive users
- When you block a user, their ability to interact with you is restricted according to App rules
- All reports are reviewed, and we commit to acting on reports within 24 hours where practicable
- Actions taken may include removing content and ejecting users who violate these Terms

6.6 Virtual Avatar and Try-On
- Avatar generation requires a body photo you upload; you must have the right to use that image
- Try-on results are approximations and may not perfectly reflect real-world fit or appearance
- We may use third-party AI processors to generate avatars and try-on images
- We do not guarantee availability, accuracy, or suitability of virtual fitting results

7. PRIVACY AND DATA

7.1 Privacy Policy
- Your use of the App is also governed by our Privacy Policy
- Please review our Privacy Policy (in-app and at ${AppConstants.privacyPolicyUrl}) to understand how we collect, use, and protect your data

7.2 Data Security
- We implement security measures to protect your data
- However, no system is 100% secure
- You are responsible for maintaining the security of your account
- You must notify us immediately of any unauthorized access

7.3 Data Deletion
- You can delete your account and data at any time through Account Settings
- Account deletion is permanent and cannot be undone
- Some data may be retained for legal or safety purposes
- Anonymized analytics data may be retained

8. SUBSCRIPTION AND PAYMENTS

8.1 Free Features
- Basic wardrobe organization and social features are available for free
- Some features may have usage limitations for free users

8.2 Premium Features (If Applicable)
- Additional features may require a subscription
- Subscription terms, pricing, and features will be clearly displayed
- Subscriptions automatically renew unless cancelled
- You can cancel subscriptions through your device's app store settings
- Refunds are subject to Google Play and App Store policies
- We reserve the right to modify subscription terms with notice

9. DISCLAIMERS

9.1 Service Availability
- We do not guarantee uninterrupted, error-free, or secure service
- The App may be unavailable due to maintenance, technical issues, or circumstances beyond our control
- We reserve the right to modify, suspend, or discontinue features at any time
- We are not responsible for any loss or inconvenience due to service unavailability

9.2 AI and Automated Features
- AI-powered features (cloth type detection, color extraction) are provided "as is"
- We do not guarantee the accuracy, completeness, or suitability of AI detections
- You are responsible for verifying and correcting AI-detected information
- We are not liable for any decisions or actions based on AI suggestions

9.3 Third-Party Services
- The App uses Firebase, Google/Apple services, our Wardrobe Chat API, AI providers, and other third-party services
- We are not responsible for third-party service outages, issues, or data breaches
- Your use of third-party services is subject to their terms and privacy policies
- We are not liable for any issues arising from third-party services

9.4 User Content and Interactions
- We are not responsible for user-generated content
- We do not endorse or verify the accuracy of user content
- We are not responsible for disputes between users
- You interact with other users at your own risk

10. LIMITATION OF LIABILITY

TO THE MAXIMUM EXTENT PERMITTED BY LAW:
- We are not liable for any indirect, incidental, special, consequential, or punitive damages
- Our total liability is limited to the amount you paid for the App (if any) or \$10, whichever is greater
- We are not responsible for data loss, though we implement security measures
- We are not liable for fashion choices, outcomes, or decisions based on AI suggestions
- We are not liable for user interactions, disputes, or content shared by users
- We are not responsible for third-party service issues or data breaches
- These limitations apply even if we have been advised of the possibility of such damages

11. INDEMNIFICATION

You agree to indemnify, defend, and hold us harmless from any claims, damages, losses, liabilities, costs, or expenses (including legal fees) arising from:
- Your use of the App
- Your violation of these Terms
- Your violation of any rights of others (including intellectual property rights)
- Content you upload, share, or post
- Your interactions with other users
- Any unauthorized use of your account

12. TERMINATION

12.1 Termination by You
- You may delete your account at any time through Account Settings > Delete Account
- Account deletion is permanent and cannot be undone
- Upon deletion, your data will be removed as described in our Privacy Policy

12.2 Termination by Us
We may terminate or suspend your account immediately if:
- You violate these Terms
- You engage in fraudulent, illegal, or harmful activity
- You harass, abuse, or harm other users
- Required by law or court order
- We discontinue the App or service
- For any other reason we deem necessary for safety or compliance

12.3 Effect of Termination
- Upon termination, your right to use the App ceases immediately
- We may delete your account and data
- You remain liable for all obligations incurred before termination
- Provisions that by their nature should survive will survive termination

13. MODIFICATIONS TO TERMS

We may modify these Terms at any time. We will:
- Post updated Terms in the App
- Update the "Last Updated" date
- Notify you of significant changes via push notification or in-app notice

Your continued use of the App after changes constitutes acceptance of the updated Terms. If you do not agree with the changes, you must stop using the App and delete your account.

14. DISPUTE RESOLUTION

14.1 Governing Law
These Terms are governed by the laws of your jurisdiction, without regard to conflict of law principles.

14.2 Dispute Resolution Process
- For disputes, please contact us first at ${AppConstants.supportEmail}
- We will attempt to resolve disputes in good faith
- If we cannot resolve a dispute, it will be resolved through appropriate legal channels in your jurisdiction

15. SEVERABILITY

If any provision of these Terms is found to be unenforceable or invalid, that provision will be limited or eliminated to the minimum extent necessary, and the remaining provisions will remain in full force and effect.

16. ENTIRE AGREEMENT

These Terms, together with our Privacy Policy, constitute the entire agreement between you and us regarding the App and supersede all prior agreements and understandings.

17. CONTACT INFORMATION

For questions, concerns, or legal notices regarding these Terms, please contact us:

Support Email: ${AppConstants.supportEmail}
Privacy Email: ${AppConstants.privacyEmail}

We will respond to your inquiry within 30 days.

18. ACKNOWLEDGMENT

By using ${AppConstants.appName}, you acknowledge that:
- You have read, understood, and agree to be bound by these Terms and Conditions
- You have read and understood our Privacy Policy
- You are at least 13 years old (or have parental consent if under 18)
- You will comply with all applicable laws and regulations
- You are responsible for your use of the App and interactions with other users

If you do not agree with these Terms, please do not use the App.

${AppConstants.appName} - Organize Your Wardrobe, Style Your Life

© ${DateTime.now().year} ${AppConstants.appName}. All rights reserved.
''';
  }

  /// Get last updated date
  static String getLastUpdatedDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
