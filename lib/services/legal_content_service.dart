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

2. INFORMATION WE COLLECT

2.1 Personal Information
- Phone Number: We collect your phone number for authentication purposes using Firebase Authentication.
- User Profile: Name, gender, birthday, and subscription plan information (if applicable).

2.2 Wardrobe Data
- Wardrobe Information: Titles, locations, seasons, and cloth counts.
- Clothing Items: Images, types, colors, seasons, occasions, and last worn dates.
- Outfit Suggestions: AI-generated outfit suggestions based on your wardrobe.

2.3 Chat Data
- Chat History: Conversations with our AI styling assistant.
- Messages: User queries and AI responses stored in Firestore.

2.4 Device Information
- Device Information: Collected through Firebase Analytics for app improvement.
- Push Notification Tokens: For sending you daily outfit suggestions and updates.

2.5 Images
- Clothing Photos: Images you upload to organize your wardrobe.
- Storage: Images are stored securely in Firebase Storage.

3. HOW WE USE YOUR INFORMATION

3.1 Core Services
- To provide wardrobe organization features
- To generate personalized outfit suggestions
- To enable AI chat assistant functionality
- To send daily outfit suggestions via push notifications

3.2 Service Improvement
- To analyze app usage patterns through Firebase Analytics
- To improve app performance and user experience
- To fix bugs and develop new features

3.3 Communication
- To send you notifications about daily suggestions
- To respond to your inquiries and provide support

4. DATA STORAGE AND SECURITY

4.1 Firebase Services
We use the following Firebase services:
- Firebase Authentication: For secure user authentication
- Cloud Firestore: For storing your wardrobe data, chat history, and user profile
- Firebase Storage: For storing clothing images
- Firebase Analytics: For understanding app usage
- Firebase Cloud Messaging: For push notifications

4.2 Data Security
- All data is encrypted in transit using HTTPS
- Firestore data is encrypted at rest
- Firebase Storage uses secure access controls
- We implement Firebase App Check for additional security

4.3 Data Location
Your data is stored in Firebase servers, which may be located in various regions. We ensure compliance with applicable data protection laws.

5. THIRD-PARTY SERVICES

5.1 Firebase (Google)
- We use Google Firebase services for authentication, database, storage, and analytics.
- Firebase's privacy policy: https://firebase.google.com/support/privacy

5.2 AI Services
- We may use third-party AI services for outfit suggestions and chat functionality.
- These services process your wardrobe data to provide personalized recommendations.

6. YOUR RIGHTS

6.1 Access
- You can access your data through the app at any time.

6.2 Deletion
- You can delete your account and all associated data through the Account Settings in the app.
- Account deletion will permanently remove:
  - Your user profile
  - All wardrobes and clothing items
  - Chat history
  - All images stored in Firebase Storage

6.3 Data Export
- You can view all your data within the app.
- For data export requests, please contact us at ${AppConstants.privacyEmail}

6.4 Opt-Out
- You can disable push notifications in your device settings.
- You can delete your account at any time.

7. DATA RETENTION

- We retain your data as long as your account is active.
- Upon account deletion, all data is permanently removed within 30 days.
- Some anonymized analytics data may be retained for service improvement.

8. CHILDREN'S PRIVACY

Our app is not intended for users under the age of 13. We do not knowingly collect personal information from children under 13. If you believe we have collected information from a child under 13, please contact us immediately.

9. CHANGES TO THIS PRIVACY POLICY

We may update this privacy policy from time to time. We will notify you of any changes by:
- Posting the new privacy policy in the app
- Updating the "Last Updated" date
- Sending you a notification if changes are significant

10. CONTACT US

If you have questions about this privacy policy or our data practices, please contact us:

Email: ${AppConstants.privacyEmail}
Support Email: ${AppConstants.supportEmail}

11. GOVERNING LAW

This privacy policy is governed by applicable data protection laws in your jurisdiction.

By using ${AppConstants.appName}, you agree to this privacy policy.
''';
  }

  /// Get Terms & Conditions content
  static String getTermsAndConditions() {
    return '''
TERMS AND CONDITIONS

Last Updated: ${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}

1. ACCEPTANCE OF TERMS

By downloading, installing, or using ${AppConstants.appName} (the "App"), you agree to be bound by these Terms and Conditions. If you do not agree to these terms, please do not use the App.

2. DESCRIPTION OF SERVICE

${AppConstants.appName} is a mobile application that helps you:
- Organize your wardrobe and clothing items
- Receive AI-powered daily outfit suggestions
- Chat with an AI styling assistant
- Manage multiple wardrobes

