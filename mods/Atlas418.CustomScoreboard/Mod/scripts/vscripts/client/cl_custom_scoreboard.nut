untyped

// ============================================================================
// Custom Scoreboard
//
// Draws onto the vanilla flat "Scoreboard" HudElement instead of building our
// own cockpit-attached VGUI screen. Our panels (see keyvalues/resource/ui/
// hudscoreboard.res, a keyvalues PATCH - not a full file replacement, merges
// with vanilla + every other mod's patch of the same file) are declared as
// new children of that same tree, so they show/hide automatically whenever
// vanilla's own Show()/Hide() on "Scoreboard" runs - no custom show/hide
// wiring needed, and no dependency on having a live pilot/titan body.
//
// We tried a cockpit-attached CreateClientsideVGuiScreen first (matching the
// HudRevamp mod's HUD trick). It rendered, but it's parented to the
// "titan_cockpit" entity, which only exists while you have a live playable
// body - so the panel got destroyed on death and never existed at all during
// the end-game screen. Switching to a flat element (same technique the
// ScoreboardPingDisplay mod uses) fixes both, since flat elements aren't
// tied to life state - same as vanilla's own scoreboard.
//
// COLUMNS & SORTING
// -------------------------
// Default behaviour matches vanilla: columns come from GameMode_GetScoreboard
// ColumnTitles/ScoreTypes(GAMETYPE), sort order from GetScoreboardCompareFunc()
// (see NOTES.md for the full per-gamemode stats reference).
//
// Either can be overridden per-gamemode via a JSONC (JSON-with-comments -
// Northstar's DecodeJSON doesn't support comments natively, so this file
// strips them itself, see StripJSONComments()) file at:
//   R2Testing/save_data/Atlas418.CustomScoreboard/scoreboard_settings.json
// (loaded with Northstar's sandboxed NSLoadFile - purely client-local,
// nothing to do with the server). Shape:
//
//   {
//     "settings": {
//       "rowHeight": 22,
//       "rowSpacing": 2,
//       "columnGap": 6,
//       "colors": {
//         // General named palette - any key you want, referenced by name
//         // from any columns[] entry below. No fixed/special keys - these
//         // names are just convention, not magic.
//         "friendly": [40, 80, 140, 160],
//         "enemy": [140, 50, 45, 160],
//         "self": [140, 120, 40, 180],
//         "party": [80, 160, 80, 180],
//         "muted_blue": [60, 70, 90, 130],
//         "muted_red": [90, 60, 60, 130]
//       }
//     },
//     // Top-level, NOT nested under "settings" - a list of reusable, named
//     // column definitions, each the exact same shape as an inline
//     // columns[] entry below (see EnsureColumnPresetsLoaded()).
//     "columnPresets": [
//       { "name": "player", "title": "PLAYER", "stat": "NAME", "background": "friendly", "backgroundSelf": "self" },
//       { "name": "ping", "title": "PING", "stat": "PGS_PING", "width": 5, "textFriendly": "friendly", "textEnemy": "enemy" }
//     ],
//     "aitdm": {
//       "sortMode": { "stat": "PGS_ASSAULT_SCORE", "descending": true },
//       "columns": [
//         // A bare string names a preset from "columnPresets" above instead
//         // of spelling the column out inline - the two forms can be mixed
//         // freely in the same array.
//         "player",
//         { "title": "SCORE", "stat": "PGS_ASSAULT_SCORE", "width": 6 },
//         { "title": "KILLS", "stat": "PGS_PILOT_KILLS", "width": 6 },
//         { "title": "TITANS", "stat": "PGS_TITAN_KILLS", "width": 7 },
//         {
//           "title": "MINIONS", "stat": "PGS_NPC_KILLS", "width": 8,
//           "background": "muted_blue", "backgroundEnemy": "muted_red"
//         },
//         "ping"
//       ]
//     },
//     "tdm": { "sortMode": { "teamsSplit": true } }
//   }
//
// "settings" is a top-level key, a sibling of the per-gamemode keys, and
// applies globally rather than per-gamemode (see EnsureSettingsLoaded()):
//   - "rowHeight": each row's box height in pixels. Defaults to
//     DEFAULT_ROW_HEIGHT, clamped to [MIN_ROW_HEIGHT, MAX_ROW_HEIGHT].
//   - "rowSpacing": pixels between rows, added on top of rowHeight. Defaults
//     to DEFAULT_ROW_SPACING, clamped to [MIN_ROW_SPACING, MAX_ROW_SPACING].
//   - "columnGap": pixels between adjacent column boxes (name column
//     included - see below). Defaults to DEFAULT_COL_GAP, clamped to
//     [MIN_COL_GAP, MAX_COL_GAP].
//   - "colors": a general named palette (see NamedColors/ResolveNamedColor)
//     - define any color under any name here, then reference it by that
//     name from any "columns[]" entry's color fields below.
//   - "centered": bool, defaults to false. false = right-anchored (original
//     behavior), true = horizontally centered. Vertical position is always
//     centered regardless of this setting.
//
// THE NAME COLUMN IS JUST A COLUMN NOW - a "columns[]" entry with
// "stat": "NAME" (a reserved sentinel, not a real PGS_* stat) marks that
// entry as the name column: its cell shows the player's name instead of a
// stat value, using the proportional cScoreboardName font and auto-sized to the
// longest currently-shown name (see EnsureColumnsLoaded()/RefreshPlayerList())
// rather than "width" (ignored on a NAME entry - character-based width
// doesn't apply to a non-monospace font). Everything else about it - title,
// all 10 color fields, and crucially its POSITION - works exactly like any
// other column: wherever "stat": "NAME" sits in the array is where it
// renders, so it can be first, last, or anywhere in between. A gamemode
// whose resolved column list (custom or vanilla-fallback) doesn't include a
// NAME entry gets one synthesized at position 0 automatically (empty title,
// default colors) so every gamemode always shows player names somewhere -
// this is what happens today for any config that doesn't mention "NAME" at
// all. Only the first "stat": "NAME" entry in a given list counts; any
// further ones are dropped with a warning (only one physical name-lane panel
// set exists to render into). Since it always consumes at most one of the
// (up to MAX_STAT_COLUMNS) real column slots when explicitly placed, and
// costs nothing extra when synthesized, this needed no new panels or
// hudscoreboard.res changes - see gen_hudscoreboard_patch.py notes in
// NOTES.md for why the existing cScoreboardHeaderName / cScoreboardPlayerNameBG_N /
// cScoreboardPlayerName_N panels were already enough.
//
// "columnPresets" (top-level, sibling of "settings" - see
// EnsureColumnPresetsLoaded()) is an array of named, reusable column
// definitions - each entry is the exact same shape as an inline columns[]
// entry (title/stat/width/any of the 10 color fields, "stat": "NAME"
// included), plus a required "name". Any columns[] entry may be a bare
// string instead of an object - it's looked up by that name here and used
// exactly as defined (no per-usage overrides), so a column reused across
// several gamemodes only needs to be written out once. An unknown preset
// name just drops that column with a console warning, same as a duplicate
// "NAME" entry - it doesn't take down the rest of that gamemode's columns.
//
// Every column entry accepts up to 10 optional color fields, each a string
// naming a "colors" entry OR a literal [r,g,b]/[r,g,b,a] array:
//   background / backgroundSelf / backgroundParty / backgroundFriendly / backgroundEnemy
//   text       / textSelf       / textParty       / textFriendly       / textEnemy
// "background"/"text" are shorthands - they set all four relationship
// states at once, unless a more specific field above overrides just one of
// them. Resolution priority per row is: self > party (only if that party
// member is also on your team - an enemy in your party still reads as an
// enemy) > friendly/enemy. A column with none of these 10 fields set keeps
// its background fully transparent - [0,0,0,0], see file.teamColorFriendly
// etc. - so an unconfigured column's box paints nothing at all; text
// defaults to plain white - both fully overridable per column regardless.
//
// Font size is NOT configurable here - VGUI label fonts are static per-panel
// properties baked into hudscoreboard.res at generation time (named scheme
// entries with a fixed point size), there's no runtime "set font size"
// native. Changing it would mean baking discrete size presets into the
// generated .res ahead of time - not done yet.
//
// The remaining top-level keys are the raw GAMETYPE string (e.g. "tdm",
// "at", "aitdm" - the same strings the game itself logs, not display names).
// Gamemodes not present in the file, or present without "columns"/
// "sortMode", keep using vanilla's own data for whichever part is missing.
// "stat" values are the PGS_* names from NOTES.md's stats reference (see
// PGS_NAME_MAP below for the exact set understood here), plus three reserved
// sentinels, not real native PGS_* constants - "NAME" (the name column),
// "PGS_GEN" (player.GetGen(), generation/prestige 1-10), and "PGS_AD"
// (assault score / deaths, computed - see ComputeAssaultOverDeaths()). See
// file.columnIsName/file.columnIsGen/file.columnIsAD in EnsureColumnsLoaded().
// A GEN or AD column behaves like any other stat column otherwise - normal
// char-based "width", normal stat-lane panel - only its cell text comes from
// a different source (GetGen(), or the computed ratio formatted to 1
// decimal since it isn't a whole count like every other stat). Both are
// equally valid in "sortMode.stat" and "columns[].stat". Titles here are
// shown verbatim (not run through Localize()).
//
// Per-column "width" (optional, defaults to DEFAULT_COL_CHAR_WIDTH) is in
// *characters*, not pixels - cScoreboardHeaderStat_N/cScoreboardPlayerStat_N_C are set to
// a monospace font ("cScoreboardStatFixed" - our own bundled JetBrains Mono NL,
// see keyvalues/resource/{fontfiletable.txt,sourcescheme.res}) specifically
// so character counts convert to pixels consistently (measured once at
// runtime, see EnsureMonoCharWidthMeasured()). This is also the real fix for column
// headers that don't fit - either shorten the title, widen the column, or
// both. The name column has no "width" field - it's always auto-sized to
// fit the longest currently-shown name (see the measurement pass in
// RefreshPlayerList()), since its font isn't monospace and a fixed
// character width wouldn't reliably predict pixels the way it does for the
// stat columns.
//
// "sortMode.teamsSplit" (optional, defaults to true) - whether the list is
// grouped into team blocks (your team first, each block keeping its
// existing stat-sorted order - a stable partition of the sorted list, not a
// re-sort) or left as one flat ranking across every player. Lives under
// "sortMode" but read independently of "stat"/"descending" - doesn't
// require a full custom sort override just to set this. Purely a sort/
// grouping concern, unrelated to the color fields above.
//
// If the file doesn't exist at all, everything just falls back to vanilla
// data for every gamemode - the JSON is entirely opt-in.
// ============================================================================

