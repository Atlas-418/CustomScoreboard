untyped

global const SCOREBOARD_LOCAL_PLAYER_COLOR = <LOCAL_R / 255.0, LOCAL_G / 255.0, LOCAL_B / 255.0>
global const SCOREBOARD_PARTY_COLOR = <PARTY_R / 255.0, PARTY_G / 255.0, PARTY_B / 255.0>
const SCOREBOARD_FRIENDLY_COLOR = <FRIENDLY_R / 255.0, FRIENDLY_G / 255.0, FRIENDLY_B / 255.0>
const SCOREBOARD_FRIENDLY_SELECTED_COLOR = <0.6640625, 0.7578125, 0.85546875>
const SCOREBOARD_ENEMY_COLOR = <ENEMY_R / 255.0, ENEMY_G / 255.0, ENEMY_B / 255.0>
const SCOREBOARD_ENEMY_SELECTED_COLOR = <1.0, 0.7019, 0.592>
const SCOREBOARD_DEAD_FONT_COLOR = <0.7, 0.7, 0.7>
const SCOREBOARD_FFA_COLOR = <0.5, 0.5, 0.5>
const SCOREBOARD_BG_ALPHA = 0.35
const SCOREBOARD_EMPTY_COLOR = <0.0, 0.0, 0.0>
const SCOREBOARD_EMPTY_BG_ALPHA = 0.35

const SCOREBOARD_TITLE_HEIGHT = 50
const SCOREBOARD_SUBTITLE_HEIGHT = 35
const SCOREBOARD_FOOTER_HEIGHT = 35
const SCOREBOARD_TEAM_LOGO_OFFSET = 24
const SCOREBOARD_TEAM_LOGO_HEIGHT = 64
const SCOREBOARD_PLAYER_ROW_OFFSET = 12
const SCOREBOARD_PLAYER_ROW_HEIGHT = 35
const SCOREBOARD_PLAYER_ROW_SPACING = 2

const int MAX_TEAM_SLOTS = 16

const int MIC_STATE_NO_MIC = 0
const int MIC_STATE_HAS_MIC = 1
const int MIC_STATE_TALKING = 2
const int MIC_STATE_PARTY_HAS_MIC = 3
const int MIC_STATE_PARTY_TALKING = 4
const int MIC_STATE_MUTED = 5

global function ClScoreboardMp_Init
global function ClScoreboardMp_GetGameTypeDescElem
global function ScoreboardFocus
global function ScoreboardLoseFocus
global function ScoreboardSelectPrevPlayer
global function ScoreboardSelectNextPlayer
global function GetScoreBoardFooterRui
global function SetScoreboardUpdateCallback

global function AddCallback_OnScoreboardUpdate
global function AddCallback_OnScoreboardPlayerUpdate

global struct SuperiorFile{// "NEVER DO THAT"
	bool hasFocus = false
	var selectedPlayer
	var prevPlayer
	var nextPlayer

	var scoreboardBg
	var scoreboard
	var background

	array<var> scoreboardOverlays
	array<var> scoreboardElems

	table header = {
		background = null
		gametypeAndMap = null
		gametypeDesc = null
		scoreHeader = null
	}

	var footer
	var pingText

	table teamElems

	table highlightColumns

	var nameEndColumn

	table playerElems

	var scoreboardRUI

	void functionref(entity,var) scoreboardUpdateCallback
} 

SuperiorFile file

array < void functionref( SuperiorFile ) > OnScoreboardUpdateCallbacks

void function AddCallback_OnScoreboardUpdate( void functionref( SuperiorFile ) callbackFunc )
{
	Assert( !OnScoreboardUpdateCallbacks.contains( callbackFunc ), "Already added " + string( callbackFunc ) + " with AddCallback_OnScoreboardUpdate" )
	OnScoreboardUpdateCallbacks.append( callbackFunc )
}


array < void functionref( entity, int, int, SuperiorFile ) > OnScoreboardPlayerUpdateCallbacks

