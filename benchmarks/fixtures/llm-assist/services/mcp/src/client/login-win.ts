import { exec } from 'node:child_process';

/** Windows fallback for `quill-cli connect` when the `open` package cannot find a browser. */
export function openInBrowserWindows(url: string): void {
  exec('start "" ' + url);
}
