#!/bin/bash

# Todoist Waybar Component - Interactive Menu Script
# Provides rofi menu for viewing, editing, and completing tasks

CONFIG_FILE="$HOME/.config/waybar/todoist.conf"

# Load configuration
if [ ! -f "$CONFIG_FILE" ]; then
    notify-send "Todoist" "Configuration file not found" -u critical
    exit 1
fi

source "$CONFIG_FILE"

# Check if API token is set
if [ -z "$API_TOKEN" ]; then
    notify-send "Todoist" "API token not configured. Please set it in $CONFIG_FILE" -u critical
    exit 1
fi

API_URL="https://api.todoist.com/rest/v2/tasks"
HEADERS=(-H "Authorization: Bearer $API_TOKEN")

# Get project ID if not set (use Inbox)
if [ -z "$PROJECT_ID" ]; then
    projects_response=$(curl -s "${HEADERS[@]}" "https://api.todoist.com/rest/v2/projects")
    if command -v jq &> /dev/null; then
        PROJECT_ID=$(echo "$projects_response" | jq -r '.[] | select(.name == "Inbox") | .id' | head -n1)
        PROJECT_NAME="Inbox"
    else
        notify-send "Todoist" "jq is required but not installed" -u critical
        exit 1
    fi
else
    # Get project name
    projects_response=$(curl -s "${HEADERS[@]}" "https://api.todoist.com/rest/v2/projects")
    PROJECT_NAME=$(echo "$projects_response" | jq -r --arg id "$PROJECT_ID" '.[] | select(.id == $id) | .name' | head -n1)
fi

# Fetch tasks
response=$(curl -s -w "\n%{http_code}" "${HEADERS[@]}" "$API_URL")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" != "200" ]; then
    error_msg="API Error: $http_code"
    if [ -n "$body" ]; then
        error_msg=$(echo "$body" | jq -r '.error // .message // "Unknown error"' 2>/dev/null || echo "Error $http_code")
    fi
    notify-send "Todoist" "$error_msg" -u critical
    exit 1
fi

# Filter tasks by project
if [ -n "$PROJECT_ID" ]; then
    tasks=$(echo "$body" | jq -c --arg project_id "$PROJECT_ID" '[.[] | select(.project_id == $project_id)]')
else
    tasks="$body"
fi

task_count=$(echo "$tasks" | jq 'length')

# Create menu options
menu_options=()

# Add header with project info
if [ -n "$PROJECT_NAME" ]; then
    menu_options+=("$PROJECT_NAME ($task_count tasks)")
    menu_options+=("")
fi

# Add tasks
if [ "$task_count" -eq 0 ]; then
    menu_options+=("✓ No tasks in this project")
else
    while IFS= read -r task; do
        task_id=$(echo "$task" | jq -r '.id')
        task_content=$(echo "$task" | jq -r '.content')
        task_due=$(echo "$task" | jq -r '.due.date // empty')
        
        # Format due date
        if [ -n "$task_due" ]; then
            # Parse date and format
            due_date=$(echo "$task_due" | cut -d'T' -f1)
            current_date=$(date +%Y-%m-%d)
            if [ "$due_date" = "$current_date" ]; then
                due_str=" (Today)"
            elif [ "$due_date" < "$current_date" ]; then
                due_str=" (Overdue: $due_date)"
            else
                due_str=" (Due: $due_date)"
            fi
        else
            due_str=""
        fi
        
        # Escape special characters for rofi
        task_display=$(echo "$task_content$due_str" | sed 's/|/\\|/g')
        menu_options+=("$task_id|$task_display")
    done < <(echo "$tasks" | jq -c '.[]')
fi

# Add separator and actions
menu_options+=("")
menu_options+=("➕ Add Task")
menu_options+=("🔄 Refresh")
menu_options+=("🌐 Open Todoist App")
menu_options+=("📂 Switch Project")

# Display menu using rofi
selected=$(printf '%s\n' "${menu_options[@]}" | rofi -dmenu -i -p "Todoist" -format 's' 2>/dev/null)

if [ -z "$selected" ]; then
    exit 0
fi

# Handle selection
if echo "$selected" | grep -q "^📁\|^✓\|^$"; then
    # Header or empty task list, do nothing
    exit 0
elif echo "$selected" | grep -q "^➕"; then
    # Add task
    new_task=$(rofi -dmenu -p "New task:" 2>/dev/null)
    if [ -n "$new_task" ]; then
        # Create task via API
        project_id_param="$PROJECT_ID"
        if [ -z "$project_id_param" ]; then
            # Get Inbox project ID
            projects_response=$(curl -s "${HEADERS[@]}" "https://api.todoist.com/rest/v2/projects")
            project_id_param=$(echo "$projects_response" | jq -r '.[] | select(.name == "Inbox") | .id' | head -n1)
        fi
        
        task_data=$(jq -n \
            --arg content "$new_task" \
            --arg project_id "$project_id_param" \
            '{content: $content, project_id: $project_id}')
        
        result=$(curl -s -w "\n%{http_code}" \
            -X POST "${HEADERS[@]}" \
            -H "Content-Type: application/json" \
            -d "$task_data" \
            "$API_URL")
        
        http_code=$(echo "$result" | tail -n1)
        if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
            notify-send "Todoist" "Task added successfully" -u low
            # Invalidate cache
            rm -f "$HOME/.config/waybar/.todoist-cache.json"
            # Send signal to waybar to refresh (if waybar is running)
            pkill -RTMIN+9 waybar 2>/dev/null || true
        else
            notify-send "Todoist" "Failed to add task" -u critical
        fi
    fi
