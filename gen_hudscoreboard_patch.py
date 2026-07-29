import io, os

MAX_LIST_SLOTS = 32
MAX_STAT_COLUMNS = 12

CANVAS_W = 1920
CANVAS_H = 1080

ROW_H = 22
ROW_SPACING = 2
ROW_STEP = ROW_H + ROW_SPACING

HEADER_H = 22
HEADER_GAP = 6

# These are just the *default* (baked-in) values, used for the brief window
# before cl_custom_scoreboard.nut's first refresh recomputes everything at
# runtime (right-anchored, sized to actual player/column count). Kept roughly
# in line with the runtime formula so that window doesn't flash somewhere
# obviously wrong. Default assumes 0 stat columns, same as the runtime code's
# own default before it fetches real gamemode column data.
RIGHT_MARGIN = 40
NAME_COL_W = 380
STAT_COL_W = 90
COL_GAP = 6
BOX_PAD = 20
BOX_W = NAME_COL_W + BOX_PAD * 2
BOX_H = HEADER_H + HEADER_GAP + MAX_LIST_SLOTS * ROW_STEP + BOX_PAD * 2

BOX_X = CANVAS_W - RIGHT_MARGIN - BOX_W
BOX_Y = 110

TITLE_Y = BOX_Y - 46

out = io.StringIO()
w = out.write

# This is a keyvalues PATCH (Northstar's keyvalues/ merge system, #base-chained
# with vanilla + every other mod's patch of the same file - NOT a full file
# replacement). Root name must match vanilla's real HudScoreboard.res exactly
# so the patch merges as siblings under it instead of creating an orphan tree.
# Confirmed against the ScoreboardPingDisplay mod, which patches the same file
# the same way.
w('"Resource/UI/HudScoreboard.res"\n{\n')

# Title
w('\tcScoreboardTitle\n\t{\n')
w('\t\tControlName\t\tLabel\n')
w(f'\t\txpos\t\t\t{BOX_X}\n')
w(f'\t\typos\t\t\t{TITLE_Y}\n')
w(f'\t\twide\t\t\t{BOX_W}\n')
w('\t\ttall\t\t\t30\n')
w('\t\tvisible\t\t\t1\n')
w('\t\tenabled\t\t\t1\n')
w('\t\tlabelText\t\t"PLAYERS"\n')
w('\t\ttextAlignment\tcenter\n')
w('\t\tfont\t\t\tDefaultExtraBold\n')
w('\t\tfgcolor\t\t\t"255 255 255 255"\n')
w('\t\twrap\t\t\t0\n')
w('\t}\n\n')

# Background box
w('\tcScoreboardListBG\n\t{\n')
w('\t\tControlName\t\tImagePanel\n')
w('\t\timage\t\t\t"vgui/hud/white"\n')
w('\t\tfg_image\t\t"vgui/hud/white"\n')
w('\t\tdrawColor\t\t"0 0 0 140"\n')
w('\t\tscaleImage\t\t1\n')
w(f'\t\txpos\t\t\t{BOX_X}\n')
w(f'\t\typos\t\t\t{BOX_Y}\n')
w(f'\t\twide\t\t\t{BOX_W}\n')
w(f'\t\ttall\t\t\t{BOX_H}\n')
w('\t\tvisible\t\t\t1\n')
w('\t}\n\n')

name_x = BOX_X + BOX_PAD
name_w = NAME_COL_W

def col_x(c):
    # +COL_GAP once up front is the name-to-stat gap (Gap A) - there's no
    # longer a shared row background to visually hide that seam now that
    # name and stat cells each get their own box.
    return name_x + NAME_COL_W + COL_GAP + c * (STAT_COL_W + COL_GAP)

# Header row: name column header + stat column titles, above the player rows.
header_y = BOX_Y + BOX_PAD

w('\tcScoreboardHeaderName\n\t{\n')
w('\t\tControlName\t\tLabel\n')
w(f'\t\txpos\t\t\t{name_x}\n')
w(f'\t\typos\t\t\t{header_y}\n')
w(f'\t\twide\t\t\t{name_w}\n')
w(f'\t\ttall\t\t\t{HEADER_H}\n')
w('\t\tvisible\t\t\t0\n')
w('\t\tenabled\t\t\t1\n')
w('\t\tlabelText\t\t""\n')
w('\t\ttextAlignment\twest\n')
w('\t\tfont\t\t\tcScoreboardName\n')
w('\t\tfgcolor\t\t\t"200 200 200 255"\n')
w('\t\twrap\t\t\t0\n')
w('\t}\n\n')