global function CustomScoreboard_Init

const string CUSTOM_CONFIG_FILE = "scoreboard_settings.json"

const int MAX_LIST_SLOTS = 32            // must match the cScoreboardPlayerName_N count generated into hudscoreboard.res
const int MAX_STAT_COLUMNS = 8           // must match the cScoreboardHeaderStat_N / cScoreboardPlayerStat_N_C count generated into hudscoreboard.res
const float LIST_REFRESH_INTERVAL = 0.5  // seconds between player list refreshes while the scoreboard is visible

// Layout numbers - must match gen_hudscoreboard_patch.py, since that script
// only sets the *default* positions baked into hudscoreboard.res;
// RefreshPlayerList() below recomputes and overrides them every refresh so
// the box resizes/recenters/repositions to the actual player count and
// column count instead.
const int CANVAS_W = 1920  // fallback only if GetScreenSize() fails - RefreshPlayerList() uses the real current resolution instead
const int CANVAS_H = 1080  // ditto
const int RIGHT_MARGIN = 40        // gap from the box's right edge to the screen edge
const int BOX_PAD = 20
const int DEFAULT_ROW_HEIGHT = 22  // row box height, in pixels - JSON-overridable, see "settings.rowHeight" and file.rowHeight. hudscoreboard.res bakes this same value in as each row panel's default "tall", but RefreshPlayerList() re-sets it every refresh same as everything else here
const int MIN_ROW_HEIGHT = 12      // floor - low enough for a "compact" layout, high enough that cScoreboardStatFixed/cScoreboardName text still fits without clipping
const int MAX_ROW_HEIGHT = 60
const int DEFAULT_ROW_SPACING = 2  // gap between rows, in pixels - JSON-overridable, see "settings.rowSpacing" and file.rowSpacing
const int MIN_ROW_SPACING = 0
const int MAX_ROW_SPACING = 40     // generous ceiling so a bad config value can't push rows off-screen or make MAX_LIST_SLOTS rows absurdly tall
const int TITLE_TO_BOX_GAP = 46    // title's Y = box's Y minus this
const int HEADER_H = 22
const int HEADER_GAP = 6           // gap between the header row and the first player row

// Width formula: whichever column is the name column (see file.columnIsName)
// is sized to the longest currently-shown player name each refresh (see the
// measurement pass in RefreshPlayerList), clamped to this range; every other
// column uses its per-column pixel width (from its char width in the
// config, see DEFAULT_COL_CHAR_WIDTH below). All columns - name included,
// wherever it sits in the array - are walked in one pass with colGap
// between each consecutive pair, so the name column doesn't need any
// special-cased gap handling anymore.
const int NAME_COL_MIN_W = 120
const int NAME_COL_MAX_W = 500
const int NAME_COL_TEXT_PADDING = 12  // breathing room added to the measured text width
const int DEFAULT_COL_GAP = 6  // pixels between adjacent column boxes - JSON-overridable, see "settings.columnGap" and file.colGap
const int MIN_COL_GAP = 0
const int MAX_COL_GAP = 40

// Stat column widths are specified in *characters* in scoreboard_settings.json
// (see MONO_MEASURE_TEXT below for how characters convert to pixels), since
// cScoreboardHeaderStat_N / cScoreboardPlayerStat_N_C are monospace ("cScoreboardStatFixed"
// font - see gen_hudscoreboard_patch.py). Columns without an explicit "width" in the
// JSON (including every vanilla-fallback column, which has no JSON entry at
// all) use this default.
const int DEFAULT_COL_CHAR_WIDTH = 8
const int MIN_COL_PX = 30  // floor, in case a char width of 0/garbage sneaks through
const int STAT_COL_TEXT_PADDING = 8  // breathing room so header/value text doesn't sit flush against the column edge and get ellipsis-truncated by rounding
const int MONO_MEASURE_SAFE_WIDTH = 2000  // temp width forced on the reference label while measuring, so its *current* (possibly narrow) column width can't clip Hud_GetTextWidth's result
const int NAME_MEASURE_SAFE_WIDTH = 2000  // same idea, forced on each cScoreboardPlayerName_N label before measuring it - otherwise a name that just got longer only "discovers" a little more of its true width each refresh, since it's still boxed to last refresh's (narrower) nameColW
const string MONO_MEASURE_TEXT = "01234567890123456789"  // 20 chars - measured once to get pixels-per-character

// Default alpha for a literal [r,g,b] color array (no 4th element given) -
// see ParseColorArray(). Column background/text colors no longer have a
// tinted default (see file.teamColorFriendly etc. below - fully transparent
// when nothing's configured), but a 3-element literal color still needs
// *some* alpha to fill in.
const int ROW_COLOR_ALPHA = 160

// Default per-column TEXT color (all four relationship states) when a
// column doesn't set "text"/"textSelf"/etc - plain white, matching every
// label's original hardcoded fgcolor before per-column text color existed.
const int TEXT_COLOR_DEFAULT_R = 255
const int TEXT_COLOR_DEFAULT_G = 255
const int TEXT_COLOR_DEFAULT_B = 255
const int TEXT_COLOR_DEFAULT_A = 255

// Every PGS_* stat the JSON config's "stat" fields are allowed to reference -
// keep this in sync with NOTES.md's stats reference. Keys are bare
// identifiers so Squirrel turns them into their own name as a string; values
// are the actual native constants.
const table<string, int> PGS_NAME_MAP = {
	PGS_KILLS = PGS_KILLS,
	PGS_DEATHS = PGS_DEATHS,
	PGS_ASSISTS = PGS_ASSISTS,
	PGS_TITAN_KILLS = PGS_TITAN_KILLS,
	PGS_PILOT_KILLS = PGS_PILOT_KILLS,
	PGS_NPC_KILLS = PGS_NPC_KILLS,
	PGS_ASSAULT_SCORE = PGS_ASSAULT_SCORE,
	PGS_DEFENSE_SCORE = PGS_DEFENSE_SCORE,
	PGS_SCORE = PGS_SCORE,
	PGS_DETONATION_SCORE = PGS_DETONATION_SCORE,
	PGS_DISTANCE_SCORE = PGS_DISTANCE_SCORE,
	PGS_ELIMINATED = PGS_ELIMINATED,
	PGS_PING = PGS_PING,
}

struct
{
	var scoreboard  // cached "Scoreboard" HudElement reference, once found

	bool columnsLoaded = false
	array<string> columnTitles      // Localize()'d for vanilla columns, verbatim for custom ones
	array<int> columnScoreTypes     // PGS_X constants - placeholder (-1) at the columnIsName index, never read there
	array<int> columnCharWidths     // width of each column, in monospace characters - placeholder (0) at the columnIsName index, never read there

