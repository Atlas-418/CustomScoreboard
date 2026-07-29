// Keyvalues PATCH (Northstar's keyvalues/ merge system - #base-chained with
// vanilla + every other mod's patch of the same file, NOT a full file
// replacement). Root name must match the vanilla file's own root key exactly
// ("Scheme") so this merges as a sibling entry instead of creating an orphan
// tree - confirmed by reading how our own hudscoreboard.res patch actually
// merges (mod_patch_*_HudScoreboard.res in runtime/compiled), same
// technique applied here. This only ADDS new named font entries - nothing
// vanilla or any other mod already defines is touched or overridden, so it
// can't repeat the vgui_screens.txt full-file-replacement incident.
//
// Both entries use "jetbrainsMono" (see fontfiletable.txt - our bundled
// JetBrains Mono NL Regular, OFL-licensed) at weight 0 so the font's own
// designed Regular weight comes through unmodified, instead of DefaultFixed
// (Lucida Console/NorthstarMono.ttf) and Default (Tahoma) which read as
// heavier at the same point sizes. "tall" values match DefaultFixed/Default
// exactly so nothing about the scoreboard's layout math changes.
Scheme
{
	Fonts
	{
		cScoreboardStatFixed
		{
			1
			{
				name		"jetbrainsMono"
				tall		10			[!$GAMECONSOLE]
				tall		14			[$GAMECONSOLE]
				weight		0
				antialias	1
			}
		}

		cScoreboardName
		{
			1
			{
				name		"jetbrainsMono"
				tall		16
				weight		0
				antialias	1
			}
		}
	}
}
