set -eu

# Parse arguments
RESTART_MODE=false
FAILED_JOB_NAME=""
NO_UPDATE_COMMIT=false
EXP_PATH=""

print_usage() {
    echo "Usage:"
    echo "  $0 [--no-update-commit|-k] <path-to-experiment-json>"
    echo "  $0 [--no-update-commit|-k] --restart <failed-training-job-name> <path-to-experiment-json>"
}

if [ $# -eq 0 ]; then
    print_usage
    exit 1
fi

while [ $# -gt 0 ]; do
    case "$1" in
        -r|--restart)
            RESTART_MODE=true
            if [ $# -lt 3 ]; then
                print_usage
                exit 1
            fi
            FAILED_JOB_NAME="$2"
            shift 2
            ;;
        -k|--no-update-commit)
            NO_UPDATE_COMMIT=true
            shift 1
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        -*)
            echo "Unknown option: $1"
            print_usage
            exit 1
            ;;
        *)
            if [ -n "$EXP_PATH" ]; then
                echo "Unexpected extra argument: $1"
                print_usage
                exit 1
            fi
            EXP_PATH="$1"
            shift 1
            ;;
    esac
done

if [ -z "$EXP_PATH" ]; then
    print_usage
    exit 1
fi

if [ "$RESTART_MODE" = true ] && [ -z "$FAILED_JOB_NAME" ]; then
    echo "ERROR: --restart requires <failed-training-job-name>"
    print_usage
    exit 1
fi

# Extract training job name and checkpoint template path from JSON
JOB_NAME=$(jq -r '.TrainingJobName' "$EXP_PATH")
CHECKPOINT_TEMPLATE=$(jq -r '.Environment.ARG_FOR_TRAIN_FROM_VAR_REPLACE__REMOTE_CHECKPOINTS' "$EXP_PATH")

# Extract commit hash and repository URL for validation
COMMIT_HASH=$(jq -r '.Environment.COMMIT_HASH_ID' "$EXP_PATH")
REPOSITORY_URL=$(jq -r '.Environment.REPOSITORY_URL' "$EXP_PATH")

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get repo and current commit hash
EXP_DIR=$(dirname "$(realpath "$EXP_PATH")")
cd "$EXP_DIR"
CURRENT_COMMIT_HASH=$(git rev-parse HEAD)

