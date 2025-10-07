#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Get inputs from the environment
GITHUB_TOKEN="$1"
REPOSITORY="$2"
PR_NUMBER="$3"
OPENAI_API_KEY="$4"

# Function to fetch the pull request details from GitHub API in unidiff format
fetch_pr_details() {
    curl -s -H "Authorization: token $GITHUB_TOKEN" \
         -H "Accept: application/vnd.github.v3.diff" \
         "https://api.github.com/repos/$REPOSITORY/pulls/$PR_NUMBER"
}

# Function to send prompt to the ChatGPT model (OpenAI API)
send_prompt_to_chatgpt() {
curl -s -X POST "https://api.openai.com/v1/chat/completions" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\": \"gpt-4o-mini\", \"messages\": $MESSAGES_JSON, \"max_tokens\": 500}"
}


# Function to save code snippet to file
save_to_file() {
    #  the script will save the code snippets to files in a directory named "autocoder-bot" with the filename specified in the JSON object.
    local filename="autocoder-bot/$1"
    local code_snippet="$2"

    mkdir -p "$(dirname "$filename")"
    echo -e "$code_snippet" > "$filename"
    echo "The code has been written to $filename"
}

# Fetch and process issue details
RESPONSE=$(fetch_pr_details)
PR_BODY=$(echo "$RESPONSE" | jq -r .body)
echo $PR_BODY
if [[ -z "$PR_BODY" ]]; then
    echo 'PR body is empty or not found in the response.'
    exit 1
fi

# Define clear, additional instructions for GPT regarding the response format
INSTRUCTIONS="You are a highly skilled software engineer specializing in code reviews. Your task is to review code changes in a unidiff format. Ensure your feedback is constructive and professional. Present it in markdown format, and refrain from mentioning: - Adding comments or documentation - Adding dependencies or related pull requests"

# Prepare the messages array for the ChatGPT API, including the instructions
MESSAGES_JSON=$(jq -n --arg body "$PR_BODY" --arg system "$INSTRUCTIONS" '[{"role":"system", "content": $system}, {"role": "user", "content": $body}]')

# Send the prompt to the ChatGPT model
RESPONSE=$(send_prompt_to_chatgpt)

if [[ -z "$RESPONSE" ]]; then
    echo "No response received from the OpenAI API."
    exit 1
fi


#write the response as a new comment on the PR
curl -s -H "Authorization: token $GITHUB_TOKEN" \
     -X POST \
     -H "Accept: application/vnd.github.v3+json" \
     -d "{\"body\": \"$COMMENT_BODY\"}" \
     "https://api.github.com/repos/$REPOSITORY/issues/$PR_NUMBER/comments"

echo "PR has been commented Successfully"
