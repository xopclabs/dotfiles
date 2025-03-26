# Default commands:
# For files: use bat with syntax highlighting.
# For directories: use eza to list directory contents.
file_cmd='bat --color=always --style=numbers --line-range=:500 {}'
dir_cmd='eza -1 --color=always --icons=always {}'

# Parse options to override default commands.
while [[ "$1" == --* ]]; do
    case "$1" in
        --file)
            file_cmd="$2"
            shift 2
            ;;
        --dir)
            dir_cmd="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Usage: $0 [--file <file_command>] [--dir <dir_command>] <path>"
            exit 1
            ;;
    esac
done

# Ensure that one argument (the path) remains.
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 [--file <file_command>] [--dir <dir_command>] <path>"
    exit 1
fi

target="$1"

# Determine whether the target is a directory or a file.
if [ -d "$target" ]; then
    # Substitute the placeholder "{}" with the target path.
    preview_cmd="${dir_cmd//\{\}/$target}"
elif [ -f "$target" ]; then
    preview_cmd="${file_cmd//\{\}/$target}"
else
    echo "Error: '$target' is neither a regular file nor a directory." >&2
    exit 1
fi

# Execute the resulting command.
eval "$preview_cmd"