# Restart mode: download previous experiment config, bump job name, update commit, and re-run
if [ "$RESTART_MODE" = "true" ]; then
    # Determine failed training checkpoint path from template
    FAILED_CHECKPOINT_PATH=$(echo "$CHECKPOINT_TEMPLATE" | sed "s/{{training_job_name}}/$FAILED_JOB_NAME/g")
    FAILED_CHECKPOINT_PATH=$(echo "$FAILED_CHECKPOINT_PATH" | sed 's/\/$//')

    # Find the previous experiment JSON saved in S3
    REMOTE_JSON_BASENAME=$(basename "$EXP_PATH")
    JSON_CANDIDATES=$(aws s3 ls "$FAILED_CHECKPOINT_PATH/" | awk '{print $4}' | grep -E '\.json$' || true)
    if echo "$JSON_CANDIDATES" | grep -qx "$REMOTE_JSON_BASENAME"; then
        REMOTE_EXP_JSON="$FAILED_CHECKPOINT_PATH/$REMOTE_JSON_BASENAME"
    else
        NUM_JSON=$(echo "$JSON_CANDIDATES" | sed '/^$/d' | wc -l | tr -d ' ')
        if [ "$NUM_JSON" = "1" ]; then
            REMOTE_EXP_JSON="$FAILED_CHECKPOINT_PATH/$(echo "$JSON_CANDIDATES" | head -n1)"
        else
            echo -e "${RED}ERROR: Could not determine experiment JSON in ${FAILED_CHECKPOINT_PATH}.${NC}"
            echo -e "${RED}Ensure the basename '$(basename "$EXP_PATH")' exists there or only one .json is present.${NC}"
            exit 1
        fi
    fi

    TMP_EXP=$(mktemp)

    if ! ERROR_OUTPUT=$(aws s3 cp "$REMOTE_EXP_JSON" "$TMP_EXP" 2>&1); then
        echo -e "${RED}ERROR: Failed to download experiment configuration for training ${FAILED_JOB_NAME}${NC}"
        echo -e "${RED}$ERROR_OUTPUT${NC}"
        exit 1
    fi

    OLD_COMMIT_HASH=$(jq -r '.Environment.COMMIT_HASH_ID' "$TMP_EXP")

    # Choose which commit to use based on flag
    COMMIT_TO_USE="$CURRENT_COMMIT_HASH"
    if [ "$NO_UPDATE_COMMIT" = true ]; then
        COMMIT_TO_USE="$OLD_COMMIT_HASH"
        echo -e "${YELLOW}Commit hash update disabled; keeping ${COMMIT_TO_USE}${NC}"
    else
        if [ "$CURRENT_COMMIT_HASH" = "$OLD_COMMIT_HASH" ]; then
            echo -e "${RED}ERROR: Current commit hash (${CURRENT_COMMIT_HASH}) is the same as the failed training's commit hash.${NC}"
            echo -e "${RED}Commit hash must differ for restart (use --no-update-commit to override).${NC}"
            exit 1
        fi
        echo -e "${GREEN}Updating commit hash: ${OLD_COMMIT_HASH} -> ${CURRENT_COMMIT_HASH}${NC}"
    fi

    # Validate chosen commit exists locally and is pushed to remote
    if ! git cat-file -e "$COMMIT_TO_USE" 2>/dev/null; then
        echo -e "${RED}ERROR: Commit ${COMMIT_TO_USE} does not exist locally${NC}"
        echo -e "${RED}Please ensure the commit hash is correct.${NC}"
        exit 1
    fi
    if ! git branch --remote --contains "$COMMIT_TO_USE" 2>/dev/null | grep -q .; then
        echo -e "${RED}ERROR: Commit ${COMMIT_TO_USE} has not been pushed to the remote repository${NC}"
        echo -e "${RED}Please push the commit before running training.${NC}"
        exit 1
    fi

    # Compute new training job name by incrementing the -NN suffix
    SUFFIX=$(echo "$FAILED_JOB_NAME" | sed -nE 's/^.*-([0-9]{2})$/\1/p')
    if [ -z "$SUFFIX" ]; then
        echo -e "${RED}ERROR: Training job name '${FAILED_JOB_NAME}' does not end with -NN (zero-padded 2 digits).${NC}"
        exit 1
    fi
    PREFIX=$(echo "$FAILED_JOB_NAME" | sed -nE 's/^(.*)-[0-9]{2}$/\1/p')
    NEXT_NUM=$(printf '%02d' "$((10#$SUFFIX + 1))")
    NEW_JOB_NAME="${PREFIX}-${NEXT_NUM}"

    # Update job name and commit hash in a new temp JSON
    TMP_EXP_UPDATED=$(mktemp)
    if ! jq --indent 4 --arg name "$NEW_JOB_NAME" --arg commit "$COMMIT_TO_USE" \
        '.TrainingJobName=$name | .Environment.COMMIT_HASH_ID=$commit' \
        "$TMP_EXP" > "$TMP_EXP_UPDATED"; then
        echo -e "${RED}ERROR: Failed to update experiment JSON with new job name and commit hash${NC}"
        exit 1
    fi

    # Create SageMaker training job with updated config
    if ! ERROR_OUTPUT=$(aws sagemaker create-training-job --cli-input-json file://"$TMP_EXP_UPDATED" --no-cli-pager 2>&1); then
        echo -e "${RED}ERROR: Failed to create training job${NC}"
        echo -e "${RED}$ERROR_OUTPUT${NC}"
        exit 1
    fi

    # Upload updated experiment JSON to the new S3 checkpoint directory
    CHECKPOINT_PATH=$(echo "$CHECKPOINT_TEMPLATE" | sed "s/{{training_job_name}}/$NEW_JOB_NAME/g")
    CHECKPOINT_PATH=$(echo "$CHECKPOINT_PATH" | sed 's/\/$//')
    if ! ERROR_OUTPUT=$(aws s3 cp "$TMP_EXP_UPDATED" "$CHECKPOINT_PATH/$(basename "$EXP_PATH")" 2>&1); then
        echo -e "${RED}ERROR: Failed to upload updated experiment configuration to S3${NC}"
        echo -e "${RED}$ERROR_OUTPUT${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ Restarted training '${FAILED_JOB_NAME}' as '${NEW_JOB_NAME}' successfully${NC}"
    exit 0
fi

# Normal mode
# Optionally update commit hash in provided experiment JSON before running
ORIGINAL_COMMIT_HASH="$COMMIT_HASH"
if [ "$NO_UPDATE_COMMIT" = true ]; then
    echo -e "${YELLOW}Commit hash update disabled; keeping ${COMMIT_HASH}${NC}"
else
    if [ "$COMMIT_HASH" != "$CURRENT_COMMIT_HASH" ]; then
        TMP_UPDATED=$(mktemp)
        if jq --indent 4 --arg commit "$CURRENT_COMMIT_HASH" '.Environment.COMMIT_HASH_ID=$commit' "$EXP_PATH" > "$TMP_UPDATED"; then
            mv "$TMP_UPDATED" "$EXP_PATH"
            COMMIT_HASH="$CURRENT_COMMIT_HASH"
            echo -e "${GREEN}Updated commit hash in input JSON: ${ORIGINAL_COMMIT_HASH} -> ${COMMIT_HASH}${NC}"
        else
            echo -e "${RED}ERROR: Failed to update commit hash in input JSON${NC}"
            rm -f "$TMP_UPDATED" || true
            exit 1
        fi
    else
        echo -e "${YELLOW}Commit hash already current; no update (${COMMIT_HASH})${NC}"
    fi
fi

# Validate that commit exists and has been pushed to the repository
# Check if commit exists locally
if ! git cat-file -e "$COMMIT_HASH" 2>/dev/null; then
    echo -e "${RED}ERROR: Commit ${COMMIT_HASH} does not exist locally${NC}"
    echo -e "${RED}Please ensure the commit hash is correct.${NC}"
    exit 1
fi
# Check if commit has been pushed to remote (exists in any remote branch)
if ! git branch --remote --contains "$COMMIT_HASH" 2>/dev/null | grep -q .; then
    echo -e "${RED}ERROR: Commit ${COMMIT_HASH} has not been pushed to the remote repository${NC}"
    echo -e "${RED}Please push the commit before running training.${NC}"
    exit 1
fi

# Replace placeholder with actual training job name using sed
CHECKPOINT_PATH=$(echo "$CHECKPOINT_TEMPLATE" | sed "s/{{training_job_name}}/$JOB_NAME/g")
# Strip trailing slash if present
CHECKPOINT_PATH=$(echo "$CHECKPOINT_PATH" | sed 's/\/$//')

# Create SageMaker training job
if ! ERROR_OUTPUT=$(aws sagemaker create-training-job --cli-input-json file://"$EXP_PATH" --no-cli-pager 2>&1); then
    echo -e "${RED}ERROR: Failed to create training job${NC}"
    echo -e "${RED}$ERROR_OUTPUT${NC}"
    exit 1
fi

# Upload experiment JSON to the S3 checkpoint directory
if ! ERROR_OUTPUT=$(aws s3 cp "$EXP_PATH" "$CHECKPOINT_PATH/$(basename "$EXP_PATH")" 2>&1); then
    echo -e "${RED}ERROR: Failed to upload experiment configuration to S3${NC}"
    echo -e "${RED}$ERROR_OUTPUT${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Training job created successfully${NC}"