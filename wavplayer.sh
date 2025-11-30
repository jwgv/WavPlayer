#!/bin/bash
# If you prefer explicit brew bash, change to: #!/opt/homebrew/bin/bash

# 🎵WavPlayer 🎵 (Random + Ordered + Favorites + Visuals)
# ── DIRECTORY PRECEDENCE ─────────────────────
# 1. Command-line directory argument → ./wavplayer.sh [options] ~/Downloads
# 2. ~/.config/wavplayer/config (if it exists) → ~/your/tracks
# 3. Fallback → $HOME/Music
#
# Options:
#   -r, --random          random playback (no immediate repeats)
#   -f, --favorites       play favorites (ignore DIR; use favorites file)
#   -v, --visual          enable visualizer (multi-color)
#       --visual-mono C   visualizer in single color (red|green|yellow|blue|orange|pink|purple)
#   -h, --help            show usage

set -euo pipefail

# ── Colors (ANSI C escapes) ─────────────────────────────
R=$'\033[0m'
BOLD=$'\033[1m'
RED=$'\033[38;5;196m'
GREEN=$'\033[38;5;82m'
YELLOW=$'\033[38;5;226m'
BLUE=$'\033[38;5;45m'
ORANGE=$'\033[38;5;208m'
PINK=$'\033[38;5;213m'
PURPLE=$'\033[38;5;141m'

# ── Config paths ─────────────────────────────────────
CONFIG_FILE="$HOME/.config/wavplayer/config"
DEFAULT_DIR="$HOME/Music"
CONFIG_DIR="$HOME/.config/wavplayer"
FAV_FILE="$CONFIG_DIR/favorites"

mkdir -p "$CONFIG_DIR"

# ── Flags and CLI parsing ─────────────────────────────
RANDOM_MODE=0
FAVORITES_ONLY=0
VISUAL_MODE=0
VISUAL_COLOR_MODE="multi"   # "multi" or "mono"
VISUAL_MONO_COLOR="$PINK"
DIR_OVERRIDE=""

# Visualizer color state (for stable per-band colors in multi-color mode)
VISUAL_BANDS_CURRENT=0
VISUAL_BAND_COLORS=()

usage() {
    cat <<EOF
Usage: $(basename "$0") [options] [music_directory]

Options:
  -r, --random          Play in random order (no immediate repeats)
  -f, --favorites       Play only favorited tracks (from $FAV_FILE)
  -v, --visual          Enable visualizer (multi-color)
      --visual-mono C   Visualizer in single color C
                        C ∈ {red,green,yellow,blue,orange,pink,purple}
  -h, --help            Show this help

Directory precedence:
  1. Explicit directory argument
  2. $CONFIG_FILE (first non-comment line)
  3. $DEFAULT_DIR
EOF
}

# Map color name to escape
set_visual_mono_color() {
    case "$1" in
        red)    VISUAL_MONO_COLOR="$RED" ;;
        green)  VISUAL_MONO_COLOR="$GREEN" ;;
        yellow) VISUAL_MONO_COLOR="$YELLOW" ;;
        blue)   VISUAL_MONO_COLOR="$BLUE" ;;
        orange) VISUAL_MONO_COLOR="$ORANGE" ;;
        pink)   VISUAL_MONO_COLOR="$PINK" ;;
        purple) VISUAL_MONO_COLOR="$PURPLE" ;;
        *)
            echo -e "${YELLOW}Unknown visual color '$1', defaulting to pink.${R}"
            VISUAL_MONO_COLOR="$PINK"
            ;;
    esac
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -r|--random) RANDOM_MODE=1 ;;
        -f|--favorites) FAVORITES_ONLY=1 ;;
        -v|--visual)
            VISUAL_MODE=1
            VISUAL_COLOR_MODE="multi"
            ;;
        --visual-mono)
            shift
            if [[ $# -eq 0 ]]; then
                echo -e "${RED}--visual-mono requires a color argument.${R}"
                usage
                exit 1
            fi
            VISUAL_MODE=1
            VISUAL_COLOR_MODE="mono"
            set_visual_mono_color "$1"
            ;;
        -h|--help) usage; exit 0 ;;
        --) shift; break ;;
        -*)
            echo -e "${RED}Unknown option: $1${R}"
            usage
            exit 1
            ;;
        *)
            # First non-flag argument → directory override
            if [[ -z "$DIR_OVERRIDE" ]]; then
                DIR_OVERRIDE="$1"
            else
                echo -e "${RED}Unexpected extra argument: $1${R}"
                usage
                exit 1
            fi
            ;;
    esac
    shift
