# Wardrobe App - Legal Documents

This folder contains the legal documents for the Wardrobe app that can be hosted on GitHub Pages.

## Files

- `index.html` - Landing page with links to Privacy Policy and Terms & Conditions
- `privacy-policy.html` - Privacy Policy page
- `terms-conditions.html` - Terms & Conditions page

## How to Host on GitHub Pages

### Step 1: Push to GitHub
1. Commit and push these files to your repository:
   ```bash
   git add docs/
   git commit -m "Add legal documents for app store"
   git push
   ```

### Step 2: Enable GitHub Pages
1. Go to your GitHub repository
2. Click on **Settings**
3. Scroll down to **Pages** (in the left sidebar)
4. Under **Source**, select:
   - Branch: `main` (or `master`)
   - Folder: `/docs`
5. Click **Save**

### Step 3: Get Your URL
After a few minutes, your pages will be available at:
- **Main page**: `https://yourusername.github.io/wardrobe/`
- **Privacy Policy**: `https://yourusername.github.io/wardrobe/privacy-policy.html`
- **Terms & Conditions**: `https://yourusername.github.io/wardrobe/terms-conditions.html`

Replace `yourusername` with your GitHub username and `wardrobe` with your repository name.

## For App Store Submission

Use these URLs in your app store listings:

### Google Play Store
- **Privacy Policy URL**: `https://yourusername.github.io/wardrobe/privacy-policy.html`

### Apple App Store
- **Privacy Policy URL**: `https://yourusername.github.io/wardrobe/privacy-policy.html`

## Important Notes

- The pages are mobile-responsive and will work on all devices
- All pages use HTTPS (required by app stores)
- The pages are publicly accessible (no login required)
- Keep these pages active for as long as your app is published
- Update the "Last Updated" date when you make changes

## Customization

If you need to update the content:
1. Edit the HTML files in this folder
2. Update the "Last Updated" date in the header
3. Commit and push the changes
4. GitHub Pages will automatically update (may take a few minutes)

## Contact Information

The contact emails in the pages are:
- Support: support@wardrobe.app
- Privacy: privacy@wardrobe.app

Update these in the HTML files if your contact information changes.