void function AddCallback_OnScoreboardPlayerUpdate( void functionref( entity, int, int, SuperiorFile ) callbackFunc )
{
	Assert( !OnScoreboardPlayerUpdateCallbacks.contains( callbackFunc ), "Already added " + string( callbackFunc ) + " with AddCallback_OnScoreboardPlayerUpdate" )
	OnScoreboardPlayerUpdateCallbacks.append( callbackFunc )
}

//foreach ( void functionref( entity ) callback in svGlobal.onPlayerRespawnedCallbacks )
//		callback( player )



//END
function ClScoreboardMp_Init()
{
	clGlobal.initScoreboardFunc = InitScoreboardMP
	clGlobal.showScoreboardFunc = ShowScoreboardMP
	clGlobal.hideScoreboardFunc = HideScoreboardMP
	clGlobal.scoreboardInputFunc = ScoreboardInputMP

	RegisterConCommandTriggeredCallback( "scoreboard_focus", ScoreboardFocus )
	RegisterConCommandTriggeredCallback( "scoreboard_toggle_focus", ScoreboardToggleFocus )
}

void function ScoreboardFocus( entity player )
{
	if ( !clGlobal.showingScoreboard )
	{
		return
	}

	EmitSoundOnEntity( player, "menu_click" )
	file.hasFocus = true

	file.selectedPlayer = GetLocalClientPlayer()
	SetScoreboardPlayer( file.selectedPlayer )
	RuiSetGameTime( Hud_GetRui( file.footer ), "startFadeTime", -1.0 )

	string text = Localize( "#LEFT_SCOREBOARD_EXIT" ) + "   " + Localize( "#X_BUTTON_MUTE" )
	#if PC_PROG
		if ( Origin_IsOverlayAvailable() )
			text = text + "   " + Localize( "#Y_BUTTON_VIEW_PROFILE" )
	#else
		text = text + "   " + Localize( "#Y_BUTTON_VIEW_PROFILE" )
	#endif

	RuiSetString( Hud_GetRui( file.footer ), "footerText", text )
}

void function ScoreboardLoseFocus( entity player )
{
	if ( !clGlobal.showingScoreboard )
		return

	EmitSoundOnEntity( player, "menu_click" )
	file.hasFocus = false
	file.selectedPlayer = null
	SetScoreboardPlayer( null )

	RuiSetString( Hud_GetRui( file.footer ), "footerText", "" )
	//RuiSetGameTime( Hud_GetRui( file.footer ), "startFadeTime", Time() )
	//RuiSetString( Hud_GetRui( file.footer ), "footerText", Localize( "#RIGHT_SCOREBOARD_FOCUS" ) )
}

void function ScoreboardToggleFocus( entity player )
{
	if ( file.hasFocus )
		ScoreboardLoseFocus( player )
	else
		ScoreboardFocus( player )
}

int function GetEnemyScoreboardTeam()
{
	return GetEnemyTeam( GetLocalClientPlayer().GetTeam() )
}

int function GetScoreboardDisplaySlotCount()
{
	int rawValue = expect int( level.maxTeamSize )
	if ( UseSingleTeamScoreboard() )
		rawValue = GetCurrentPlaylistVarInt( "max_players", 8 )

	return minint( MAX_TEAM_SLOTS, rawValue )
}