done

# ── Resolve directory precedence (used when NOT in favorites-only mode) ─────
if [[ -n "$DIR_OVERRIDE" ]]; then
    DIR="$DIR_OVERRIDE"
elif [[ -f "$CONFIG_FILE" ]]; then
    DIR=$(grep -v '^[[:space:]]*$' "$CONFIG_FILE" | grep -v '^[[:space:]]*[#;]' | head -n1 | xargs)
    DIR="${DIR:-$DEFAULT_DIR}"
else
    DIR="$DEFAULT_DIR"
fi
DIR="${DIR/#\~/$HOME}"

if [[ "$FAVORITES_ONLY" -eq 0 ]]; then
    [ -d "$DIR" ] || { echo -e "${RED}Error: Directory not found → $DIR${R}"; exit 1; }
fi

clear
echo -e "${PURPLE}🎵 WavPlayer 🎵 ${PINK}v1.0-beta1${R}"
if [[ "$FAVORITES_ONLY" -eq 1 ]]; then
    echo -e "${YELLOW}Mode: ${GREEN}Favorites only${R}"
else
    echo -e "${YELLOW}Playing from: ${GREEN}${DIR}${R}"
fi
[[ "$RANDOM_MODE" -eq 1 ]] && echo -e "${YELLOW}Playback: ${GREEN}Random (no immediate repeats)${R}" || echo -e "${YELLOW}Playback: ${GREEN}Alphabetical order${R}"

if [[ "$VISUAL_MODE" -eq 1 ]]; then
    if [[ "$VISUAL_COLOR_MODE" == "mono" ]]; then
        echo -e "${YELLOW}Visuals: ${GREEN}ON (mono color)${R}"
    else
        echo -e "${YELLOW}Visuals: ${GREEN}ON (multi-color)${R}"
    fi
else
    echo -e "${YELLOW}Visuals: ${RED}OFF${R}"
fi

# Colored controls
echo -e "${YELLOW}Controls:${R} \
${RED}q${R} = quit • \
${GREEN}p/space${R} = pause/resume • \
${BLUE}r${R} = replay • \
${PINK}f${R} = favorite toggle • \
${YELLOW}any other key${R} = skip\n"

# ── Fun messages to display during song playback ─────────────────
fun_messages=(
    "Vibes are off the charts! 🚀"
    "You’re in for a treat! 🍬"
    "Can you feel the groove? 💃"
    "This track's a straight-up vibe! 🌟"
    "Total ear candy! 🍭"
    "Hitting the right notes! 🎶"
    "Chef’s kiss! 😘"
    "Pure magic right here! ✨"
    "This track is a legend in the making! 🏆"
    "We’re in the zone! ⚡"
    "Let the music take you places 🌍"
)