	// Marks which single entry (always exactly one, after EnsureColumnsLoaded()
	// synthesizes one if the config didn't provide it - see the header comment)
	// is the name column - shows the player's name via the dedicated
	// cScoreboardHeaderName/cScoreboardPlayerNameBG_N/cScoreboardPlayerName_N panels and gets its
	// width auto-measured, instead of being treated as a real PGS_* stat
	// column. Wherever this is true in the array is where the name column
	// renders - RefreshPlayerList() walks all columns in one positional pass.
	array<bool> columnIsName = []

	// Marks a "stat": "PGS_GEN" column (player.GetGen(), generation/prestige
	// 1-10 - not a real PGS_* stat, GetPlayerGameStat() has no equivalent).
	// Unlike columnIsName this doesn't change panel choice or width sizing -
	// a GEN column renders in a completely normal stat-lane slot, monospace
	// char-width and all - it only changes which native RefreshPlayerList()
	// calls to get the cell's text.
	array<bool> columnIsGen = []
	// Marks a "stat": "PGS_AD" column (assault score / deaths, computed - see
	// ComputeAssaultOverDeaths()). Same "ordinary stat-lane column otherwise"
	// treatment as columnIsGen - real char-based width, only the cell text
	// comes from a different source.
	array<bool> columnIsAD = []


	// Per-column colors, parallel to the arrays above - one entry per column
	// (name column included, indexed the same as every stat column), fully
	// resolved at parse time (shorthand + per-state override + default
	// already folded in by ResolveTieredColors(), see EnsureColumnsLoaded())
	// so RefreshPlayerList() never re-resolves anything at paint time, just
	// indexes by column. array<var>, not array<int> - same reasoning as
	// teamColorFriendly etc. below.
	array<var> columnBgSelf = []
	array<var> columnBgParty = []
	array<var> columnBgFriendly = []
	array<var> columnBgEnemy = []
	array<var> columnTextSelf = []
	array<var> columnTextParty = []
	array<var> columnTextFriendly = []
	array<var> columnTextEnemy = []

	bool monoCharPxMeasured = false
	float monoCharPx = 8.0  // fallback estimate; overwritten by the real measurement before it's ever used

	bool customConfigLoadAttempted = false  // true once the async file load has resolved, success or not
	table customConfig = {}                 // parsed scoreboard_settings.json, keyed by GAMETYPE string

	bool useCustomSort = false
	int customSortStatType
	bool customSortDescending = true
	bool customSortIsAD = false  // true when "sortMode.stat" is "PGS_AD" - see CustomStatCompare/ComputeAssaultOverDeaths (also valid in columns[].stat, see file.columnIsAD)
	bool teamsSplit = false  // per-gamemode - true groups the sorted list into team blocks, see EnsureColumnsLoaded()

	bool settingsLoaded = false  // true once "settings" (or its absence) has been read from customConfig
	int rowHeight = DEFAULT_ROW_HEIGHT
	int rowSpacing = DEFAULT_ROW_SPACING
	int colGap = DEFAULT_COL_GAP
	bool centered = false  // JSON-overridable, see "settings.centered" - false (default) = right-anchored, true = horizontally centered

	// General named color palette ("settings.colors" - any key, not a fixed
	// set) - populated in EnsureSettingsLoaded(). Plain table (mirrors
	// customConfig below), only ever accessed by key or membership-checked,
	// never passed whole into a native.
	table namedColors = {}

	// Named column presets ("columnPresets" - a top-level key, sibling of
	// "settings", not nested under it) - name -> raw preset object (the
	// same shape as an inline columns[] entry), populated once in
	// EnsureColumnPresetsLoaded(). A columns[] entry that's a bare string
	// looks itself up here and substitutes the result in place of an inline
	// object before EnsureColumnsLoaded()'s normal per-column parsing runs.
	bool columnPresetsLoaded = false
	table columnPresets = {}

	// var, not array<int> - SetColor()'s native param is declared "var", and
	// this compiler refuses to pass a statically-typed array<int> into it no
	// matter how that array<int> was produced (field, local, function
	// return all hit the same "Attempted to pass/assign type array<int>..."
	// error). Keeping these as var end-to-end (see also ParseColorArray)
	// sidesteps it entirely. These four are the DEFAULT background color a
	// column falls back to when it doesn't configure its own
	// "background"/"backgroundSelf"/etc - fully transparent, so an
	// unconfigured column's background box doesn't paint anything at all
	// (previously a tinted friendly/enemy/self/party color; changed to
	// [0,0,0,0] at the user's request - a column that wants a tint now has
	// to say so explicitly via "background"/etc, same as everything else in
	// this per-column color system).
	var teamColorFriendly = [ 0, 0, 0, 0 ]
	var teamColorEnemy = [ 0, 0, 0, 0 ]
	var teamColorSelf = [ 0, 0, 0, 0 ]
	var teamColorParty = [ 0, 0, 0, 0 ]

	// Default per-column TEXT color (all four states) - see TEXT_COLOR_DEFAULT_*.
	var textColorDefault = [ TEXT_COLOR_DEFAULT_R, TEXT_COLOR_DEFAULT_G, TEXT_COLOR_DEFAULT_B, TEXT_COLOR_DEFAULT_A ]
} file

void function CustomScoreboard_Init()
{
	// This runs on every mapspawn transition, including menu/lobby loads. A
	// single uncaught error here aborts the rest of the "After mapspawn"
	// callback chain for EVERY mod (not just this one) - confirmed the hard
	// way - so nothing in this function is allowed to throw.
	try
	{
		thread PlayerListRefreshThread()

		// Northstar's DecodeJSON is a thin wrapper around RapidJSON's default
		// Parse() with no comment flags set (checked the native source) - it
		// can't read // or /* */ comments. NSLoadJSONFile would fail outright
		// on a commented file, so we load the raw text ourselves via
		// NSLoadFile and strip comments before decoding it by hand.
		NSLoadFile( CUSTOM_CONFIG_FILE, OnCustomConfigFileLoaded, OnCustomConfigLoadFailed )
	}
	catch ( ex )
	{
		print( "CustomScoreboard_Init failed: " + ex )
	}
}

void function OnCustomConfigFileLoaded( string rawContent )
{
	try
	{
		string cleaned = StripJSONComments( rawContent )
		file.customConfig = DecodeJSON( cleaned, true )
		file.customConfigLoadAttempted = true
	}
	catch ( ex )
	{
		print( "scoreboard_settings.json: failed to parse: " + ex )
		file.customConfig = {}
		file.customConfigLoadAttempted = true
	}
}

void function OnCustomConfigLoadFailed()
{
	// No file, or the OS failed to read it - customConfig stays {}, meaning
	// every gamemode just falls back to vanilla data. This is the normal
	// case for anyone who hasn't created the file yet.
	file.customConfig = {}
	file.customConfigLoadAttempted = true
}

// Strips // line comments and /* */ block comments from a JSON string so it
// can be decoded with Northstar's strict-JSON DecodeJSON(), while leaving
// the contents of quoted strings untouched (so e.g. a "title" containing
// "//" isn't mistaken for a comment). Not a full JSON tokenizer - doesn't
// handle every edge case (e.g. unicode escapes), but is enough for a config
// file we're the only ones writing.
string function StripJSONComments( string input )
{
	string result = ""
	int i = 0
	int len = input.len()
	bool inString = false
	bool inLineComment = false
	bool inBlockComment = false

	while ( i < len )
	{
		string c = input.slice( i, i + 1 )
		string c2 = ( i + 1 < len ) ? input.slice( i + 1, i + 2 ) : ""

		if ( inLineComment )
		{
			if ( c == "\n" )
			{
				inLineComment = false
				result += c
			}
			i++
			continue
		}

		if ( inBlockComment )
		{
			if ( c == "*" && c2 == "/" )
			{
				inBlockComment = false
				i += 2
				continue
			}
			i++
			continue
		}

		if ( inString )
		{
			result += c
			if ( c == "\\" && c2 != "" )
			{
				// escaped char (e.g. \") - copy it verbatim so it doesn't
				// prematurely end the string below
				result += c2
				i += 2
				continue
			}
			if ( c == "\"" )
				inString = false
			i++
			continue
		}

		// not currently inside a string or a comment
		if ( c == "\"" )
		{
			inString = true
			result += c
			i++
			continue
		}

		if ( c == "/" && c2 == "/" )
		{
			inLineComment = true
			i += 2
			continue
		}

		if ( c == "/" && c2 == "*" )
		{
			inBlockComment = true
			i += 2
			continue
		}

		result += c
		i++
	}

	return result
}

int function ResolvePGSName( string name )
{
	if ( name in PGS_NAME_MAP )
		return PGS_NAME_MAP[name]

	print( "scoreboard_settings.json: unknown stat name \"" + name + "\", falling back to PGS_KILLS" )
	return PGS_KILLS
}

