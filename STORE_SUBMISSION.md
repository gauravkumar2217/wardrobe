# App Store Submission Guide

This document provides a comprehensive checklist for submitting the Wardrobe app to Google Play Store and Apple App Store.

## Google Play Store Requirements

### Pre-Submission Checklist

- [ ] **App Signing**
  - [ ] Keystore file created and secured
  - [ ] `key.properties` file configured
  - [ ] Release build tested with signed APK/AAB

- [ ] **App Information**
  - [ ] App name: "Wardrobe"
  - [ ] Short description (80 characters max)
  - [ ] Full description (4000 characters max)
  - [ ] App icon (512x512 PNG)
  - [ ] Feature graphic (1024x500 PNG)

- [ ] **Screenshots**
  - [ ] Phone screenshots (at least 2, up to 8)
  - [ ] Tablet screenshots (if supported)
  - [ ] Screenshots show key features

- [ ] **Privacy & Security**
  - [ ] Privacy Policy URL (hosted online, publicly accessible)
  - [ ] Data safety section completed
  - [ ] Permissions explained
  - [ ] Data collection disclosed

- [ ] **Content Rating**
  - [ ] Content rating questionnaire completed
  - [ ] Target audience specified

- [ ] **Pricing & Distribution**
  - [ ] App pricing set (Free/Paid)
  - [ ] Countries selected for distribution
  - [ ] Age restrictions set (if applicable)

- [ ] **Store Listing**
  - [ ] App description written
  - [ ] Short description written
  - [ ] Promotional text (optional)
  - [ ] What's new section (for updates)

### Required Assets

1. **App Icon**: 512x512 PNG (no transparency)
2. **Feature Graphic**: 1024x500 PNG
3. **Screenshots**: 
   - Phone: 16:9 or 9:16 aspect ratio
   - Minimum 320px, maximum 3840px
   - At least 2 screenshots required

### Privacy Policy

- Must be hosted online
- Publicly accessible (no login required)
- Must cover all data collection
- Include contact information
- Update date should be current

### Data Safety Section

Complete the following in Google Play Console:
- Data collection types
- Data sharing practices
- Security practices
- Data deletion options

### Submission Steps

1. Create Google Play Developer account ($25 one-time fee)
2. Create new app in Google Play Console
3. Complete store listing
4. Upload app bundle (AAB format)
5. Complete content rating
6. Complete data safety section
7. Set pricing and distribution
8. Review and publish

## Apple App Store Requirements

### Pre-Submission Checklist

- [ ] **App Signing**
  - [ ] Apple Developer account ($99/year)
  - [ ] App ID created
  - [ ] Provisioning profiles configured
  - [ ] Certificates installed

- [ ] **App Information**
  - [ ] App name: "Wardrobe"
  - [ ] Subtitle (30 characters max)
  - [ ] Description (4000 characters max)
  - [ ] Keywords (100 characters max)
  - [ ] App icon (1024x1024 PNG, no transparency)

- [ ] **Screenshots**
  - [ ] iPhone screenshots (6.7", 6.5", 5.5" displays)
  - [ ] iPad screenshots (if supported)
  - [ ] App Preview videos (optional)

- [ ] **Privacy & Security**
  - [ ] Privacy Policy URL (hosted online)
  - [ ] Privacy nutrition labels completed
  - [ ] App privacy details disclosed

- [ ] **App Store Information**
  - [ ] Category selected
  - [ ] Age rating completed
  - [ ] Pricing set
  - [ ] Availability countries selected

- [ ] **App Review Information**
  - [ ] Contact information provided
  - [ ] Demo account (if required)
  - [ ] Notes for reviewer

### Required Assets

1. **App Icon**: 1024x1024 PNG (no transparency, no rounded corners)
2. **Screenshots**:
   - iPhone 6.7" display: 1290x2796 pixels
   - iPhone 6.5" display: 1242x2688 pixels
   - iPhone 5.5" display: 1242x2208 pixels
   - iPad Pro: 2048x2732 pixels

### Privacy Policy

- Must be hosted online
- Publicly accessible
- Must cover all data collection
- Include contact information
- Update date should be current

### App Privacy Details

Complete in App Store Connect:
- Data collection types
- Data linked to user
- Data used to track user
- Data not linked to user

### Submission Steps

1. Create Apple Developer account ($99/year)
2. Create App ID in Apple Developer portal
3. Create app in App Store Connect
4. Complete app information
5. Upload build via Xcode or Transporter
6. Complete privacy details
7. Submit for review

## Common Requirements (Both Stores)

### Privacy Policy

- Must be accessible online
- Must cover:
  - Data collection
  - Data usage
  - Data storage
  - User rights
  - Contact information

### App Description

Use the content from `assets/store/app_description.txt` and customize as needed.

### Short Description

Use the content from `assets/store/short_description.txt`.

### Screenshots

Take screenshots showing:
1. Welcome/Home screen
2. Wardrobe organization
3. Outfit suggestions
4. AI chat assistant
5. Settings/About page

### Testing Before Submission

- [ ] Test on physical devices (Android and iOS)
- [ ] Test in release mode
- [ ] Verify all features work
- [ ] Check all links work
- [ ] Verify permissions are requested properly
- [ ] Test account creation and deletion
- [ ] Test push notifications
- [ ] Verify legal pages are accessible

### Post-Submission

- [ ] Monitor app reviews
- [ ] Respond to user feedback
- [ ] Fix critical bugs quickly
- [ ] Update app regularly
- [ ] Monitor crash reports

## Resources

- **Privacy Policy**: `assets/store/privacy_policy.txt`
- **Terms & Conditions**: `assets/store/terms_conditions.txt`
- **App Description**: `assets/store/app_description.txt`
- **Short Description**: `assets/store/short_description.txt`

## Support

For questions about submission:
- Google Play: [Play Console Help](https://support.google.com/googleplay/android-developer)
- Apple App Store: [App Store Connect Help](https://help.apple.com/app-store-connect/)

