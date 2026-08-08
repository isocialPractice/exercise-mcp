// Loads the original pastiche numbers from assets/songbook.txt.
import { readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
// Compiled output runs from build/, so assets/ sits one level up.
export const ASSETS_DIR = resolve(dirname(fileURLToPath(import.meta.url)), "..", "assets");
const SONG_OPEN = /^--SONG: ([A-Z]+)--$/;
const SONG_CLOSE = "--END--";
// Parse the songbook once at startup; a stdio server can afford the sync read.
export function loadSongbook() {
    const text = readFileSync(join(ASSETS_DIR, "songbook.txt"), "utf8");
    const songs = new Map();
    let current = null;
    let inChorus = false;
    for (const raw of text.split(/\r?\n/)) {
        const line = raw.trimEnd();
        const open = line.match(SONG_OPEN);
        if (open) {
            current = { mood: open[1], title: "", tempo: "", chorus: [] };
            inChorus = false;
            continue;
        }
        if (!current) {
            continue;
        }
        if (line === SONG_CLOSE) {
            songs.set(current.mood, current);
            current = null;
            continue;
        }
        if (line.startsWith("Title:")) {
            current.title = line.slice("Title:".length).trim();
        }
        else if (line.startsWith("Tempo:")) {
            current.tempo = line.slice("Tempo:".length).trim();
        }
        else if (line === "Chorus:") {
            inChorus = true;
        }
        else if (inChorus && line.length > 0) {
            current.chorus.push(line);
        }
    }
    return songs;
}
