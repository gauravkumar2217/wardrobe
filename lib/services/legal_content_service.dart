import '../constants/app_constants.dart';

/// Service to provide legal content for Privacy Policy and Terms & Conditions
class LegalContentService {
  /// Get Privacy Policy content
  static String getPrivacyPolicy() {
    return '''
PRIVACY POLICY

Last Updated: ${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}

1. INTRODUCTION

Welcome to ${AppConstants.appName} (the "App"). We respect your privacy and are committed to protecting your personal data. This privacy policy explains how we collect, use, and safeguard your information when you use our mobile application.

By using ${AppConstants.appName}, you agree to the collection and use of information in accordance with this policy.

2. INFORMATION WE COLLECT

2.1 Account and Authentication Information
- Phone Number: We collect your phone number for authentication purposes using Firebase Authentication. Phone numbers are verified via SMS.
- Email Address: If you choose to sign in with Google or email, we collect your email address for authentication and account recovery.
- Google Account Information: If you sign in with Google, we access your basic profile information (name, email, profile picture) as provided by Google.
- Username: A unique username you create for your account.
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
- Shared Clothing: Clothing items you share with friends via direct messages.

2.4 Notifications and Preferences
- Notification Settings: Your preferences for receiving notifications (friend requests, friend accepts, direct messages, cloth likes, cloth comments, suggestions).
- Quiet Hours: Your preferred quiet hours for notifications.
- Push Notification Tokens: Device tokens for sending push notifications.

2.5 Device and Usage Information
- Device Information: Device type, operating system, app version, and device identifiers collected through Firebase Analytics.
- Usage Analytics: App usage patterns, feature usage, and performance metrics to improve the app experience.
- Crash Reports: Error logs and crash reports to identify and fix issues.

2.6 Images and Media
- Clothing Photos: Images you upload to organize your wardrobe. Images are stored securely in Firebase Storage.
- Profile Photos: Your profile picture stored in Firebase Storage.
- Image Processing: Images are processed locally on your device using ML Kit and Palette Generator for AI features. Images are not sent to third-party AI services for analysis.

3. HOW WE USE YOUR INFORMATION

3.1 Core App Services
- To provide wardrobe organization and management features
- To enable AI-powered cloth type and color detection
- To track clothing placement and wear history
- To generate personalized outfit suggestions (future feature)
- To enable social features including friends, messaging, comments, and likes
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

4.1 Firebase Services
We use the following Google Firebase services:
- Firebase Authentication: For secure user authentication (phone, email, Google Sign-In)
- Cloud Firestore: For storing your wardrobe data, clothing items, user profiles, friends, messages, comments, likes, and notifications
- Firebase Storage: For storing clothing images and profile photos
- Firebase Analytics: For understanding app usage (anonymized data)
- Firebase Cloud Messaging: For sending push notifications
- Firebase App Check: For additional security and abuse prevention

4.2 Data Security Measures
- All data is encrypted in transit using HTTPS/TLS
- Firestore data is encrypted at rest
- Firebase Storage uses secure access controls and encryption
- We implement Firebase App Check to prevent unauthorized access
- User authentication is handled securely through Firebase Authentication
- Access to user data is controlled through Firestore security rules

4.3 Data Location
Your data is stored in Firebase servers, which may be located in various regions. We ensure compliance with applicable data protection laws including GDPR, CCPA, and other regional requirements.

5. THIRD-PARTY SERVICES

5.1 Google Services
- Firebase (Google): We use Google Firebase services for authentication, database, storage, analytics, and messaging. Firebase's privacy policy: https://firebase.google.com/support/privacy
- Google Sign-In: If you choose to sign in with Google, your authentication is handled by Google. We only receive basic profile information you authorize.
- Google ML Kit: Used for on-device image labeling to detect cloth types. Processing occurs locally on your device.
- Google Play Services: Required for push notifications and app functionality on Android devices.

5.2 Apple Services
- Apple Sign-In: If available, authentication is handled by Apple. We only receive information you authorize.
- Apple Push Notification Service: Used for push notifications on iOS devices.

5.3 Image Processing Libraries
- Palette Generator: Used locally on your device to extract color information from images. No data is sent to external servers.

5.4 Analytics
- Firebase Analytics: We use Firebase Analytics to understand app usage. Analytics data is anonymized and aggregated.

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
  * All images stored in Firebase Storage
  * Friend connections and friend requests
  * Direct messages and chat history
  * Comments and likes
  * Notification preferences
- Deletion is permanent and cannot be undone
- Some anonymized analytics data may be retained for service improvement

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

By downloading, installing, accessing, or using ${AppConstants.appName} (the "App"), you agree to be bound by these Terms and Conditions ("Terms"). If you do not agree to these Terms, please do not use the App.

These Terms constitute a legally binding agreement between you and us. We may update these Terms from time to time, and your continued use of the App after changes constitutes acceptance.

2. DESCRIPTION OF SERVICE

${AppConstants.appName} is a mobile application that provides the following services:
- Wardrobe organization and management
- Clothing item tracking with images, categories, and metadata
- AI-powered cloth type and color detection
- Placement tracking (InWardrobe, OutWardrobe, Laundry, DryCleaning, Repairing)
- Wear history tracking
- Social features including friends, direct messaging, comments, and likes
- Clothing item sharing with friends
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
- You may create an account using phone number, email, or Google Sign-In
- Phone numbers are verified via SMS
- Email addresses may be verified via email
- Google Sign-In requires authorization from your Google account

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
- Cloth type and color detection are provided using AI/ML technology (Google ML Kit and Palette Generator)
- AI features process images locally on your device
- We do not guarantee the accuracy of AI detections
- You are responsible for verifying and correcting AI-detected information
- We are not liable for any decisions made based on AI suggestions

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
- When you block a user, their content is immediately removed from your feed
- Blocking a user also notifies the developer of the inappropriate content
- All reports are reviewed, and we commit to acting on reports within 24 hours
- Actions taken may include removing content and ejecting users who violate these Terms

7. PRIVACY AND DATA

7.1 Privacy Policy
- Your use of the App is also governed by our Privacy Policy
- Please review our Privacy Policy to understand how we collect, use, and protect your data

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
- The App uses Firebase, Google services, and other third-party services
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
