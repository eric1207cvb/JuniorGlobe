# Remote Narration API

JuniorGlobe now uses the existing WonderKid speech proxy directly instead of a job-based narration API.

## Base URL

- Override with `JUNIORGLOBE_REMOTE_NARRATION_BASE_URL`
- If unset, the app falls back to `JUNIORGLOBE_PREMIUM_REWRITE_BASE_URL`
- Japanese voice A/B can be switched with `JUNIORGLOBE_JAPANESE_REMOTE_VOICE_AB`
  - `A` or unset: `marin`
  - `B`: `cedar`

Example:

- `https://wonderkidai-server.onrender.com`
- `http://192.168.1.8:8080`

## Speech Endpoint

`POST /api/speech`

Request body mirrors the OpenAI speech API payload that your Express server forwards upstream:

```json
{
  "model": "gpt-4o-mini-tts",
  "voice": "marin",
  "input": "美國太空總署與人工智慧團隊合作。\n\n孩子一起看英國廣播公司直播。",
  "response_format": "mp3",
  "speed": 0.99,
  "instructions": "Speak in contemporary Taiwan Mandarin, using the natural pronunciation commonly heard from warm female elementary teachers in Taiwan. Keep the pacing smooth, lively, and relaxed for children. Read full phrases naturally, including English names commonly used in Taiwan. Avoid robotic pacing, clipped syllables, exaggerated announcer delivery, or any accent that does not sound local to Taiwan."
}
```

Response:

- `200 OK`
- `Content-Type: audio/mpeg`
- Raw MP3 bytes

## App Behavior

- Stage 1 `requesting_script`
  - The app locally cleans and builds the narration transcript.
- Stage 2 `generating_audio`
  - The app waits for `/api/speech` to return MP3 audio.
- Stage 3 `preparing_playback`
  - The app writes the MP3 to a temporary file, loads it into `AVPlayer`, and estimates sentence timings locally.

## Sentence Highlighting

The current backend does not return sentence timing metadata.

JuniorGlobe therefore estimates highlighting on-device from:

- the cleaned transcript sentences
- the final audio duration

This keeps progressive sentence highlighting without requiring backend changes.

## Required Server Behavior

- `/api/speech` must accept JSON and forward it to `https://api.openai.com/v1/audio/speech`
- the response body must stay as raw audio bytes
- `Content-Type` should remain `audio/mpeg`
- requests should complete within the client timeout window of `90` seconds