// ----------------------------------------------------------------------------
// Column + sort data - resolved once per match (GAMETYPE doesn't change
// mid-match), custom config taking priority over vanilla per-gamemode data.
// ----------------------------------------------------------------------------

// Inserted at index 0 (not appended) so the name column defaults to the
// leftmost position when nothing in the config explicitly places it - see
// EnsureColumnsLoaded(). array.insert(idx, val) is standard Squirrel, first
// use of it in this file specifically (everything else here only ever
// .append()s or .clear()s), but it's ordinary stdlib behavior, not an
// engine native, so it doesn't carry the same risk as this file's other
// "first use of X" callouts.
void function PrependDefaultNameColumn()
{
	file.columnTitles.insert( 0, "" )
	file.columnScoreTypes.insert( 0, -1 )
	file.columnCharWidths.insert( 0, 0 )
	file.columnIsName.insert( 0, true )
	file.columnIsGen.insert( 0, false )
	file.columnIsAD.insert( 0, false )
	file.columnBgSelf.insert( 0, file.teamColorSelf )
	file.columnBgParty.insert( 0, file.teamColorParty )
	file.columnBgFriendly.insert( 0, file.teamColorFriendly )
	file.columnBgEnemy.insert( 0, file.teamColorEnemy )
	file.columnTextSelf.insert( 0, file.textColorDefault )
	file.columnTextParty.insert( 0, file.textColorDefault )
	file.columnTextFriendly.insert( 0, file.textColorDefault )
	file.columnTextEnemy.insert( 0, file.textColorDefault )
}

void function EnsureColumnsLoaded()
{
	if ( file.columnsLoaded )
		return

	// GAMETYPE is only meaningful while an actual match is loaded (empty in
	// menus/lobby); calling the gamemode data lookups outside of that throws -
	// learned that one the hard way already.
	if ( GAMETYPE == "" )
		return

	// Wait for the async config file load to resolve before deciding
	// anything, so we don't briefly show vanilla columns and then swap to
	// custom ones a moment later.
	if ( !file.customConfigLoadAttempted )
		return

	// JSON-decoded values are all just "var" (dynamic) - deliberately not
	// using strict type assertions on them here, only the safe string()
	// coercion (confirmed pattern, used everywhere else in this codebase for
	// int->string) and plain equality checks. A malformed entry is caught
	// and logged per-section below rather than aborting the whole function,
	// so one bad field (e.g. a bad "sortMode") doesn't also take out a
	// perfectly fine "columns" block.

	var gamemodeConfig = null
	if ( GAMETYPE in file.customConfig )
		gamemodeConfig = file.customConfig[GAMETYPE]

	bool gotCustomColumns = false
	if ( gamemodeConfig != null && "columns" in gamemodeConfig )
	{
		try
		{
			var customColumns = gamemodeConfig.columns
			if ( customColumns.len() > MAX_STAT_COLUMNS )
				print( "scoreboard_settings.json: " + GAMETYPE + " has " + customColumns.len() + " columns, only the first " + MAX_STAT_COLUMNS + " will be shown (MAX_STAT_COLUMNS)" )

			int count = minint( customColumns.len(), MAX_STAT_COLUMNS )
			bool sawNameColumn = false
			for ( int i = 0; i < count; i++ )
			{
				var rawEntry = customColumns[i]

				// A bare string names a preset from "columnPresets" (see
				// EnsureColumnPresetsLoaded()) instead of spelling out the
				// column inline - substitute the preset's raw object in and
				// let every bit of parsing below run exactly as it would
				// for an inline object, unchanged. An unknown name just
				// drops this column (matches the duplicate-NAME-entry
				// handling right below - warn, continue, don't abort the
				// whole "columns" block over one bad entry).
				var col
				if ( typeof rawEntry == "string" )
				{
					string presetName = expect string( rawEntry )
					if ( presetName in file.columnPresets )
						col = file.columnPresets[presetName]
					else
					{
						print( "scoreboard_settings.json: " + GAMETYPE + " references unknown column preset \"" + presetName + "\"" )
						continue
					}
				}
				else
					col = rawEntry

				// "stat": "NAME" is a reserved sentinel (not a real PGS_*
				// name) marking this entry as the name column - see the
				// header comment. Only one physical name-lane panel set
				// exists per row, so a second NAME entry is dropped with a
				// warning rather than fought over.
				bool isNameEntry = "stat" in col && string( col.stat ) == "NAME"
				if ( isNameEntry && sawNameColumn )
				{
					print( "scoreboard_settings.json: " + GAMETYPE + " has more than one \"stat\": \"NAME\" column, only the first is used" )
					continue
				}

				// "stat": "PGS_GEN" is a reserved sentinel too (not a real
				// native PGS_* constant - player.GetGen() is a wholly
				// separate getter, GetPlayerGameStat() has no equivalent)
				// marking this entry as a generation/prestige (1-10) column.
				// Unlike NAME, no dedup/synthesis needed - it's an ordinary
				// stat-lane column in every other respect.
				bool isGenEntry = "stat" in col && string( col.stat ) == "PGS_GEN"

				// "stat": "PGS_AD" is a third reserved sentinel - assault
				// score / deaths, computed per row at paint time (see
				// ComputeAssaultOverDeaths()) rather than read from a single
				// native stat. Same "ordinary column otherwise" treatment as
				// GEN - real char-based width, only the cell text differs.
				bool isADEntry = "stat" in col && string( col.stat ) == "PGS_AD"

				file.columnTitles.append( string( col.title ) )
				file.columnIsName.append( isNameEntry )
				file.columnIsGen.append( isGenEntry )
				file.columnIsAD.append( isADEntry )

				if ( isNameEntry )
				{
					// No real stat, no character-based width - see the
					// header comment for why. Placeholders only; nothing
					// below ever reads columnScoreTypes/columnCharWidths at
					// a columnIsName index, it measures actual name text
					// instead (see RefreshPlayerList()).
					file.columnScoreTypes.append( -1 )
					file.columnCharWidths.append( 0 )
					sawNameColumn = true
				}
				else
				{
					// A GEN column still gets a real, character-based width
					// like any other stat column (see RefreshPlayerList()) -
					// only its cell *text* comes from a different native.
					// columnScoreTypes gets the same unused -1 placeholder a
					// NAME entry gets; nothing ever reads it for a GEN or AD
					// column either (see file.columnIsGen/file.columnIsAD).
					// isADEntry must be checked before ResolvePGSName() runs -
					// "PGS_AD" has no PGS_NAME_MAP entry, so passing it
					// through would log a spurious "unknown stat name"
					// warning and silently fall back to PGS_KILLS.
					file.columnScoreTypes.append( ( isGenEntry || isADEntry ) ? -1 : ResolvePGSName( string( col.stat ) ) )

					int charWidth = DEFAULT_COL_CHAR_WIDTH
					// Not using int(col.width) here - Northstar's int() builtin
					// throws ("Cannot cast type "int" to "int"") when given a
					// value that's already an integer, which every plain JSON
					// number like `"width": 6` decodes as. A bare assignment
					// doesn't compile either ("var" -> "int" needs an explicit
					// conversion) - expect int(...) is the compiler-level type
					// assertion (already used safely for level.maxTeamSize in
					// cl_scoreboard_mp.nut) rather than a call into that broken
					// cast function, so it sidesteps the bug entirely.
					if ( "width" in col )
						charWidth = expect int( col.width )
					file.columnCharWidths.append( charWidth )
				}

				var bgColors = ResolveTieredColors( col, "background", "backgroundSelf", "backgroundParty", "backgroundFriendly", "backgroundEnemy", file.teamColorSelf, file.teamColorParty, file.teamColorFriendly, file.teamColorEnemy )
				file.columnBgSelf.append( bgColors.self )
				file.columnBgParty.append( bgColors.party )
				file.columnBgFriendly.append( bgColors.friendly )
				file.columnBgEnemy.append( bgColors.enemy )

				var textColors = ResolveTieredColors( col, "text", "textSelf", "textParty", "textFriendly", "textEnemy", file.textColorDefault, file.textColorDefault, file.textColorDefault, file.textColorDefault )
				file.columnTextSelf.append( textColors.self )
				file.columnTextParty.append( textColors.party )
				file.columnTextFriendly.append( textColors.friendly )
				file.columnTextEnemy.append( textColors.enemy )
			}
			gotCustomColumns = count > 0
		}
		catch ( ex )
		{
			print( "scoreboard_settings.json: failed to read \"columns\" for " + GAMETYPE + ": " + ex )
			file.columnTitles.clear()
			file.columnScoreTypes.clear()
			file.columnCharWidths.clear()
			file.columnIsName.clear()
			file.columnIsGen.clear()
			file.columnIsAD.clear()
			file.columnBgSelf.clear()
			file.columnBgParty.clear()
			file.columnBgFriendly.clear()
			file.columnBgEnemy.clear()
			file.columnTextSelf.clear()
			file.columnTextParty.clear()
			file.columnTextFriendly.clear()
			file.columnTextEnemy.clear()
		}
	}

	if ( !gotCustomColumns )
	{
		try
		{
			array<string> titles = GameMode_GetScoreboardColumnTitles( GAMETYPE )
			array<int> scoreTypes = GameMode_GetScoreboardColumnScoreTypes( GAMETYPE )

			int count = minint( titles.len(), MAX_STAT_COLUMNS )
			for ( int i = 0; i < count; i++ )
			{
				file.columnTitles.append( Localize( titles[i] ) )
				file.columnScoreTypes.append( scoreTypes[i] )
				file.columnCharWidths.append( DEFAULT_COL_CHAR_WIDTH )
				file.columnIsName.append( false )  // GameMode_GetScoreboardColumnTitles never includes a name entry - synthesized below
				file.columnIsGen.append( false )   // nor a GEN entry - GetGen() is opt-in only, no vanilla equivalent
				file.columnIsAD.append( false )    // nor an AD entry - assault-over-deaths is opt-in only, no vanilla equivalent

				// No JSON entry for a vanilla-fallback column, so no
				// overrides - straight to the plain defaults, same as an
				// unconfigured custom column would get.
				file.columnBgSelf.append( file.teamColorSelf )
				file.columnBgParty.append( file.teamColorParty )
				file.columnBgFriendly.append( file.teamColorFriendly )
				file.columnBgEnemy.append( file.teamColorEnemy )
				file.columnTextSelf.append( file.textColorDefault )
				file.columnTextParty.append( file.textColorDefault )
				file.columnTextFriendly.append( file.textColorDefault )
				file.columnTextEnemy.append( file.textColorDefault )
			}
		}
		catch ( ex )
		{
			print( "EnsureColumnsLoaded (vanilla columns) failed: " + ex )
		}
	}

	// Safety net covering every path above (custom columns with no "NAME"
	// entry, vanilla fallback, or either one failing outright) - guarantees
	// exactly one columnIsName entry always exists by the time this
	// function returns, so RefreshPlayerList() never has to handle "no name
	// column at all" as a case.
	bool haveNameColumn = false
	foreach ( isNameFlag in file.columnIsName )
	{
		if ( isNameFlag )
		{
			haveNameColumn = true
			break
		}
	}
	if ( !haveNameColumn )
		PrependDefaultNameColumn()

	if ( gamemodeConfig != null && "sortMode" in gamemodeConfig )
	{
		try
		{
			var sortMode = gamemodeConfig.sortMode
			string sortStatName = string( sortMode.stat )

			// "PGS_AD" (assault score / deaths, computed - see
			// ComputeAssaultOverDeaths()) has no PGS_NAME_MAP entry, so it
			// can't go through ResolvePGSName() here like a real stat -
			// detected directly instead. Also valid in columns[].stat (see
			// isADEntry in the columns loop above), same computed value
			// either way, just formatted for display there instead of
			// compared.
			file.customSortIsAD = sortStatName == "PGS_AD"
			if ( !file.customSortIsAD )
				file.customSortStatType = ResolvePGSName( sortStatName )

			bool descending = true
			if ( "descending" in sortMode && sortMode.descending == false )
				descending = false
			file.customSortDescending = descending

			file.useCustomSort = true
		}
		catch ( ex )
		{
			print( "scoreboard_settings.json: failed to read \"sortMode\" for " + GAMETYPE + ": " + ex )
			file.useCustomSort = false
		}
	}

	// Whether to group the sorted list into team blocks (your team first,
	// each block keeping its existing stat-sorted order) instead of one flat
	// ranking. Defaults to false (matches original/vanilla-like behavior -
	// opt in per-gamemode rather than changing everyone's list unasked).
	// Lives under "sortMode" (sibling of "stat"/"descending") rather than
	// directly on the gamemode, and is read independently of them - a
	// config with "teamsSplit" but no "stat" still works fine, doesn't
	// force a custom sort override.
	file.teamsSplit = false
	if ( gamemodeConfig != null && "sortMode" in gamemodeConfig )
	{
		try
		{
			var sortMode = gamemodeConfig.sortMode
			if ( "teamsSplit" in sortMode )
				file.teamsSplit = sortMode.teamsSplit != false
		}
		catch ( ex )
		{
			print( "scoreboard_settings.json: failed to read \"sortMode.teamsSplit\" for " + GAMETYPE + ": " + ex )
		}
	}

	file.columnsLoaded = true
}