animate() {
    local text="$1"
    local pink=$(tput setaf 5)
    local bright=$(tput bold)
    local reset=$(tput sgr0)

    for ((i=1; i<=${#text}; i++)); do
        printf "%s" "${pink}${bright}${text:0:i}"
        sleep 0.03
        printf "\r"
    done
    printf "%s\n" "${pink}${bright}${text}${reset}"
}

# ── Metadata helpers (Artist/Album) ───────────────────────────────
# Try to get artist/album from media tags via ffprobe; fall back to path inference.
trim() {
    local s="$*"
    # shellcheck disable=SC2001
    s=$(sed -e 's/^\s\+//' -e 's/\s\+$//' <<<"$s")
    printf '%s' "$s"
}

ffprobe_tag() {
    local file="$1"; shift
    local tag="$1"
    command -v ffprobe >/dev/null 2>&1 || { printf ''; return; }
    ffprobe -v error -show_entries "format_tags=${tag}" -of default=nw=1:nk=1 "$file" 2>/dev/null | head -n1
}

infer_artist_album_from_path() {
    local file="$1"
    local parent grandparent artist album
    parent=$(basename -- "$(dirname -- "$file")")
    grandparent=$(basename -- "$(dirname -- "$(dirname -- "$file")")")

    # Heuristics:
    # 1) If parent looks like "Artist - Album" (common), split it.
    if [[ "$parent" == *" - "* ]]; then
        artist="${parent%% - *}"
        album="${parent#* - }"
    else
        # 2) Use grandparent as artist, parent as album if grandparent is non-trivial
        artist="$grandparent"
        album="$parent"
    fi

    artist=$(trim "$artist")
    album=$(trim "$album")
    printf '%s\t%s' "$artist" "$album"
}

get_artist_album() {
    local file="$1"
    local artist album

    # Prefer tags via ffprobe if available
    artist=$(ffprobe_tag "$file" artist)
    album=$(ffprobe_tag "$file" album)

    artist=$(trim "$artist")
    album=$(trim "$album")

    if [[ -z "$artist" && -z "$album" ]]; then
        # Fallback to path inference
        IFS=$'\t' read -r artist album < <(infer_artist_album_from_path "$file")
    fi

    printf '%s\t%s' "$artist" "$album"
}

# Get title from metadata (via ffprobe). Returns empty if unavailable.
get_title() {
    local file="$1"
    local title
    title=$(ffprobe_tag "$file" title)
    title=$(trim "$title")
    printf '%s' "$title"
}

# ── Favorites helpers ────────────────────────────────────────────
is_favorite() {
    local track="$1"
    [[ -f "$FAV_FILE" ]] && grep -Fxq -- "$track" "$FAV_FILE"
}

toggle_favorite() {
    local track="$1"
    mkdir -p "$CONFIG_DIR"
    touch "$FAV_FILE"

    if is_favorite "$track"; then
        # Remove from favorites
        grep -Fxv -- "$track" "$FAV_FILE" > "${FAV_FILE}.tmp" || true
        mv "${FAV_FILE}.tmp" "$FAV_FILE"
        return 1  # removed
    else
        printf '%s\n' "$track" >> "$FAV_FILE"
        return 0  # added
    fi
}

load_favorites_playlist() {
    # fills global "files" array with favorites that still exist
    files=()
    [[ -f "$FAV_FILE" ]] || return
    while IFS= read -r line; do
        [[ -n "$line" && -f "$line" ]] && files+=("$line")
    done < "$FAV_FILE"
}

# ── Playback + Visual helpers ────────────────────────────────────
PID=""
BAR_WIDTH=30

# Initialize stable per-band colors for the visualizer (per track)
init_visual_band_colors() {
    local bands="$1"
    VISUAL_BANDS_CURRENT="$bands"
    VISUAL_BAND_COLORS=()

    local palette=("$RED" "$GREEN" "$YELLOW" "$BLUE" "$ORANGE" "$PINK" "$PURPLE")
    local i
    for ((i=0; i<bands; i++)); do
        VISUAL_BAND_COLORS+=("${palette[$((RANDOM % ${#palette[@]}))]}")
    done
}

# Playback with optional offset (in seconds, integer)
playback() {
    local file="$1"
    local offset="${2:-0}"
    local off_int=${offset%.*}
    (( off_int < 0 )) && off_int=0

    # Use ffmpeg → sox/play for all formats so we can seek
    if (( off_int > 0 )); then
        ffmpeg -hide_banner -loglevel error -ss "$off_int" -i "$file" -f sox - 2>/dev/null | \
            play -t sox - -q gain -n -1 rate -h 2>/dev/null &
    else
        ffmpeg -hide_banner -loglevel error -i "$file" -f sox - 2>/dev/null | \
            play -t sox - -q gain -n -1 rate -h 2>/dev/null &
    fi

    PID=$!
    disown "$PID"
}

generate_visual() {
    # pct: 0-100, bands: number of bands (fixed to 8 here)
    local pct="$1"
    local bands="$2"
    (( bands <= 0 )) && { printf ""; return; }

    local pattern=("▁" "▂" "▃" "▄" "▅" "▆" "▇" "█")
    local max_level=$(( ${#pattern[@]} - 1 ))

    local base_level=$(( pct * max_level / 100 ))
    (( base_level < 0 )) && base_level=0
    (( base_level > max_level )) && base_level=$max_level

    # Ensure band colors are initialized for this band count in multi-color mode
    if [[ "$VISUAL_COLOR_MODE" == "multi" ]]; then
        if (( VISUAL_BANDS_CURRENT != bands )) || (( ${#VISUAL_BAND_COLORS[@]} != bands )); then
            init_visual_band_colors "$bands"
        fi
    fi

    local out=""
    local i
    for ((i=0; i<bands; i++)); do
        local delta=$(( (RANDOM % 5) - 2 ))   # -2..+2 for slight wiggle
        local level=$(( base_level + delta ))
        (( level < 0 )) && level=0
        (( level > max_level )) && level=$max_level

        local color
        if [[ "$VISUAL_COLOR_MODE" == "mono" ]]; then
            color="$VISUAL_MONO_COLOR"
        else
            # Stable per-band color
            color="${VISUAL_BAND_COLORS[$i]}"
        fi

        out+="${color}${pattern[$level]}${R} "
    done
    printf "%s" "$out"
}

# Put terminal in raw-ish mode: no echo, no canonical; chars delivered immediately
stty -echo -icanon time 0 min 0
# Hide cursor
tput civis 2>/dev/null || printf '\033[?25l'

on_exit() {
    stty sane
    tput cnorm 2>/dev/null || printf '\033[?25h'
    if [[ -n "${PID:-}" ]]; then
        kill "$PID" 2>/dev/null || true
    fi
}

trap 'on_exit; exit 1' INT TERM
trap 'on_exit' EXIT

REPLAY=0
last_played=""
current_index=0
no_files_retries=0

while :; do
    # ── Choose track (respect REPLAY, favorites, random, alphabetical) ───────
    if [[ "$REPLAY" -eq 0 ]]; then
        files=()

        if [[ "$FAVORITES_ONLY" -eq 1 ]]; then
            load_favorites_playlist
            if (( ${#files[@]} == 0 )); then
                echo -e "${RED}No valid favorites found in ${FAV_FILE}.${R}"
                echo -e "${YELLOW}Add favorites with 'f' during playback, then restart with -f.${R}"
                (( no_files_retries++ ))
                if (( no_files_retries >= 3 )); then
                    echo -e "${RED}No playable files found after 3 retries. Exiting.${R}"
                    exit 1
                fi
                sleep 5
                continue
            fi
        else
            while IFS= read -r -d '' f; do files+=("$f"); done < \
                <(find -L "$DIR" -type f \( -iname "*.wav" -o -iname "*.aiff" -o -iname "*.mp3" -o -iname "*.m4a" -o -iname "*.aac" -o -iname "*.aifc" -o -iname "*.flac" -o -iname "*.ogg" \) -print0 2>/dev/null | sort -z)
            if (( ${#files[@]} == 0 )); then
                echo -e "${RED}No files – retrying in 5s…${R}"
                (( no_files_retries++ ))
                if (( no_files_retries >= 3 )); then
                    echo -e "${RED}No playable files found after 3 retries. Exiting.${R}"
                    exit 1
                fi
                sleep 5
                continue
            fi
        fi

        # Reset retry counter once we have files to play
        no_files_retries=0

        if [[ "$RANDOM_MODE" -eq 1 ]]; then
            if (( ${#files[@]} == 1 )); then
                local_idx=0
            else
                while :; do
                    local_idx=$((RANDOM % ${#files[@]}))
                    [[ "${files[$local_idx]}" != "$last_played" ]] && break
                done
            fi
        else
            (( current_index >= ${#files[@]} )) && current_index=0
            local_idx=$current_index
            current_index=$(( (current_index + 1) % ${#files[@]} ))
        fi

        sfile="${files[$local_idx]}"
        last_played="$sfile"

        # ── DURATION using mac-native afinfo ─────────────────────────
        duration_raw=$(afinfo "$sfile" 2>/dev/null | grep "duration" | awk '{print $3}' 2>/dev/null || echo "")
        if [[ $duration_raw =~ ^[0-9]+([.][0-9]+)?$ ]]; then
            secs=$(printf "%.0f" "$duration_raw")
        else
            secs=0
        fi

        if (( secs > 0 )); then
            fmt=$(printf "%02d:%02d" $((secs/60)) $((secs%60)))
        else
            fmt="--:--"
        fi

        # Initialize stable per-band colors per track (for multi-color mode)
        if [[ "$VISUAL_MODE" -eq 1 && "$VISUAL_COLOR_MODE" == "multi" ]]; then
            init_visual_band_colors 8
        fi
    fi

    REPLAY=0

    name="$(basename "$sfile")"
    # Filename without extension for cleaner fallback display
    base_name="${name%.*}"
    # Prefer embedded title (via ffprobe) when available; fallback to filename
    title="$(get_title "$sfile" || true)"
    if [[ -n "$title" ]]; then
        display_name="$title"
    else
        display_name="$base_name"
    fi

    # Favorite icon
    if is_favorite "$sfile"; then
        IS_FAVORITE=1
        FAV_ICON="★"
    else
        IS_FAVORITE=0
        FAV_ICON="☆"
    fi

    # Do NOT clear here, so the "🎵WavPlayer 🎵" header stays visible.
    echo
    echo -e "${ORANGE}Now playing:${R} ${BOLD}${GREEN}${display_name}${R} ${PINK}[$FAV_ICON]${R}"
    # Artist/Album (from metadata via ffprobe, or inferred from path)
    artist=""; album=""
    IFS=$'\t' read -r artist album < <(get_artist_album "$sfile" || true) || true
    if [[ -n "$artist" || -n "$album" ]]; then
        [[ -n "$artist" ]] && echo -e "${BLUE}Artist: ${YELLOW}${artist}${R}"
        [[ -n "$album" ]] && echo -e "${BLUE}Album:  ${YELLOW}${album}${R}"
    fi
    if [[ "$FAVORITES_ONLY" -eq 1 ]]; then
        echo -e "${BLUE}Source: ${YELLOW}Favorites list${R}"
    else
        echo -e "${BLUE}Directory: ${YELLOW}${DIR}${R}"
    fi
    echo -e "${BLUE}Duration: ${YELLOW}${fmt}${R}\n"

    animate "${fun_messages[RANDOM % ${#fun_messages[@]}]}"

    # ── Play song ───────────────────────────────────────────────
    base_offset=0      # seconds already played (accumulated over pauses)
    playback "$sfile" 0
    start_time=$(date +%s)
    PAUSED=0

    # ── Main playback loop ──────────────────────────────────────
    while :; do
        # If not paused, check if process is still alive
        if [[ "$PAUSED" -eq 0 && -n "$PID" ]]; then
            if ! kill -0 "$PID" 2>/dev/null; then
                break
            fi
        fi

        # ---- Keyboard input handling ----
        if read -t 1 -n 1 key 2>/dev/null; then
            case "$key" in
                [qQ])
                    echo -e "\n${RED}Quit – goodbye!${R}"
                    [[ -n "$PID" ]] && { kill "$PID" 2>/dev/null || true; wait "$PID" 2>/dev/null || true; }
                    exit 0
                    ;;

                "" | " " | [pP])
                    if [[ "$PAUSED" -eq 0 ]]; then
                        # Pause: compute elapsed, kill player cleanly
                        now=$(date +%s)
                        elapsed=$(( base_offset + now - start_time ))
                        (( elapsed < 0 )) && elapsed=0
                        base_offset=$elapsed

                        if [[ -n "$PID" ]]; then
                            kill "$PID" 2>/dev/null || true
                            wait "$PID" 2>/dev/null || true
                            PID=""
                        fi

                        PAUSED=1
                        echo -en "\r${YELLOW}[PAUSED] Press Space or 'p' to resume...${R}          "
                    else
                        # Resume: start new pipeline from base_offset
                        playback "$sfile" "$base_offset"
                        start_time=$(date +%s)
                        PAUSED=0
                        echo -en "\r${GREEN}Resumed.${R}                                        "
                    fi
                    continue
                    ;;

                [rR])
                    echo -e "\n${BLUE}Replaying…${R}"
                    [[ -n "$PID" ]] && { kill "$PID" 2>/dev/null || true; wait "$PID" 2>/dev/null || true; }
                    REPLAY=1
                    break
                    ;;

                [fF])
                    if toggle_favorite "$sfile"; then
                        IS_FAVORITE=1
                        FAV_ICON="★"
                        echo -e "\n${GREEN}Added to favorites.${R}"
                    else
                        IS_FAVORITE=0
                        FAV_ICON="☆"
                        echo -e "\n${YELLOW}Removed from favorites.${R}"
                    fi
                    continue
                    ;;

                *)
                    echo -e "\n${RED}Skipped! → next${R}"
                    [[ -n "$PID" ]] && { kill "$PID" 2>/dev/null || true; wait "$PID" 2>/dev/null || true; }
                    break
                    ;;
            esac
        fi

        # Skip progress updates & visuals while paused
        if [[ "$PAUSED" -eq 1 ]]; then
            continue
        fi

        # ---- Progress bar & visuals ----
        now=$(date +%s)
        elapsed=$(( base_offset + now - start_time ))
        (( elapsed < 0 )) && elapsed=0

        if (( secs > 0 )); then
            (( elapsed >= secs )) && break
            pct=$((100 * elapsed / secs))
            (( pct > 100 )) && pct=100
        else
            pct=$((100 * elapsed / 300))
            (( pct > 100 )) && pct=100
        fi

        filled=$((pct * BAR_WIDTH / 100))
        (( filled > BAR_WIDTH )) && filled=$BAR_WIDTH

        bar_filled=""
        if (( filled > 0 )); then
            bar_filled=$(printf "${GREEN}█${R}%.0s" $(seq 1 "$filled"))
        fi
        bar_empty=""
        if (( BAR_WIDTH > filled )); then
            bar_empty=$(printf ' %.0s' $(seq 1 $((BAR_WIDTH - filled))))
        fi

        bar="${BLUE}|${R}${bar_filled}${bar_empty}${BLUE}|${R}"

        visual=""
        if [[ "$VISUAL_MODE" -eq 1 ]]; then
            vbands=8   # fixed width visualizer
            visual=" "
            visual+="$(generate_visual "$pct" "$vbands")"
        fi

        if (( secs > 0 )); then
            printf "\r ${BLUE}[%02d:%02d / %s] ${YELLOW}%3d%%%s %s ${PINK}[%s]${R}%s" \
                $((elapsed/60)) $((elapsed%60)) "$fmt" "$pct" "${R}" "$bar" "$FAV_ICON" "$visual"
        else    
            t=$elapsed
            printf "\r ${BLUE}[%02d:%02d / --:--] ${YELLOW}%3d%%%s %s ${PINK}[%s]${R}%s" \
                $((t/60)) $((t%60)) "$pct" "${R}" "$bar" "$FAV_ICON" "$visual"
        fi
    done

    if [[ "$REPLAY" -eq 1 ]]; then
        continue
    fi
done
