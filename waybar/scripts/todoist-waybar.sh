#!/bin/bash

# Todoist Waybar Component - Main Script
# Fetches tasks from Todoist API and outputs JSON for waybar

CONFIG_FILE="$HOME/.config/waybar/todoist.conf"
CACHE_FILE="$HOME/.config/waybar/.todoist-cache.json"
CACHE_AGE=30  # Cache for 30 seconds

# Load configuration
if [ ! -f "$CONFIG_FILE" ]; then
    echo '{"text":"⚠️","tooltip":"Todoist config not found","class":"error"}'
    exit 1
fi

source "$CONFIG_FILE"

# Check if API token is set
if [ -z "$API_TOKEN" ]; then
    echo '{"text":"⚠️","tooltip":"Todoist API token not configured","class":"error"}'
    exit 1
fi

# Use cache if recent enough
if [ -f "$CACHE_FILE" ]; then
    cache_time=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
    current_time=$(date +%s)
    age=$((current_time - cache_time))
    
    if [ $age -lt $CACHE_AGE ]; then
        cat "$CACHE_FILE"
        exit 0
    fi
fi

# Get tasks from Todoist API
API_URL="https://api.todoist.com/rest/v2/tasks"
HEADERS=(-H "Authorization: Bearer $API_TOKEN")

# Fetch tasks
response=$(curl -s -w "\n%{http_code}" "${HEADERS[@]}" "$API_URL")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

# Check for errors
if [ "$http_code" != "200" ]; then
    error_msg="API Error: $http_code"
    if command -v jq &> /dev/null && [ -n "$body" ]; then
        error_msg=$(echo "$body" | jq -r '.error // .message // "Unknown error"' 2>/dev/null || echo "Error $http_code")
    fi
    # Escape quotes for JSON
    error_msg=$(echo "$error_msg" | sed 's/"/\\"/g')
    echo "{\"text\":\"⚠️\",\"tooltip\":\"$error_msg\",\"class\":\"error\"}"
    exit 1
fi

# Get project ID if not set (use Inbox)
if [ -z "$PROJECT_ID" ]; then
    # Fetch projects to find Inbox
    projects_response=$(curl -s "${HEADERS[@]}" "https://api.todoist.com/rest/v2/projects")
    if command -v jq &> /dev/null; then
        PROJECT_ID=$(echo "$projects_response" | jq -r '.[] | select(.name == "Inbox") | .id' | head -n1)
    fi
fi

# Filter tasks by project if PROJECT_ID is set
if [ -n "$PROJECT_ID" ] && command -v jq &> /dev/null; then
    tasks=$(echo "$body" | jq -c --arg project_id "$PROJECT_ID" '[.[] | select(.project_id == $project_id)]')
else
    tasks="$body"
fi

# Parse tasks and create tooltip
if ! command -v jq &> /dev/null; then
    echo '{"text":"⚠️","tooltip":"jq is required but not installed","class":"error"}'
    exit 1
fi

task_count=$(echo "$tasks" | jq 'length')
task_limit=${TASK_LIMIT:-10}

# Create tooltip with today's tasks only
current_date=$(date +%Y-%m-%d)
today_tasks=$(echo "$tasks" | jq --arg today "$current_date" '[.[] | select(.due != null and .due.date == $today)]')
today_task_count=$(echo "$today_tasks" | jq 'length')

# Check for overdue tasks first
overdue_count=$(echo "$tasks" | jq -r --arg today "$current_date" '[.[] | select(.due != null and .due.date < $today)] | length')

if [ "$today_task_count" -eq 0 ]; then
    tooltip="No tasks for today"
    text="✓ 0"
    class="empty"
else
    # Get task list for tooltip (today's tasks only)
    todays_task_list=$(echo "$today_tasks" | jq -r ".[0:$task_limit] | .[] | \"\(.content)\"" | sed 's/"/\\"/g')
    if [ "$today_task_count" -gt "$task_limit" ]; then
        remaining=$((today_task_count - task_limit))
        tooltip="${todays_task_list}\n... and $remaining more"
    else
        tooltip="$todays_task_list"
    fi

    text="📋 $today_task_count"
    class="normal"
fi

# Override with urgent status if there are overdue tasks
if [ "$overdue_count" -gt 0 ]; then
    class="urgent"
    text="🔴 $today_task_count"
fi

# Create JSON output
output=$(jq -n \
    --arg text "$text" \
    --arg tooltip "$tooltip" \
    --arg class "$class" \
    '{text: $text, tooltip: $tooltip, class: $class}')

# Cache the result
echo "$output" | jq -c . > "$CACHE_FILE"

# Output for waybar
echo "$output" | jq -c .