3. USER ACCOUNT

3.1 Account Creation
- You must provide accurate information when creating an account
- You are responsible for maintaining the security of your account
- You must be at least 13 years old to use this App

3.2 Account Responsibilities
- You are responsible for all activities under your account
- You must notify us immediately of any unauthorized use
- You must not share your account credentials with others

4. ACCEPTABLE USE

4.1 Permitted Use
- Use the App for personal, non-commercial purposes
- Organize your own wardrobe and clothing items
- Follow all applicable laws and regulations

4.2 Prohibited Activities
You agree NOT to:
- Upload illegal, offensive, or inappropriate content
- Upload images that are not your own clothing items
- Attempt to hack, reverse engineer, or compromise the App
- Use the App to violate any laws or regulations
- Interfere with the App's security or functionality
- Create multiple accounts to circumvent limitations
- Use automated systems to access the App
- Share your account with others

5. CONTENT AND INTELLECTUAL PROPERTY

5.1 Your Content
- You retain ownership of images and data you upload
- You grant us a license to use, store, and process your content to provide the App's services
- You are responsible for ensuring you have rights to upload any content

5.2 Our Content
- The App, including its design, features, and AI technology, is our intellectual property
- You may not copy, modify, or distribute the App without permission
- All trademarks and logos are our property

5.3 AI-Generated Content
- Outfit suggestions are generated by AI and are for informational purposes only
- We do not guarantee the accuracy or suitability of AI suggestions
- You are responsible for your fashion choices

6. SUBSCRIPTION AND PAYMENTS

6.1 Free Features
- Basic wardrobe organization is free
- Limited number of wardrobes may be available for free users

6.2 Premium Features
- Additional features may require a subscription
- Subscription terms and pricing will be clearly displayed
- Subscriptions auto-renew unless cancelled
- Refunds are subject to platform policies (Google Play/App Store)

7. DISCLAIMERS

7.1 Service Availability
- We do not guarantee uninterrupted or error-free service
- The App may be unavailable due to maintenance or technical issues
- We reserve the right to modify or discontinue features

7.2 AI Suggestions
- Outfit suggestions are AI-generated and may not always be accurate
- We are not responsible for fashion choices made based on suggestions
- Suggestions are provided "as is" without warranties

7.3 Third-Party Services
- The App uses Firebase and other third-party services
- We are not responsible for third-party service outages or issues

8. LIMITATION OF LIABILITY

TO THE MAXIMUM EXTENT PERMITTED BY LAW:
- We are not liable for any indirect, incidental, or consequential damages
- Our total liability is limited to the amount you paid for the App (if any)
- We are not responsible for data loss, though we implement security measures
- We are not liable for fashion choices or outcomes based on AI suggestions

9. INDEMNIFICATION

You agree to indemnify and hold us harmless from any claims, damages, or expenses arising from:
- Your use of the App
- Your violation of these Terms
- Your violation of any rights of others
- Content you upload

10. TERMINATION

10.1 By You
- You may delete your account at any time through Account Settings
- Account deletion is permanent and cannot be undone

10.2 By Us
We may terminate or suspend your account if:
- You violate these Terms
- You engage in fraudulent or illegal activity
- Required by law or court order
- We discontinue the App

11. MODIFICATIONS TO TERMS

We may modify these Terms at any time. We will:
- Post updated Terms in the App
- Update the "Last Updated" date
- Notify you of significant changes

Continued use of the App after changes constitutes acceptance.

12. DATA DELETION

Upon account deletion:
- All your data will be permanently deleted
- This includes wardrobes, clothing items, images, and chat history
- Deletion may take up to 30 days to complete
- Some anonymized analytics data may be retained

13. GOVERNING LAW

These Terms are governed by the laws of your jurisdiction. Any disputes will be resolved through appropriate legal channels.

14. SEVERABILITY

If any provision of these Terms is found to be unenforceable, the remaining provisions will remain in effect.

15. ENTIRE AGREEMENT

These Terms constitute the entire agreement between you and us regarding the App.

16. CONTACT INFORMATION

For questions about these Terms, please contact us:

Email: ${AppConstants.supportEmail}
Privacy Email: ${AppConstants.privacyEmail}

17. ACKNOWLEDGMENT

By using ${AppConstants.appName}, you acknowledge that you have read, understood, and agree to be bound by these Terms and Conditions.

${AppConstants.appName} - Organize Your Wardrobe, Style Your Life
''';
  }

  /// Get last updated date
  static String getLastUpdatedDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