elif echo "$selected" | grep -q "^🔄"; then
    # Refresh - invalidate cache
    rm -f "$HOME/.config/waybar/.todoist-cache.json"
    pkill -RTMIN+9 waybar 2>/dev/null || true
    notify-send "Todoist" "Refreshing..." -u low
elif echo "$selected" | grep -q "^🌐"; then
    # Open Todoist app
    eval "$TODOIST_APP_CMD"
elif echo "$selected" | grep -q "^📂"; then
    # Switch project - fetch all projects and let user select
    projects_response=$(curl -s "${HEADERS[@]}" "https://api.todoist.com/rest/v2/projects")
    project_list=$(echo "$projects_response" | jq -r '.[] | "\(.id)|\(.name)"')
    
    selected_project=$(printf '%s\n' "$project_list" | rofi -dmenu -i -p "Select project:" -format 's' 2>/dev/null)
    
    if [ -n "$selected_project" ]; then
        new_project_id=$(echo "$selected_project" | cut -d'|' -f1)
        # Update config file
        if grep -q "^PROJECT_ID=" "$CONFIG_FILE"; then
            sed -i "s|^PROJECT_ID=.*|PROJECT_ID=\"$new_project_id\"|" "$CONFIG_FILE"
        else
            echo "PROJECT_ID=\"$new_project_id\"" >> "$CONFIG_FILE"
        fi
        notify-send "Todoist" "Project switched" -u low
        # Refresh cache
        rm -f "$HOME/.config/waybar/.todoist-cache.json"
        pkill -RTMIN+9 waybar 2>/dev/null || true
    fi
elif echo "$selected" | grep -q "|"; then
    # Task selected - show action menu
    task_id=$(echo "$selected" | cut -d'|' -f1)
    task_content=$(echo "$selected" | cut -d'|' -f2- | sed 's/\\|/|/g')
    
    action=$(printf '%s\n' "✓ Complete" "✏️ Edit" "📋 View Details" | rofi -dmenu -i -p "$task_content" 2>/dev/null)
    
    if [ -z "$action" ]; then
        exit 0
    fi
    
    if echo "$action" | grep -q "Complete"; then
        # Complete task
        result=$(curl -s -w "\n%{http_code}" \
            -X POST "${HEADERS[@]}" \
            "https://api.todoist.com/rest/v2/tasks/$task_id/close")
        
        http_code=$(echo "$result" | tail -n1)
        if [ "$http_code" = "204" ]; then
            notify-send "Todoist" "Task completed" -u low
            # Invalidate cache
            rm -f "$HOME/.config/waybar/.todoist-cache.json"
            pkill -RTMIN+9 waybar 2>/dev/null || true
        else
            notify-send "Todoist" "Failed to complete task" -u critical
        fi
    elif echo "$action" | grep -q "Edit"; then
        # Edit task
        new_content=$(echo "$task_content" | sed 's/ (.*//' | rofi -dmenu -p "Edit task:" 2>/dev/null)
        
        if [ -n "$new_content" ]; then
            task_data=$(jq -n --arg content "$new_content" '{content: $content}')
            
            result=$(curl -s -w "\n%{http_code}" \
                -X POST "${HEADERS[@]}" \
                -H "Content-Type: application/json" \
                -d "$task_data" \
                "https://api.todoist.com/rest/v2/tasks/$task_id")
            
            http_code=$(echo "$result" | tail -n1)
            if [ "$http_code" = "200" ] || [ "$http_code" = "204" ]; then
                notify-send "Todoist" "Task updated" -u low
                rm -f "$HOME/.config/waybar/.todoist-cache.json"
                pkill -RTMIN+9 waybar 2>/dev/null || true
            else
                notify-send "Todoist" "Failed to update task" -u critical
            fi
        fi
    elif echo "$action" | grep -q "View Details"; then
        # View task details
        task_details=$(echo "$tasks" | jq -r --arg id "$task_id" '.[] | select(.id == $id)')
        task_info=$(echo "$task_details" | jq -r '
            "Task: \(.content)\n" +
            (if .description != null and .description != "" then "Description: \(.description)\n" else "" end) +
            (if .due != null then "Due: \(.due.date)\n" else "" end) +
            (if .priority > 1 then "Priority: \(.priority)\n" else "" end)
        ')
        rofi -e "$task_info" 2>/dev/null || notify-send "Todoist" "$task_info" -u low
    fi
fi

