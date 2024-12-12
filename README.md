# YouTube Subtitle Downloader

This is a Ruby-based tool for downloading subtitles from YouTube videos. Users can specify the language of the subtitles they want to download or list all available subtitles for a given video.

## Features

- **Download specific language subtitles**: Users can download subtitles in their preferred language.
- **List available subtitle languages**: View all subtitles supported for a video.
- **Download all available subtitles**: Download every subtitle option available for the video.
- **Debug mode**: Enable detailed output for troubleshooting.

## Installation

Make sure you have Ruby installed on your system. Save the script as `yt_sub_fetch.rb`.

```bash
git clone git@github.com:cofemei/yt_sub_fetch.git
cd yt_sub_fetch
```

## Usage

Run the following command in your terminal:

```bash
chmod +x bin/yt_sub_fetch
bin/yt_sub_fetch [options] URL
```

### Parameters

- `-u`, `--url URL`: The YouTube video URL.
- `-l`, `--lang LANG`: Subtitle language code (e.g., `en`, `zh-TW`).
- `-L`, `--list`: List available subtitle languages.
- `-a`, `--all`: Download all available subtitles.
- `-d`, `--debug`: Enable debug output.
- `-h`, `--help`: Display help information.

### Example

To download English subtitles for a specific video, use the following command:

```bash
bin/yt_sub_fetch -l "en" "https://www.youtube.com/watch?v=VIDEO_ID"
```

Replace `"VIDEO_ID"` with the actual ID of the YouTube video you want to download subtitles from.

## Notes

- Ensure that you provide a valid YouTube video URL.
- Subtitle downloads may be subject to copyright restrictions; please comply with relevant laws and regulations.

## Contribution

Contributions are welcome! If you find any issues or have suggestions for improvements, please submit an issue or a pull request.

## Contact

For any issues or suggestions, please submit a GitHub issue.