// Named column presets ("columnPresets" - a top-level key, sibling of
// "settings" and every per-gamemode key, NOT nested under "settings") - own
// latch since it isn't part of EnsureSettingsLoaded()'s "settings" object.
// Must run before EnsureColumnsLoaded() so a columns[] entry that names a
// preset can actually find it - see RefreshPlayerList()'s call order.
void function EnsureColumnPresetsLoaded()
{
	if ( file.columnPresetsLoaded )
		return

	if ( !file.customConfigLoadAttempted )
		return

	if ( "columnPresets" in file.customConfig )
	{
		try
		{
			foreach ( preset in file.customConfig.columnPresets )
			{
				if ( !( "name" in preset ) )
					continue

				string name = string( preset.name )
				if ( name == "" )
					continue

				// Duplicate name: "=" is safe here since the slot already
				// exists (unlike a brand-new key, which needs "<-" - see the
				// file.namedColors newslot gotcha in NOTES.md) - last one in
				// the array wins, same "last write wins" behavior a plain
				// JSON object would have with a repeated key.
				if ( name in file.columnPresets )
					file.columnPresets[name] = preset
				else
					file.columnPresets[name] <- preset
			}
		}
		catch ( ex )
		{
			print( "scoreboard_settings.json: failed to read \"columnPresets\": " + ex )
		}
	}

	file.columnPresetsLoaded = true
}

// Global display settings ("settings" key in scoreboard_settings.json, a
// sibling of the per-gamemode keys) - not gamemode-specific, so this only
// ever needs to run once, gated purely on the config load having resolved.
void function EnsureSettingsLoaded()
{
	if ( file.settingsLoaded )
		return

	if ( !file.customConfigLoadAttempted )
		return

	if ( "settings" in file.customConfig )
	{
		var settings = file.customConfig.settings

		if ( "rowHeight" in settings )
		{
			try
			{
				int height = expect int( settings.rowHeight )
				if ( height < MIN_ROW_HEIGHT )
					height = MIN_ROW_HEIGHT
				if ( height > MAX_ROW_HEIGHT )
					height = MAX_ROW_HEIGHT
				file.rowHeight = height
			}
			catch ( ex )
			{
				print( "scoreboard_settings.json: failed to read \"settings.rowHeight\": " + ex )
			}
		}

		if ( "rowSpacing" in settings )
		{
			try
			{
				int spacing = expect int( settings.rowSpacing )
				if ( spacing < MIN_ROW_SPACING )
					spacing = MIN_ROW_SPACING
				if ( spacing > MAX_ROW_SPACING )
					spacing = MAX_ROW_SPACING
				file.rowSpacing = spacing
			}
			catch ( ex )
			{
				print( "scoreboard_settings.json: failed to read \"settings.rowSpacing\": " + ex )
			}
		}

		if ( "columnGap" in settings )
		{
			try
			{
				int gap = expect int( settings.columnGap )
				if ( gap < MIN_COL_GAP )
					gap = MIN_COL_GAP
				if ( gap > MAX_COL_GAP )
					gap = MAX_COL_GAP
				file.colGap = gap
			}
			catch ( ex )
			{
				print( "scoreboard_settings.json: failed to read \"settings.columnGap\": " + ex )
			}
		}

		if ( "centered" in settings )
		{
			try
			{
				file.centered = settings.centered != false
			}
			catch ( ex )
			{
				print( "scoreboard_settings.json: failed to read \"settings.centered\": " + ex )
			}
		}

		// General named palette - any key, not a fixed set. Populates
		// file.namedColors for lookup by name from any "columns[]" entry's
		// color fields (the name column included - it's just a "columns[]"
		// entry too now, see EnsureColumnsLoaded()). foreach (key, value in
		// table) over a plain table is
		// a confirmed-safe pattern (see cl_mapspawn.gnut). friendly/enemy/
		// self/party get no special treatment here anymore - they're just
		// palette entries like any other name; file.teamColorFriendly etc.
		// stay at their hardcoded defaults unless a column explicitly
		// references a palette color for that state.
		//
		// file.namedColors[name] <- parsed, not "=" - this is Squirrel's
		// newslot operator, required specifically because namedColors starts
		// as an empty table with none of these keys pre-existing yet. "="
		// only *updates* an already-existing slot and throws "the index ...
		// does not exist" on a brand new one - confirmed the hard way, this
		// silently aborted the whole foreach on its first iteration (wrapped
		// in one try/catch covering all entries), leaving namedColors
		// permanently empty every single refresh with no visible symptom
		// beyond every named color falling back to its hardcoded default.
		if ( "colors" in settings )
		{
			try
			{
				foreach ( name, value in settings.colors )
				{
					var parsed = ParseColorArray( value )
					if ( parsed.len() > 0 )
						file.namedColors[name] <- parsed
				}
			}
			catch ( colorsEx )
			{
				print( "scoreboard_settings.json: failed to read \"settings.colors\": " + colorsEx )
			}
		}
	}

	file.settingsLoaded = true
}