void function InitScoreboardMP()
{
	entity localPlayer = GetLocalClientPlayer()
	int myTeam = localPlayer.GetTeam()
	int enemyTeam = GetEnemyScoreboardTeam()

	local scoreboard = HudElement( "Scoreboard" )
	file.scoreboard = scoreboard

	// Atlas custom scoreboard draws everything itself (see cl_custom_scoreboard.nut).
	// We keep these two specifically because GetScoreBoardFooterRui(),
	// ClScoreboardMp_GetGameTypeDescElem(), and ScoreboardFocus()/ScoreboardLoseFocus()
	// are public API other code may call expecting a valid panel back - they're
	// explicitly hidden below since we don't want their vanilla content on screen.
	file.header.gametypeDesc = HudElement( "ScoreboardHeaderGametypeDesc", scoreboard )
	file.footer = HudElement( "ScoreboardGamepadFooter", scoreboard )
	file.header.gametypeDesc.Hide()
	file.footer.Hide()

	file.scoreboardElems.append( file.header.gametypeDesc )
	file.scoreboardElems.append( file.footer )

	// Every child declared in the vanilla scoreboard's underlying .res gets
	// instantiated as soon as "Scoreboard" itself is created, regardless of
	// whether any script ever calls HudElement() on it - visibility is just
	// whatever that child's own compiled default is. Row backgrounds default
	// to hidden (vanilla only ever shows them via an explicit .Show() call,
	// which we no longer make), but ping text defaults to visible - hence it
	// showing a stale "999" once we stopped feeding it real data. Hide it
	// explicitly rather than relying on a default that isn't actually there.
	HudElement( "ScoreboardPingText", scoreboard ).Hide()

	file.playerElems[myTeam] <- []
	file.playerElems[enemyTeam] <- []
}


array<var> function CreateScoreboardOverlays()
{
	array<var> overlays

	switch ( GAMETYPE )
	{
		case ATTRITION:
			overlays.extend( AT_CreateScoreboardOverlays() )
			break;
		default:

			break;
	}

	return overlays
}

function ScoreboardFadeIn()
{
	foreach ( elem in file.scoreboardElems )
	{
		RuiSetGameTime( Hud_GetRui( elem ), "fadeOutStartTime", RUI_BADGAMETIME )
		RuiSetGameTime( Hud_GetRui( elem ), "fadeInStartTime", Time() )
	}

	if ( file.scoreboardBg != null )
	{
		RuiSetGameTime( file.scoreboardBg, "fadeOutStartTime", RUI_BADGAMETIME )
		RuiSetGameTime( file.scoreboardBg, "fadeInStartTime", Time() )
	}
}

function ScoreboardFadeOut()
{
	foreach ( elem in file.scoreboardElems )
	{
		RuiSetGameTime( Hud_GetRui( elem ), "fadeInStartTime", RUI_BADGAMETIME )
		RuiSetGameTime( Hud_GetRui( elem ), "fadeOutStartTime", Time() )
	}

	if ( file.scoreboardBg != null )
	{
		RuiSetGameTime( file.scoreboardBg, "fadeInStartTime", RUI_BADGAMETIME )
		RuiSetGameTime( file.scoreboardBg, "fadeOutStartTime", Time() )
	}
}


//MAIN FUNC
void function ShowScoreboardMP()
{
	file.scoreboardOverlays = CreateScoreboardOverlays()

	RuiSetGameTime( Hud_GetRui( file.footer ), "startFadeTime", Time() )
	RuiSetString( Hud_GetRui( file.footer ), "footerText", Localize( "#RIGHT_SCOREBOARD_FOCUS" ) )

	EndSignal( clGlobal.signalDummy, "OnHideScoreboard" )

	// Atlas custom scoreboard draws onto this same "Scoreboard" tree (see
	// cl_custom_scoreboard.nut + keyvalues/resource/ui/hudscoreboard.res), so
	// no separate show/hide call is needed here - our panels are children of
	// file.scoreboard and cascade with it automatically.
	file.scoreboard.Show()
	ScoreboardFadeIn()

	// Stripped for a clean review baseline: player sorting, focus/selection
	// tracking (file.selectedPlayer/prevPlayer/nextPlayer), and firing
	// OnScoreboardPlayerUpdateCallbacks/OnScoreboardUpdateCallbacks are all
	// removed for now. Nothing currently consumes them - cl_custom_scoreboard.nut's
	// row drawing is stripped too. This is exactly the scaffolding row drawing
	// will need again once rebuilt.
	for ( ;; )
	{
		Assert( clGlobal.showingScoreboard )
		WaitFrame()
	}
}