for c in range(MAX_STAT_COLUMNS):
    w(f'\tcScoreboardHeaderStat_{c}\n\t{{\n')
    w('\t\tControlName\t\tLabel\n')
    w(f'\t\txpos\t\t\t{col_x(c)}\n')
    w(f'\t\typos\t\t\t{header_y}\n')
    w(f'\t\twide\t\t\t{STAT_COL_W}\n')
    w(f'\t\ttall\t\t\t{HEADER_H}\n')
    w('\t\tvisible\t\t\t0\n')
    w('\t\tenabled\t\t\t1\n')
    w('\t\tlabelText\t\t""\n')
    w('\t\ttextAlignment\teast\n')
    # Monospace - column widths are specified in characters (see
    # cl_custom_scoreboard.nut), which only makes sense with a fixed-width
    # font. "cScoreboardStatFixed" = bundled JetBrains Mono NL Regular, registered
    # via our own keyvalues/resource/{fontfiletable.txt,sourcescheme.res}
    # patches - lighter-weight than vanilla's DefaultFixed (Lucida Console).
    w('\t\tfont\t\t\tcScoreboardStatFixed\n')
    w('\t\tfgcolor\t\t\t"200 200 200 255"\n')
    w('\t\twrap\t\t\t0\n')
    w('\t}\n\n')

# Player rows: each cell (name + every stat column) gets its own background
# box instead of one shared row-wide bar, so columns read as distinct
# "chips" separated by columnGap. Each background is declared immediately
# before its corresponding label so it renders behind it (declaration order
# determines paint order in this panel system).
rows_start_y = BOX_Y + BOX_PAD + HEADER_H + HEADER_GAP
for i in range(MAX_LIST_SLOTS):
    y = rows_start_y + i * ROW_STEP

    w(f'\tcScoreboardPlayerNameBG_{i}\n\t{{\n')
    w('\t\tControlName\t\tImagePanel\n')
    w('\t\timage\t\t\t"vgui/hud/white"\n')
    w('\t\tfg_image\t\t"vgui/hud/white"\n')
    w('\t\tdrawColor\t\t"80 80 80 160"\n')
    w('\t\tscaleImage\t\t1\n')
    w(f'\t\txpos\t\t\t{name_x}\n')
    w(f'\t\typos\t\t\t{y}\n')
    w(f'\t\twide\t\t\t{name_w}\n')
    w(f'\t\ttall\t\t\t{ROW_H}\n')
    w('\t\tvisible\t\t\t0\n')
    w('\t}\n\n')

    w(f'\tcScoreboardPlayerName_{i}\n\t{{\n')
    w('\t\tControlName\t\tLabel\n')
    w(f'\t\txpos\t\t\t{name_x}\n')
    w(f'\t\typos\t\t\t{y}\n')
    w(f'\t\twide\t\t\t{name_w}\n')
    w(f'\t\ttall\t\t\t{ROW_H}\n')
    w('\t\tvisible\t\t\t0\n')
    w('\t\tenabled\t\t\t1\n')
    w('\t\tlabelText\t\t""\n')
    w('\t\ttextAlignment\twest\n')
    # "cScoreboardName" - same bundled font as cScoreboardStatFixed, lighter-weight than
    # vanilla's Default (Tahoma) at the same point size.
    w('\t\tfont\t\t\tcScoreboardName\n')
    w('\t\tfgcolor\t\t\t"255 255 255 255"\n')
    w('\t\twrap\t\t\t0\n')
    w('\t}\n\n')

    for c in range(MAX_STAT_COLUMNS):
        w(f'\tcScoreboardPlayerStatBG_{i}_{c}\n\t{{\n')
        w('\t\tControlName\t\tImagePanel\n')
        w('\t\timage\t\t\t"vgui/hud/white"\n')
        w('\t\tfg_image\t\t"vgui/hud/white"\n')
        w('\t\tdrawColor\t\t"80 80 80 160"\n')
        w('\t\tscaleImage\t\t1\n')
        w(f'\t\txpos\t\t\t{col_x(c)}\n')
        w(f'\t\typos\t\t\t{y}\n')
        w(f'\t\twide\t\t\t{STAT_COL_W}\n')
        w(f'\t\ttall\t\t\t{ROW_H}\n')
        w('\t\tvisible\t\t\t0\n')
        w('\t}\n\n')

        w(f'\tcScoreboardPlayerStat_{i}_{c}\n\t{{\n')
        w('\t\tControlName\t\tLabel\n')
        w(f'\t\txpos\t\t\t{col_x(c)}\n')
        w(f'\t\typos\t\t\t{y}\n')
        w(f'\t\twide\t\t\t{STAT_COL_W}\n')
        w(f'\t\ttall\t\t\t{ROW_H}\n')
        w('\t\tvisible\t\t\t0\n')
        w('\t\tenabled\t\t\t1\n')
        w('\t\tlabelText\t\t""\n')
        w('\t\ttextAlignment\teast\n')
        w('\t\tfont\t\t\tcScoreboardStatFixed\n')
        w('\t\tfgcolor\t\t\t"255 255 255 255"\n')
        w('\t\twrap\t\t\t0\n')
        w('\t}\n\n')

w('}\n')

content = out.getvalue()

# Relative to this script's own location (package root) rather than a
# hardcoded absolute drive path, so this still works if the whole package
# folder ever gets moved/copied elsewhere.
package_root = os.path.dirname(os.path.abspath(__file__))
path = os.path.join(package_root, "mods", "Atlas418.CustomScoreboard", "keyvalues", "resource", "ui", "hudscoreboard.res")
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w", newline="\n") as f:
    f.write(content)

print("wrote", len(content), "bytes to", path)
print("box:", BOX_X, BOX_Y, BOX_W, BOX_H, "bottom=", BOX_Y+BOX_H)
