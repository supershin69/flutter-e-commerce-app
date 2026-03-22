# Assets Directory

This directory contains all image assets for the e-commerce app.

## Folder Structure

### `/images/categories/`
Place category icon images here. The app expects the following category icons:
- `phone.png` - Phone category icon
- `camera.png` - Camera category icon  
- `tablet.png` - Tablet category icon
- `tv.png` - TV category icon
- `headphones.png` - Headphones category icon
- `watch.png` - Watch category icon

**Note:** Currently, the app uses Material Icons for categories. To use custom images, you'll need to update the home screen code to use `Image.asset()` instead of `Icon()`.

### `/images/banners/`
Place promotional banner images here. The app supports multiple banners that will be displayed in a carousel.

**Recommended dimensions:** 800x400px or similar aspect ratio
**File format:** JPG or PNG

### `/images/`
Main images directory for product images and other general assets.

## Current Assets
- Product images: `phone.jpg`, `laptop.jpg`, `airpod.jpg`
- Advertisement banners: `ad1.jpg`, `ad2.jpg`, `ad3.jpg`
- App logo: `app_logo.png`, `app_logo.jpg`
- Flash screen logo: `flash_logo.png`