void function HideScoreboardMP()
{
	ScoreboardFadeOut()
	wait( 0.1 )
	file.hasFocus = false
	file.selectedPlayer = null
	SetScoreboardPlayer( null )

	file.scoreboard.Hide()
	if ( file.scoreboardBg != null )
	{
		RuiDestroy( file.scoreboardBg )
		file.scoreboardBg = null
	}
	foreach ( overlay in file.scoreboardOverlays )
	{
		RuiDestroy( overlay )
	}
	file.scoreboardOverlays = []

	entity localPlayer = GetLocalClientPlayer()
	int myTeam = localPlayer.GetTeam()
	int enemyTeam = GetEnemyScoreboardTeam()

	Signal( clGlobal.signalDummy, "OnHideScoreboard" )
}

function GetConnectionImage( ping )
{
	local image

	if ( ping > 150 )
		image = SCOREBOARD_MATERIAL_CONNECTION_QUALITY_1
	else if ( ping > 100 )
		image = SCOREBOARD_MATERIAL_CONNECTION_QUALITY_2
	else if ( ping > 75 )
		image = SCOREBOARD_MATERIAL_CONNECTION_QUALITY_3
	else if ( ping > 50 )
		image = SCOREBOARD_MATERIAL_CONNECTION_QUALITY_4
	else
		image = SCOREBOARD_MATERIAL_CONNECTION_QUALITY_5

	return image
}

asset function GetPlayerGenIcon( entity player )
{
	switch ( player.GetGen() )
	{
		case 1:
			return SCOREBOARD_MATERIAL_GEN1
		case 2:
			return SCOREBOARD_MATERIAL_GEN2
		case 3:
			return SCOREBOARD_MATERIAL_GEN3
		case 4:
			return SCOREBOARD_MATERIAL_GEN4
		case 5:
			return SCOREBOARD_MATERIAL_GEN5
		case 6:
			return SCOREBOARD_MATERIAL_GEN6
		case 7:
			return SCOREBOARD_MATERIAL_GEN7
		case 8:
			return SCOREBOARD_MATERIAL_GEN8
		case 9:
			return SCOREBOARD_MATERIAL_GEN9
		case 10:
			return SCOREBOARD_MATERIAL_GEN10
		default:
			Assert( 0, "GetGen( player ) did not return a value between 0 and 9" )
	}
	unreachable
}

int function GetNumTeamPlayers()
{
	if ( UseSingleTeamScoreboard() )
		return GetCurrentPlaylistVarInt( "max_players", MAX_TEAM_SLOTS )
	return GetCurrentPlaylistVarInt( "max_players", MAX_TEAM_SLOTS ) / 2
}

void function ScoreboardInputMP( int key )
{
	Assert( clGlobal.showingScoreboard )

	entity player = GetLocalClientPlayer()

	switch( key )
	{
		case SCOREBOARD_INPUT_SELECT_PREV:
			ScoreboardSelectPrevPlayer( player )
			break

		case SCOREBOARD_INPUT_SELECT_NEXT:
			ScoreboardSelectNextPlayer( player )
			break

		case SCOREBOARD_FOCUS:
			ScoreboardFocus( player )
			break

		case SCOREBOARD_LOSE_FOCUS:
			ScoreboardLoseFocus( player )
			break
	}
}

var function ClScoreboardMp_GetGameTypeDescElem()
{
	return file.header.gametypeDesc
}

bool function UseSingleTeamScoreboard()
{
	return ( IsFFAGame() || IsSingleTeamMode() )
}

void function ScoreboardSelectNextPlayer( entity player )
{
	EmitSoundOnEntity( player, "menu_click" )
	file.selectedPlayer = file.nextPlayer
	SetScoreboardPlayer( file.selectedPlayer )
}

void function ScoreboardSelectPrevPlayer( entity player )
{
	EmitSoundOnEntity( player, "menu_click" )
	file.selectedPlayer = file.prevPlayer
	SetScoreboardPlayer( file.selectedPlayer )
}

var function GetScoreBoardFooterRui()
{
	return Hud_GetRui( file.footer )
}

void function SetScoreboardUpdateCallback( void functionref( entity, var ) func )
{
	file.scoreboardUpdateCallback = func
}