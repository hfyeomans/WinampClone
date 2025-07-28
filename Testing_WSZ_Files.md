# Testing with Real WinAmp .wsz Files

## How to Test

1. **Open the WinAmpPlayer app** (it should now be running)

2. **Load a .wsz skin file**:
   - Click the "Skins" button in the toolbar (or use Cmd+K)
   - Navigate to any .wsz file you have
   - The app supports standard WinAmp 2.x classic skins

3. **What to verify**:
   - Bitmap fonts should render using the skin's text.bmp file
   - Time display should use numbers.bmp for authentic LCD display
   - Song titles should scroll with proper bitmap rendering
   - Text colors should adapt to the skin's color scheme
   - All windows (Main, EQ, Playlist) should be properly skinned

## Where to get .wsz files

1. **WinAmp Skin Museum**: https://skins.webamp.org/
2. **Classic WinAmp skins**: Search for "winamp classic skins download"
3. **Your old collection**: Check if you have any .wsz files from the WinAmp era

## Expected Behavior

When you load a .wsz file:
- The skin should extract and apply immediately
- Bitmap fonts from text.bmp should replace system fonts
- Number displays should use the skin's numbers.bmp
- Colors should update based on the skin's pledit.txt or sampled from bitmaps
- All UI elements should reflect the skin's visual style

## Troubleshooting

If a skin doesn't load properly:
1. Check Console.app for any error messages
2. Ensure the .wsz file contains required files (main.bmp, cbuttons.bmp, etc.)
3. Try a different skin to see if it's skin-specific

## Implementation Status

✅ Bitmap font rendering implemented
✅ ScrollingBitmapText for song titles
✅ BitmapNumberText for time displays
✅ Skin color extraction and management
✅ Full skin support for all windows

The app now has full authentic WinAmp text rendering using bitmap fonts!