// Reads a [r, g, b] or [r, g, b, a] JSON array into a clamped RGBA int
// array, or an empty array if it's missing/malformed (caller keeps whatever
// default was already in place - checks .len() > 0 rather than comparing
// against null). Returns var, not array<int> - the result eventually flows
// into SetColor()'s native "var" param, and this compiler rejects a
// statically-typed array<int> there no matter how it got produced.
var function ParseColorArray( var colorArr )
{
	try
	{
		if ( colorArr.len() < 3 )
			return []

		int r = ClampColorComponent( expect int( colorArr[0] ) )
		int g = ClampColorComponent( expect int( colorArr[1] ) )
		int b = ClampColorComponent( expect int( colorArr[2] ) )
		int a = colorArr.len() >= 4 ? ClampColorComponent( expect int( colorArr[3] ) ) : ROW_COLOR_ALPHA

		return [ r, g, b, a ]
	}
	catch ( ex )
	{
		print( "scoreboard_settings.json: failed to read a team color: " + ex )
		return []
	}
}

int function ClampColorComponent( int v )
{
	if ( v < 0 )
		return 0
	if ( v > 255 )
		return 255
	return v
}

// Looks up a named color from the general palette (settings.colors, see
// EnsureSettingsLoaded()). Returns [] (not found) rather than null, matching
// ParseColorArray's "empty array means invalid/missing" convention - callers
// use the same ".len() > 0" check for both.
var function ResolveNamedColor( string name )
{
	if ( name in file.namedColors )
		return file.namedColors[name]

	print( "scoreboard_settings.json: unknown color name \"" + name + "\"" )
	return []
}

// A column color field's raw JSON value is either a string (a name to look
// up in the palette) or a literal [r,g,b]/[r,g,b,a] array - resolves either
// case, or [] if invalid/not found. typeof is a core Squirrel keyword, not
// an engine-specific native, so it's trusted here without the same caution
// given to natives - but this is the first use of it in this file.
var function ResolveColorField( var raw )
{
	if ( typeof raw == "string" )
		return ResolveNamedColor( expect string( raw ) )

	return ParseColorArray( raw )
}

// Resolves one color axis (background or text) for one column - or the name
// column - into all four relationship-state colors at once. shorthandKey,
// if present, seeds all four; each state-specific key, if present, then
// overrides just that one state. A field that's present but fails to
// resolve (unknown name, malformed array) just keeps whatever it would
// otherwise have been - ResolveColorField's own callees already print a
// warning at the point of failure, so this doesn't need to duplicate that.
// Called twice per column (background/text) from EnsureColumnsLoaded() and
// EnsureSettingsLoaded()'s "nameColumn" block - one shared implementation.
// Returns var holding a table, not a strict "table" return type, to avoid
// relying on an untested strict-table-return pattern in this compiler.
var function ResolveTieredColors( var rawObj, string shorthandKey, string selfKey, string partyKey, string friendlyKey, string enemyKey, var defaultSelf, var defaultParty, var defaultFriendly, var defaultEnemy )
{
	var selfColor = defaultSelf
	var partyColor = defaultParty
	var friendlyColor = defaultFriendly
	var enemyColor = defaultEnemy

	if ( shorthandKey in rawObj )
	{
		var shorthand = ResolveColorField( rawObj[shorthandKey] )
		if ( shorthand.len() > 0 )
		{
			selfColor = shorthand
			partyColor = shorthand
			friendlyColor = shorthand
			enemyColor = shorthand
		}
	}

	if ( selfKey in rawObj )
	{
		var resolvedSelf = ResolveColorField( rawObj[selfKey] )
		if ( resolvedSelf.len() > 0 )
			selfColor = resolvedSelf
	}

	if ( partyKey in rawObj )
	{
		var resolvedParty = ResolveColorField( rawObj[partyKey] )
		if ( resolvedParty.len() > 0 )
			partyColor = resolvedParty
	}

	if ( friendlyKey in rawObj )
	{
		var resolvedFriendly = ResolveColorField( rawObj[friendlyKey] )
		if ( resolvedFriendly.len() > 0 )
			friendlyColor = resolvedFriendly
	}

	if ( enemyKey in rawObj )
	{
		var resolvedEnemy = ResolveColorField( rawObj[enemyKey] )
		if ( resolvedEnemy.len() > 0 )
			enemyColor = resolvedEnemy
	}

	return { self = selfColor, party = partyColor, friendly = friendlyColor, enemy = enemyColor }
}

int function CustomStatCompare( entity a, entity b )
{
	float aVal
	float bVal

	if ( file.customSortIsAD )
	{
		aVal = ComputeAssaultOverDeaths( a )
		bVal = ComputeAssaultOverDeaths( b )
	}
	else
	{
		aVal = float( a.GetPlayerGameStat( file.customSortStatType ) )
		bVal = float( b.GetPlayerGameStat( file.customSortStatType ) )
	}

	if ( aVal == bVal )
		return 0

	if ( file.customSortDescending )
		return aVal < bVal ? 1 : -1
	else
		return aVal > bVal ? 1 : -1

	unreachable
}

// "PGS_AD" value - assault score divided by deaths. Used both for sorting
// (CustomStatCompare) and for display (RefreshPlayerList, formatted to 1
// decimal via format("%.1f", ...) since it's a ratio, not a whole count).
// Deaths of 0 is treated as 1 (not 0) so a flawless player doesn't divide by
// zero or sort as tied-with-everyone-else-at-0-deaths. float division (not
// int) so close scores don't spuriously tie from truncation when sorting -
// e.g. 19/2 and 20/2 would both floor to 9 as ints despite being genuinely
// different ratios.
float function ComputeAssaultOverDeaths( entity player )
{
	int assault = player.GetPlayerGameStat( PGS_ASSAULT_SCORE )
	int deaths = player.GetPlayerGameStat( PGS_DEATHS )
	return float( assault ) / float( deaths > 0 ? deaths : 1 )
}

// Picks the right one of a column's four pre-resolved tiered colors for one
// row, given that row's already-computed relationship flags. Single nested
// ternary (no "unreachable" needed) - used identically for every
// background/text color lookup at paint time, so the self > party >
// friendly/enemy priority logic lives in exactly one place.
var function PickTier( bool isSelf, bool isPartyFriendly, bool isFriendly, var selfColor, var partyColor, var friendlyColor, var enemyColor )
{
	return isSelf ? selfColor : ( isPartyFriendly ? partyColor : ( isFriendly ? friendlyColor : enemyColor ) )
}

// Measures pixels-per-character for the monospace font once (it can't
// change at runtime - font is baked into the .res - so this never needs
// re-measuring), by setting a known-length reference string on one of the
// cScoreboardStatFixed-font labels and reading back its rendered width.
void function EnsureMonoCharWidthMeasured()
{
	if ( file.monoCharPxMeasured )
		return

	try
	{
		var refLabel = HudElement( "cScoreboardHeaderStat_0", file.scoreboard )
		if ( refLabel == null )
			return

		// Force a generously wide, VISIBLE box before measuring - this
		// label's width/visibility get overwritten every refresh to match
		// whatever column currently occupies stat-lane slot 0 (see the
		// header loop in RefreshPlayerList), and Hud_GetTextWidth() turned
		// out to report that current box width back (clipped), not the
		// text's true natural extent. Without the width override, the very
		// first measurement (still at the .res default) came back 0 (never
		// painted yet), and the second came back clipped to whatever narrow
		// width the previous refresh had just set - which then latched in
		// permanently as an absurdly small px-per-char and collapsed every
		// column to MIN_COL_PX. The visibility override is needed for the
		// same reason but a newer cause: if slot 0 happens to be occupied by
		// a column with an empty "title" (a NAME-less/icon column, or just a
		// stat column with a deliberately blank header), the header loop
		// never calls Hud_SetVisible(..., true) on it at all - it stays
		// permanently hidden, Hud_GetTextWidth() never returns a real
		// measurement, and monoCharPx gets stuck at its 8.0 fallback
		// forever, again collapsing every column toward MIN_COL_PX.
		// Whatever we force here gets correctly overwritten right back to
		// hidden by the header loop later in this same refresh if slot 0's
		// real column does have an empty title - this is a one-frame,
		// measurement-only override, not a persistent visual change.
		Hud_SetWidth( refLabel, MONO_MEASURE_SAFE_WIDTH )
		Hud_SetVisible( refLabel, true )
		Hud_SetText( refLabel, MONO_MEASURE_TEXT )
		int measuredWidth = Hud_GetTextWidth( refLabel )

		// Still not painted yet - keep the fallback default and retry next
		// refresh rather than latching a bogus 0px/char permanently.
		if ( measuredWidth <= 0 )
			return

		file.monoCharPx = float( measuredWidth ) / MONO_MEASURE_TEXT.len()
		file.monoCharPxMeasured = true
	}
	catch ( ex )
	{
		print( "EnsureMonoCharWidthMeasured failed: " + ex )
	}
}

