set -eu

if [ $# -ne 1 ]; then
    echo "Usage: $0 <path-to-experiment-json>"
    exit 1
fi

EXP_PATH=$1

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

# Validate that commit exists and has been pushed to the repository
# Get the directory containing the experiment file (should be in git repo)
EXP_DIR=$(dirname "$(realpath "$EXP_PATH")")
cd "$EXP_DIR"
# Check if commit exists locally
if ! git cat-file -e "$COMMIT_HASH" 2>/dev/null; then
    echo -e "${RED}ERROR: Commit ${COMMIT_HASH} does not exist locally${NC}"
    echo -e"${RED}Please ensure the commit hash is correct.${NC}"
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