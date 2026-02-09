# Image Scaler

A lightweight macOS app for batch image resizing and format conversion, powered by `sips`. Includes a Finder extension so you can scale images straight from a right-click context menu.

## Features

- **Three scaling modes**
  - **UI Assets (@1x/@2x/@3x)** — generate asset sets from a base pixel size, with built-in presets for common UI element sizes
  - **Single (fit width)** — resize to a maximum width
  - **Single (fit within box)** — resize to fit within a maximum width and/or height
- **Format conversion** — output as JPG or PNG
- **Never upscale** — skip resizing if the image is already smaller than the target
- **Preserve aspect ratio** — maintain proportions when resizing
- **Keep original filename** — output files use the source filename (single/box modes)
- **ImageOptim integration** — optionally send processed images to [ImageOptim](https://imageoptim.com) for further optimization
- **Persistent settings** — all options are remembered between launches
- **Finder extension** — right-click image files in Finder and choose "Scale Images..." to send them directly to the app

## Getting Images In

- Drag and drop onto the app window
- Use the "Choose Images..." button
- Right-click files in Finder → "Scale Images..."

## Output

Processed images are saved in a subfolder next to the originals:
- UI Assets mode → `scaled/`
- Single/Box modes → `scaled_single/`

## Finder Extension Setup

After building and running the app, enable the extension in **System Settings → Login Items & Extensions → Added Extensions** and toggle on **Image Scaler → Finder**.

## Requirements

- macOS 15.0+
- Xcode 16+

## License

MIT