// ----------------------------------------------------------------------------
// Player list + columns
// ----------------------------------------------------------------------------

void function PlayerListRefreshThread()
{
	while ( true )
	{
		wait LIST_REFRESH_INTERVAL

		if ( clGlobal.showingScoreboard )
			RefreshPlayerList()
	}
}

void function RefreshPlayerList()
{
	try
	{
		// Re-fetch fresh every refresh instead of caching the handle
		// indefinitely. During a disconnect/leave-lobby transition the
		// engine can tear down the VGUI tree outside of script's control;
		// calling Hud_Set*() natives on a stale/destroyed panel handle is a
		// native access violation, not a catchable Squirrel exception - the
		// try/catch around this whole function does nothing against that.
		// This lookup is as cheap as every child HudElement() call below,
		// which are already redone fresh every refresh for the same reason.
		file.scoreboard = HudElement( "Scoreboard" )

		if ( file.scoreboard == null )
			return

		if ( !clGlobal.showingScoreboard )
			return

		// Settings (including the named color palette) must load before
		// columns - EnsureColumnsLoaded() resolves per-column color fields
		// that can reference names from file.namedColors, which
		// EnsureSettingsLoaded() populates. Column presets ("columnPresets",
		// a sibling of "settings") must load before columns too, for the
		// same reason - a columns[] entry naming a preset needs
		// file.columnPresets already populated to find it.
		EnsureSettingsLoaded()
		EnsureColumnPresetsLoaded()
		EnsureColumnsLoaded()
		EnsureMonoCharWidthMeasured()
		int columnCount = file.columnTitles.len()  // name column included - always at least 1, see EnsureColumnsLoaded()
		int rowStep = file.rowHeight + file.rowSpacing

		entity localPlayer = GetLocalClientPlayer()
		int localTeam = IsValid( localPlayer ) ? localPlayer.GetTeam() : 0

		// team = 0 means "all players, all teams" rather than filtering to one -
		// see GetSortedPlayers() in _utility_shared.nut. Sort order is either
		// the custom one from scoreboard_settings.json, or vanilla's own
		// per-gamemode default (GetScoreboardCompareFunc()).
		IntFromEntityCompare compareFunc = file.useCustomSort ? CustomStatCompare : GetScoreboardCompareFunc()
		array<entity> players = GetSortedPlayers( compareFunc, 0 )

		// "sortMode.teamsSplit" (per-gamemode, see EnsureColumnsLoaded()) -
		// when true, group the already stat-sorted list into your team's
		// block first, then the other team's, each block keeping its
		// existing relative sort order (a stable partition, not a re-sort).
		if ( file.teamsSplit )
		{
			array<entity> friendlyPlayers
			array<entity> enemyPlayers
			foreach ( player in players )
			{
				if ( IsValid( player ) && player.GetTeam() == localTeam )
					friendlyPlayers.append( player )
				else
					enemyPlayers.append( player )
			}

			players = friendlyPlayers
			foreach ( player in enemyPlayers )
				players.append( player )
		}

		// Resize the box to fit exactly this many rows (capped at what we have
		// slots for) and recenter it vertically, rather than always showing a
		// fixed MAX_LIST_SLOTS-tall box.
		int shownCount = minint( players.len(), MAX_LIST_SLOTS )
		if ( shownCount < 1 )
			shownCount = 1

		// Size the name column to the longest name actually on screen right
		// now, wherever that column ends up sitting (see file.columnIsName).
		// Setting the text here (rather than in the main loop below) means
		// we're not measuring stale text left over from a previous refresh -
		// Hud_GetTextWidth() measures whatever's currently set.
		int longestNameWidth = 0
		for ( int m = 0; m < shownCount; m++ )
		{
			if ( !IsValid( players[m] ) )
				continue

			var measureLabel = HudElement( "cScoreboardPlayerName_" + m, file.scoreboard )
			if ( measureLabel == null )
				continue

			Hud_SetWidth( measureLabel, NAME_MEASURE_SAFE_WIDTH )
			Hud_SetText( measureLabel, players[m].GetPlayerNameWithClanTag() )
			int textWidth = Hud_GetTextWidth( measureLabel )
			if ( textWidth > longestNameWidth )
				longestNameWidth = textWidth
		}

		int nameColW = longestNameWidth + NAME_COL_TEXT_PADDING
		if ( nameColW < NAME_COL_MIN_W )
			nameColW = NAME_COL_MIN_W
		if ( nameColW > NAME_COL_MAX_W )
			nameColW = NAME_COL_MAX_W

		// Per-column pixel width and X offset, walking every column - name
		// column included, wherever file.columnIsName places it - in one
		// pass. The name column uses nameColW (measured above); every other
		// column uses its char width from the config. Columns can have
		// different widths now, so this can't be a flat index*width formula,
		// has to be accumulated.
		array<int> columnPixelWidths
		array<int> columnXOffsets
		int columnsRunningOffset = 0
		for ( int c = 0; c < columnCount; c++ )
		{
			int colPx
			if ( file.columnIsName[c] )
				colPx = nameColW
			else
			{
				colPx = int( file.columnCharWidths[c] * file.monoCharPx + 0.999 ) + STAT_COL_TEXT_PADDING
				if ( colPx < MIN_COL_PX )
					colPx = MIN_COL_PX
			}

			columnPixelWidths.append( colPx )
			columnXOffsets.append( columnsRunningOffset )
			columnsRunningOffset += colPx + file.colGap
		}
		int columnsTotalWidth = columnCount > 0 ? columnsRunningOffset - file.colGap : 0
		int boxWidth = BOX_PAD * 2 + columnsTotalWidth

		// CANVAS_W/CANVAS_H are just the fallback - GetScreenSize() gives the
		// real current resolution, confirmed (via diagnostic logging) to not
		// always match the hardcoded 1920x1080 assumption, which was
		// anchoring the box to the wrong right edge on other resolutions.
		int canvasW = CANVAS_W
		int canvasH = CANVAS_H
		try
		{
			float[2] screenSize = GetScreenSize()
			if ( screenSize[0] > 0 && screenSize[1] > 0 )
			{
				canvasW = int( screenSize[0] )
				canvasH = int( screenSize[1] )
			}
		}
		catch ( ex )
		{
			print( "RefreshPlayerList: GetScreenSize() failed, falling back to " + CANVAS_W + "x" + CANVAS_H + ": " + ex )
		}

		int boxHeight = HEADER_H + HEADER_GAP + shownCount * rowStep + BOX_PAD * 2
		int boxX = file.centered ? ( canvasW - boxWidth ) / 2 : canvasW - RIGHT_MARGIN - boxWidth
		int boxY = ( canvasH - boxHeight ) / 2
		int titleY = boxY - TITLE_TO_BOX_GAP
		int headerY = boxY + BOX_PAD
		int rowsStartY = headerY + HEADER_H + HEADER_GAP

		// From here down, every HudElement() lookup is null-checked before
		// any Hud_Set*() call touches it - a panel disappearing mid-refresh
		// (e.g. the tree tearing down as we're leaving the match) means a
		// null result, and calling the natives on null is exactly the kind
		// of native (not Squirrel-catchable) crash this got hardened against.

		var title = HudElement( "cScoreboardTitle", file.scoreboard )
		if ( title != null )
		{
			Hud_SetPos( title, boxX, titleY )
			Hud_SetWidth( title, boxWidth )
		}

		var listBg = HudElement( "cScoreboardListBG", file.scoreboard )
		if ( listBg != null )
		{
			Hud_SetPos( listBg, boxX, boxY )
			Hud_SetWidth( listBg, boxWidth )
			Hud_SetHeight( listBg, boxHeight )
		}

		// Column headers - walks every column in array order (name column
		// included, wherever it sits - see file.columnIsName) using
		// cScoreboardHeaderName for whichever one is the name column and the next
		// available cScoreboardHeaderStat_N for everything else. A header is
		// hidden whenever its title is empty - true for a name column with
		// no "title" set (matching the historical "no header shown" default
		// look) same as for any stat column that happens to have one.
		int headerStatPanelIndex = 0
		for ( int c = 0; c < columnCount; c++ )
		{
			int colX = boxX + BOX_PAD + columnXOffsets[c]

			if ( file.columnIsName[c] )
			{
				var headerName = HudElement( "cScoreboardHeaderName", file.scoreboard )
				if ( headerName == null )
					continue

				if ( file.columnTitles[c] == "" )
					Hud_SetVisible( headerName, false )
				else
				{
					Hud_SetPos( headerName, colX, headerY )
					Hud_SetWidth( headerName, columnPixelWidths[c] )
					Hud_SetVisible( headerName, true )
					Hud_SetText( headerName, file.columnTitles[c] )
				}
				continue
			}

			var headerLabel = HudElement( "cScoreboardHeaderStat_" + headerStatPanelIndex, file.scoreboard )
			headerStatPanelIndex++
			if ( headerLabel == null )
				continue

			if ( file.columnTitles[c] == "" )
			{
				Hud_SetVisible( headerLabel, false )
				continue
			}

			Hud_SetPos( headerLabel, colX, headerY )
			Hud_SetWidth( headerLabel, columnPixelWidths[c] )
			Hud_SetVisible( headerLabel, true )
			Hud_SetText( headerLabel, file.columnTitles[c] )
		}
		for ( int hc = headerStatPanelIndex; hc < MAX_STAT_COLUMNS; hc++ )
		{
			var unusedHeaderLabel = HudElement( "cScoreboardHeaderStat_" + hc, file.scoreboard )
			if ( unusedHeaderLabel != null )
				Hud_SetVisible( unusedHeaderLabel, false )
		}

		for ( int i = 0; i < MAX_LIST_SLOTS; i++ )
		{
			if ( i >= players.len() || !IsValid( players[i] ) )
			{
				var hiddenNameBg = HudElement( "cScoreboardPlayerNameBG_" + i, file.scoreboard )
				if ( hiddenNameBg != null )
					Hud_SetVisible( hiddenNameBg, false )
				var hiddenNameLabel = HudElement( "cScoreboardPlayerName_" + i, file.scoreboard )
				if ( hiddenNameLabel != null )
					Hud_SetVisible( hiddenNameLabel, false )
				for ( int c = 0; c < MAX_STAT_COLUMNS; c++ )
				{
					var hiddenStatBg = HudElement( "cScoreboardPlayerStatBG_" + i + "_" + c, file.scoreboard )
					if ( hiddenStatBg != null )
						Hud_SetVisible( hiddenStatBg, false )
					var hiddenStatLabel = HudElement( "cScoreboardPlayerStat_" + i + "_" + c, file.scoreboard )
					if ( hiddenStatLabel != null )
						Hud_SetVisible( hiddenStatLabel, false )
				}
				continue
			}

			entity player = players[i]
			int rowY = rowsStartY + i * rowStep

			// Relationship flags computed once per row, used for every
			// column's background AND text color (name column and every
			// stat column) via PickTier(). "teamsSplit" (see above) only
			// controls whether the list is grouped into blocks, it has no
			// bearing on coloring.
			bool isFriendly = player.GetTeam() == localTeam
			bool isParty = IsPartyMember( player )
			bool isSelf = IsValid( localPlayer ) && player == localPlayer
			bool isPartyFriendly = isParty && isFriendly

			// Walks every column in array order - name column included,
			// wherever it sits - using cScoreboardPlayerNameBG_i/cScoreboardPlayerName_i
			// for whichever one is the name column and the next available
			// cScoreboardPlayerStatBG_i_N/cScoreboardPlayerStat_i_N for everything else.
			int rowStatPanelIndex = 0
			for ( int c = 0; c < columnCount; c++ )
			{
				int colX = boxX + BOX_PAD + columnXOffsets[c]

				if ( file.columnIsName[c] )
				{
					var nameBg = HudElement( "cScoreboardPlayerNameBG_" + i, file.scoreboard )
					if ( nameBg != null )
					{
						Hud_SetPos( nameBg, colX, rowY )
						Hud_SetWidth( nameBg, columnPixelWidths[c] )
						Hud_SetHeight( nameBg, file.rowHeight )
						Hud_SetVisible( nameBg, true )

						// Re-checking IsValid(player) immediately before each
						// SetColor call, not reusing the flags computed above -
						// player could disconnect mid-refresh (this whole
						// function runs synchronously, but the engine's own
						// entity/panel teardown isn't gated by that), and
						// calling a native on a stale entity/panel handle is a
						// crash try/catch can't stop.
						if ( IsValid( player ) )
							nameBg.SetColor( PickTier( isSelf, isPartyFriendly, isFriendly, file.columnBgSelf[c], file.columnBgParty[c], file.columnBgFriendly[c], file.columnBgEnemy[c] ) )
					}

					// Text itself was already set by the measurement pass
					// above (measuring requires the real text to already be
					// set) - just position/color it here.
					var nameLabel = HudElement( "cScoreboardPlayerName_" + i, file.scoreboard )
					if ( nameLabel != null )
					{
						Hud_SetPos( nameLabel, colX, rowY )
						Hud_SetWidth( nameLabel, columnPixelWidths[c] )
						Hud_SetHeight( nameLabel, file.rowHeight )
						Hud_SetVisible( nameLabel, true )

						if ( IsValid( player ) )
							nameLabel.SetColor( PickTier( isSelf, isPartyFriendly, isFriendly, file.columnTextSelf[c], file.columnTextParty[c], file.columnTextFriendly[c], file.columnTextEnemy[c] ) )
					}

					continue
				}

				var statBg = HudElement( "cScoreboardPlayerStatBG_" + i + "_" + rowStatPanelIndex, file.scoreboard )
				var statLabel = HudElement( "cScoreboardPlayerStat_" + i + "_" + rowStatPanelIndex, file.scoreboard )
				rowStatPanelIndex++

				if ( statBg != null )
				{
					Hud_SetPos( statBg, colX, rowY )
					Hud_SetWidth( statBg, columnPixelWidths[c] )
					Hud_SetHeight( statBg, file.rowHeight )
					Hud_SetVisible( statBg, true )

					if ( IsValid( player ) )
						statBg.SetColor( PickTier( isSelf, isPartyFriendly, isFriendly, file.columnBgSelf[c], file.columnBgParty[c], file.columnBgFriendly[c], file.columnBgEnemy[c] ) )
				}

				if ( statLabel != null )
				{
					Hud_SetPos( statLabel, colX, rowY )
					Hud_SetWidth( statLabel, columnPixelWidths[c] )
					Hud_SetHeight( statLabel, file.rowHeight )
					Hud_SetVisible( statLabel, true )

					// Re-validated per-column rather than once before the
					// loop - see the IsValid(player) comment above.
					if ( IsValid( player ) )
					{
						// GetGen() for "PGS_GEN", ComputeAssaultOverDeaths()
						// for "PGS_AD" (formatted to 1 decimal - it's a
						// ratio, not a whole count), GetPlayerGameStat() for
						// everything else - see file.columnIsGen/columnIsAD.
						if ( file.columnIsGen[c] )
							Hud_SetText( statLabel, string( player.GetGen() ) )
						else if ( file.columnIsAD[c] )
							Hud_SetText( statLabel, format( "%.1f", ComputeAssaultOverDeaths( player ) ) )
						else
							Hud_SetText( statLabel, string( player.GetPlayerGameStat( file.columnScoreTypes[c] ) ) )
						statLabel.SetColor( PickTier( isSelf, isPartyFriendly, isFriendly, file.columnTextSelf[c], file.columnTextParty[c], file.columnTextFriendly[c], file.columnTextEnemy[c] ) )
					}
				}
			}

			for ( int hc2 = rowStatPanelIndex; hc2 < MAX_STAT_COLUMNS; hc2++ )
			{
				var unusedStatBg = HudElement( "cScoreboardPlayerStatBG_" + i + "_" + hc2, file.scoreboard )
				if ( unusedStatBg != null )
					Hud_SetVisible( unusedStatBg, false )
				var unusedStatLabel = HudElement( "cScoreboardPlayerStat_" + i + "_" + hc2, file.scoreboard )
				if ( unusedStatLabel != null )
					Hud_SetVisible( unusedStatLabel, false )
			}
		}
	}
	catch ( ex )
	{
		print( "RefreshPlayerList failed: " + ex )
	}
}
