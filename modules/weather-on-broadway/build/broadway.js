const STORM_TERMS = ["thunder", "storm", "squall", "hail", "torrential", "rain", "shower", "drizzle"];
const SNOW_TERMS = ["snow", "sleet", "blizzard", "flurr", "wintry", "freezing"];
const CLOUD_TERMS = ["cloud", "overcast", "fog", "haze", "mist"];
// Pick the number the current conditions call for.
export function moodOf(period) {
    const conditions = `${period.shortForecast ?? ""} ${period.detailedForecast ?? ""}`.toLowerCase();
    if (SNOW_TERMS.some((term) => conditions.includes(term))) {
        return "SNOWY";
    }
    if (STORM_TERMS.some((term) => conditions.includes(term))) {
        return "STORMY";
    }
    if (CLOUD_TERMS.some((term) => conditions.includes(term))) {
        return "CLOUDY";
    }
    return "SUNNY";
}
// Two rotating couplet templates per mood. Data lands mid-line so the rhyme
// words stay fixed and the meter survives whatever the forecast says.
const VERSE_TEMPLATES = {
    SUNNY: [
        '{name}: the callboard reads "{short}" - places, everyone, places,\n' +
            "   {temp} degrees, a {wind} breeze on all our upturned faces.",
        '{name} struts on at {temp} degrees, the sky a painted set,\n' +
            '   "{short}," sings the playbill - best entrance we\'ve had yet.',
    ],
    CLOUDY: [
        '{name} drifts in quietly, "{short}" on the bill,\n' +
            "   {temp} degrees, a {wind} sigh, the balcony sits still.",
        '{name}: the house goes dim beneath a slow gray velvet drape,\n' +
            '   {temp} degrees and "{short}" - no understudy for this shape.',
    ],
    STORMY: [
        '{name}! Cue the kettledrums - "{short}" takes the stage,\n' +
            "   {temp} degrees, a {wind} gale, the script has turned the page!",
        '{name}: the rigging rattles as "{short}" steals the show,\n' +
            "   {temp} degrees, wind {wind} - hold fast to the front row!",
    ],
    SNOWY: [
        '{name} falls in pianissimo, "{short}" soft and slow,\n' +
            "   {temp} degrees, a {wind} hush, the aisles fill up with snow.",
        '{name}: the flies release their drifting paper-lantern white,\n' +
            '   {temp} degrees and "{short}" - an encore every night.',
    ],
};
const STAGE_DIRECTIONS = {
    SUNNY: "[Curtain rises. The follow spot finds the sun already center stage.]",
    CLOUDY: "[Curtain rises on a dim house. Somewhere, a lone clarinet.]",
    STORMY: "[Curtain rises. Thunder rolls in the wings. The pit braces.]",
    SNOWY: "[Curtain rises. Paper snow drifts past the footlights.]",
    ALERT: "[The house lights snap on mid-scene. The stage manager steps out.]",
};
function fill(template, period) {
    const wind = [period.windSpeed, period.windDirection].filter(Boolean).join(" ") || "still";
    return template
        .replaceAll("{name}", period.name ?? "Next")
        .replaceAll("{short}", period.shortForecast ?? "weather unbilled")
        .replaceAll("{temp}", String(period.temperature ?? "??"))
        .replaceAll("{wind}", wind);
}
function chorusBlock(song) {
    return ["   (chorus)", ...song.chorus.map((line) => `   ${line}`)].join("\n");
}
// The whole forecast as one number: the current period picks the song, every
// period gets a verse, the chorus lands after the first verse and the last.
export function formatForecast(periods, song) {
    const mood = song.mood;
    const templates = VERSE_TEMPLATES[mood] ?? VERSE_TEMPLATES.SUNNY;
    const out = [
        "WEATHER ON BROADWAY",
        `Tonight's number: "${song.title}" (${song.tempo})`,
        "",
        STAGE_DIRECTIONS[song.mood],
        "",
    ];
    periods.slice(0, 5).forEach((period, index) => {
        out.push(`Verse ${index + 1}:`);
        out.push(`   ${fill(templates[index % templates.length], period)}`);
        if (index === 0) {
            out.push(chorusBlock(song));
        }
        out.push("");
    });
    out.push(chorusBlock(song));
    out.push("");
    out.push("[Curtain. House lights up.]");
    return out.join("\n");
}
// Alerts arrive as the emergency ensemble number, one scene per alert.
export function formatAlerts(features, song) {
    const out = [
        "WEATHER ON BROADWAY - SPECIAL BULLETIN",
        `The company interrupts with: "${song.title}" (${song.tempo})`,
        "",
        STAGE_DIRECTIONS.ALERT,
        "",
        chorusBlock(song),
        "",
    ];
    features.forEach((feature, index) => {
        const props = feature.properties;
        out.push(`Scene ${index + 1}: ${props.event ?? "Unbilled Event"} (${props.severity ?? "severity unbilled"})`);
        out.push(`   Setting: ${props.areaDesc ?? "area unbilled"}`);
        if (props.headline) {
            out.push(`   The stage manager reads: ${props.headline}`);
        }
        if (props.instruction) {
            out.push(`   [Direction to the house: ${props.instruction}]`);
        }
        out.push("");
    });
    out.push("[The company holds until the all-clear.]");
    return out.join("\n");
}
